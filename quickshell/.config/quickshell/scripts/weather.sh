#!/bin/bash
# Quickshell module: current conditions plus a three-day outlook.
# Prints one line of JSON, consumed by the module's JsonScript.
#
#   weather.sh              wherever this machine is, per weather-place.sh
#   weather.sh LAT LON NAME the fixed point the panel was told to use instead
#
# The panel passes the three arguments once you have typed an address into it,
# and passes none once you clear it again; it has already resolved the address,
# so nothing here geocodes anything.
#
# Source: Open-Meteo -- no API key, no account, no rate limit worth worrying
# about at a 15-minute poll. timezone=auto rather than a fixed zone, because the
# location is no longer fixed: the daily rows have to break on midnight where
# the weather is, not where the laptop happens to be.
#
# Prints `text` for the bar glyph plus the fields the click-open panel lays out;
# there is no prose here, the panel does its own phrasing.
#
# On a failed fetch the last good reading is reused and flagged stale, so a
# brief drop in connectivity doesn't blank the module. The cache holds the
# finished object rather than the raw response, which is what lets a stale
# reading keep the place name it was actually taken at -- change location while
# the network is down and the panel says Pinheiros, stale, rather than
# relabelling old numbers with the new address. Only if there has never been a
# successful fetch does it print empty text, which makes the module hide itself
# (same trick as recording.sh / updates.sh).

set -uo pipefail

cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-weather.json"
here=$(dirname "$(readlink -f "$0")")

# Nothing usable, at any stage: fall back to the last good reading, flagged, or
# hide the module if there has never been one.
give_up() {
	if [ -s "$cache" ]; then
		jq -c '.stale = true' "$cache"
	else
		printf '{"text":""}\n'
	fi
	exit 0
}

# WMO weather code -> icon + description. Clear and partly-cloudy get a night
# variant; everything else looks the same day or night. Tab-separated because
# the descriptions have spaces in them.
describe() {
	local code=$1 is_day=$2 icon desc

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

	printf '%s\t%s\n' "$icon" "$desc"
}

# Degrees -> the compass point a person would say. The 16 sectors are 22.5°
# wide and N straddles 0, so the rounding is (deg + 11.25) / 22.5, scaled up by
# four to keep it in integers.
compass() {
	local deg
	deg=$(printf '%.0f' "$1")
	local points=(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW)
	printf '%s' "${points[$(((deg * 4 + 45) / 90 % 16))]}"
}

# ----------------------------------------------------------------------
# Where
# ----------------------------------------------------------------------

if [ $# -ge 3 ]; then
	lat=$1 lon=$2 place=$3
else
	read -r lat lon place < <("$here/weather-place.sh" | jq -r '"\(.lat // "") \(.lon // "") \(.place // "")"')
	[ -n "$lat" ] || give_up
fi

# ----------------------------------------------------------------------
# What
# ----------------------------------------------------------------------

url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}"
url+="&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m"
url+="&daily=weather_code,temperature_2m_max,temperature_2m_min"
url+="&forecast_days=4&timezone=auto"

resp=$(curl -sS --max-time 10 "$url" 2>/dev/null)

# Accept only a response that actually carries a reading -- an error body or a
# captive-portal redirect is still HTTP 200, so test for the field itself.
printf '%s' "$resp" | jq -e '.current.temperature_2m != null' >/dev/null 2>&1 || give_up

read -r temp feels hum code is_day speed dir when < <(
	printf '%s' "$resp" |
		jq -r '.current | "\(.temperature_2m) \(.apparent_temperature) \(.relative_humidity_2m) \(.weather_code) \(.is_day) \(.wind_speed_10m) \(.wind_direction_10m) \(.time)"'
)

IFS=$'\t' read -r icon desc < <(describe "$code" "$is_day")

# forecast_days=4 asks for today plus three, and today is already the whole top
# half of the panel, so the daily rows start at index 1. The dates are plain
# calendar days in the location's own timezone, which is why the weekday can be
# taken locally without the zone mattering.
forecast="[]"
while IFS=$'\t' read -r day dcode hi lo; do
	[ -n "$day" ] || continue
	IFS=$'\t' read -r dicon ddesc < <(describe "$dcode" 1)
	forecast=$(jq -nc \
		--argjson acc "$forecast" \
		--arg day "$(date -d "$day" +%a)" \
		--arg icon "$dicon" \
		--arg desc "$ddesc" \
		--arg hi "$(printf '%.0f' "$hi")" \
		--arg lo "$(printf '%.0f' "$lo")" \
		'$acc + [{day:$day, icon:$icon, desc:$desc, hi:$hi, lo:$lo}]')
done < <(
	printf '%s' "$resp" |
		jq -r '[.daily.time, .daily.weather_code, .daily.temperature_2m_max, .daily.temperature_2m_min]
		       | transpose | .[1:4][] | @tsv'
)

jq -nc \
	--arg text "$(printf '%s %.0f°' "$icon" "$temp")" \
	--arg icon "$icon" \
	--arg desc "$desc" \
	--arg place "$place" \
	--arg temp "$(printf '%.0f' "$temp")" \
	--arg feels "$(printf '%.0f' "$feels")" \
	--arg humidity "$(printf '%.0f' "$hum")" \
	--arg wind "$(printf '%.0f km/h %s' "$speed" "$(compass "$dir")")" \
	--arg updated "${when#*T}" \
	--argjson forecast "$forecast" \
	'{text:$text, icon:$icon, desc:$desc, place:$place, temp:$temp, feels:$feels,
	  humidity:$humidity, wind:$wind, updated:$updated, forecast:$forecast, stale:false}' |
	tee "$cache"
