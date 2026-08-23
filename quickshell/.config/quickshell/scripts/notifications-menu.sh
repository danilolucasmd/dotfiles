#!/usr/bin/env bash
# Browse past notifications in walker.
# - Select an entry    -> dismiss just that one (menu reopens so you can dismiss several)
# - Select "Clear all" -> dismiss everything
# - Escape             -> close
# Single-instance + toggle: if the menu is already open, invoking again closes it.

store="${XDG_STATE_HOME:-$HOME/.local/state}/mako-history"
log="$store/log.jsonl"
mkdir -p "$store"
lock="$store/menu.lock"

# Toggle: if another instance already holds the lock, the menu is open -> close it.
exec 9>"$lock"
if ! flock -n 9; then
  walker --close 2>/dev/null || pkill -x walker
  exit 0
fi

while :; do
  [ -f "$log" ] || : > "$log"

  uids=()
  labels=()
  while IFS=$'\t' read -r uid t app sum body; do
    [ -z "$uid" ] && continue
    ts=$(date -d "@$t" +'%H:%M' 2>/dev/null || echo '--:--')
    label="$ts"
    [ -n "$app" ] && label="$label  $app"
    [ -n "$sum" ] && label="$label: $sum"
    if [ -n "$body" ]; then
      bsh=${body:0:80}
      [ "${#body}" -gt 80 ] && bsh="$bsh…"
      label="$label — $bsh"
    fi
    uids+=("$uid")
    labels+=("$label")
  done < <(tac "$log" | jq -r '[.uid,.time,(.app//""),(.summary//""),((.body//"")|gsub("[\r\n]+";" "))]|@tsv' 2>/dev/null)

  if [ "${#uids[@]}" -eq 0 ]; then
    printf 'No past notifications\n' | walker --dmenu -p 'Notifications' >/dev/null 2>&1
    break
  fi

  # Index 0 is the "Clear all" row; the rest line up with uids[].
  menu_uids=("__CLEARALL__" "${uids[@]}")
  idx=$( { printf '󰩺  Clear all (%s)\n' "${#uids[@]}"; printf '%s\n' "${labels[@]}"; } \
          | walker --dmenu --index -p 'Notifications' 2>/dev/null )

  [ -z "$idx" ] && break                 # Escape / closed
  case "$idx" in *[!0-9]*) break ;; esac  # non-numeric -> bail

  sel="${menu_uids[$idx]}"
  if [ "$sel" = "__CLEARALL__" ]; then
    : > "$log"
    break
  else
    tmp=$(mktemp)
    if jq -c --arg uid "$sel" 'select(.uid != $uid)' "$log" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$log"
    else
      rm -f "$tmp"
    fi
  fi
done
