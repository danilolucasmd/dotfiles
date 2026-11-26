#!/usr/bin/env bash
#
# Generate the web-app launchers from apps.conf: one desktop entry per app,
# each running it through qutebrowser-app.sh as a bare qutebrowser window of its
# own. That script holds everything about how an app runs; this one only writes
# the entries, and removes the ones it wrote for apps since deleted.
#
# Usage:  ./generate.sh

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/apps.conf"
ICONS="$DIR/icons"
APPDIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
MARKER="X-Generated-By=webapps-generator"

mkdir -p "$APPDIR"

# Remove launchers we previously generated so deletions in apps.conf propagate.
shopt -s nullglob
for f in "$APPDIR"/webapp-*.desktop; do
  grep -qF "$MARKER" "$f" && rm -f "$f"
done
shopt -u nullglob

trim() { sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

count=0
while IFS='|' read -r name url slug _rest || [[ -n "${name:-}" ]]; do
  name="$(printf '%s' "${name:-}" | trim)"
  url="$(printf '%s' "${url:-}" | trim)"
  slug="$(printf '%s' "${slug:-}" | trim)"
  [[ -z "$name" || "$name" == \#* ]] && continue
  if [[ -z "$url" || -z "$slug" ]]; then
    echo "skip (missing url/slug): $name" >&2; continue
  fi

  # Must match the app id qutebrowser-app.sh gives the window.
  host="$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#[/?#].*##')"
  wmclass="webapp-$host"
  icon="$ICONS/$slug.png"
  [[ -f "$icon" ]] || icon="webapp-$slug"   # fall back to a themed icon name

  out="$APPDIR/webapp-$slug.desktop"
  cat > "$out" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Name=$name
Exec="$DIR/qutebrowser-app.sh" $slug $url
Icon=$icon
StartupWMClass=$wmclass
Categories=Network;
$MARKER
EOF
  echo "generated: ${out##*/}  ($url)"
  count=$((count + 1))
done < "$CONF"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPDIR" 2>/dev/null || true
echo "Done: $count web app(s)."
