#!/usr/bin/env bash
# The clipboard history behind super+V: the listing the panel draws, and the
# things it can do to an entry.
#
# The store is cliphist, fed by the two `wl-paste --watch` lines that `watch`
# starts. It replaced elephant's clipboard provider along with the rest of
# walker; cliphist is the same idea with none of walker attached -- a plain
# `id<TAB>preview` listing on stdout and a `decode` that hands back the original
# bytes, which is all a panel drawing its own list ever needed from it.
#
# Everything here is a subcommand rather than a pile of scripts because they
# share the one thing that is easy to get wrong: an entry is addressed by its
# cliphist id, and `cliphist delete` will not take one -- it wants the whole
# listing line back on stdin, which is what `line_for` reconstructs.
set -euo pipefail

# Globs that match nothing expand to nothing, which is what lets `prune` and
# `edit` loop over a cache directory that may be empty or absent.
shopt -s nullglob

cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clipboard"

# What cliphist does not store and the panel's information block wants: which
# application a copy came from, and when. One file per id rather than one file
# for the table, because the two watchers are separate processes and a pair of
# concurrent copies would otherwise interleave into a corrupt JSON document.
meta="$cache/meta"

# This script's own path, for the `wl-paste --watch` lines: they re-enter it as
# `store`, and a watcher started with a relative path would break the moment
# anything ran it from another directory.
self=$(readlink -f "$0")

# The listing line for an id, which is what `cliphist delete` reads. Rebuilt
# from the listing rather than remembered by the caller: the preview half has to
# match byte for byte, and the panel only ever holds the id.
line_for() {
	cliphist list | awk -F'\t' -v id="$1" '$1 == id { print; exit }'
}

# Everything cliphist has aged out, dropped from our side too. The listing is
# the only authority on what still exists -- cliphist evicts silently once it is
# over its max-items -- and a cache that only ever grew would be holding the
# thumbnail and the source application of every image copied since the machine
# was installed.
prune() {
	local ids f id
	ids=$(cliphist list | cut -f1)
	for f in "$cache"/*.* "$meta"/*.json; do
		id=${f##*/}
		id=${id%%.*}
		grep -qxF -- "$id" <<<"$ids" || rm -f "$f"
	done
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

# The pattern that names this script's own watchers and nothing else. `watch`
# and `pause` both match on it, so there is one definition of what a clipboard
# watcher looks like rather than two that can drift apart. Deliberately stopping
# short of the command the watcher runs: that used to be `cliphist store` and is
# now this script, and a pattern that named either would leave the other kind
# running after an update.
watchers='wl-paste --type (text|image) --watch'

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
	setsid wl-paste --type text --watch "$self" store >/dev/null 2>&1 &
	setsid wl-paste --type image --watch "$self" store >/dev/null 2>&1 &
	;;

# What the watchers run, with the copied bytes on stdin. A plain `cliphist
# store` with a note taken beside it: the source application, which cliphist has
# no field for and which is the one thing about an entry you cannot work out by
# looking at it afterwards. The window title is deliberately not kept: nothing
# draws it, and a cache of every page title copied from is not a thing to write
# to disk for free.
#
# The window is read after the store rather than before so that the note is
# never written for a copy that did not land. It is still the *current* focus
# and not the focus at the moment ctrl+C was pressed -- there is no such thing
# to ask for -- so copying and immediately switching windows mislabels the
# entry. Rare enough, and the alternative is no application column at all.
store)
	before=$(cliphist list | head -n1 | cut -f1 || true)
	cliphist store
	after=$(cliphist list | head -n1 | cut -f1 || true)

	# Nothing new on top: either cliphist ignored this copy (it has its own
	# ignore rules, which is how a password manager stays out of the history)
	# or it was already the newest entry. The top id then belongs to an older
	# copy whose source must not be overwritten with this window.
	[[ -n $after && $after != "$before" ]] || exit 0

	mkdir -p "$meta"
	hyprctl activewindow -j 2>/dev/null |
		jq -c --argjson id "$after" '{ id: $id, app: (.class // ""), at: (now | floor) }' \
			>"$meta/$after.json" || true
	# An empty file is what a failed hyprctl leaves behind, and `list` would
	# rather have no note than one it has to defend itself against.
	[[ -s "$meta/$after.json" ]] || rm -f "$meta/$after.json"
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
# or image and carrying whatever `store` noted about where it came from. The
# tab split is `.[0]` and the rest joined back together, because a preview is
# free to contain tabs of its own -- cliphist only collapses newlines.
list)
	prune
	thumbnails
	# The notes as one id -> note object, built out here rather than in the jq
	# below: reading a directory of files is not something a jq filter over
	# stdin can do, and passing it in whole is one argument instead of one
	# `--slurpfile` per entry.
	notes=$(cat "$meta"/*.json 2>/dev/null | jq -s 'map({ key: (.id | tostring), value: . }) | from_entries' || true)
	[[ -n $notes ]] || notes='{}'

	cliphist list | jq -Rs --arg cache "$cache" --argjson notes "$notes" '
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
				# Every entry gets the note fields whether or not there is
				# a note: an entry copied before this script started keeping
				# them is the common case, and the panel drops an empty field
				# rather than testing for a missing one.
				| . + (($notes[.id | tostring] // {}) | { app: (.app // ""), at: (.at // 0) })
				| if (.preview | test(img)) then
					(.preview | capture(img)) as $m
					| . + {
						kind: "image",
						ext: $m.ext,
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

# What the preview pane draws for a text entry, and the counts under it.
# `cliphist list` collapses every newline into a space so that one entry is one
# line, which is right for the list and useless for a preview -- this is the
# only way back to the text as it was actually copied.
#
# Through a temporary file rather than straight down a pipe because the pane
# wants two different things from the same decode: the first 4KB to draw, and a
# character and word count over the whole of it.
#
# 1MiB is where that stops being worth it. A paste bigger than that is read only
# as far as the cap -- `|| true` because that cap is what closes the pipe and
# cliphist dying of SIGPIPE is the expected outcome -- and the counts are
# declared unknown rather than reported as the count of the part we looked at.
preview)
	tmp=$(mktemp)
	trap 'rm -f "$tmp"' EXIT

	cap=1048576
	cliphist decode "$2" | head -c "$cap" >"$tmp" || true

	bytes=$(wc -c <"$tmp")
	if ((bytes >= cap)); then
		chars=null
		words=null
		lines=null
		truncated=true
	else
		chars=$(wc -m <"$tmp")
		words=$(wc -w <"$tmp")
		# wc counts terminators, not lines, so an entry that was copied without
		# a trailing newline -- which is most of them -- is one short.
		lines=$(wc -l <"$tmp")
		if [[ -s $tmp && $(tail -c1 "$tmp" | wc -l) -eq 0 ]]; then
			lines=$((lines + 1))
		fi
		truncated=false
	fi

	head -c 4096 "$tmp" |
		jq -Rs --argjson chars "$chars" --argjson words "$words" --argjson lines "$lines" \
			--argjson bytes "$bytes" --argjson truncated "$truncated" \
			'{ chars: $chars, words: $words, lines: $lines, bytes: $bytes, truncated: $truncated, text: . }'
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
	for f in "$cache/$2".*; do
		setsid tensaku --filename "$f" >/dev/null 2>&1 &
		exit 0
	done
	exit 1
	;;

delete)
	line_for "$2" | cliphist delete
	rm -f "$cache/$2".* "$meta/$2.json"
	;;

wipe)
	cliphist wipe
	rm -rf "$cache"
	;;

*)
	echo "usage: clipboard.sh watch|pause|status|store|list|preview <id>|paste <id>|edit <id>|delete <id>|wipe" >&2
	exit 2
	;;
esac
