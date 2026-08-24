import qs
import qs.components

// Which link is carrying traffic, and how well.
//
// waybar read this from sysfs itself; Quickshell talks to NetworkManager, which
// is the backend this machine runs. The reading lives in NetworkState, which
// the panel shares.
//
// One glyph rather than the old `󰤨 85%`: the percentage was the only number in
// the always-visible cluster that nothing else could have told you, and now the
// panel prints it along with everything else. The bars carry it well enough for
// a glance.
BarItem {
	id: root

	rightMargin: Theme.gap

	tooltip: {
		const lines = [];
		if (NetworkState.wiredUp)
			lines.push(`Ethernet — ${NetworkState.wiredDevice.name}`);
		if (NetworkState.wifiUp)
			lines.push(`Wi-Fi — ${NetworkState.wifiNetwork?.name ?? NetworkState.wifiDevice.name} (${NetworkState.signal}%)`);
		if (lines.length === 0)
			return NetworkState.wifiBlocked ? "Wi-Fi blocked by hardware switch" : NetworkState.wifiEnabled ? "Disconnected" : "Wi-Fi off";
		if (NetworkState.limited)
			lines.push("No internet access");
		return lines.join("\n");
	}

	onClicked: NetworkState.toggle()
	// The switch the panel puts under the pointer anyway, for when the panel is
	// not what you wanted — turning the radio off and on again is most of what
	// anyone does to Wi-Fi.
	onRightClicked: NetworkState.toggleWifi()

	BarText {
		text: NetworkState.icon
		// Connected is the ordinary state and reads as ordinary text. Amber is
		// associated-but-going-nowhere, which looks identical from the glyph
		// alone and is the one worth catching. Dim is nothing connected, the
		// same way the Bluetooth and notification glyphs go quiet.
		color: NetworkState.limited ? Theme.yellow : NetworkState.online ? Theme.fg : Theme.dim
		font.pixelSize: Theme.fontIcon
	}
}
