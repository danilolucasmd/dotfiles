#!/usr/bin/env bash
# Open something KDE Connect received, in whatever this system opens it with.
#
#   open-shared.sh file <file:// url>   a received file
#   open-shared.sh text <text>          shared text (already on the clipboard)
#
# Text that ends in a link opens the link, which is what sharing a page from the
# phone's browser sends. Any other text is written to a file and opened as one,
# so it gets the same editor a received .txt would.
#
# This replaces the buttons KDE Connect puts on its own text notification rather
# than invoking them. "Open in Text Editor" writes its temporary file relative to
# the daemon's working directory, which is $HOME, leaving one stray
# kdeconnect-XXXXXX.txt per click. It then has KIO launch nvim.desktop, a
# Terminal=true entry, with no Plasma terminal configured to run it in.
#
# The terminal case is the reason this is not just `xdg-open`. Outside a desktop
# environment xdg-open runs a Terminal=true entry in the terminal it was itself
# started from, and launched from the shell there is none: nvim starts with no
# tty and exits before anything is drawn.

set -euo pipefail

kind=${1:?file or text}
value=${2:-}

open_path() {
  local path=$1 mime entry desktop dir cmd

  mime=$(xdg-mime query filetype "$path")
  entry=$(xdg-mime query default "$mime")

  desktop=""
  if [[ -n $entry ]]; then
    for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS//:/ }; do
      if [[ -f $dir/applications/$entry ]]; then
        desktop=$dir/applications/$entry
        break
      fi
    done
  fi

  if [[ -n $desktop ]] && grep -qx 'Terminal=true' "$desktop"; then
    # Field codes (%F, %u, ...) stripped and the file appended: the whole of
    # the Exec spec that a terminal editor's entry ever uses.
    cmd=$(sed -n '/^\[Desktop Entry\]/,/^\[/s/^Exec=//p' "$desktop" | head -n1 | sed 's/%[a-zA-Z]//g')
    read -ra cmd <<<"$cmd"
    exec ghostty -e "${cmd[@]}" "$path"
  fi

  exec xdg-open "$path"
}

case $kind in
  file)
    path=${value#file://}
    open_path "$(printf '%b' "${path//%/\\x}")"
    ;;
  text)
    last=$(printf '%s\n' "$value" | sed '/^[[:space:]]*$/d' | tail -n1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [[ $last =~ ^https?://[^[:space:]]+$ ]]; then
      exec xdg-open "$last"
    fi
    # The runtime dir is a tmpfs cleared at logout, so these never pile up.
    dir=${XDG_RUNTIME_DIR:-/tmp}/kdeconnect
    mkdir -p "$dir"
    file=$dir/shared-$(date +%Y%m%d-%H%M%S).txt
    printf '%s\n' "$value" >"$file"
    open_path "$file"
    ;;
  *)
    echo "usage: open-shared.sh file <url> | text <text>" >&2
    exit 2
    ;;
esac
