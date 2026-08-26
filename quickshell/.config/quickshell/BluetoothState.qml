pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// The adapter and everything BlueZ knows is on it: what the bar glyph draws,
// and what the panel lists.
//
// A singleton for the same reason the other panels have one: the panel is a
// window of its own rather than a child of the bar module, and super+B
// can summon it without the bar being involved at all.
//
// Nothing here shells out. The waybar version ran `bluetoothctl` and tailed
// `dbus-monitor` to know when to re-read it; BlueZ is a first-class service in
// Quickshell, so connection state is just a property that notifies.
Singleton {
	id: root

	// One adapter is all this machine has, and all the panel draws. A second
	// would want a picker in front of the list, which is a different panel.
	readonly property var adapter: Bluetooth.defaultAdapter
	readonly property bool available: adapter !== null

	readonly property bool enabled: adapter?.enabled ?? false
	// rfkill. Nothing the panel's switch does brings the adapter back from
	// this one -- it is `rfkill unblock bluetooth` or the laptop's own key.
	readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
	// Mid-transition. The switch is left alone while this is true rather than
	// bouncing the adapter a second time on a double click.
	readonly property bool settling: adapter?.state === BluetoothAdapterState.Enabling || adapter?.state === BluetoothAdapterState.Disabling

	readonly property bool discovering: adapter?.discovering ?? false

	readonly property var devices: adapter?.devices?.values ?? []
	readonly property var connected: devices.filter(d => d.connected)
	readonly property bool anyConnected: connected.length > 0

	// The two sections the panel draws, matching what BlueZ itself
	// distinguishes: a device it holds keys for, and one it has merely seen.
	// Connected devices float to the top of the paired list -- they are what
	// the panel was opened to act on.
	readonly property var paired: sorted(devices.filter(d => known(d)))
	readonly property var nearby: sorted(devices.filter(d => !known(d)))

	property bool panelOpen: false
	// Whether discovery should be running, as distinct from whether it is.
	// The panel's `s` key writes this rather than the adapter itself: the
	// Binding below owns `discovering`, and a direct write would be undone by
	// it on the next re-evaluation.
	property bool wantDiscovery: false

	// What the bar draws. Three shapes rather than the two the module carried
	// before: an adapter that is off looks nothing like one that is on with
	// nothing connected, and the old glyph pair could not say so. The colour
	// stays put across all three -- see the module for why.
	readonly property string icon: {
		if (!available || blocked || !enabled)
			return "󰂲";
		return anyConnected ? "󰂰" : "󰂱";
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		// Opening always sweeps. The nearby list is the half of the panel
		// that needs it, and someone who stopped the sweep last time was
		// stopping it for that visit, not for good.
		if (panelOpen)
			wantDiscovery = true;
	}

	function close(): void {
		panelOpen = false;
	}

	// ------------------------------------------------------------------
	// Actions
	// ------------------------------------------------------------------

	function setEnabled(on: bool): void {
		if (adapter && !blocked)
			adapter.enabled = on;
	}

	function toggleAdapter(): void {
		setEnabled(!enabled);
	}

	// Discovery is not free: the radio hops channels to listen, which an
	// A2DP stream sharing that radio can be heard doing. So it runs only
	// while the panel that wants the results is on screen, and `s` stops it
	// for when the stutter is worse than the wait.
	function toggleDiscovery(): void {
		wantDiscovery = !wantDiscovery;
	}

	// ------------------------------------------------------------------
	// Reading a device
	// ------------------------------------------------------------------

	// Paired in the sense the panel means it: BlueZ has keys for this device
	// and will let it back on without a fresh pairing. `bonded` is the newer
	// property of the two and is not always set on a device paired long ago,
	// so both count.
	function known(device: var): bool {
		return (device?.paired ?? false) || (device?.bonded ?? false);
	}

	// The user-set alias first, then whatever the device broadcast. The
	// address is only ever a backstop: BlueZ fills the alias with the address
	// itself, colons swapped for dashes, when a device has answered no name
	// request -- which is why `named` below cannot just test for an empty
	// string.
	function label(device: var): string {
		return device?.name || device?.deviceName || device?.address || "Unknown device";
	}

	// Whether the device ever answered a name request. BlueZ has no empty
	// name to test for -- a device that did not answer is given its own
	// address with the colons swapped for dashes -- so that is what this
	// looks for, and a user-set alias counts as a name however it was
	// arrived at.
	function named(device: var): bool {
		if (!device)
			return false;
		if (device.deviceName)
			return true;
		return !!device.name && device.name !== device.address.replace(/:/g, "-");
	}

	// Connected devices first, then named before unnamed, then alphabetical.
	// The last two are what make the nearby list readable: a sweep in a block
	// of flats is mostly anonymous BLE beacons shouting their MAC, and the
	// handful of rows anyone opened the panel for belong above them.
	// Alphabetical rather than order-of-arrival because discovery reshuffles
	// the list every few seconds, and a stable order means a row does not move
	// out from under the pointer on its way to being clicked.
	function sorted(list: var): var {
		return [...list].sort((a, b) => {
			if (a.connected !== b.connected)
				return a.connected ? -1 : 1;
			if (named(a) !== named(b))
				return named(a) ? -1 : 1;
			return label(a).localeCompare(label(b));
		});
	}

	// The freedesktop icon name BlueZ derives from the device's class, mapped
	// onto the Nerd Font. Worth doing: a list of identical Bluetooth glyphs
	// tells you nothing, and which row is the headset is the whole question
	// being asked of it.
	function deviceIcon(device: var): string {
		switch (device?.icon) {
		case "audio-headset":
		case "audio-headphones":
			return "󰋋";
		case "audio-card":
		case "multimedia-player":
			return "󰓃";
		case "input-mouse":
			return "󰍽";
		case "input-keyboard":
			return "󰌌";
		case "input-gaming":
			return "󰊴";
		case "phone":
			return "󰄜";
		case "computer":
			return "󰌢";
		case "printer":
			return "󰐪";
		case "camera-photo":
		case "camera-video":
			return "󰄀";
		case "video-display":
			return "󰍹";
		default:
			return "󰂯";
		}
	}

	// Whether BlueZ has a charge figure at all. Most devices do not: it
	// arrives over the Battery Provider interface, which a device has to
	// implement, and the panel says nothing rather than 0% for the rest.
	function hasBattery(device: var): bool {
		return device?.batteryAvailable ?? false;
	}

	// Quickshell hands battery over as a 0..1 fraction; be tolerant of a
	// backend that hands back a percentage instead, the same way the Wi-Fi
	// signal reading is.
	function batteryOf(device: var): int {
		const b = device?.battery ?? 0;
		return Math.round(b <= 1 ? b * 100 : b);
	}

	// One line under the name, saying what the row is doing rather than what
	// it is: the glyph and the section heading have already said that.
	function stateLabel(device: var): string {
		if (!device)
			return "";
		if (device.pairing)
			return "Pairing…";
		switch (device.state) {
		case BluetoothDeviceState.Connecting:
			return "Connecting…";
		case BluetoothDeviceState.Disconnecting:
			return "Disconnecting…";
		case BluetoothDeviceState.Connected:
			return hasBattery(device) ? `Connected · ${batteryOf(device)}%` : "Connected";
		default:
			return known(device) ? "Paired" : "Available";
		}
	}

	// Discovery follows the panel rather than being left running: see
	// toggleDiscovery. `when` covers only the adapter existing, so closing
	// the panel drives the property to false through the binding rather than
	// detaching and leaving the radio sweeping behind a closed card.
	Binding {
		target: root.adapter
		property: "discovering"
		value: root.panelOpen && root.wantDiscovery && root.enabled
		when: root.adapter !== null
	}
}
