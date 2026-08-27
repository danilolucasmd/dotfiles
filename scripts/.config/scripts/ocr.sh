#!/bin/env bash

# Text recognition: drag an area and its text lands on the clipboard. Nothing
# is ever written to disk -- the capture only exists as the pipe between grim
# and tesseract. screenshot.sh explains why the grab cannot be backgrounded.
#
# Deliberately a plain slurp, without the window rectangles screenshot.sh and
# screen-record.sh feed it. Those exist so a whole window can be taken in one
# click, and a whole window is never what is wanted here: recognition is for a
# few lines out of a window, and the hover highlight lifting a window out of
# the wash under the pointer is only a distraction while aiming at them. Left
# alone, slurp dims the entire screen evenly, which is exactly the backdrop to
# pick text against.

geometry=$(slurp) || exit 0

# Whichever of the languages we ask for is actually installed. install.sh pulls
# English and Portuguese, but a machine missing one would otherwise fail the
# whole run with "Failed loading language" instead of recognising the other.
langs=$(tesseract --list-langs 2>/dev/null | grep -xE 'eng|por' | paste -sd+)
[ -z "$langs" ] && langs=eng

# tesseract was trained on scanned paper at ~300 DPI, and screen text is
# nowhere near that -- a 14px UI font has about a third of the stroke width it
# expects, which is the difference between clean output and a page of
# punctuation. Upscaling the crop before recognition is the whole fix, and on a
# selection this small it costs a fraction of a second. Grayscale first because
# the colour channels only feed the same luminance to the recogniser, and a
# light unsharp after the resize puts back the edge interpolation softened.
#
# --psm 6 (a single uniform block of text) rather than tesseract's automatic
# page segmentation: the automatic mode is looking for the columns and headings
# of a scanned page, and on a hand-drawn crop of a few lines it regularly finds
# no page at all and returns nothing. A selection here is a block by
# construction -- the user drew the box around it.
text=$(grim -g "$geometry" - \
	| magick png:- -colorspace Gray -resize 300% -unsharp 0x1 png:- \
	| tesseract - - --psm 6 -l "$langs" 2>/dev/null)

# tesseract pads its output with a trailing form feed, blank lines around the
# block and trailing spaces on every line. Strip all of it so the clipboard
# holds only what was recognised -- the command substitution above has already
# taken the trailing newlines.
text=$(printf '%s' "$text" | tr -d '\f' | sed -e 's/[[:space:]]*$//' -e '/./,$!d')

if [ -z "$text" ]; then
	notify-send "No text found" "Nothing in the selection was recognised." \
		-t 5000 -a "Text recognition"
	exit 0
fi

printf '%s' "$text" | wl-copy

# The text itself as the body: it is both the confirmation and the only chance
# to notice a word came out wrong before pasting it. notify-send reads the body
# as markup, so anything the recognition produced that looks like a tag has to
# be escaped or it disappears from the notification.
body=$(printf '%s' "$text" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
notify-send "Text copied" "$body" -t 5000 -a "Text recognition"
