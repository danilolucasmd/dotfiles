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
	// The 8px is the clearance to the recording dot, which hangs off this
	// module rather than off the clock now. The gap on the *left* is not set
	// here at all -- it is the negative anchor margin in Bar.qml, which pulls
	// the mug back out of the clock's own trailing 16px.
	rightMargin: 10

	tooltip: KeepAwakeState.enabled ? "Keep awake on" : "Keep awake off"

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
