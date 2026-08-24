import qs
import qs.components

// The display module: a glyph that opens DisplayPanel, and a scroll wheel on
// the backlight of whichever screen this instance of the bar is on.
//
// No number beside the glyph, unlike the volume and battery modules either side
// of it. Brightness is its own feedback — the screen is the readout — and a
// percentage here would mean holding a sysfs reading open forever for a number
// nobody glances at, on a machine where only one of the two screens has one to
// give. The panel has the reading, and the wheel has the control.
BarItem {
	id: root

	// The screen this bar is on. Scrolling dims the monitor under the pointer,
	// and clicking opens the panel already pointed at it — every other module
	// here is machine-wide, but a display is not. A keybind has no screen and
	// falls back to the focused monitor.
	property string screenName: ""

	rightMargin: Theme.gap

	onClicked: DisplayState.toggle(root.screenName)

	// Nothing happens on a screen with no backlight, which is the honest answer
	// on an external monitor: there is no software behind its brightness.
	onWheelUp: DisplayState.step(root.screenName, 5)
	onWheelDown: DisplayState.step(root.screenName, -5)

	BarText {
		text: "󰍹"
		font.pixelSize: Theme.fontIcon
	}
}
