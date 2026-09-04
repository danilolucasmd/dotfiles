#!/bin/bash
# Claude Code, as one agent for the agent-usage panel.
#
# Every provider in this directory answers the same two verbs and prints one
# line of JSON, which is the whole of the multi-agent contract -- drop a
# `codex.sh` beside this one and a tab for it appears in the panel with nothing
# else to change. See agents/README.md.
#
#   limits  cheap, polled on a timer: identity, plan, and one entry per
#           rate-limit window. Empty output means "this agent is not installed
#           here" and the panel forgets it exists; an entry with available:false
#           means "installed, but nothing has been read yet", which is worth a
#           tab and a sentence.
#   tokens  expensive, run only while the panel is open: what the last seven
#           days actually cost, by day and by model.
#
# The limits half has three sources, newest wins:
#   1. The statusLine feed (agent-usage-statusline.sh) -- Claude Code hands it
#      .rate_limits on every render, so it is near-live while a session runs,
#      costs nothing and cannot be rate limited. Needs a settings.json entry.
#   2. ~/.claude.json .cachedUsageUtilization -- Claude Code's own cache of the
#      usage endpoint. Refreshes itself every few minutes during a session.
#   3. Anthropic's OAuth usage endpoint, fetched here with the token Claude Code
#      stores in ~/.claude/.credentials.json. The only source that still works
#      with no session running, and the only one carrying the per-model weekly
#      windows, but it rate limits hard, so it is polled slowly and skipped
#      entirely while source 1 is fresh. The token goes to curl over stdin, not
#      argv, so it stays out of ps.
#
# The tokens half reads nothing but the session transcripts Claude Code already
# writes to ~/.claude/projects/**/*.jsonl. No endpoint reports this.

# Data older than this (minutes) is reported as stale.
stale_after=360
# How often to actually hit the network. Usage cannot move while no Claude
# process is running, so idle polling backs off hard instead of pestering the
# endpoint all day. It rate-limits hard -- ~20 requests in 30s earned a 429 that
# was still in force 10 minutes later -- so the sustained cadence stays slow and
# $backoff_429 sits the module right out when one lands. Freshness is meant to
# come from source 1, not from polling this.
fetch_active=300
fetch_idle=900
backoff_429=900
# Skip the network entirely while the statusLine feed is at most this old.
sl_fresh=90
# Days of transcript the token history covers. The store keeps one day more
# than the panel draws, so "6 days ago" is still whole when the clock rolls over
# mid-session rather than being half-pruned into a short bar.
show_days=7
keep_days=8

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
store="$cache_dir/agent-tokens/claude-code"

now=$(date +%s)

file_age() { # seconds since mtime, or a huge number if absent
  [ -f "$1" ] && echo $(( now - $(stat -c %Y "$1" 2>/dev/null || echo 0) )) || echo 999999
}

# ---------------------------------------------------------------- limits ----

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
  if [ "$code" = "200" ] && jq -e '.limits != null or .five_hour != null or .seven_day != null' "$tmp" >/dev/null 2>&1; then
    mv -f "$tmp" "$cache"
    return 0
  fi
  # Rate limited: date the attempt marker into the future so the guard below
  # holds us off for $backoff_429 rather than retrying on the next tick.
  [ "$code" = "429" ] && touch -d "@$((now + backoff_429))" "$attempt"
  rm -f "$tmp"
  return 1
}

# Every source reduced to the same shape: a capture time and a list of windows
# carrying nothing but a name, a percentage and an ISO reset. The panel does all
# the phrasing, so no prose is built here.
#
# The endpoint's `limits` array is the only source that enumerates the windows
# rather than naming two of them in fixed fields, which is what lets a
# per-model weekly window ("Opus Weekly") appear without this script being
# taught the model names. The other two sources, and older endpoint payloads,
# still only have five_hour / seven_day, so both shapes are read.
normalise='
  def cap: if . == "" then . else (.[0:1] | ascii_upcase) + .[1:] end;
  def name($kind):
    if $kind == "session" then "Session"
    elif $kind == "weekly_all" then "Weekly"
    elif ($kind | startswith("weekly_")) then
      ($kind | ltrimstr("weekly_") | gsub("_"; " ") | cap) + " Weekly"
    else ($kind | gsub("_"; " ") | cap) end;
  def pct: if . == null then -1 else (. | floor) end;
  def win($kind; $w):
    if $w == null or ($w.utilization // $w.percent) == null then empty
    else { label: name($kind),
           span: (if $kind == "session" then "5h" else "7d" end),
           seconds: (if $kind == "session" then 18000 else 604800 end),
           pct: (($w.utilization // $w.percent) | pct),
           resetsAt: ($w.resets_at // "") }
    end;
  { at: $at,
    limits: [ if (.limits | type) == "array" and (.limits | length) > 0
              then (.limits[] | win(.kind; .))
              else (win("session"; .five_hour), win("weekly_all"; .seven_day))
              end ] }
  | select(.limits | length > 0)'

read_source() { # $1=file  $2=name of the source it came from
  local at
  [ -f "$1" ] || return
  at=$(stat -c %Y "$1" 2>/dev/null) || return
  jq -c --argjson at "$at" --arg source "$2" \
    "$normalise | .source = \$source" "$1" 2>/dev/null
}

do_limits() {
  # Nothing to report on a machine that has never run Claude Code -- not even a
  # tab, which is the difference between "no agent" and "no reading yet".
  [ -d "$cfg_dir" ] || return

  # Back off to $fetch_idle unless a Claude session is live.
  local min_fetch
  if pgrep -x claude >/dev/null 2>&1; then min_fetch=$fetch_active; else min_fetch=$fetch_idle; fi
  if [ "$(file_age "$sl_cache")" -lt "$sl_fresh" ]; then
    : # statusLine feed is current -- nothing the endpoint could add
  elif [ "$(file_age "$attempt")" -ge "$min_fetch" ]; then
    refresh
  fi

  local reading
  reading=$( { read_source "$sl_cache" "statusLine feed"
               read_source "$cache" "usage endpoint"
               # Claude Code's own cache nests the windows and timestamps itself
               # in ms, so it is reshaped into the common form before the same
               # normaliser runs over it.
               [ -r "$state" ] && jq -c '
                 .cachedUsageUtilization as $c
                 | ($c.utilization // empty)
                 | select(.five_hour != null or .seven_day != null)
                 | { five_hour, seven_day, at: (($c.fetchedAtMs // 0) / 1000 | floor) }' \
                 "$state" 2>/dev/null \
                 | jq -c --arg source "Claude Code cache" \
                     "(.at) as \$at | $normalise | .source = \$source" 2>/dev/null
             } | jq -sc 'max_by(.at) // empty' )

  # A plan the account is on rather than a plan this script knows about: the
  # tier string is where the multiplier lives ("...max_20x..."), and it is only
  # ever shown, so an unrecognised one degrades to the bare subscription name.
  #
  # The account profile in .claude.json is asked for first because it is the
  # only one of the two that follows an upgrade: .credentials.json is written
  # when the OAuth token is issued and keeps saying "pro" until the token is
  # refreshed, which can be weeks after the plan changed. The profile carries a
  # `profileFetchedAt` and is refetched on startup, so an upgrade shows up on
  # the next launch. Credentials stay as the fallback for the window before the
  # first profile fetch lands.
  local plan=""
  local sub tier
  if [ -r "$state" ]; then
    # organizationType is "claude_max" / "claude_pro"; the user tier overrides
    # the organization one where a seat sets it, which is why it is asked for
    # first rather than merged.
    sub=$(jq -r '.oauthAccount.organizationType // empty
                 | sub("^claude_"; "")' "$state" 2>/dev/null)
    tier=$(jq -r '.oauthAccount.userRateLimitTier
                  // .oauthAccount.organizationRateLimitTier // empty' \
                 "$state" 2>/dev/null)
  fi
  if [ -z "$sub" ] && [ -r "$creds" ]; then
    sub=$(jq -r '.claudeAiOauth.subscriptionType // empty' "$creds" 2>/dev/null)
    tier=$(jq -r '.claudeAiOauth.rateLimitTier // empty' "$creds" 2>/dev/null)
  fi
  plan=${sub^^}
  # The multiplier is a suffix on a name, so it is only appended when there is
  # a name to suffix -- a tier with no subscription beside it would otherwise
  # render as a leading space and a bare "5X".
  if [ -n "$plan" ]; then
    case "$tier" in
      *20x*) plan="$plan 20X" ;;
      *5x*)  plan="$plan 5X" ;;
    esac
  fi

  if [ -z "$reading" ]; then
    jq -nc --arg plan "$plan" \
      '{id:"claude-code", name:"Claude Code", icon:"󰚩", avatar:"claude.svg",
        plan:$plan, available:false, limits:[]}'
    return
  fi

  # Everything derived from the clock is computed here rather than in QML: the
  # panel is redrawn on a binding, not on a tick, so a countdown worked out at
  # paint time would be frozen at whatever it said when the reading landed.
  jq -c --arg plan "$plan" --argjson now "$now" --argjson staleAfter "$stale_after" '
    def epoch: if . == null or . == "" then null
               else (.[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) end;
    def countdown($s):
      if $s == null then "?" elif $s <= 0 then "now"
      else ($s / 86400 | floor) as $d | ($s % 86400 / 3600 | floor) as $h
         | ($s % 3600 / 60 | floor) as $m
         | if $d > 0 then "\($d)d \($h)h" elif $h > 0 then "\($h)h \($m)m"
           else "\($m)m" end
      end;
    ($now - .at) as $age
    | { id: "claude-code", name: "Claude Code", icon: "󰚩",
        avatar: "claude.svg", plan: $plan,
        available: true, source: .source, ageSeconds: $age,
        stale: ($age >= $staleAfter * 60),
        limits: [ .limits[]
          | (.resetsAt | epoch) as $until
          | { label, span, pct,
              resetsIn: countdown(if $until == null then null else $until - $now end),
              # Percentage of the window already elapsed, so usage can be read
              # against the pace that would exactly exhaust the allowance at
              # reset time. A window sitting idle has no reset and therefore no
              # anchor to measure elapsed time from, so it reports -1 and the
              # panel draws no pace mark at all.
              pace: (if $until == null then -1
                     else (($now - ($until - .seconds)) * 100 / .seconds | floor) end) } ] }' \
    <<<"$reading"
}

# ------------------------------------------------------------------ cost ----

# What a million tokens costs, in USD. These are the public API list rates, so
# the dollars the panel draws are "what this week would have cost on the API" --
# a subscription is a flat monthly fee and has no per-token price to report
# against. That is still the number worth seeing: it is the only way to compare
# a day against another day, or Opus against Haiku, in a unit that is not
# "percent of an allowance Anthropic does not publish".
#
# Only input and output are listed, because cache tokens are the same three
# multiples of the input rate on every model: a 5-minute cache write is 1.25x
# input, a 1-hour write 2x, and a cache read 0.1x. Pricing them at the plain
# input rate is not a rounding error -- Claude Code is over 90% cache reads on a
# normal session, so it would overstate the week by nearly ten times.
#
# Fast mode is exactly double the standard rate on the models that offer it, so
# it is a multiplier here rather than a second table; `usage.speed` says which
# one a message ran at. The 1M-context premium is deliberately not modelled: it
# only applies to the requests inside a `[1m]` session that actually exceed 200K
# input tokens, and Claude Code does not record enough per-request context to
# tell which those were.
#
# An unrecognised model falls back to its family's current rate rather than to
# zero. A model released after this was written is far likelier to be priced
# like the rest of its family than to be free, and a confident $0.00 in the
# panel is a worse answer than a slightly stale rate.
price_defs='
  def rates($model; $fast):
    ($model | sub("\\[[^\\]]*\\]$"; "") | sub("-[0-9]{8}$"; "")) as $m
    | ({ "claude-fable-5":   [10, 50],
         "claude-mythos-5":  [10, 50],
         "claude-opus-5":    [5, 25],
         "claude-opus-4-8":  [5, 25],
         "claude-opus-4-7":  [5, 25],
         "claude-opus-4-6":  [5, 25],
         "claude-opus-4-5":  [5, 25],
         "claude-opus-4-1":  [15, 75],
         "claude-opus-4":    [15, 75],
         "claude-sonnet-5":  [2, 10],
         "claude-sonnet-4-6": [3, 15],
         "claude-sonnet-4-5": [3, 15],
         "claude-sonnet-4":   [3, 15],
         "claude-haiku-4-5":  [1, 5],
         "claude-3-5-haiku":  [0.8, 4]
       }[$m]
       // (if   ($m | test("fable|mythos")) then [10, 50]
          elif ($m | test("opus"))   then [5, 25]
          elif ($m | test("sonnet")) then [2, 10]
          elif ($m | test("haiku"))  then [1, 5]
          else [0, 0] end))
    | if $fast then [(.[0] * 2), (.[1] * 2)] else . end;

  # Micro-dollars, so the row stays an integer all the way through awk. A
  # rate is USD per million tokens and the cost is tokens x rate / 1e6 USD,
  # which is tokens x rate micro-dollars -- the two conversions cancel and
  # there is no division to lose precision to.
  def cost($model; $u):
    rates($model; (($u.speed // "") == "fast")) as $r
    | (($u.cache_creation.ephemeral_1h_input_tokens // 0)) as $c1h
    | ([(($u.cache_creation_input_tokens // 0) - $c1h), 0] | max) as $c5m
    | ( (($u.input_tokens // 0) * $r[0])
      + ($c5m * $r[0] * 1.25)
      + ($c1h * $r[0] * 2)
      + (($u.cache_read_input_tokens // 0) * $r[0] * 0.1)
      + (($u.output_tokens // 0) * $r[1]) )
    | round;
'

# ---------------------------------------------------------------- tokens ----

# What the windows above cost, from the transcripts rather than from any
# endpoint -- Anthropic reports a percentage of an allowance it does not
# publish, so "57% of the session window" is not a number you can compare
# against yesterday. These are.
#
# ~/.claude/projects is 300 MB here and a full jq pass over the last eight days
# of it takes 1.2s, which is far too slow to sit on the panel's refresh. So the
# parse is incremental: a store of one row per assistant message, and a stamp of
# (inode, size) per transcript so an unchanged file is never opened twice. A
# steady-state run touches the one file the live session is appending to.
#
# Rows are deduplicated by message id, which is not a nicety: resuming or
# compacting a session copies its history into the new transcript, and 7218 rows
# across eight days here are only 3826 distinct messages. Summing the file as it
# lies overstates every figure by nearly half.
do_tokens() {
  local root="$cfg_dir/projects"
  [ -d "$root" ] || return
  mkdir -p "$store" || return

  local horizon=$(( now - keep_days * 86400 ))
  local stamps="$store/stamps.tsv" rows="$store/rows.tsv"

  # The store is a cache of parsed rows, so a change to the row format -- or to
  # the price table, which is baked into each row -- has to throw it away. It
  # costs one full reparse, and the alternative is a week of the panel drawing
  # yesterday's prices against today's.
  local schema="$store/schema" version="2:$(printf '%s' "$price_defs" | cksum | cut -d" " -f1)"
  if [ "$(cat "$schema" 2>/dev/null)" != "$version" ]; then
    rm -f "$rows" "$stamps"
    printf '%s\n' "$version" >"$schema"
  fi

  local -a files
  mapfile -t files < <(find "$root" -name '*.jsonl' \
    -newermt "$(date -d "@$horizon" +%Y-%m-%dT%H:%M:%S)" 2>/dev/null)

  local -A stamp_now stamp_old
  local f s
  for f in "${files[@]}"; do
    s=$(stat -c '%i:%s' "$f" 2>/dev/null) || continue
    stamp_now[$f]=$s
  done
  if [ -f "$stamps" ]; then
    while IFS=$'\t' read -r f s; do stamp_old[$f]=$s; done <"$stamps"
  fi

  # Three sets: live files (keep or reparse), changed files (reparse), and
  # everything else, whose rows go out with the same sweep that prunes rows
  # older than the horizon.
  local -a changed=() keep=()
  for f in "${!stamp_now[@]}"; do
    if [ "${stamp_old[$f]-}" = "${stamp_now[$f]}" ]; then keep+=("$f"); else changed+=("$f"); fi
  done

  : >"$rows.new"
  if [ -f "$rows" ] && [ ${#keep[@]} -gt 0 ]; then
    printf '%s\n' "${keep[@]}" | awk -F'\t' -v horizon="$horizon" '
      NR == FNR { keep[$0] = 1; next }
      ($1 in keep) && ($3 + 0) >= horizon' - "$rows" >>"$rows.new"
  fi

  for f in "${changed[@]}"; do
    # `iterations` is a per-request breakdown that repeats the same totals, and
    # a message with no id cannot be deduplicated, so both are dropped rather
    # than double-counted. `<synthetic>` is Claude Code's own placeholder for a
    # message no model produced.
    jq -r --arg path "$f" --argjson horizon "$horizon" "$price_defs"'
      select(.type == "assistant" and .message.usage != null)
      | select((.message.id // "") != "")
      | select((.message.model // "") | startswith("<") | not)
      | ((.timestamp // "")[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $at
      | select($at >= $horizon)
      | .message.usage as $u
      | (.message.model // "?") as $model
      | [ $path, .message.id, $at, $model,
          (($u.input_tokens // 0) + ($u.output_tokens // 0)
           + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)),
          cost($model; $u) ]
      | @tsv' "$f" 2>/dev/null
  done >>"$rows.new"

  mv -f "$rows.new" "$rows"
  if [ ${#stamp_now[@]} -gt 0 ]; then
    for f in "${!stamp_now[@]}"; do printf '%s\t%s\n' "$f" "${stamp_now[$f]}"; done >"$stamps"
  else
    : >"$stamps"
  fi

  # Day boundaries come from `date`, not from dividing the epoch by 86400: the
  # buckets are local days, and a DST change makes one of them 23 or 25 hours
  # long. Labels are weekday names because the panel is read at a glance -- the
  # question it answers is "was yesterday heavy", not "what was the 21st".
  local -a starts=() labels=()
  local i
  for ((i = show_days - 1; i >= 0; i--)); do
    starts+=("$(date -d "$i days ago 00:00" +%s)")
    if [ "$i" -eq 0 ]; then labels+=("Today"); else labels+=("$(date -d "$i days ago" +%a)"); fi
  done

  awk -F'\t' -v starts="${starts[*]}" -v labels="${labels[*]}" '
    # "claude-sonnet-4-5-20250929" -> "Sonnet 4.5". The release date and the
    # context-window suffix are dropped because they split one model across two
    # bars for a distinction this panel is not making; word-vs-number is what
    # separates the family from the version, which survives "3-5-haiku" having
    # them the other way round.
    function pretty(m,   t, n, i, name, ver) {
      sub(/^claude-/, "", m)
      sub(/\[[^]]*\]$/, "", m)
      sub(/-[0-9]{8}$/, "", m)
      n = split(m, t, "-")
      for (i = 1; i <= n; i++) {
        if (t[i] ~ /^[0-9]+$/)
          ver = (ver == "" ? t[i] : ver "." t[i])
        else
          name = (name == "" ? "" : name " ") toupper(substr(t[i], 1, 1)) substr(t[i], 2)
      }
      if (name == "") return m
      return (ver == "" ? name : name " " ver)
    }
    BEGIN { n = split(starts, S, " "); split(labels, L, " ") }
    !seen[$2]++ {
      ts = $3 + 0
      if (ts < S[1]) next
      for (i = n; i >= 1; i--)
        if (ts >= S[i]) { day[i] += $5 + 0; daycost[i] += $6 + 0; break }
      p = pretty($4)
      model[p] += $5 + 0
      modelcost[p] += $6 + 0
    }
    END {
      for (i = 1; i <= n; i++) printf "D\t%s\t%d\t%d\n", L[i], day[i], daycost[i]
      for (m in model) printf "M\t%s\t%d\t%d\n", m, model[m], modelcost[m]
    }' "$rows" \
  | jq -Rsc '
      # Back out of micro-dollars, to two decimal places -- the panel prints
      # cents and a float carried further only invites 3.9299999999.
      def usd: (. / 1e4 | round) / 100;
      [ split("\n")[] | select(length > 0) | split("\t") ] as $r
      | { byDay: [ $r[] | select(.[0] == "D")
                   | { label: .[1], tokens: (.[2] | tonumber), cost: (.[3] | tonumber | usd) } ],
          # Descending, because the panel is answering "what is this costing"
          # and the answer is the top bar.
          byModel: ( [ $r[] | select(.[0] == "M")
                       | { label: .[1], tokens: (.[2] | tonumber), cost: (.[3] | tonumber | usd) } ]
                     | sort_by(-.tokens) ) }
      | .total = ([ .byModel[].tokens ] | add // 0)
      | .totalCost = (([ $r[] | select(.[0] == "M") | (.[3] | tonumber) ] | add // 0) | usd)'
}

case "${1:-limits}" in
  limits) do_limits ;;
  tokens) do_tokens ;;
  *) exit 2 ;;
esac
