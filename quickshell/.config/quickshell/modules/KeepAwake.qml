import QtQuick
import qs
import qs.components

// Unlike the night light glyph beside the weather, this one is always on the
// bar: the click is the only way to turn it back off, so the off state has to
// be somewhere to click. Colour carries the state -- dim for a machine that is
// free to lock and suspend, awake yellow for one that is not -- and the mug
// fills up with it: md-coffee_outline while the machine may sleep, its filled
// md-coffee twin while it may not. The two are the same drawing at the same
// advance and the same ink box, so the swap changes weight without anything
// beside it moving.
//
// Bar.qml parks it between the clock and the recording dot.
BarItem {
	// No left margin: the clock's own 16px is the gap the mug sits in, the same
	// way the recording dot used to sit in it. The 8px on the right is the
	// clearance to that dot, which now hangs off this module instead.
	rightMargin: 8

	tooltip: KeepAwakeState.enabled ? "Keep awake on — screen will not lock or blank, machine will not suspend itself. Click to turn it off" : "Keep awake off — click to keep the screen and the machine up"

	onClicked: KeepAwakeState.toggle()

	BarText {
		text: KeepAwakeState.enabled ? "󰅶" : "󰛊"
		color: KeepAwakeState.enabled ? Theme.yellow : Theme.dim
		// 14 rather than Theme.fontIcon's 16, which is the one place on the bar
		// that wants a size of its own. The mug is a cup standing on a thin
		// saucer line, so its ink weight sits above the middle of the box it is
		// centred in -- at 16px it read as ~2px high against the digits beside
		// it, and at 14 that halves while the glyph still carries.
		font.pixelSize: 14
	}
}
