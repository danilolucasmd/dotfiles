#!/usr/bin/env bash
# Report one Hyprland workspace's state as Waybar JSON.
# Usage: workspace-state.sh <id>
#   text  -> the workspace number
#   class -> any of: active (focused), fullscreen (holds a fullscreen window),
#            empty (persistent placeholder / no windows)
n="$1"

ws="$(hyprctl -j workspaces 2>/dev/null)"
if [ -z "$ws" ]; then
	printf '{"text":"%s","class":[]}\n' "$n"
	exit 0
fi
active="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // -1')"

printf '%s' "$ws" | jq -c --argjson n "$n" --argjson active "${active:--1}" '
	(map(select(.id == $n)) | .[0]) as $w
	| ($w != null)                         as $exists
	| ($exists and ($w.windows > 0))       as $occupied
	| ($exists and $w.hasfullscreen)       as $fullscreen
	| {
		text: ($n | tostring),
		class: (
			(if $n == $active then ["active"] else [] end)
			+ (if $fullscreen then ["fullscreen"] else [] end)
			+ (if ($occupied | not) then ["empty"] else [] end)
		)
	}
'
