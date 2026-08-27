#!/usr/bin/env bash
# Put something on the clipboard and then paste it into whatever had focus
# before the picker opened.
#
# Two callers:
#
#   copy-and-paste.sh
#       elephant's `command` for the clipboard (super+V) and symbols (`.` in
#       walker) providers, with the entry's content on stdin: plain text for a
#       text entry or an emoji, the raw bytes of the cached PNG for an image.
#       elephant's default here is a bare `wl-copy`, which is why Return used to
#       do nothing but put the entry back on the clipboard, leaving the actual
#       paste to the user.
#
#   copy-and-paste.sh --layer <namespace> <text>
#       the Quickshell emoji picker (super+E), which is a layer surface of its
#       own rather than walker's and hands the emoji over as an argument.
#
# Either way the copy is kept as well as the paste -- the entry does belong on
# the clipboard, and the symbols provider's history sorting is built around it.
#
# ctrl+v, not ctrl+shift+v: ghostty is bound to paste on ctrl+v here (see
# ghostty/.config/ghostty/config), which is the only app on this machine that
# would otherwise have wanted the terminal chord, so one keystroke covers
# everything and this script never has to ask what it is pasting into.

set -euo pipefail

# Whose surface going away means focus is coming back. walker's, unless the
# caller says otherwise.
layer=walker

if [[ ${1-} == --layer ]]; then
	layer=$2
	shift 2
fi

if (($#)); then
	wl-copy -- "$1"
else
	wl-copy
fi

# Backgrounded because elephant waits for this command to exit, and everything
# below is about a window elephant has nothing to do with.
(
	# Not a fixed sleep. The picker still holds exclusive keyboard focus at the
	# moment this runs, so a ctrl+v sent too early is typed into its own search
	# input and lost when it closes. Its layer surface disappearing is the one
	# honest signal that focus is on its way back; the cap is ~1.2s so a picker
	# left open (--keepopen, or a wedged instance) drops the paste rather than
	# firing it at a random moment.
	for _ in $(seq 60); do
		hyprctl layers -j | grep -q "\"namespace\": \"$layer\"" || break
		sleep 0.02
	done

	# The surface being gone is not yet the window underneath having keyboard
	# focus; the compositor needs a moment to hand it back.
	sleep 0.08

	wtype -M ctrl -k v -m ctrl
) >/dev/null 2>&1 &
