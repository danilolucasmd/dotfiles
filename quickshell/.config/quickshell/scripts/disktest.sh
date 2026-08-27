#!/bin/bash
# Quickshell module: the performance panel's disk throughput test.
#
# Prints one JSON object per line -- a line when a phase starts and a line
# after every pass inside it -- and each line carries the whole reading so far,
# so the panel replaces its state with the newest line rather than merging
# them. Runs once and exits; the panel starts it on `d` and nothing starts it
# on a timer, because a run writes two gigabytes and reads them back, which is
# both the drive's whole attention for a few seconds and real wear on it.
#
# This is the question the panel's other disk figures cannot answer. The read
# and write rates up there are what the machine happens to be doing, which on
# an idle desktop is nothing whatever the drive is worth, and `busy` is a share
# of an interval rather than a speed. Finding out how fast the drive is means
# making it go as fast as it can.
#
# Sequential only, and deliberately: measuring random IOPS honestly needs a
# queue depth and a submission rate that `dd` cannot produce -- forking a
# process per 4 KiB read times the fork, not the drive -- and fio is a package
# this repo does not otherwise need. So the number here is the one a large file
# copy would see, which is also the one a drive is sold on.

set -uo pipefail

# ------------------------------------------------------------------
# Shape of a run
#
# Four streams at once for the same reason the network test uses four
# connections: one `dd` is a single thread at queue depth 1, and an NVMe drive
# answers a single outstanding request with a fraction of the parallelism it
# has. Four is enough to keep the queue non-empty without the streams starting
# to seek against each other.
#
# Four passes rather than one long transfer so there is something to report on
# the way through -- a pass boundary is where the progress bar moves and where
# the running figure is recomputed. The barrier between passes costs a percent
# or so of the aggregate rate, which is worth it for a panel that would
# otherwise sit blank for five seconds.
#
# 128 MiB per stream per pass, so a phase moves 2 GiB. Large enough that the
# ramp into steady state is a small share of it, small enough that a run is
# neither a minute long nor a meaningful bite out of an SSD's write budget.
# ------------------------------------------------------------------

streams=4
passes=4
chunk_mb=128

phase_bytes=$((streams * passes * chunk_mb * 1024 * 1024))

read_rate=""
write_rate=""
device=""
mount=""
error=""

# Every line is the complete state, with the phase that is *running* on it and
# how far through that phase it is. Numbers already measured stay filled in, so
# the panel prints the write figure while the read is still being measured.
emit() {
	jq -nc \
		--arg phase "$1" \
		--arg progress "$2" \
		--arg read "$read_rate" \
		--arg write "$write_rate" \
		--arg bytes "$phase_bytes" \
		--arg device "$device" \
		--arg mount "$mount" \
		--arg error "$error" \
		'{
			phase: $phase,
			progress: ($progress | tonumber),
			read: (if $read == "" then null else ($read | tonumber) end),
			write: (if $write == "" then null else ($write | tonumber) end),
			bytes: ($bytes | tonumber),
			device: $device,
			mount: $mount,
			error: $error
		}'
}

fail() {
	error=$1
	emit done 0
	exit 0
}

# ------------------------------------------------------------------
# Where the test writes
#
# The cache directory, because it is the one place a user's session owns that
# is on a real filesystem. Not /tmp: that is tmpfs here, and a test run against
# tmpfs measures how fast memory is, which is a fine number and not this one.
# ------------------------------------------------------------------

dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/disktest"
buffer="/dev/shm/quickshell-disktest.bin"

mkdir -p "$dir" 2>/dev/null || fail "Could not create the test directory."

fstype=$(findmnt -no FSTYPE --target "$dir" 2>/dev/null)
if [[ "$fstype" == tmpfs || "$fstype" == ramfs ]]; then
	fail "The cache directory is in memory, not on the disk."
fi

# Which drive is actually under the test, worked out the way system-stats.sh
# works out the one the panel meters: the mount's source with any btrfs
# subvolume stripped, then the partition's parent device. Worth printing -- on
# a machine where the cache and the root filesystem live on different drives,
# this is the figure's explanation.
mount=$(findmnt -no TARGET --target "$dir" 2>/dev/null)
source=$(findmnt -no SOURCE --target "$dir" 2>/dev/null | sed 's/\[.*//')
device=$(lsblk -no PKNAME "$source" 2>/dev/null | head -1)
[ -z "$device" ] && device=$(basename "$source")

# The test files, plus room to spare: filling the filesystem to the last byte
# while measuring it would be a poor trade.
need=$((phase_bytes + 512 * 1024 * 1024))
avail=$(df -B1 --output=avail "$dir" 2>/dev/null | tail -1 | tr -dc '0-9')
if [[ -n "$avail" && "$avail" -lt "$need" ]]; then
	fail "Not enough free space for the test ($(numfmt --to=iec "$need") needed)."
fi

# A run killed outright leaves its files behind, and a stale one would be read
# back by the next run's read phase instead of what that run just wrote.
rm -f "$dir"/stream* 2>/dev/null

# btrfs here is mounted `compress=zstd`, and a compressed inode is one the
# kernel will not serve O_DIRECT for -- it falls back to the page cache, and a
# read phase served from the page cache reports how fast memory is. `chattr +C`
# on the directory turns off compression and copy-on-write for the files
# created in it afterwards, which is why this happens before the write phase
# and why the files are removed above rather than reused. It is a btrfs
# attribute and fails harmlessly on a filesystem without one.
chattr +C "$dir" 2>/dev/null

trap 'rm -f "$buffer" "$dir"/stream* 2>/dev/null' EXIT

# TERM is what the panel sends when `d` cancels a run or the panel is closed
# with one going. bash defers a trap until the command in the foreground
# returns, so the transfers run in the background and are waited on: `wait` is
# interruptible, and cancelling means the drive is left alone now rather than
# at the end of the pass.
pids=()

cancel() {
	[[ ${#pids[@]} -gt 0 ]] && kill "${pids[@]}" 2>/dev/null
	exit 143
}

trap cancel TERM INT

now() {
	date +%s.%N
}

# Bytes over seconds, as whole bytes per second. In awk because the numbers are
# a fraction of a second apart and bash has only integers.
rate() {
	awk -v b="$1" -v s="$2" -v e="$3" 'BEGIN { d = e - s; printf "%.0f", (d > 0 ? b / d : 0) }'
}

# ------------------------------------------------------------------
# Something incompressible to write
#
# Zeros would measure zstd rather than the drive, and would do it even with
# copy-on-write off on a filesystem that compresses regardless. /dev/urandom
# gives about 430 MB/s here, which is well under what the drive does, so the
# data is generated once into tmpfs and then written from memory -- reading the
# random source inside the write phase would measure the source.
#
# One buffer for all four streams: they read the same pages out of tmpfs, and
# writing the same block to four different files is still four real writes with
# copy-on-write and deduplication both off.
# ------------------------------------------------------------------

emit prepare 0

head -c $((chunk_mb * 1024 * 1024)) /dev/urandom >"$buffer" 2>/dev/null &
pids=($!)
wait "${pids[0]}"
pids=()

[[ -s "$buffer" ]] || fail "Could not prepare the test data."

# ------------------------------------------------------------------
# One pass
#
# Every stream reads or writes its own file at the offset this pass owns, so
# each file is written once, straight through, across the four passes -- which
# is what makes it sequential rather than four rewrites of the same megabytes.
#
# `notrunc` matters more than it looks: without it `dd` truncates the file
# before seeking, and the earlier passes' extents become a hole. A hole reads
# back instantly, and the read phase would report a drive faster than any drive
# is.
#
# `fsync` on the write closes the other hole: O_DIRECT hands the data to the
# device but the device may still be holding it in its own cache, and a write
# rate measured to the edge of a cache is the cache's rate.
# ------------------------------------------------------------------

pass() {
	local mode=$1 p=$2 i
	pids=()

	for ((i = 0; i < streams; i++)); do
		if [[ "$mode" == write ]]; then
			dd if="$buffer" of="$dir/stream$i" bs=1M count="$chunk_mb" \
				seek=$((p * chunk_mb)) oflag=direct conv=notrunc,fsync status=none 2>/dev/null &
		else
			dd if="$dir/stream$i" of=/dev/null bs=1M count="$chunk_mb" \
				skip=$((p * chunk_mb)) iflag=direct status=none 2>/dev/null &
		fi
		pids+=($!)
	done

	for i in "${pids[@]}"; do
		wait "$i"
	done
	pids=()
}

# A phase is its passes, timed as one: the aggregate rate is every stream's
# bytes over the wall clock they all ran in, which is the only way to add up
# four transfers that overlap. The running figure after each pass is the same
# division over the passes done so far, so it settles rather than jumping.
run_phase() {
	local mode=$1 p start done_bytes
	local per_pass=$((streams * chunk_mb * 1024 * 1024))

	emit "$mode" 0

	start=$(now)
	for ((p = 0; p < passes; p++)); do
		pass "$mode" "$p"
		done_bytes=$(((p + 1) * per_pass))
		if [[ "$mode" == write ]]; then
			write_rate=$(rate "$done_bytes" "$start" "$(now)")
		else
			read_rate=$(rate "$done_bytes" "$start" "$(now)")
		fi
		emit "$mode" "$(awk -v p="$((p + 1))" -v n="$passes" 'BEGIN { printf "%.3f", p / n }')"
	done
}

# Write first, then read the files it left. Not the other way round: the read
# phase needs something the right size to read, and reading what was just
# written is what makes the second phase free of any setup of its own.
run_phase write
run_phase read

# A drive that answered every request at nothing is not a slow drive, it is a
# failed test -- an out-of-space write or a device that went away mid-run.
if [[ "$write_rate" == "0" || "$read_rate" == "0" ]]; then
	error="The drive did not answer the test."
fi

emit done 1
