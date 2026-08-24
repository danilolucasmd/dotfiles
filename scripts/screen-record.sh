#!/bin/env bash

pgrep -x "wf-recorder" && pkill -INT -x wf-recorder && exit 0

geometry=$(slurp) || exit 0

dateTime=$(date +%m-%d-%Y-%H:%M:%S)
file="$HOME/Videos/$dateTime.mp4"
wf-recorder -g "$geometry" --bframes max_b_frames -f "$file"

# Deliberately the same shape as hyprshot's "Screenshot saved": summary, and a
# body naming the file in italics. Nothing identifies this sender as a window,
# so clicking the notification falls through focus-sender.sh's class passes to
# its path pass, which opens nautilus on the folder with the file selected --
# exactly what a screenshot notification does.
[ -s "$file" ] && notify-send "Recording saved" \
	"Video saved in <i>${file}</i>." \
	-t 5000 -a "Screen Recorder"
