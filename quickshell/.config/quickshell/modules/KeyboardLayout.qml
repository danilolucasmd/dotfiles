import QtQuick
import qs
import qs.components

// US vs US-International. The reading and the switching live in KeyboardState,
// which the picker panel shares; this is just the badge.
BarItem {
	rightMargin: Theme.gap
	highlighted: KeyboardState.panelOpen

	// Left-click picks a layout from the list, like the volume and mic modules
	// pick a device. The old click-to-flip is still here on the right button —
	// with two layouts configured that is the shorter way round.
	onClicked: KeyboardState.toggle()
	onRightClicked: KeyboardState.next()

	BarText {
		text: `󰌌 ${KeyboardState.code}`
		font.weight: Font.DemiBold
	}
}
