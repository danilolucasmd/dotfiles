#!/usr/bin/env bash
#
# Run one web app as its own qutebrowser instance: qutebrowser-app.sh <slug> <url>
#
# A separate instance, because qutebrowser gives every window of one instance
# the same app id, and an app needs its own (its icon in the bar, its windows
# kept apart from the browser's, notifications routed back to it). The cost is
# a profile per app under ~/.local/share/qutebrowser-apps/<slug>: each app is
# signed into once, separately from the main browser.
#
# The window is bare: no tab bar, a status bar only while in a mode other than
# normal (insert, hints, the command line), and tabs_are_windows so a link
# the app opens in a new tab shows up as a window rather than vanishing into a
# hidden tab bar. Forced dark mode is off: the apps all have dark themes of
# their own, which preferred_color_scheme still asks for, and forcing one over
# them only garbles it. Requests to become a protocol handler (Gmail asking for
# mailto: links) are refused: the registration would only cover links clicked
# inside that app's own window, and the answer is not kept between launches, so
# the question came back every time. Everything else (keys, theme) is the main
# config.py, which every app loads.
#
# The app id is webapp-<host>, and the app's notifications carry it as their
# desktop entry (config.py does that), so quickshell's focus-sender.sh can take
# a clicked one straight to this window. They are signed with the app's name
# rather than "qutebrowser", and the origin URL qutebrowser would otherwise put
# above every message is off: the name already says where it came from.
set -euo pipefail

slug=$1
url=$2
host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://##; s#[/?#].*##')
class="webapp-$host"

# The app's display name from apps.conf, for config.py to sign its
# notifications with (QUTE_WEBAPP_NAME; see the notifications section there).
QUTE_WEBAPP_NAME=$(awk -F'|' -v s="$slug" '!/^#/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/[ \t]/, "", $3); if ($3 == s) { print $1; exit } }' "$(dirname "$(realpath "$0")")/apps.conf")
export QUTE_WEBAPP_NAME

# Launching an app that is already open raises it instead of opening a second
# window, which is what a dock icon is expected to do.
if command -v hyprctl >/dev/null 2>&1; then
	addr=$(hyprctl clients -j | jq -r --arg c "$class" 'map(select(.class == $c)) | first | .address // empty')
	if [[ -n "$addr" ]]; then
		exec hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
	fi
fi

# QtWebEngine ships no Widevine, so DRM video (Spotify) needs a copy from
# elsewhere: Brave downloads one into its profile and keeps it updated. The
# newest version is picked at launch, since the directory is versioned.
qt_args='"force-dark-mode"'
widevine=$(ls -d "$HOME"/.config/BraveSoftware/Brave-Browser/WidevineCdm/*/_platform_specific/linux_x64/libwidevinecdm.so 2>/dev/null | sort -V | tail -n1 || true)
[[ -n "$widevine" ]] && qt_args+=", \"widevine-path=$widevine\""

# WhatsApp starts in passthrough: it is all typing and its own shortcuts
# (Ctrl+Alt+N, Alt+arrows through chats), and in normal mode every key that
# misses the message box is a qutebrowser command instead. Nothing about a page
# load leaves passthrough (only switching tabs could, and the app has one), so
# entering it once at startup holds; Shift+Escape gets back to normal mode.
# The status bar is off entirely there rather than in-mode, or it would sit at
# the bottom saying PASSTHROUGH for as long as the app is open. The command
# line still shows when `:` is typed: qutebrowser raises the bar for it even
# under `never`.
statusbar=in-mode
startup=()
case "$slug" in
	whatsapp)
		statusbar=never
		startup=(":mode-enter passthrough")
		;;
esac

# The apps' user scripts (see greasemonkey/) are linked into each profile's
# config directory, which is where a --basedir instance looks for them; the
# main browser's scripts in ~/.config/qutebrowser are not seen by the apps.
basedir="${XDG_DATA_HOME:-$HOME/.local/share}/qutebrowser-apps/$slug"
mkdir -p "$basedir/config"
ln -sfn "$(dirname "$(realpath "$0")")/greasemonkey" "$basedir/config/greasemonkey"

exec qutebrowser \
	--basedir "$basedir" \
	--config-py "${XDG_CONFIG_HOME:-$HOME/.config}/qutebrowser/config.py" \
	--desktop-file-name "$class" \
	--set tabs.show never \
	--set statusbar.show "$statusbar" \
	--set tabs.tabs_are_windows true \
	--set window.title_format '{current_title}' \
	--set content.notifications.enabled true \
	--set content.notifications.show_origin false \
	--set colors.webpage.darkmode.enabled false \
	--set content.register_protocol_handler false \
	--set confirm_quit '["never"]' \
	--set qt.args "[$qt_args]" \
	"$url" "${startup[@]}"
