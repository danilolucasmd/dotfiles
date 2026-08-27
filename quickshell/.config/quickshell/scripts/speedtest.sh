#!/bin/bash
# Quickshell module: the network panel's throughput test.
#
# Prints one JSON object per phase on its own line -- latency, then download,
# then upload, then done -- and each line carries the whole reading so far, so
# the panel replaces its state with the newest line rather than merging them.
# Runs once and exits; the panel starts it on `s` and nothing starts it on a
# timer, because a run saturates the link for twelve seconds -- which on a fast
# one is a gigabyte, and which the endpoint rate limits if it is asked for
# again too soon.
#
# The server is Cloudflare's own speed endpoint rather than speedtest-cli: it
# is the same host the browser tests hit, it needs no package (curl and jq are
# already here for the rest of the panel), and it answers from whichever edge
# the link is actually routed to -- which is the number worth having, since it
# is the path everything else takes too.
#
# Throughput is measured with several connections at once and their rates
# summed. One TCP stream is bounded by its own window and by whatever shaping
# sits in front of it, and on anything past ~100 Mbit it reports the stream's
# limit instead of the link's.

set -uo pipefail

endpoint="https://speed.cloudflare.com"

# 50 MiB: the endpoint refuses a __down between 64 MiB and 100 MiB, and the
# transfer is cut by --max-time long before the body runs out anyway. The size
# only has to be large enough that it does not.
chunk=$((50 * 1024 * 1024))
down_streams=4
up_streams=3
# Long enough to leave TCP slow start behind and still be over before anyone
# wonders whether it hung. Reported to the panel, which draws its progress bar
# against it.
seconds=6

latency=""
jitter=""
download=""
upload=""
server=""
location=""
error=""

# Every line is the complete state, with the phase that is *starting* on it.
# Numbers already measured stay filled in, so the panel prints the download
# figure while the upload is still running.
emit() {
	jq -nc \
		--arg phase "$1" \
		--arg seconds "$2" \
		--arg latency "$latency" \
		--arg jitter "$jitter" \
		--arg download "$download" \
		--arg upload "$upload" \
		--arg server "$server" \
		--arg location "$location" \
		--arg error "$error" \
		'{
			phase: $phase,
			seconds: ($seconds | tonumber),
			latency: (if $latency == "" then null else ($latency | tonumber) end),
			jitter: (if $jitter == "" then null else ($jitter | tonumber) end),
			download: (if $download == "" then null else ($download | tonumber) end),
			upload: (if $upload == "" then null else ($upload | tonumber) end),
			server: $server,
			location: $location,
			error: $error
		}'
}

headers=$(mktemp)
payload=$(mktemp)
rates=$(mktemp)
trap 'rm -f "$headers" "$payload" "$rates"' EXIT

# TERM is what the panel sends when `s` cancels a run or the panel is closed
# with one going. bash defers a trap until the command in the foreground
# returns, so the transfers run in the background and are waited on: `wait` is
# interruptible, and cancelling means the sockets close now rather than when
# --max-time would have ended the phase anyway.
transfer=""

cancel() {
	[[ -n "$transfer" ]] && kill "$transfer" 2>/dev/null
	exit 143
}

trap cancel TERM INT

# One "<status> <bytes per second>" line per stream, for summarise() below.
measure() {
	curl "$@" >"$rates" 2>/dev/null &
	transfer=$!
	wait "$transfer"
	transfer=""
}

# The phase's aggregate rate, and the status of the first stream that was not
# served. A refusal has to be read off the status rather than off the rate: the
# endpoint answers a run that comes too soon after the last one with a 429, and
# a rejection body is a few bytes delivered very fast — which arrives here as a
# plausible-looking 44 B/s rather than as an error.
#
# 1xx counts as served: --max-time cuts the uploads off mid-body, and a stream
# that never got to send its last byte is reported as the 100 Continue it was
# still working under.
summarise() {
	awk '
		{
			if ($1 ~ /^[12]/)
				sum += $2
			else if (refused == "")
				refused = $1
		}
		END { printf "%.0f %s\n", sum, refused }
	' "$rates"
}

# The endpoint is a shared one and rate limits per address, so the run that
# comes too soon after the last one is the failure worth naming.
refusalMessage() {
	if [[ "$1" == "429" ]]; then
		printf 'The test server is rate limiting. Give it a minute.'
	else
		printf 'The test server refused the transfer (HTTP %s).' "$1"
	fi
}

# ------------------------------------------------------------------
# Latency
#
# Five zero-byte bodies, timed to the first byte back: that is a request
# answered by the same edge the transfers will use, where the panel's other
# figure is an ICMP round trip to 1.1.1.1. They are different questions and
# they disagree often enough to be worth having both.
# ------------------------------------------------------------------

emit latency 2

samples=""
refused=""
for i in $(seq 1 5); do
	read -r code t < <(curl -s -o /dev/null -D "$headers" --max-time 5 \
		-w '%{http_code} %{time_starttransfer}' "$endpoint/__down?bytes=0&i=$i" 2>/dev/null)
	# A request that failed outright writes a zero rather than nothing, and a
	# zero would become the minimum and report a round trip that never
	# happened. A request that was refused is timed accurately and is still not
	# a measurement of anything.
	if [[ "$code" == 2* && -n "$t" && "$t" != "0.000000" ]]; then
		samples+="$t"$'\n'
	elif [[ -n "$code" && "$code" != "000" && "$refused" == "" ]]; then
		refused="$code"
	fi
done

# Refused rather than unreachable, when the server said so: the two want
# different things done about them, and only one of them is the link's fault.
if [[ -z "$samples" ]]; then
	if [[ -n "$refused" ]]; then
		error=$(refusalMessage "$refused")
	else
		error="Could not reach the test server."
	fi
	emit done 0
	exit 0
fi

# The minimum rather than the mean: the low sample is the one that met no
# queue, which is the link's latency; the rest are the queue. Jitter is the
# mean gap between consecutive probes, which is what the queue looks like.
read -r latency jitter < <(printf '%s' "$samples" | awk '
	{
		v = $1 * 1000
		n++
		if (min == "" || v < min)
			min = v
		if (n > 1) {
			d = v - prev
			if (d < 0)
				d = -d
			jsum += d
			jn++
		}
		prev = v
	}
	END { printf "%.1f %.1f\n", min, (jn ? jsum / jn : 0) }
')

# Which edge answered, from the headers of the probe above. Cloudflare names
# the colo (an airport code) and the city it sits in; a test against a server
# on another continent explains a figure that otherwise looks like a fault.
server=$(grep -im1 '^colo:' "$headers" | cut -d' ' -f2- | tr -d '\r')
location=$(grep -im1 '^city:' "$headers" | cut -d' ' -f2- | tr -d '\r')

# ------------------------------------------------------------------
# Download
# ------------------------------------------------------------------

emit download "$seconds"

down_args=()
for ((i = 0; i < down_streams; i++)); do
	down_args+=(-o /dev/null)
done
for ((i = 0; i < down_streams; i++)); do
	# The index is there to keep the edge from serving one cached response to
	# every stream.
	down_args+=("$endpoint/__down?bytes=$chunk&i=$i")
done

# --max-time aborts every stream at the same moment and curl exits 28, but it
# has already written the -w line for each: an aborted transfer still knows how
# fast it was going. Summing those is the aggregate rate.
measure -s --parallel --parallel-immediate --parallel-max "$down_streams" \
	--max-time "$seconds" -w '%{http_code} %{speed_download}\n' "${down_args[@]}"
read -r download refused < <(summarise)

if [[ "$download" == "0" && -n "$refused" ]]; then
	download=""
	error=$(refusalMessage "$refused")
	emit done 0
	exit 0
fi

# ------------------------------------------------------------------
# Upload
# ------------------------------------------------------------------

emit upload "$seconds"

# A sparse file rather than bytes piped in: curl needs a length up front to
# send a Content-Length, and reading the same sparse file from three streams
# costs no disk and no memory.
truncate -s "$chunk" "$payload"

up_args=()
for ((i = 0; i < up_streams; i++)); do
	up_args+=(-o /dev/null)
done
for ((i = 0; i < up_streams; i++)); do
	up_args+=(-T "$payload" "$endpoint/__up?i=$i")
done

measure -s --parallel --parallel-immediate --parallel-max "$up_streams" \
	--max-time "$seconds" -w '%{http_code} %{speed_upload}\n' "${up_args[@]}"
read -r upload refused < <(summarise)

# The download is already measured and stays on the panel; only the upload cell
# has nothing to show, and the message says why.
if [[ "$upload" == "0" && -n "$refused" ]]; then
	upload=""
	error=$(refusalMessage "$refused")
fi

emit done 0
