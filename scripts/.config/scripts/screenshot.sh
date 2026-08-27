#!/bin/env bash

# The screenshot binds. This used to be hyprshot, and stopped being it for one
# reason: hyprshot runs its grab as a *background* job (`begin_grab $OPTION &`),
# and bash gives a background job /dev/null for stdin, so slurp never sees the
# window rectangles piped in -- which is the whole hover-a-window-and-click
# half of the bind. Everything hyprshot did for us is four lines anyway: grim,
# wl-copy, a file, a notification.
#
# Without --full the selection is region-or-window: drag for an arbitrary area,
# or hover a window until it lifts out of the dimmed screen and click to take
# that window alone. window-boxes.sh explains how the second half works.
# --full skips the selection and grabs the focused monitor whole, handed to
# grim as an output name rather than a geometry so a scaled or rotated monitor
# needs no arithmetic here.
#
# --clipboard-only copies without writing a file, matching the bind that
# existed before.

dir=$(dirname "$0")
clipboard=0
full=0

for arg in "$@"; do
	case "$arg" in
		--full) full=1 ;;
		--clipboard-only) clipboard=1 ;;
	esac
done

if [ "$full" -eq 1 ]; then
	monitor=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
	target=(-o "$monitor")
else
	geometry=$("$dir/window-boxes.sh" | slurp -d) || exit 0
	target=(-g "$geometry")
fi

if [ "$clipboard" -eq 1 ]; then
	grim "${target[@]}" - | wl-copy --type image/png
	notify-send "Screenshot saved" "Image copied to the clipboard." \
		-t 5000 -a "Screenshot"
	exit 0
fi

dateTime=$(date +'%Y-%m-%d-%H%M%S')
file="$HOME/Pictures/Screenshots/$dateTime.png"

# install.sh creates this, but a screenshot should never fail because the
# directory went missing.
mkdir -p "$HOME/Pictures/Screenshots"
grim "${target[@]}" "$file"
wl-copy --type image/png <"$file"

# The image itself as the icon, which is what hyprshot did and what makes the
# notification readable at a glance. Nothing here identifies the sender as a
# window, so clicking it falls through focus-sender.sh's class passes to its
# path pass -- which opens the PNG in tensaku, the annotation editor, so the
# shot can be drawn on and put back on the clipboard. That pass recognises this
# notification by the `-a "Screenshot"` below, so the name is load-bearing.
[ -s "$file" ] && notify-send "Screenshot saved" \
	"Image saved in <i>${file}</i> and copied to the clipboard." \
	-t 5000 -i "$file" -a "Screenshot"
