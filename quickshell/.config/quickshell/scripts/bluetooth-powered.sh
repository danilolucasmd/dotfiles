#!/bin/bash
# Quickshell module: BlueZ's own Powered flag for one adapter, printed as one
# line of JSON, so BluetoothState can tell whether what Quickshell believes
# about the adapter still matches what BlueZ says about it.
#
# Nothing else in the Bluetooth module shells out — BlueZ is a first-class
# service in Quickshell and every other reading is a property that notifies.
# This one call exists because of a race in that client, which shows up on
# every resume from suspend on a machine whose adapter is a USB dongle:
#
#   the dongle is re-enumerated on resume, so bluetoothd drops
#   /org/bluez/hci0 and republishes it a moment later. Quickshell only
#   subscribes to an object's PropertiesChanged once it has seen the
#   InterfacesAdded that announced it, and registering that match rule with
#   the bus is itself a round trip — so the "Powered": true that bluetoothd
#   sends a few milliseconds after republishing the adapter is routed to
#   nobody. Quickshell is left holding the properties InterfacesAdded carried,
#   which say the adapter is still coming up, and the bar and the panel go on
#   reporting a Bluetooth that is off while music plays through it.
#
# The read is deliberately narrow: only Powered, only when BluetoothState asks.
# busctl rather than bluetoothctl because it is systemd's, is therefore always
# installed, prints one line, and wants no interactive session.

path=${1:-/org/bluez/hci0}

# `busctl get-property` prints the signature and the value: `b true`.
read -r _ powered < <(busctl --system get-property org.bluez "$path" \
	org.bluez.Adapter1 Powered 2>/dev/null)

case $powered in
true | false)
	printf '{"powered":%s}\n' "$powered"
	;;
*)
	# No adapter at that path, or BlueZ is not running. Say nothing rather
	# than guess: an empty reading leaves Quickshell's own view alone.
	printf '{}\n'
	;;
esac
