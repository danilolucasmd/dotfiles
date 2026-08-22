#!/bin/bash
# Claude Code statusLine hook for the waybar agent-usage module.
#
# Prints nothing — its only job is to tee the .rate_limits block Claude Code
# hands every statusLine invocation into a cache the module reads. This is the
# freshest usage source there is: it updates on every status line render, costs
# no network call, and is not subject to the OAuth usage endpoint's rate limit
# (which is small — ~20 requests in half a minute earns a multi-minute 429).
#
# Wire it up in ~/.claude/settings.json:
#   "statusLine": { "type": "command",
#                   "command": "bash ~/.config/waybar/scripts/agent-usage-statusline.sh" }
#
# Normalises to the same shape as the OAuth endpoint payload (top-level
# five_hour / seven_day with .utilization and an ISO-8601 .resets_at) so the
# module can read every source with one expression.

out="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/agent-usage-statusline.json"
mkdir -p "${out%/*}" 2>/dev/null || exit 0
tmp=$(mktemp "$out.XXXXXX" 2>/dev/null) || exit 0

# rate_limits is absent for non-subscription auth and until the session's first
# API response, and either window can be missing on its own.
jq -c '
  def win(w): if w == null or w.used_percentage == null then null
              else { utilization: w.used_percentage,
                     resets_at: (if w.resets_at == null then "" else (w.resets_at | todate) end) }
              end;
  { five_hour: win(.rate_limits.five_hour), seven_day: win(.rate_limits.seven_day) }
  | select(.five_hour != null or .seven_day != null)
' >"$tmp" 2>/dev/null

if [ -s "$tmp" ]; then
  if cmp -s "$tmp" "$out"; then
    # Same numbers: just mark the data as still-current and stay quiet, so the
    # module does not start calling it stale during a long idle session.
    rm -f "$tmp"; touch "$out"
  else
    mv -f "$tmp" "$out"
    # Only wake waybar when a number actually moved — this runs on every render.
    pkill -RTMIN+11 waybar 2>/dev/null
  fi
else
  rm -f "$tmp"
fi
exit 0
