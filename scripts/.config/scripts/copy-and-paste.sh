#!/usr/bin/env bash
# Put something on the clipboard and then paste it into whatever had focus
# before the picker opened.
#
# Two callers, both of them quickshell panels, and both handing over an entry
# the same way -- on stdin as bytes:
#
#   clipboard.sh paste <id>
#       the clipboard history behind super+V, piping `cliphist decode` in:
#       plain text for a text entry, the raw bytes of the cached PNG for an
#       image, so nothing here has to know which it is holding.
#
#   copy-and-paste.sh --layer <namespace> <text>
#       the emoji picker (super+E), which hands its emoji over as an argument
#       rather than on stdin.
#
# The paste half is the reason this exists at all. It was written when walker
# and elephant were still here, because elephant's `command` for a chosen entry
# was a bare `wl-copy` -- Return refilled the clipboard and left the actual
# paste to the user. Both of those are gone; the wait below is what survived
# them, and it is the part worth not having two copies of.
#
# Either way the copy is kept as well as the paste: the thing that was chosen
# does belong on the clipboard, and pasting it somewhere is not a reason for the
# next ctrl+v to produce something else.
#
# ctrl+v, not ctrl+shift+v: ghostty is bound to paste on ctrl+v here (see
# ghostty/.config/ghostty/config), which is the only app on this machine that
# would otherwise have wanted the terminal chord, so one keystroke covers
# everything and this script never has to ask what it is pasting into.

set -euo pipefail

# Whose surface going away means focus is coming back. The launcher's, unless
# the caller says otherwise -- the emoji picker is a layer surface of its own.
layer=quickshell:launcher

if [[ ${1-} == --layer ]]; then
	layer=$2
	shift 2
fi

if (($#)); then
	wl-copy -- "$1"
else
	wl-copy
fi

# Backgrounded because the caller waits for this command to exit, and everything
# below is about a window the caller has nothing to do with.
(
	# Not a fixed sleep. The panel still holds the keyboard at the moment this
	# runs, so a ctrl+v sent too early is typed into its own search field and
	# lost when it closes. Its layer surface disappearing is the one honest
	# signal that focus is on its way back; the cap is ~1.2s so a panel left
	# open, or a wedged one, drops the paste rather than firing it at a random
	# moment.
	for _ in $(seq 60); do
		hyprctl layers -j | grep -q "\"namespace\": \"$layer\"" || break
		sleep 0.02
	done

	# The surface being gone is not yet the window underneath having keyboard
	# focus; the compositor needs a moment to hand it back.
	sleep 0.08

	wtype -M ctrl -k v -m ctrl
) >/dev/null 2>&1 &
