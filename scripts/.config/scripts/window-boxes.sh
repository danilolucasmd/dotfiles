#!/bin/env bash

# Every window currently on screen as a slurp predefined rectangle, one per
# line, in the "<x>,<y> <width>x<height>" form slurp reads from stdin.
#
# slurp only *forces* a choice between these with -r; handed them without it,
# they become a second way to select layered on top of the free drag: hovering
# a window makes it the pending selection and a click takes it, while
# click-and-drag still cuts an arbitrary region. That is the whole point of
# this file -- one keybind that screenshots or records either a hand-drawn area
# or a whole window, with no separate "window mode" to remember.
#
# The colours stay slurp's defaults on purpose. Measured against a plain grim
# capture of the same screen: a rectangle that is *not* hovered comes out
# pixel-identical to the rest of the dimmed screen (both are the real pixels
# under a 25% white wash), and the hovered one comes out in the untouched
# original colours. So the boxes cost nothing visually until the pointer is
# actually over a window, and the hover feedback is just that window lifting
# out of the wash.

# Windows sitting on a workspace no monitor is displaying still come back from
# `hyprctl clients` with real coordinates, and a rectangle there would select
# whatever happens to be drawn on top of it instead. Keep only the workspaces
# the monitors are actually showing.
visible=$(hyprctl -j monitors | jq '[.[].activeWorkspace.id]')

hyprctl -j clients | jq -r --argjson visible "$visible" '
	.[]
	| select(.mapped and (.hidden | not) and (.workspace.id | IN($visible[])))
	| "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
'
