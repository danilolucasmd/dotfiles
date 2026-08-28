#!/usr/bin/env bash
# The wallpaper picker's two halves: the listing the panel draws, and setting
# the one that was chosen.
#
# The wallpaper is addressed everywhere through one stable path --
# ~/.local/state/hypr/wallpaper, a symlink at $ACTIVE_WALLPAPER_PATH -- rather
# than by naming the image file. hyprpaper and hyprlock both read that env var
# out of hyprland.conf, and a chosen wallpaper has to outlive the session, so
# the alternatives were rewriting `env =` in a checked-in config from a picker
# (runtime state in the repo) or sourcing a generated fragment (a `source =` of
# a file that does not exist yet on a fresh clone is a config error). Retargeting
# a symlink is neither: the config never changes, the link *is* the state, and
# hyprpaper picks the new one up at the next login with nothing to re-apply.
#
# The link has no extension on purpose, so it can point at a .jpg or a .png
# without being renamed. That is safe because hyprpaper and hyprlock both load
# images through hyprgraphics, which sniffs the format with libmagic rather than
# trusting the name -- and both canonicalise the path first, which is why
# `listactive` below answers with the real file.
set -euo pipefail

dir="${XDG_CONFIG_HOME:-$HOME/.config}/wallpapers"
link="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/wallpaper"

case "${1:-list}" in
# Everything the panel draws: every wallpaper on the machine, and which one is
# already up so it can open on it rather than on the first of the list.
list)
	# What is on screen right now, resolved past both symlinks -- the state
	# link and the ~/.config/wallpapers one stow leaves pointing into this
	# repo -- which is why the entries below carry a `real` to compare against
	# rather than being matched on the path the panel would set.
	current=$(hyprctl hyprpaper listactive 2>/dev/null | sed -n '1s/^[^:]*: *//p')
	# hyprpaper not up yet, or up with nothing loaded: the link still knows.
	[[ -n $current ]] || current=$(readlink -f "$link" 2>/dev/null || true)

	for f in "$dir"/*; do
		# Also what skips the unexpanded glob when the directory is empty.
		[[ -f $f ]] || continue
		# By extension rather than by `file`: this runs for every entry on
		# every open, and the directory is ours -- anything in it that is not
		# one of these is not a wallpaper somebody put there to use.
		case "${f,,}" in
		*.jpg | *.jpeg | *.png | *.webp | *.bmp) ;;
		*) continue ;;
		esac

		name=${f##*/}
		jq -nc \
			--arg path "$f" \
			--arg real "$(realpath "$f")" \
			--arg name "${name%.*}" \
			'{path: $path, real: $real, name: $name}'
	done | jq -sc --arg current "$current" '{current: $current, wallpapers: .}'
	;;

# Chosen. The link is what makes it stick; the hyprctl is what makes it visible
# without waiting for a login. Nothing preloads first -- hyprpaper 0.8 loads on
# demand and has dropped the `preload` request altogether.
set)
	target=${2:-}
	if [[ -z $target || ! -f $target ]]; then
		echo "wallpaper.sh: not a file: ${target:-<none>}" >&2
		exit 1
	fi

	mkdir -p "${link%/*}"
	ln -sfn "$target" "$link"
	hyprctl hyprpaper wallpaper ",$link" >/dev/null
	;;

*)
	echo "usage: wallpaper.sh [list|set <path>]" >&2
	exit 1
	;;
esac
