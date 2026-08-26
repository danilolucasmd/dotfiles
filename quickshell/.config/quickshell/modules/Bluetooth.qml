import qs
import qs.components

// Bluetooth on the bar, everything else a click away in BluetoothPanel. The
// reading lives in BluetoothState, which the panel and the super+B
// binding share.
//
// The click used to open buds-tui in a terminal, on the reasoning that
// connecting the earbuds is what taking them out of the case already does, so
// the only thing left worth clicking for was per-bud battery and ANC mode.
// That held for exactly one device. Anything else -- a controller, a phone,
// something being paired for the first time -- had no route in from the bar at
// all, so the click opens the panel now like every other module here. buds is
// still installed, and still the only thing that knows what BlueZ does not; it
// is a terminal command again rather than something the bar launches.
BarItem {
	id: root

	rightMargin: Theme.gap
	highlighted: BluetoothState.panelOpen

	tooltip: {
		if (!BluetoothState.available)
			return "No Bluetooth adapter";
		if (BluetoothState.blocked)
			return "Bluetooth blocked by rfkill";
		if (!BluetoothState.enabled)
			return "Bluetooth off";
		if (!BluetoothState.anyConnected)
			return "No Bluetooth device connected";
		return BluetoothState.connected.map(d => {
			const battery = BluetoothState.hasBattery(d) ? ` (${BluetoothState.batteryOf(d)}%)` : "";
			return `${BluetoothState.label(d)}${battery}`;
		}).join("\n");
	}

	onClicked: BluetoothState.toggle()
	// The switch the panel puts under the pointer anyway, for when the panel
	// is not what you wanted -- the same shortcut the network module offers on
	// its own radio.
	onRightClicked: BluetoothState.toggleAdapter()

	BarText {
		text: BluetoothState.icon
		// One colour in every state. The glyph already has three shapes to say
		// which one it is in, and a colour that moved with them was saying the
		// same thing twice -- at the cost of the module flickering between two
		// weights every time the earbuds went back in their case.
		color: Theme.fg
		font.pixelSize: Theme.fontIcon
	}
}
