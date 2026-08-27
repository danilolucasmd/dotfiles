#!/bin/env bash

pgrep -x "wf-recorder" && pkill -INT -x wf-recorder && exit 0

# Without an argument the selection is the same region-or-window slurp the
# screenshot bind uses -- drag an area, or hover a window until it lifts out of
# the dim and click it. --full skips the selection and records the focused
# monitor whole, handed to wf-recorder as an output name rather than a
# geometry so a scaled or rotated monitor needs no arithmetic here.
if [ "$1" = "--full" ]; then
	monitor=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
	target=(-o "$monitor")
else
	geometry=$("$(dirname "$0")/window-boxes.sh" | slurp -d) || exit 0
	target=(-g "$geometry")
fi

dateTime=$(date +%m-%d-%Y-%H:%M:%S)
file="$HOME/Videos/$dateTime.mp4"

# install.sh creates this, but a recording should never fail because the
# directory went missing.
mkdir -p "$HOME/Videos"
wf-recorder "${target[@]}" --bframes max_b_frames -f "$file"

# Deliberately the same shape as screenshot.sh's "Screenshot saved": summary,
# and a body naming the file in italics. Nothing identifies this sender as a window,
# so clicking the notification falls through focus-sender.sh's class passes to
# its path pass, which opens nautilus on the folder with the file selected --
# exactly what a screenshot notification does.
[ -s "$file" ] && notify-send "Recording saved" \
	"Video saved in <i>${file}</i>." \
	-t 5000 -a "Screen Recorder"
