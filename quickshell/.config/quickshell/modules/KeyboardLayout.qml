import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.components

// US vs US-International. The waybar version kept its own connection to
// Hyprland's socket2 to catch `activelayout`; Quickshell already has one, so
// this just listens to the event stream it exposes.
BarItem {
	id: root

	property string keymap: ""

	readonly property bool intl: keymap.toLowerCase().includes("intl")

	rightMargin: Theme.gap
	tooltip: intl ? "US International (dead keys)" : "US"

	// The event only fires on a change, so seed from the current state.
	Process {
		running: true
		command: ["hyprctl", "devices", "-j"]

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const keyboards = JSON.parse(text).keyboards ?? [];
					const main = keyboards.find(k => k.main) ?? keyboards[0];
					root.keymap = main?.active_keymap ?? "";
				} catch (e) {
				}
			}
		}
	}

	Connections {
		target: Hyprland

		function onRawEvent(event: HyprlandEvent): void {
			// payload: KEYBOARDNAME,LAYOUTNAME
			if (event.name === "activelayout")
				root.keymap = event.data.split(",").slice(1).join(",");
		}
	}

	BarText {
		text: root.intl ? "󰌌 BR" : "󰌌 US"
		font.weight: Font.DemiBold
	}
}
