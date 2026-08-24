pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.components

// Everything the bar and the network panel know about the machine's links: the
// two devices, which of them is carrying traffic, the Wi-Fi networks in range,
// and the counters the panel prints.
//
// A singleton for the reason the other panels have one: the panel is a window
// of its own rather than a child of the bar module, and super+shift+W can
// summon it without the bar being involved at all.
//
// The backend is NetworkManager (systemd-networkd is masked here, for Proton
// VPN's sake), which Quickshell exposes as devices with properties rather than
// as `nmcli` output to parse — so only the numbers NM does not carry go through
// a script.
Singleton {
	id: root

	readonly property var devices: Networking.devices?.values ?? []

	// One of each is all this machine has, and all the panel draws. A second
	// adapter of either kind would be a different panel.
	readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
	readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null

	readonly property bool wifiUp: wifiDevice?.connected ?? false
	readonly property bool wiredUp: wiredDevice?.connected ?? false
	readonly property bool online: wifiUp || wiredUp

	// Wired wins when both are up, because that is what the routing table does
	// with them: NetworkManager gives Ethernet the lower metric, so the Wi-Fi
	// association is real but idle.
	readonly property var primary: wiredUp ? wiredDevice : (wifiUp ? wifiDevice : null)

	// The network the Wi-Fi device is actually associated with, as opposed to
	// the ones it can see.
	readonly property var wifiNetwork: networks.find(n => n.connected) ?? null

	// NetworkManager reports strength as a percentage; be tolerant of a backend
	// that hands back a 0..1 fraction instead.
	readonly property int signal: {
		const s = wifiNetwork?.signalStrength ?? 0;
		return Math.round(s <= 1 ? s * 100 : s);
	}

	readonly property bool wifiEnabled: Networking.wifiEnabled
	// rfkill. No switch the panel offers can bring Wi-Fi back from this one.
	readonly property bool wifiBlocked: !Networking.wifiHardwareEnabled

	// Associated but going nowhere: a captive portal, or a router that is up
	// while its uplink is not. Worth a colour of its own — the glyph would
	// otherwise say everything is fine.
	readonly property bool limited: online && Networking.connectivity !== NetworkConnectivity.Full && Networking.connectivity !== NetworkConnectivity.Unknown

	// Every access point in range, strongest first, with the one in use pinned
	// to the top. Deduplicated by name: a mesh or an extender puts the same
	// SSID on the air several times over, and the panel is offering a network
	// to join rather than a radio to talk to.
	readonly property var networks: {
		const all = wifiDevice?.networks?.values ?? [];
		const best = new Map();
		for (const n of all) {
			const seen = best.get(n.name);
			if (!seen || n.connected || (!seen.connected && n.signalStrength > seen.signalStrength))
				best.set(n.name, n);
		}
		return [...best.values()].sort((a, b) => {
			if (a.connected !== b.connected)
				return a.connected ? -1 : 1;
			return b.signalStrength - a.signalStrength;
		});
	}

	readonly property var knownNetworks: networks.filter(n => n.known)
	readonly property var otherNetworks: networks.filter(n => !n.known)

	// What the bar draws. Ethernet has one glyph; Wi-Fi has five, and picking
	// between them is the whole point of having the module in the bar.
	readonly property string icon: {
		if (wiredUp)
			return "󰈀";
		if (wifiUp)
			return strengthIcon(signal);
		if (!wifiEnabled || wifiBlocked)
			return "󰤮";
		return "󰤯";
	}

	property bool panelOpen: false

	// ------------------------------------------------------------------
	// Counters
	//
	// Rates are a difference between two samples rather than something the
	// script measures: /proc/net/dev is cumulative, so holding the last reading
	// and dividing costs nothing, where measuring in the script would mean
	// sleeping a second inside every poll.
	// ------------------------------------------------------------------

	readonly property var stats: statsScript.data

	property var lastSample: null
	property real rxRate: 0
	property real txRate: 0

	// The last few probes rather than only the newest: three packets is too
	// coarse to call a loss percentage from, and a figure that jumps between 0
	// and 33 every two seconds says less than the average of ten of them.
	property var pingWindow: []
	readonly property int pingWindowSize: 10

	readonly property real packetLoss: {
		let sent = 0;
		let recv = 0;
		for (const p of pingWindow) {
			sent += p.sent;
			recv += p.recv;
		}
		return sent > 0 ? (sent - recv) / sent * 100 : 0;
	}

	readonly property real ping: stats.ping ?? 0
	readonly property string address: stats.address || primary?.address || ""
	readonly property string gateway: stats.gateway || ""
	readonly property string dns: stats.dns || ""

	// The interface the counters are for. Handed to the script rather than left
	// for it to work out, so the panel and the script never disagree about
	// which link is being described.
	readonly property string primaryName: primary?.name ?? ""

	function toggle(): void {
		panelOpen = !panelOpen;
		if (panelOpen) {
			// Opening starts the counters from scratch: whatever was in them is
			// from the last time the panel was up, and dividing by that gap
			// would print a rate averaged over minutes of not looking.
			reset();
			statsScript.refresh();
		}
	}

	function close(): void {
		panelOpen = false;
	}

	function reset(): void {
		lastSample = null;
		rxRate = 0;
		txRate = 0;
		pingWindow = [];
	}

	function sample(d: var): void {
		if (!d || !d.iface)
			return;

		const prev = lastSample;
		// A sample from the other interface is not comparable with this one,
		// and neither is one taken before a counter reset.
		if (prev && prev.iface === d.iface && d.t > prev.t && d.rx >= prev.rx && d.tx >= prev.tx) {
			const dt = d.t - prev.t;
			rxRate = (d.rx - prev.rx) / dt;
			txRate = (d.tx - prev.tx) / dt;
		}
		lastSample = d;

		pingWindow = [...pingWindow, {
			sent: d.sent ?? 0,
			recv: d.recv ?? 0
		}].slice(-pingWindowSize);
	}

	// ------------------------------------------------------------------
	// Actions
	// ------------------------------------------------------------------

	function setWifiEnabled(enabled: bool): void {
		Networking.wifiEnabled = enabled;
	}

	function toggleWifi(): void {
		if (!wifiBlocked)
			Networking.wifiEnabled = !Networking.wifiEnabled;
	}

	// ------------------------------------------------------------------
	// Formatting, shared by the bar's tooltip and the panel
	// ------------------------------------------------------------------

	function strengthIcon(strength: int): string {
		if (strength >= 80)
			return "󰤨";
		if (strength >= 55)
			return "󰤥";
		if (strength >= 30)
			return "󰤢";
		if (strength >= 10)
			return "󰤟";
		return "󰤯";
	}

	// A network's strength as the same 0..100 the bar reads, whichever scale
	// the backend handed it over on.
	function strengthOf(network: var): int {
		const s = network?.signalStrength ?? 0;
		return Math.round(s <= 1 ? s * 100 : s);
	}

	function secured(network: var): bool {
		const s = network?.security;
		return s !== undefined && s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe;
	}

	function securityLabel(network: var): string {
		if (!network)
			return "";
		switch (network.security) {
		case WifiSecurityType.Open:
			return "Open";
		case WifiSecurityType.Owe:
			return "Open (OWE)";
		case WifiSecurityType.Sae:
			return "WPA3";
		case WifiSecurityType.Wpa3SuiteB192:
			return "WPA3 Enterprise";
		case WifiSecurityType.Wpa2Psk:
			return "WPA2";
		case WifiSecurityType.WpaPsk:
			return "WPA";
		case WifiSecurityType.Wpa2Eap:
		case WifiSecurityType.WpaEap:
			return "Enterprise";
		case WifiSecurityType.StaticWep:
		case WifiSecurityType.DynamicWep:
			return "WEP";
		case WifiSecurityType.Leap:
			return "LEAP";
		default:
			return "Secured";
		}
	}

	// Why a join did not take, in the words the panel puts under the prompt.
	function failureLabel(reason: int): string {
		switch (reason) {
		case ConnectionFailReason.NoSecrets:
			return "Wrong password";
		case ConnectionFailReason.WifiAuthTimeout:
			return "Authentication timed out";
		case ConnectionFailReason.WifiNetworkLost:
			return "Network went out of range";
		case ConnectionFailReason.WifiClientDisconnected:
			return "Disconnected by the access point";
		case ConnectionFailReason.WifiClientFailed:
			return "The access point refused the connection";
		default:
			return "Could not connect";
		}
	}

	// Byte counters, at the precision each magnitude deserves: a total in GB
	// wants two decimals to move at all, a rate in B/s wants none.
	function formatBytes(bytes: real): string {
		if (!(bytes > 0))
			return "0 B";
		const units = ["B", "KB", "MB", "GB", "TB"];
		let i = 0;
		let n = bytes;
		while (n >= 1024 && i < units.length - 1) {
			n /= 1024;
			i++;
		}
		return `${n.toFixed(i === 0 ? 0 : 2)} ${units[i]}`;
	}

	function formatRate(bytesPerSecond: real): string {
		return `${formatBytes(bytesPerSecond)}/s`;
	}

	// Scanning is not free — it takes the radio off the air for a moment on
	// each channel — so the device only sweeps while the list that wants the
	// results is on screen.
	Binding {
		target: root.wifiDevice
		property: "scannerEnabled"
		value: root.panelOpen
		when: root.wifiDevice !== null
	}

	JsonScript {
		id: statsScript

		command: [`${Paths.scripts}/network-stats.sh`, root.primaryName]
		// Only while the panel is up: this pings on every run, and nothing
		// behind a closed panel reads the result.
		intervalMs: root.panelOpen ? 2000 : 0

		onDataChanged: root.sample(data)
	}
}
