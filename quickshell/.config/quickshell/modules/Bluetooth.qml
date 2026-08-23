import Quickshell.Bluetooth
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

	// Click toggles the first known audio device, same as before.
	onClicked: {
		const audio = devices.find(d => {
			const icon = (d.icon ?? "").toLowerCase();
			return icon.startsWith("audio-") || icon.includes("headphone") || icon.includes("headset") || icon.includes("earbud");
		});
		if (!audio)
			return;
		if (audio.connected)
			audio.disconnect();
		else
			audio.connect();
	}

	BarText {
		text: root.anyConnected ? "󰂰" : "󰂱"
		color: root.anyConnected ? Theme.blue : Theme.dim
		font.pixelSize: Theme.fontIcon
	}
}
