#!/bin/bash
# Waybar module: current conditions for Pinheiros, São Paulo.
# Prints one line of JSON for a custom/* module with "return-type": "json".
#
# Source: Open-Meteo — no API key, no account, no rate limit worth worrying
# about at a 15-minute poll.
#
# Coordinates are hardcoded on purpose. Every "detect my location" weather
# endpoint geolocates by IP, which reports the Proton VPN exit node instead of
# São Paulo whenever the VPN is up.
#
# On a failed fetch the last good reading is reused and marked stale in the
# tooltip, so a brief drop in connectivity doesn't blank the module. Only if
# there has never been a successful fetch does it print empty text, which
# makes waybar hide it (same trick as recording.sh / updates.sh).

set -uo pipefail

lat=-23.5670
lon=-46.7020
cache="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather.json"

url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}"
url+="&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day"
url+="&timezone=America/Sao_Paulo"

resp=$(curl -sS --max-time 10 "$url" 2>/dev/null)

# Accept only a response that actually carries a reading — an error body or a
# captive-portal redirect is still HTTP 200, so test for the field itself.
if printf '%s' "$resp" | jq -e '.current.temperature_2m != null' >/dev/null 2>&1; then
	printf '%s' "$resp" >"$cache"
	stale=""
elif [ -s "$cache" ]; then
	resp=$(cat "$cache")
	stale=" (stale — no connection)"
else
	printf '{"text":""}\n'
	exit 0
fi

read -r temp feels hum code is_day when < <(
	printf '%s' "$resp" |
		jq -r '.current | "\(.temperature_2m) \(.apparent_temperature) \(.relative_humidity_2m) \(.weather_code) \(.is_day) \(.time)"'
)

# WMO weather code -> icon + description. Clear and partly-cloudy get a night
# variant; everything else looks the same day or night.
case "$code" in
0) if [ "$is_day" = 1 ]; then icon="󰖙" desc="Sunny"; else icon="󰖔" desc="Clear"; fi ;;
1) if [ "$is_day" = 1 ]; then icon="󰖙" desc="Mainly sunny"; else icon="󰖔" desc="Mainly clear"; fi ;;
2) if [ "$is_day" = 1 ]; then icon="󰖕" desc="Partly cloudy"; else icon="󰼱" desc="Partly cloudy"; fi ;;
3) icon="󰖐" desc="Overcast" ;;
45 | 48) icon="󰖑" desc="Fog" ;;
51 | 53 | 55) icon="󰖗" desc="Drizzle" ;;
56 | 57) icon="󰖗" desc="Freezing drizzle" ;;
61 | 63) icon="󰖗" desc="Rain" ;;
65) icon="󰖖" desc="Heavy rain" ;;
66 | 67) icon="󰖖" desc="Freezing rain" ;;
71 | 73 | 75 | 77) icon="󰖘" desc="Snow" ;;
80 | 81) icon="󰖗" desc="Rain showers" ;;
82) icon="󰖖" desc="Heavy showers" ;;
85 | 86) icon="󰖘" desc="Snow showers" ;;
95) icon="󰙾" desc="Thunderstorm" ;;
96 | 99) icon="󰖒" desc="Thunderstorm with hail" ;;
*) icon="󰖐" desc="Unknown (WMO $code)" ;;
esac

[ "$is_day" = 1 ] && class="day" || class="night"

tooltip=$(printf '%s — Pinheiros, São Paulo\nFeels like %.0f°C · humidity %.0f%%\nUpdated %s%s' \
	"$desc" "$feels" "$hum" "${when#*T}" "$stale")

jq -nc \
	--arg text "$(printf '%s %.0f°' "$icon" "$temp")" \
	--arg tt "$tooltip" \
	--arg class "$class" \
	'{text:$text, tooltip:$tt, class:$class}'
