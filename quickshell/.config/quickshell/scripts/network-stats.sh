#!/bin/bash
# Quickshell module: the numbers the network panel prints that NetworkManager
# does not expose over D-Bus — byte counters, the default gateway, the
# resolvers in use, and a reachability probe.
#
# Prints one line of JSON, consumed by the panel's JsonScript. Takes the
# interface to report on as $1; with none it reports on whatever carries the
# default route, which is what the panel wants whenever it has nothing better
# to name.
#
# Counters are cumulative — the kernel's own since-boot totals. Rates are the
# caller's job: it holds two samples and divides, which is cheaper and steadier
# than sleeping a second inside here on every poll.
#
# Only run while the panel is open. It pings on every invocation, and three
# packets every couple of seconds is not something to leave running behind a
# closed panel.

set -uo pipefail

iface="${1:-}"

# The default route's device, and the route itself, in one query: the gateway
# comes from the same record, and asking twice can catch two different routes
# if one changes in between.
route=$(ip -j route show default 2>/dev/null | jq -c 'sort_by(.metric // 0) | .[0] // {}')

if [ -z "$iface" ]; then
	iface=$(printf '%s' "$route" | jq -r '.dev // empty')
fi

# The gateway of the default route, but only if that route leaves by the
# interface being reported on — an interface that is up and addressed but not
# carrying the default route has no gateway worth printing.
gateway=$(printf '%s' "$route" | jq -r --arg i "$iface" 'select(.dev == $i) | .gateway // empty')

# Counters first, and the timestamp with them: everything below this takes time
# (the ping most of all), and a rate is only as good as the interval it is
# divided by.
counters=$(sed 's/:/ /' /proc/net/dev | awk -v i="$iface" '$1 == i { print $2, $10 }')
rx=$(printf '%s' "$counters" | cut -d' ' -f1)
tx=$(printf '%s' "$counters" | cut -d' ' -f2)
t=$(date +%s.%N)

address=$(ip -j -4 addr show dev "$iface" 2>/dev/null | jq -r '.[0].addr_info[0].local // empty')

# No systemd-resolved on this machine, so the resolvers are NetworkManager's to
# report. Per device rather than globally: with the VPN up the tunnel has its
# own, and the panel is describing one link at a time.
dns=$(nmcli -t -f IP4.DNS device show "$iface" 2>/dev/null | cut -d: -f2- | grep -v '^$' | paste -sd ' ')

# 1.1.1.1 rather than a hostname: a resolver that is down is a different fault
# from a network that is, and this probe is asking about the second one. Three
# packets so a single drop reads as a loss rather than as a dead link, and the
# caller keeps a window of these anyway.
ping=$(ping -n -q -c 3 -i 0.2 -W 1 1.1.1.1 2>/dev/null)
sent=$(printf '%s' "$ping" | grep -oP '^\d+(?= packets transmitted)')
recv=$(printf '%s' "$ping" | grep -oP '\d+(?= received)')
rtt=$(printf '%s' "$ping" | grep -oP 'rtt [^=]+= [\d.]+/\K[\d.]+')

jq -nc \
	--arg iface "$iface" \
	--arg address "$address" \
	--arg gateway "$gateway" \
	--arg dns "$dns" \
	--arg t "$t" \
	--arg rx "${rx:-}" \
	--arg tx "${tx:-}" \
	--arg sent "${sent:-0}" \
	--arg recv "${recv:-0}" \
	--arg rtt "${rtt:-}" \
	'{
		iface: $iface,
		address: $address,
		gateway: $gateway,
		dns: $dns,
		t: ($t | tonumber),
		rx: (if $rx == "" then null else ($rx | tonumber) end),
		tx: (if $tx == "" then null else ($tx | tonumber) end),
		sent: ($sent | tonumber),
		recv: ($recv | tonumber),
		ping: (if $rtt == "" then null else ($rtt | tonumber) end)
	}'
