import qs
import qs.components

// Visible only while the blue-light filter is on, which is the only state worth
// a seat: a permanent glyph saying "not tinted" would be reporting the normal
// condition of the screen forever. Bar.qml parks it just off the left edge of
// the centre group, mirroring the recording dot on the right.
//
// The glyph is a sun going down rather than the moon the desktop convention
// would use, because the weather module two places along already draws 󰖔 for a
// clear night and two moons on one bar say nothing to each other. It also
// happens to be the tool's own name.
BarItem {
	// The 8px the clock keeps between itself and the weather glyph, so the
	// centre group reads as evenly spaced whether this is showing or not.
	rightMargin: 8

	active: NightLightState.enabled
	tooltip: `Night light on (${NightLightState.temperature}K) — click to turn it off`

	// A toggle would be a click that can do nothing visible: the module is only
	// on screen while the filter is on, so off is the only thing left to ask
	// for.
	onClicked: NightLightState.disable()

	BarText {
		text: "󰖚"
		// The one module here that is coloured for what it *is* rather than for
		// how bad it is -- warm, because that is what it did to the screen.
		color: Theme.peach
		font.pixelSize: Theme.fontIcon
	}
}
