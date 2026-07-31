#!/usr/bin/env bash
# Waybar media indicator: a bare play/pause glyph in the right cluster. The
# track itself lives in the tooltip; clicking the glyph toggles playback.
# Shows the player that a bare `playerctl play-pause` would control, i.e. the
# exact player that responds to the XF86AudioPlay key (see hyprland.conf).
# Uses playerctl's default (most-recently-active) selection with --follow so it
# updates in real time and switches automatically between e.g. YouTube/Spotify.

SEP=$'\x1f' # unit separator: won't appear in track metadata

# Escape a string for Pango markup, then for JSON.
escape() {
  local s="$1"
  # NOTE: bash 5.2 treats a literal & in the replacement as the matched text
  # (patsub_replacement), so & must be written as \& below.
  s="${s//&/\&amp;}"
  s="${s//</\&lt;}"
  s="${s//>/\&gt;}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

emit() {
  local status="$1" player="$2" artist="$3" title="$4"

  if [[ -z "$status" || "$status" == "Stopped" ]]; then
    printf '{"text":""}\n'
    return
  fi

  local icon class
  case "$status" in
    Playing) icon="󰐊"; class="playing" ;;
    Paused)  icon="󰏤"; class="paused" ;;
    *)       icon="󰐊"; class="playing" ;;
  esac

  # Everything the bar used to show now lives in the tooltip.
  local tip
  if [[ -n "$artist" && -n "$title" ]]; then
    tip="$artist — $title"
  elif [[ -n "$title" ]]; then
    tip="$title"
  else
    tip="$player"
  fi
  tip="$status ($player): $tip"

  printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' \
    "$icon" "$(escape "$tip")" "$class" "$class"
}

# playerctl --follow emits the current state immediately and then on every
# change (title, play/pause, or the active player switching). A blank status
# field means no player is around -> hide the module.
playerctl --follow \
  --format "{{status}}${SEP}{{playerName}}${SEP}{{artist}}${SEP}{{title}}" \
  metadata 2>/dev/null |
while IFS= read -r line; do
  status="${line%%"$SEP"*}"; rest="${line#*"$SEP"}"
  player="${rest%%"$SEP"*}"; rest="${rest#*"$SEP"}"
  artist="${rest%%"$SEP"*}"; title="${rest##*"$SEP"}"
  emit "$status" "$player" "$artist" "$title"
done

# If playerctl ever exits (e.g. it is restarted), fall back to an empty state
# so waybar hides the module until it restarts this script.
printf '{"text":""}\n'
