#!/usr/bin/env bash
# Logs a notification (by mako id) into a persistent history store.
# Invoked by mako via:  on-notify=exec "$HOME/.config/mako/scripts/capture.sh" "$id"
# mako only passes the notification id, so we look the rest up via `makoctl list -j`.

id="$1"
[ -z "$id" ] && exit 0

store="${XDG_STATE_HOME:-$HOME/.local/state}/mako-history"
log="$store/log.jsonl"
mkdir -p "$store"

# Grab this notification's fields while it is still active.
notif=$(makoctl list -j 2>/dev/null | jq -c --argjson id "$id" 'map(select(.id == $id)) | .[0] // empty')
[ -z "$notif" ] && exit 0

# Skip music/now-playing spam (mpd track changes, etc.).
cat=$(printf '%s' "$notif" | jq -r '.category // ""')
[ "$cat" = "mpd" ] && exit 0

uid=$(date +%s%N)
printf '%s' "$notif" | jq -c \
  --arg uid "$uid" \
  --argjson t "$(date +%s)" \
  '{uid:$uid, time:$t, app:(.app_name//""), summary:(.summary//""), body:(.body//""), urgency:(.urgency//"normal")}' \
  >> "$log"

# Keep the store bounded.
tail -n 200 "$log" > "$log.tmp" 2>/dev/null && mv "$log.tmp" "$log"

# Nudge the waybar module to refresh its badge.
pkill -RTMIN+9 waybar 2>/dev/null || true
exit 0
