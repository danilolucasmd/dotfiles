#!/bin/env bash

pgrep -x "wf-recorder" && pkill -INT -x wf-recorder && exit 0

geometry=$(slurp) || exit 0

dateTime=$(date +%m-%d-%Y-%H:%M:%S)
wf-recorder -g "$geometry" --bframes max_b_frames -f $HOME/Videos/$dateTime.mp4
