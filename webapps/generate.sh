#!/usr/bin/env bash
#
# Generate toolbar-free Brave web-app launchers from apps.conf.
#
# Brave's own "Install app" writes launchers that use --app-id=<id>, which opens
# the installed-PWA window — and that window shows a thin toolbar whenever the
# site's web-app manifest asks for it (display: minimal-ui / out-of-scope nav).
# There is no Brave setting to turn that off.
#
# This script instead writes launchers that use --app=<URL>, which opens a bare
# content-only window with no toolbar, regardless of the site's manifest.
# A stable --class is set so Hyprland / Waybar group each window under its icon.
#
# Usage:  ./generate.sh
# Env:    BRAVE_PROFILE  (default: Default)   BRAVE_BIN (default: autodetected)

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/apps.conf"
ICONS="$DIR/icons"
APPDIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
PROFILE="${BRAVE_PROFILE:-Default}"
MARKER="X-Generated-By=webapps-generator"

BRAVE="${BRAVE_BIN:-$(command -v brave || command -v brave-browser || echo /opt/brave-bin/brave)}"
[[ -x "$BRAVE" ]] || { echo "error: brave binary not found (set BRAVE_BIN)" >&2; exit 1; }

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

  wmclass="webapp-$slug"
  icon="$ICONS/$slug.png"
  [[ -f "$icon" ]] || icon="$wmclass"   # fall back to a themed icon name

  out="$APPDIR/webapp-$slug.desktop"
  cat > "$out" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Name=$name
Exec=$BRAVE --profile-directory=$PROFILE --app=$url --class=$wmclass
Icon=$icon
StartupWMClass=$wmclass
Categories=Network;
$MARKER
EOF
  echo "generated: ${out##*/}  ($url)"
  count=$((count + 1))
done < "$CONF"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPDIR" 2>/dev/null || true
echo "Done — $count web app(s). Using: $BRAVE (profile: $PROFILE)"
