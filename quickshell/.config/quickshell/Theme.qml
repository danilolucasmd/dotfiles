pragma Singleton

import QtQuick
import Quickshell

// Colours and metrics lifted from the waybar style.css this shell replaces, so
// the migration was a change of engine, not of appearance. `dim` has since been
// retuned by hand; the rest still matches waybar.
Singleton {
	readonly property color bg: "#1f1f1f"
	readonly property color fg: "#dddddd"

	// Everything secondary: subtext, out-of-month days, timestamps, the glyph of
	// a module with nothing to say. Half-transparent white rather than a fixed
	// grey, so it sits at the same remove from whichever surface it lands on —
	// the #1f1f1f bar or a #2a2a2a card.
	//
	// NOTE the byte order. Qt reads an 8-digit hex colour as #AARRGGBB, not CSS's
	// #RRGGBBAA, so this is the same colour the walker stylesheet spells
	// #ffffff80 — written the other way round it would be a pale yellow.
	readonly property color dim: "#80ffffff"
	readonly property color red: "#f38ba8"
	readonly property color yellow: "#f9e2af"
	readonly property color green: "#a6e3a1"
	readonly property color blue: "#89b4fa"
	readonly property color peach: "#fab387"

	readonly property color tooltipBg: "#2a2a2a"
	readonly property color tooltipBorder: "#3f3f3f"

	// The bar's separator rule. Structural chrome rather than text, so it does
	// not follow `dim`: at half white a 1px line comes out at 65% of the
	// foreground's brightness and reads heavier than the glyphs it divides.
	// This is the weight the divider had when `dim` was still #6c7086.
	readonly property color line: "#59ffffff"

	// The unfilled part of a meter in the usage panel: readable against the
	// tooltip surface it sits on without competing with the fill.
	readonly property color track: "#3f3f3f"

	readonly property string fontFamily: "JetBrainsMono Nerd Font"

	readonly property int barHeight: 30

	// waybar font-size values, which were px and map 1:1 onto font.pixelSize.
	readonly property int fontText: 12
	readonly property int fontIcon: 16

	// The 16px right margin every module in the right cluster carried.
	readonly property int gap: 16
}
