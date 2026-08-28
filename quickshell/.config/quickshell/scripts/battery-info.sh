#!/bin/bash
# Quickshell module: the per-pack facts UPower does not carry. Prints one line
# of JSON — an array, one entry per battery — consumed by BatteryState's
# JsonScript and printed by the battery panel under each pack's meter.
#
# UPower's device gives percentage, health, change rate and the time estimates,
# and stops there. The things a worn pack is actually judged by — how many
# cycles it has been through, what it is holding in watt-hours against what it
# was built to hold, what the cell voltage has sagged to — live only in sysfs,
# so the panel reads them here rather than going without them.
#
# Also the charge threshold, which is the one value in here that is written as
# well as read: `limit` is what the pack is set to stop at, `limitWritable`
# whether this user can move it without going through polkit. See
# charge-limit.sh, which does the writing.
#
# Energy is reported in µWh by most firmware and in µAh (charge_*) by the rest;
# both come back here as watt-hours, the charge-reporting kind multiplied by
# the pack's design voltage, so the panel has one unit to print.

set -uo pipefail

readonly THRESHOLD=charge_control_end_threshold

# A sysfs attribute, or the empty string when the file is absent. head -n1
# because a couple of these are newline-terminated multi-value files on some
# firmware.
field() {
	head -n1 "$1/$2" 2>/dev/null
}

# An integer attribute as JSON, or `null` when it is missing or is not a
# number. Missing is the honest answer for a pack whose firmware does not count
# cycles, and it is a different answer from 0, which some of them do report.
int() {
	local value=$1
	[[ $value =~ ^-?[0-9]+$ ]] && printf '%s' "$value" || printf 'null'
}

# A µ-unit attribute as its base unit, to two decimals: µWh -> Wh, µV -> V,
# µW -> W. Same null rule as above.
scaled() {
	local value=$1
	[[ $value =~ ^-?[0-9]+$ ]] || {
		printf 'null'
		return
	}
	awk -v v="$value" 'BEGIN { printf "%.2f", v / 1000000 }'
}

# A µAh attribute as watt-hours, against a µV voltage: (µAh/1e6) * (µV/1e6).
# Only reached on firmware that reports charge rather than energy.
scaledCharge() {
	local charge=$1 volts=$2
	[[ $charge =~ ^-?[0-9]+$ ]] && [[ $volts =~ ^[0-9]+$ ]] || {
		printf 'null'
		return
	}
	awk -v c="$charge" -v v="$volts" 'BEGIN { printf "%.2f", c / 1000000 * (v / 1000000) }'
}

# Whichever of the two the firmware speaks, in watt-hours.
energy() {
	local dir=$1 energyAttr=$2 chargeAttr=$3 volts=$4
	local raw
	raw=$(field "$dir" "$energyAttr")
	if [[ $raw =~ ^-?[0-9]+$ ]]; then
		scaled "$raw"
	else
		scaledCharge "$(field "$dir" "$chargeAttr")" "$volts"
	fi
}

# A sysfs string as a JSON string. These are vendor-set — model names with a
# stray quote or backslash are not a thing anyone has seen, but the panel
# should not be one bad character away from parsing nothing at all.
str() {
	local value=$1
	value=${value//\\/\\\\}
	value=${value//\"/\\\"}
	printf '"%s"' "$value"
}

first=1
printf '['

for dir in /sys/class/power_supply/*/; do
	[ -d "$dir" ] || continue
	[ "$(field "$dir" type)" = "Battery" ] || continue
	# The wireless mouse and the headset are power supplies of type Battery
	# too, and they have none of this. A pack the panel draws is one that
	# reports its capacity.
	[ -f "$dir/energy_full_design" ] || [ -f "$dir/charge_full_design" ] || continue

	name=$(basename "$dir")
	voltsRaw=$(field "$dir" voltage_now)
	designVoltsRaw=$(field "$dir" voltage_min_design)
	# Design voltage is what the µAh -> Wh conversion wants; a pack that does
	# not publish one falls back to what it is sitting at now, which is close
	# enough for a capacity figure and better than printing nothing.
	convVolts=$designVoltsRaw
	[[ $convVolts =~ ^[0-9]+$ ]] || convVolts=$voltsRaw

	limitRaw=$(field "$dir" "$THRESHOLD")
	if [[ $limitRaw =~ ^[0-9]+$ ]]; then
		limitSupported=true
		[ -w "$dir/$THRESHOLD" ] && limitWritable=true || limitWritable=false
	else
		limitSupported=false
		limitWritable=false
	fi

	[ $first -eq 1 ] || printf ','
	first=0

	printf '{"name":%s,"model":%s,"manufacturer":%s,"technology":%s,' \
		"$(str "$name")" \
		"$(str "$(field "$dir" model_name)")" \
		"$(str "$(field "$dir" manufacturer)")" \
		"$(str "$(field "$dir" technology)")"
	printf '"cycleCount":%s,"energyNow":%s,"energyFull":%s,"energyDesign":%s,' \
		"$(int "$(field "$dir" cycle_count)")" \
		"$(energy "$dir" energy_now charge_now "$convVolts")" \
		"$(energy "$dir" energy_full charge_full "$convVolts")" \
		"$(energy "$dir" energy_full_design charge_full_design "$convVolts")"
	printf '"voltage":%s,"voltageDesign":%s,"power":%s,' \
		"$(scaled "$voltsRaw")" \
		"$(scaled "$designVoltsRaw")" \
		"$(scaled "$(field "$dir" power_now)")"
	printf '"limit":%s,"limitSupported":%s,"limitWritable":%s}' \
		"$(int "$limitRaw")" "$limitSupported" "$limitWritable"
done

printf ']\n'
