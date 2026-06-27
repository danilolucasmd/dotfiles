#!/usr/bin/env bash
# Waybar module: shows a bell with a count of stored (un-dismissed) past notifications.

store="${XDG_STATE_HOME:-$HOME/.local/state}/mako-history"
log="$store/log.jsonl"

icon_has="󰂚"
icon_empty="󰂜"

count=0
[ -f "$log" ] && count=$(wc -l < "$log" 2>/dev/null | tr -d ' ')
[ -z "$count" ] && count=0

if [ "$count" -gt 0 ]; then
  tt=$(tac "$log" | jq -r '"• \(.summary)\(if (.body//"")!="" then " — "+.body else "" end)"' 2>/dev/null \
        | head -n 12 | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
  jq -nc --arg t "$icon_has $count" --arg tt "$tt" \
     '{text:$t, tooltip:$tt, class:"has-notifications", alt:"has"}'
else
  jq -nc --arg t "$icon_empty" \
     '{text:$t, tooltip:"No past notifications", class:"empty", alt:"empty"}'
fi
