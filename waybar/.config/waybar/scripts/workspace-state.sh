#!/usr/bin/env bash
# Emit one workspace's Waybar JSON.
# Fast path: cat the file that ws-events.py pre-computed (no hyprctl/jq).
# Fallback: compute directly (e.g. at startup, before the first event).
# Usage: workspace-state.sh <id>
n="$1"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
f="$runtime/waybar-ws-$n.json"

if [ -s "$f" ]; then
	cat "$f"
	exit 0
fi

# --- fallback -------------------------------------------------------------
ws="$(hyprctl -j workspaces 2>/dev/null)"
if [ -z "$ws" ]; then
	printf '{"text":"%s","class":[]}\n' "$n"
	exit 0
fi
active="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // -1')"

printf '%s' "$ws" | jq -c --argjson n "$n" --argjson active "${active:--1}" '
	(map(select(.id == $n)) | .[0]) as $w
	| ($w != null)                   as $exists
	| ($exists and ($w.windows > 0)) as $occupied
	| ($exists and $w.hasfullscreen) as $fullscreen
	| {
		text: ($n | tostring),
		class: (
			(if $n == $active then ["active"] else [] end)
			+ (if $fullscreen then ["fullscreen"] else [] end)
			+ (if ($occupied | not) then ["empty"] else [] end)
		)
	}
'
