#!/usr/bin/env bash
# elephant's `command` for the clipboard (super+V) and symbols (super+E)
# providers -- what Return on a walker entry ends up running, with the entry's
# content on stdin. Both providers hand it over the same way: plain text for a
# text entry or an emoji, the raw bytes of the cached PNG for an image.
#
# elephant's default here is a bare `wl-copy`, which is why Return used to do
# nothing but put the entry back on the clipboard, leaving the actual paste to
# the user. This keeps the copy -- the entry does belong on the clipboard, and
# the symbols provider's history sorting is built around it -- and then presses
# ctrl+v into whatever was focused before walker opened.
#
# ctrl+v, not ctrl+shift+v: ghostty is bound to paste on ctrl+v here (see
# ghostty/.config/ghostty/config), which is the only app on this machine that
# would otherwise have wanted the terminal chord, so one keystroke covers
# everything and this script never has to ask what it is pasting into.

set -euo pipefail

wl-copy

# Backgrounded because elephant waits for this command to exit, and everything
# below is about a window elephant has nothing to do with.
(
	# Not a fixed sleep. walker still holds exclusive keyboard focus at the
	# moment elephant runs this, so a ctrl+v sent too early is typed into
	# walker's own search input and lost when it closes. Its layer surface
	# disappearing is the one honest signal that focus is on its way back;
	# the cap is ~1.2s so a walker left open (--keepopen, or a wedged
	# instance) drops the paste rather than firing it at a random moment.
	for _ in $(seq 60); do
		hyprctl layers -j | grep -q '"namespace": "walker"' || break
		sleep 0.02
	done

	# The surface being gone is not yet the window underneath having keyboard
	# focus; the compositor needs a moment to hand it back.
	sleep 0.08

	wtype -M ctrl -k v -m ctrl
) >/dev/null 2>&1 &
