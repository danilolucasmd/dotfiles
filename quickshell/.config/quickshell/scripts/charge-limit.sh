#!/bin/bash
# Sets the charge threshold on every pack that has one: the percentage the
# firmware stops charging at. Driven by the battery panel's slider.
#
#   charge-limit.sh <20-100> [--no-prompt]
#
# The attribute is root-owned out of the box, so this writes it directly when
# the udev rule from install.sh has handed the wheel group write access, and
# falls back to one pkexec for the whole set otherwise — one prompt for the
# gesture, not one per pack. --no-prompt says never to ask: it is what the
# shell's startup reconcile uses, so a login on a machine without the rule
# leaves the packs alone rather than opening a password dialog at every boot.
#
# Prints one line of JSON so the panel can say what happened rather than
# silently snapping the slider back.

set -uo pipefail

readonly THRESHOLD=charge_control_end_threshold
readonly START=charge_control_start_threshold

limit=${1:-}
prompt=1
[ "${2:-}" = "--no-prompt" ] && prompt=0

fail() {
	printf '{"ok":false,"error":"%s"}\n' "$1"
	exit 1
}

[[ $limit =~ ^[0-9]+$ ]] || fail "not a percentage: ${limit:-<none>}"
[ "$limit" -ge 20 ] && [ "$limit" -le 100 ] || fail "out of range: $limit"

targets=()
for dir in /sys/class/power_supply/*/; do
	[ -f "$dir/$THRESHOLD" ] && targets+=("$dir")
done

[ ${#targets[@]} -gt 0 ] || fail "no pack exposes a charge threshold"

# The writes, as one shell program, so the pkexec path can hand the whole set
# to a single root shell.
program=""
names=""
for dir in "${targets[@]}"; do
	name=$(basename "$dir")
	names="${names:+$names,}\"$name\""

	# A start threshold at or above the new stop is a range the firmware
	# rejects outright. Walk it down first — 5 points under is the hysteresis
	# these packs ship with — and only when it is actually in the way.
	start=$(head -n1 "$dir/$START" 2>/dev/null)
	if [[ $start =~ ^[0-9]+$ ]] && [ "$start" -ge "$limit" ]; then
		program+="printf '%s' $((limit > 5 ? limit - 5 : 0)) > '$dir$START' || exit 1; "
	fi

	program+="printf '%s' $limit > '$dir$THRESHOLD' || exit 1; "
done

writable=1
for dir in "${targets[@]}"; do
	[ -w "$dir/$THRESHOLD" ] || writable=0
done

if [ $writable -eq 1 ]; then
	/bin/sh -c "$program" 2>/dev/null || fail "write refused by the firmware"
	method=direct
else
	[ $prompt -eq 1 ] || fail "not writable — install the udev rule, or set it from the panel"
	command -v pkexec >/dev/null || fail "not writable and no pkexec to ask with"
	pkexec /bin/sh -c "$program" 2>/dev/null || fail "not applied — the prompt was refused, or the firmware was"
	method=pkexec
fi

printf '{"ok":true,"limit":%s,"method":"%s","packs":[%s]}\n' "$limit" "$method" "$names"
