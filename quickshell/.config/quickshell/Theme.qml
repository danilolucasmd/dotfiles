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
	// a module with nothing to say. Opaque, so it reads the same weight on the
	// #1f1f1f bar as on a #2a2a2a card rather than picking up whatever is
	// behind it.
	readonly property color dim: "#888888"
	readonly property color red: "#f38ba8"
	readonly property color yellow: "#f9e2af"
	readonly property color green: "#a6e3a1"
	readonly property color blue: "#89b4fa"
	readonly property color peach: "#fab387"

	readonly property color tooltipBg: "#2a2a2a"
	readonly property color tooltipBorder: "#3f3f3f"

	// The bar's separator rule. Structural chrome rather than text, so it does
	// not follow `dim` — a 1px line at the subtext colour reads heavier than
	// the glyphs it divides. Half-transparent so it stays a rule on any
	// surface; over the bar it lands at #6d6d6d.
	readonly property color line: "#59ffffff"

	// A control a row cannot offer — the skip glyphs on a video that reports no
	// next track. Lighter than the card and the highlighted row it has to read
	// against (#2a2a2a and #3f3f3f both), darker than `dim`, which is doing
	// secondary *text* right beside it.
	readonly property color disabled: "#5a5a5a"

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
