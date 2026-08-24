#!/bin/bash
# Quickshell module: the machine's backlight devices, each tagged with the DRM
# connector it lights. Prints one line of JSON — an array — consumed by the
# display panel's JsonScript.
#
# The mapping is what the panel actually needs: `brightnessctl -l` names the
# devices but says nothing about which screen a device belongs to, and on a
# laptop with a monitor plugged in only one of the two screens has a backlight
# at all. sysfs knows, because the device hangs off the connector's own node:
#
#   /sys/class/backlight/intel_backlight
#     -> /sys/devices/…/drm/card1/card1-eDP-1/intel_backlight
#
# so the parent directory names the connector, once the card prefix is off it.
# A device that does not sit under a connector — ddcci, or a vendor platform
# driver — reports an empty one and simply never matches a monitor.
#
# Discovery only, and static: the levels themselves are read from sysfs
# directly, which delivers a change notification and so needs no polling.

set -uo pipefail

first=1
printf '['

for dir in /sys/class/backlight/*/; do
	# The glob itself when the directory is empty, i.e. a machine with no
	# backlight at all. Every desktop is one.
	[ -d "$dir" ] || continue

	device=$(basename "$dir")
	max=$(cat "$dir/max_brightness" 2>/dev/null) || continue
	# A zero maximum would make every percentage a division by zero, and the
	# device is unusable anyway.
	[ "${max:-0}" -gt 0 ] 2>/dev/null || continue

	# card1-eDP-1 -> eDP-1. The shortest match of `card*-` is the prefix, so a
	# connector with a dash of its own (DP-1) survives intact.
	parent=$(basename "$(dirname "$(readlink -f "$dir")")")
	connector=${parent#card*-}
	[ "$connector" = "$parent" ] && connector=""

	[ $first -eq 1 ] || printf ','
	first=0
	printf '{"device":"%s","connector":"%s","max":%s}' "$device" "$connector" "$max"
done

printf ']\n'
