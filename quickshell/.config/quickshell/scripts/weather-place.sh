#!/bin/bash
# Where the weather module's reading is for. Two modes, both printing one line
# of JSON on stdout:
#
#   weather-place.sh              the machine's own location, found by IP
#   weather-place.sh "<address>"  whatever was typed into the weather panel
#
# Output is {"lat":…, "lon":…, "place":"Pinheiros, São Paulo"} on success and
# {"error":"…"} on failure, where the error is written to be shown to a person
# under the address box.
#
# Split out of weather.sh because the panel needs the same lookup for its own
# reasons: it resolves an address the moment you type it so it can complain
# about a typo there and then, and so the 15-minute poll afterwards is a single
# request to Open-Meteo rather than a geocode every time.
#
# Sources:
#   ipwho.is    — IP -> coordinates. Keyless, https, and does not rate-limit at
#                 the once-an-hour this asks for. (ipapi.co, the more obvious
#                 name, refuses anonymous requests outright.)
#   Nominatim   — coordinates <-> address. Its usage policy wants a User-Agent
#                 naming the client, hence -A; one request an hour is far below
#                 anything it objects to.
#
# Geolocating by IP reports the Proton VPN exit node whenever the VPN is up,
# which is why the module used to have Pinheiros hardcoded. That is not a bug to
# be fixed here -- there is nothing an IP lookup can do about a VPN -- it is why
# the panel lets you type the address yourself.

set -uo pipefail

ua="quickshell-weather (personal dotfiles)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-weather-place.json"
# Long enough that the quarter-hourly poll costs nothing, short enough that
# picking the laptop up and moving cities is noticed within the hour.
ttl=3600

fail() {
	jq -nc --arg error "$1" '{error:$error}'
	exit 0
}

# The address parts, in the order a person would say them: the neighbourhood
# first, then the city it is in. OSM files the neighbourhood under whichever of
# half a dozen keys the local mappers used, and outside a city there may be no
# such level at all, so both halves fall through a list and an empty one simply
# drops out. When the two come back identical -- a town that is its own
# district -- it is said once.
place_of() {
	jq -r '
		.address as $a
		| [($a.neighbourhood // $a.suburb // $a.quarter // $a.city_district // $a.city_block // empty),
		   ($a.city // $a.town // $a.municipality // $a.village // $a.county // empty)]
		| map(select(. != null and . != ""))
		| (if (length == 2 and .[0] == .[1]) then [.[0]] else . end)
		| join(", ")
	'
}

# ----------------------------------------------------------------------
# An address typed into the panel
# ----------------------------------------------------------------------

if [ $# -ge 1 ] && [ -n "${1// /}" ]; then
	hit=$(curl -sS --max-time 12 -A "$ua" --get \
		--data-urlencode "q=$1" \
		--data-urlencode "format=jsonv2" \
		--data-urlencode "limit=1" \
		--data-urlencode "addressdetails=1" \
		"https://nominatim.openstreetmap.org/search" 2>/dev/null)

	[ -n "$hit" ] || fail "Could not reach the geocoder."

	hit=$(printf '%s' "$hit" | jq -c '.[0] // empty' 2>/dev/null)
	[ -n "$hit" ] || fail "Nothing found for that address."

	# A result always carries coordinates; the pretty name may still come back
	# empty for a point in the middle of nowhere, and then the address as OSM
	# spells it is better than a blank header.
	place=$(printf '%s' "$hit" | place_of)
	[ -n "$place" ] || place=$(printf '%s' "$hit" | jq -r '.display_name | split(", ")[0:2] | join(", ")')

	printf '%s' "$hit" | jq -c --arg place "$place" '{lat:(.lat | tonumber), lon:(.lon | tonumber), place:$place}'
	exit 0
fi

# ----------------------------------------------------------------------
# The machine's own location
# ----------------------------------------------------------------------

if [ -s "$cache" ] && [ $(($(date +%s) - $(stat -c %Y "$cache"))) -lt "$ttl" ]; then
	cat "$cache"
	exit 0
fi

ip=$(curl -sS --max-time 10 "https://ipwho.is/" 2>/dev/null)

if ! printf '%s' "$ip" | jq -e '.success == true' >/dev/null 2>&1; then
	# No lookup, but a location from within the hour is still roughly where we
	# are. Only a cold start with no network has nothing at all to say.
	[ -s "$cache" ] && cat "$cache" && exit 0
	fail "Could not work out where this machine is."
fi

read -r lat lon city < <(printf '%s' "$ip" | jq -r '"\(.latitude) \(.longitude) \(.city // "")"')

# The IP lookup knows the city and nothing finer, so the neighbourhood is a
# second request. zoom=14 is the level Nominatim answers with a district rather
# than a street address; the city from the IP stands in if it has nothing.
place=$(curl -sS --max-time 12 -A "$ua" \
	"https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=jsonv2&zoom=14&addressdetails=1" 2>/dev/null |
	place_of)
[ -n "$place" ] && [ "$place" != "null" ] || place="$city"
[ -n "$place" ] || fail "Could not work out where this machine is."

jq -nc --argjson lat "$lat" --argjson lon "$lon" --arg place "$place" \
	'{lat:$lat, lon:$lon, place:$place}' | tee "$cache"
