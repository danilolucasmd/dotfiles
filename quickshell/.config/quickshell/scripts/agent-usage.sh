#!/bin/bash
# Quickshell module: Claude Code rate-limit usage (5h session window + 7d window).
# Prints one line of JSON, consumed by the module's JsonScript.
# Empty text => the module hides itself (same trick as recording.sh).
#
# Three sources, newest wins:
#   1. The statusLine feed (agent-usage-statusline.sh) — Claude Code hands it
#      .rate_limits on every render, so it is near-live while a session runs,
#      costs nothing and cannot be rate limited. Needs a settings.json entry.
#   2. ~/.claude.json .cachedUsageUtilization — Claude Code's own cache of the
#      usage endpoint. Refreshes itself every few minutes during a session.
#   3. Anthropic's OAuth usage endpoint, fetched here with the token Claude Code
#      stores in ~/.claude/.credentials.json. The only source that still works
#      with no session running, but it rate limits hard, so it is polled slowly
#      and skipped entirely while source 1 is fresh. The token goes to curl over
#      stdin, not argv, so it stays out of ps.

# Percent thresholds for the warning / critical colours.
warn_at=70
crit_at=90
# Data older than this (minutes) is reported as stale.
stale_after=360
# How often to actually hit the network. Usage cannot move while no Claude
# process is running, so idle polling backs off hard instead of pestering the
# endpoint all day. It rate-limits hard — ~20 requests in 30s earned a 429 that
# was still in force 10 minutes later — so the sustained cadence stays slow and
# $backoff_429 sits the module right out when one lands. Freshness is meant to
# come from source 1, not from polling this.
fetch_active=300
fetch_idle=900
backoff_429=900
# Skip the network entirely while the statusLine feed is at most this old.
sl_fresh=90

cfg_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
creds="$cfg_dir/.credentials.json"
state="${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/}"
state="${state:-$HOME/}.claude.json"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
cache="$cache_dir/agent-usage.json"
sl_cache="$cache_dir/agent-usage-statusline.json"
# Touched on every fetch ATTEMPT, so a failing endpoint backs off at the same
# cadence as a succeeding one instead of being retried every tick.
attempt="$cache_dir/agent-usage.attempt"

now=$(date +%s)

hide() { printf '{"text":""}\n'; exit 0; }

file_age() { # seconds since mtime, or a huge number if absent
  [ -f "$1" ] && echo $(( now - $(stat -c %Y "$1" 2>/dev/null || echo 0) )) || echo 999999
}

# GET the usage endpoint into $cache. Returns non-zero and leaves the previous
# cache untouched on any failure, so a flaky network degrades to source 2.
refresh() {
  [ -r "$creds" ] || return 1
  local exp tok tmp
  exp=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds" 2>/dev/null) || return 1
  # expiresAt is epoch ms. An expired token means Claude Code has to renew it.
  [ "${exp%%.*}" -gt "$((now * 1000))" ] 2>/dev/null || return 1
  tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
  [ -n "$tok" ] || return 1

  mkdir -p "$cache_dir" || return 1
  tmp=$(mktemp "$cache.XXXXXX") || return 1
  touch "$attempt"
  local code
  code=$(curl -sS --max-time 8 -o "$tmp" -w '%{http_code}' --config - 2>/dev/null <<-EOF
		url = "https://api.anthropic.com/api/oauth/usage"
		header = "Authorization: Bearer $tok"
		header = "anthropic-beta: oauth-2025-04-20"
		header = "Accept: application/json"
	EOF
  )
  # Only promote a payload that actually carries a window.
  if [ "$code" = "200" ] && jq -e '.five_hour != null or .seven_day != null' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp.reject"
    mv -f "$tmp" "$cache"
    return 0
  fi
  # Rate limited: date the attempt marker into the future so the guard below
  # holds us off for $backoff_429 rather than retrying on the next tick.
  [ "$code" = "429" ] && touch -d "@$((now + backoff_429))" "$attempt"
  rm -f "$tmp"
  return 1
}

# Back off to $fetch_idle unless a Claude session is live.
if pgrep -x claude >/dev/null 2>&1; then min_fetch=$fetch_active; else min_fetch=$fetch_idle; fi
if [ "$(file_age "$sl_cache")" -lt "$sl_fresh" ]; then
  : # statusLine feed is current — nothing the endpoint could add
elif [ "$(file_age "$attempt")" -ge "$min_fetch" ]; then
  refresh
fi

# Every source reduced to the same 5 fields; the most recently captured wins.
# Sources 1 and 3 carry the windows at the top level and are timestamped by file
# mtime; Claude Code's cache nests them and timestamps itself in ms.
read_flat() { # $1=file with top-level five_hour/seven_day
  local at
  [ -f "$1" ] || return
  at=$(stat -c %Y "$1" 2>/dev/null) || return
  jq -r --argjson at "$at" '
    select(.five_hour != null or .seven_day != null)
    | [ (.five_hour.utilization // -1), (.five_hour.resets_at // ""),
        (.seven_day.utilization // -1), (.seven_day.resets_at // ""), $at ]
    | @tsv' "$1" 2>/dev/null
}

fields=""; best_at=0
consider() {
  local at
  [ -n "$1" ] || return
  at=$(cut -f5 <<<"$1")
  [ "$at" -gt "$best_at" ] 2>/dev/null || return
  fields=$1; best_at=$at
}

consider "$(read_flat "$sl_cache")"
consider "$(read_flat "$cache")"
[ -r "$state" ] && consider "$(jq -r '
  .cachedUsageUtilization as $c
  | ($c.utilization // empty) as $u
  | select($u.five_hour != null or $u.seven_day != null)
  | [ ($u.five_hour.utilization // -1), ($u.five_hour.resets_at // ""),
      ($u.seven_day.utilization // -1), ($u.seven_day.resets_at // ""),
      (($c.fetchedAtMs // 0) / 1000 | floor) ]
  | @tsv' "$state" 2>/dev/null)"

[ -n "$fields" ] || hide
IFS=$'\t' read -r five_pct five_reset seven_pct seven_reset captured_at <<<"$fields"
five_pct=${five_pct%%.*}; seven_pct=${seven_pct%%.*}

# "43m" / "16h 2m" / "2d 4h" — how long the window has left.
countdown() { # $1=iso8601 timestamp
  local until left d h m
  [ -n "$1" ] || { printf '?'; return; }
  until=$(date -d "$1" +%s 2>/dev/null) || { printf '?'; return; }
  left=$((until - now))
  [ "$left" -le 0 ] && { printf 'now'; return; }
  d=$((left / 86400)); h=$((left % 86400 / 3600)); m=$((left % 3600 / 60))
  if   [ "$d" -gt 0 ]; then printf '%dd %dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh %dm' "$h" "$m"
  else                      printf '%dm' "$m"
  fi
}

# Percentage of the window that has already elapsed, so usage can be compared
# against the pace that would exactly exhaust the allowance at reset time.
elapsed_pct() { # $1=iso8601 reset  $2=window length in seconds
  local until start
  until=$(date -d "$1" +%s 2>/dev/null) || { printf -- '-1'; return; }
  start=$((until - $2))
  printf '%d' $(( (now - start) * 100 / $2 ))
}

five_left=$(countdown "$five_reset")
seven_left=$(countdown "$seven_reset")
five_pace=$(elapsed_pct "$five_reset" $((5 * 3600)))
seven_pace=$(elapsed_pct "$seven_reset" $((7 * 86400)))

age_min=$(( (now - captured_at) / 60 ))
stale=0
[ "$age_min" -ge "$stale_after" ] && stale=1

# Class: worst of the two windows wins for warning/critical, so a weekly spike
# still shows even though only the 5h number is displayed. .ahead tracks the
# displayed 5h window. Staleness outranks everything (dimmed, because a stale
# high number is not something to alarm about).
worst=$five_pct
[ "$seven_pct" -gt "$worst" ] && worst=$seven_pct
if   [ "$stale" -eq 1 ];          then class=stale
elif [ "$worst" -ge "$crit_at" ]; then class=critical
elif [ "$worst" -ge "$warn_at" ]; then class=warning
elif [ "$five_pace" -ge 0 ] && [ "$five_pct" -gt "$five_pace" ]; then class=ahead
else                                   class=normal
fi

# Only the 5h session window is shown — it is the one that actually bites.
# The weekly window lives in the tooltip, but still drives the colour.
text="󰚩 ${five_pct}%"
[ "$five_pct" -lt 0 ] && text="󰚩 7d ${seven_pct}%"

pace_note() { # $1=used  $2=pace
  [ "$2" -lt 0 ] && return
  if [ "$1" -gt "$2" ]; then printf ' (ahead of pace, %d%% elapsed)' "$2"
  else                       printf ' (on pace, %d%% elapsed)' "$2"
  fi
}

tooltip="Claude Code usage"
[ "$five_pct"  -ge 0 ] && tooltip+=$'\n'"Session (5h): ${five_pct}% used$(pace_note "$five_pct" "$five_pace"), resets in ${five_left}"
[ "$seven_pct" -ge 0 ] && tooltip+=$'\n'"Weekly (7d): ${seven_pct}% used$(pace_note "$seven_pct" "$seven_pace"), resets in ${seven_left}"
if [ "$stale" -eq 1 ]; then
  tooltip+=$'\n\n'"Stale: last refreshed $((age_min / 60))h ago."
elif [ "$age_min" -lt 1 ]; then
  tooltip+=$'\n\n'"Updated $(( now - captured_at ))s ago."
else
  tooltip+=$'\n\n'"Updated ${age_min}m ago."
fi

jq -nc --arg text "$text" --arg tt "$tooltip" --arg class "$class" \
  '{text:$text, tooltip:$tt, class:$class}'
