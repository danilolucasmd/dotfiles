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

	// Same flip alt+space does, and deliberately through Hyprland rather than
	// around it: kb-layout-per-app.py is listening for `activelayout`, so a
	// click is remembered for the focused window's class like any other toggle.
	onClicked: flip.running = true

	Process {
		id: flip

		command: ["hyprctl", "switchxkblayout", "all", "next"]
	}

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
