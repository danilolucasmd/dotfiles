#!/usr/bin/env bash
# Left-clicking a notification jumps to the app that sent it, on whatever
# workspace that app happens to live.
#
# Wired up in mako's config as:
#   on-button-left=exec "$HOME/.config/mako/scripts/focus-sender.sh" "$id"
#
# There are two paths, because notifications differ in what they offer:
#
#   1. The notification carries a default action (Brave, Discord, ...). Invoke
#      it and let the app decide what to raise -- Brave focuses the exact
#      window holding the tab that fired the notification, which is finer
#      grained than anything we could work out from the outside. Apps raise
#      themselves through xdg-activation, which Hyprland ignores unless
#      misc:focus_on_activate is true (set in hyprland.conf).
#
#   2. No default action (notify-send, Hyprshot, pika-backup, ...). Nothing
#      will raise itself, so match the sender against the window list here.
#
# mako only passes the notification id, so the rest is looked up via
# `makoctl list -j` while the notification is still on screen.

id="$1"
[[ "$id" =~ ^[0-9]+$ ]] || exit 0

notif=$(makoctl list -j 2>/dev/null |
  jq -c --argjson id "$id" 'map(select(.id == $id)) | .[0] // empty')
[ -z "$notif" ] && exit 0

# Path 1: hand it back to the app.
if [ "$(jq -r '(.actions // {}) | has("default")' <<<"$notif")" = "true" ]; then
  makoctl invoke -n "$id" default
  exit 0
fi

# Path 2: find the sender's window ourselves.
#
# desktop_entry is the reliable signal when an app sets it (it is meant to name
# the app's .desktop file, which usually matches the window class). app_name is
# a human label -- "Brave", "KDE Connect" -- so it only matches loosely, hence
# the ranking below. Classes are compared with punctuation and case stripped so
# that e.g. "KDE Connect" can meet "kdeconnect".
entry=$(jq -r '.desktop_entry // ""' <<<"$notif")
app=$(jq -r '.app_name // ""' <<<"$notif")

addr=$(hyprctl clients -j 2>/dev/null | jq -r --arg entry "$entry" --arg app "$app" '
  def norm: (. // "") | ascii_downcase | gsub("[^a-z0-9]"; "");
  # org.telegram.desktop -> telegram, so a reverse-DNS entry can still match a
  # plainly-named window class.
  def leaf: (. // "") | sub("\\.desktop$"; "") | split(".") | last // "";

  ($entry | norm) as $e
  | ($entry | leaf | norm) as $eleaf
  | ($app | norm) as $a
  | [ .[]
      | { addr: .address,
          # focusHistoryID: 0 is the focused window, so lower means more
          # recently used -- the best tie-breaker when an app has several
          # windows open.
          hist: (.focusHistoryID // 9999),
          cls: (.class | norm),
          icls: (.initialClass | norm) }
      | .score = (
          if    $e     != "" and (.cls == $e     or .icls == $e)     then 5
          elif  $eleaf != "" and (.cls == $eleaf or .icls == $eleaf) then 4
          elif  $a     != "" and (.cls == $a     or .icls == $a)     then 3
          elif  $e     != "" and (.cls | startswith($e))             then 2
          elif  $a     != "" and (.cls | contains($a))               then 1
          else 0 end)
      | select(.score > 0) ]
  | sort_by(-.score, .hist)
  | .[0].addr // empty')

# focuswindow switches to the window's workspace on its way, so this crosses
# workspaces on its own.
[ -n "$addr" ] && hyprctl dispatch focuswindow "address:$addr" >/dev/null

# Clicking should clear the notification either way; mako leaves it up when the
# button is bound to exec rather than to one of its built-in actions.
makoctl dismiss -n "$id" 2>/dev/null
exit 0
