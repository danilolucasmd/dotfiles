pragma Singleton

import QtQuick
import Quickshell

// Colours and metrics lifted verbatim from the waybar style.css this shell
// replaces, so the migration is a change of engine, not of appearance.
Singleton {
	readonly property color bg: "#1f1f1f"
	readonly property color fg: "#dddddd"
	readonly property color dim: "#6c7086"
	readonly property color red: "#f38ba8"
	readonly property color yellow: "#f9e2af"
	readonly property color green: "#a6e3a1"
	readonly property color blue: "#89b4fa"
	readonly property color peach: "#fab387"

	readonly property color tooltipBg: "#2a2a2a"
	readonly property color tooltipBorder: "#3f3f3f"

	readonly property string fontFamily: "JetBrainsMono Nerd Font"

	readonly property int barHeight: 30

	// waybar font-size values, which were px and map 1:1 onto font.pixelSize.
	readonly property int fontText: 12
	readonly property int fontIcon: 16

	// The 16px right margin every module in the right cluster carried.
	readonly property int gap: 16
}
