import Quickshell.Bluetooth
import Quickshell.Io
import qs
import qs.components

// Connected Bluetooth devices. The waybar version shelled out to
// `bluetoothctl` and tailed dbus-monitor to know when to re-read; BlueZ is a
// first-class service here, so connection state is just a property.
BarItem {
	id: root

	readonly property var devices: Bluetooth.defaultAdapter?.devices?.values ?? []
	readonly property var connected: devices.filter(d => d.connected)

	readonly property bool anyConnected: connected.length > 0

	rightMargin: Theme.gap
	tooltip: anyConnected ? `Connected: ${connected.map(d => d.name || d.address).join(", ")}` : "No Bluetooth device connected"

	// Click opens buds-tui in a terminal rather than connecting or
	// disconnecting: connecting the earbuds is what taking them out of the case
	// already does, and what the click was really wanted for is the thing only
	// that app can do — battery per bud, noise-cancelling mode, equaliser.
	//
	// Absolute path because the module inherits quickshell's environment, which
	// need not have ~/.local/bin on PATH.
	onClicked: buds.running = true

	Process {
		id: buds

		command: ["ghostty", "-e", `${Paths.home}/.local/bin/buds`]
	}

	BarText {
		text: root.anyConnected ? "󰂰" : "󰂱"
		color: root.anyConnected ? Theme.blue : Theme.dim
		font.pixelSize: Theme.fontIcon
	}
}
