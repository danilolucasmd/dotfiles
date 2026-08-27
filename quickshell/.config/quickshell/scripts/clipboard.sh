#!/usr/bin/env bash
# The clipboard history behind super+V: the listing the panel draws, and the
# four things it can do to an entry.
#
# The store is cliphist, fed by the two `wl-paste --watch` lines in
# hyprland.conf. It replaced elephant's clipboard provider along with the rest
# of walker; cliphist is the same idea with none of walker attached -- a plain
# `id<TAB>preview` listing on stdout and a `decode` that hands back the original
# bytes, which is all a panel drawing its own list ever needed from it.
#
# Everything here is a subcommand rather than five scripts because they share
# the one thing that is easy to get wrong: an entry is addressed by its cliphist
# id, and `cliphist delete` will not take one -- it wants the whole listing line
# back on stdin, which is what `line_for` reconstructs.
set -euo pipefail

cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clipboard"

# The listing line for an id, which is what `cliphist delete` reads. Rebuilt
# from the listing rather than remembered by the caller: the preview half has to
# match byte for byte, and the panel only ever holds the id.
line_for() {
	cliphist list | awk -F'\t' -v id="$1" '$1 == id { print; exit }'
}

# Image entries are previewed as `[[ binary data 8 KiB png 64x64 ]]` and their
# bytes only come back through `decode`, so the panel cannot show a thumbnail
# without a file on disk to point an Image at. Decoded once into the cache and
# left there: ids are never reused, so a cached file can only ever be the entry
# it was named for, and a wipe takes the directory with it.
thumbnails() {
	mkdir -p "$cache"
	while IFS=$'\t' read -r id preview; do
		[[ $preview == '[[ binary data '* ]] || continue
		# The extension as cliphist reports it, which is what the panel is told
		# the file is called. Anything unrecognised is left alone rather than
		# guessed at -- a thumbnail that fails to load is better than a
		# mislabelled file handed to tensaku.
		ext=$(sed -n 's/^\[\[ binary data [0-9.]* [A-Za-z]* \([a-z]*\) .*/\1/p' <<<"$preview")
		[[ -n $ext ]] || continue
		[[ -s "$cache/$id.$ext" ]] || cliphist decode "$id" >"$cache/$id.$ext"
	done < <(cliphist list)
}

# The pattern that names this script's own watchers and nothing else. Both
# `watch` and `pause` match on it, so there is one definition of what a
# clipboard watcher looks like rather than two that can drift apart.
watchers='wl-paste --type (text|image) --watch cliphist store'

case "${1:-list}" in
# What hyprland.conf runs at startup, and what `resume` runs again. Two
# watchers because wl-paste watches one MIME type at a time, and an image on
# the clipboard is not offered as text.
#
# The pkill first is not paranoia: this is re-runnable by design -- `resume`
# is the same command -- and a second pair of watchers would file every copy
# into cliphist twice.
watch)
	pkill -f "$watchers" || true
	setsid wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
	setsid wl-paste --type image --watch cliphist store >/dev/null 2>&1 &
	;;

# ctrl+p in the panel. cliphist itself has no pause -- it is a store, not a
# daemon -- so pausing is stopping the things that feed it, which is why the
# watchers had to be something this script starts rather than two exec-once
# lines hyprland alone knew about.
pause)
	pkill -f "$watchers" || true
	;;

# For the panel's own indicator, so a paused history says so rather than
# looking like a clipboard nobody has copied into.
status)
	if pgrep -f "$watchers" >/dev/null; then
		echo '{"watching":true}'
	else
		echo '{"watching":false}'
	fi
	;;

# One line of JSON for the panel: every entry, newest first, each tagged text
# or image. The tab split is `.[0]` and the rest joined back together, because
# a preview is free to contain tabs of its own -- cliphist only collapses
# newlines.
list)
	thumbnails
	cliphist list | jq -Rs --arg cache "$cache" '
		# The one pattern, used twice: `test` to decide which kind of entry this
		# is, `capture` to pull it apart. jq'"'"'s `capture` raises rather than
		# returning null when it does not match, and a raised error inside the
		# comprehension drops the element silently -- which is how every text
		# entry once vanished from this listing.
		def img: "^\\[\\[ binary data (?<size>[0-9.]+ [A-Za-z]+) (?<ext>[a-z]+) (?<width>[0-9]+)x(?<height>[0-9]+) \\]\\]$";
		{
			entries: [
				splits("\n")
				| select(length > 0)
				# `.[0]` and the rest joined back together, because a preview may
				# hold tabs of its own -- cliphist only collapses newlines.
				| (split("\t") | { id: (.[0] | tonumber), preview: (.[1:] | join("\t")) })
				| if (.preview | test(img)) then
					(.preview | capture(img)) as $m
					| . + {
						kind: "image",
						size: $m.size,
						width: ($m.width | tonumber),
						height: ($m.height | tonumber),
						path: "\($cache)/\(.id).\($m.ext)"
					}
				else
					. + { kind: "text" }
				end
			]
		}'
	;;

# What the preview pane draws for a text entry. `cliphist list` collapses every
# newline into a space so that one entry is one line, which is right for the
# list and useless for a preview -- this is the only way back to the text as it
# was actually copied.
#
# Capped, and `|| true` because that cap is what closes the pipe: a 40MB paste
# would otherwise be read in full to fill a pane that shows forty lines, and
# cliphist dying of SIGPIPE is the expected outcome rather than a failure.
preview)
	cliphist decode "$2" | head -c 4096 || true
	;;

# Chosen: back onto the clipboard, then into whatever had focus before the
# launcher opened. The same script the emoji picker uses, and it takes the
# entry on stdin either way -- text as text, an image as the raw PNG -- so
# nothing here has to know which it is holding.
paste)
	cliphist decode "$2" | "$HOME/.config/scripts/copy-and-paste.sh" --layer quickshell:launcher
	;;

# ctrl+o on an image. tensaku wants a file, and `thumbnails` has already put
# one in the cache under the name the panel was told, so this is only the
# lookup and the launch. Backgrounded: the panel closes on its own and must not
# wait for an editor session to end.
edit)
	shopt -s nullglob
	for f in "$cache/$2".*; do
		setsid tensaku --filename "$f" >/dev/null 2>&1 &
		exit 0
	done
	exit 1
	;;

delete)
	line_for "$2" | cliphist delete
	rm -f "$cache/$2".*
	;;

wipe)
	cliphist wipe
	rm -rf "$cache"
	;;

*)
	echo "usage: clipboard.sh watch|pause|status|list|preview <id>|paste <id>|edit <id>|delete <id>|wipe" >&2
	exit 2
	;;
esac
