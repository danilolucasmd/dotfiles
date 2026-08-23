#!/bin/bash
# Quickshell module: number of available package updates (official repos + AUR).
# Prints one line of JSON, consumed by the module's JsonScript.
# Empty text => the module hides itself (same trick as recording.sh).

# Max packages listed per section in the tooltip (keeps it from overflowing).
max_per_section=25

# Official repo updates. checkupdates is safe: it syncs a TEMP db (no root, no
# partial-upgrade risk) and exits 2 when there are none.
official=$(checkupdates 2>/dev/null)
# AUR updates. Queries the AUR only; does not touch the system db.
aur=$(yay -Qua 2>/dev/null)

# Count non-empty lines (empty input -> 0).
n_official=$(printf '%s\n' "$official" | grep -c .)
n_aur=$(printf '%s\n' "$aur" | grep -c .)
total=$((n_official + n_aur))

# Up to date (or both checks failed, e.g. offline) -> hide.
if [ "$total" -eq 0 ]; then
  printf '{"text":""}\n'
  exit 0
fi

# Render one tooltip section, truncated to $max_per_section lines.
section() { # $1=heading  $2=list  $3=count
  [ "$3" -eq 0 ] && return
  printf '%s (%s):\n' "$1" "$3"
  printf '%s\n' "$2" | head -n "$max_per_section"
  [ "$3" -gt "$max_per_section" ] && printf '… and %s more\n' "$(($3 - max_per_section))"
}

tooltip=$(
  section "Official" "$official" "$n_official"
  [ "$n_official" -gt 0 ] && [ "$n_aur" -gt 0 ] && printf '\n'
  section "AUR" "$aur" "$n_aur"
)

jq -nc --arg text "󰚰 $total" --arg tt "$tooltip" \
  '{text:$text, tooltip:$tt, class:"has-updates"}'
