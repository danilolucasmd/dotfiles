import Quickshell.Networking
import qs
import qs.components

// Wi-Fi signal strength / wired / disconnected.
//
// waybar read this from sysfs itself; Quickshell talks to NetworkManager,
// which is the backend this machine runs (systemd-networkd is masked, for
// Proton VPN's sake).
BarItem {
	id: root

	readonly property var devices: Networking.devices?.values ?? []

	readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
	readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null

	// The network the Wi-Fi device is actually associated with.
	readonly property var wifiNetwork: {
		if (!wifi)
			return null;
		const nets = wifi.networks?.values ?? [];
		return nets.find(n => n.connected) ?? null;
	}

	// NetworkManager reports strength as a percentage; be tolerant of a
	// backend that hands back a 0..1 fraction instead.
	readonly property int signal: {
		const s = wifiNetwork?.signalStrength ?? 0;
		return Math.round(s <= 1 ? s * 100 : s);
	}

	rightMargin: Theme.gap

	tooltip: {
		if (wifi)
			return `${wifiNetwork?.name ?? wifi.name} — ${signal}%`;
		if (wired)
			return `Wired (${wired.name})`;
		return "Disconnected";
	}

	BarText {
		font.pixelSize: Theme.fontIcon

		text: {
			if (root.wifi)
				return `󰤨 ${root.signal}%`;
			if (root.wired)
				return "󰈀";
			return "󰤭";
		}
	}
}
