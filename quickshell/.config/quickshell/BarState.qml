pragma Singleton

import Quickshell

// Bar state shared by every screen's bar, so plugging in a second monitor
// doesn't give it its own idea of what's open.
Singleton {
	// Whether the collapsed half of the right cluster is showing. It lives only
	// as long as the pointer is on the bar, so there is nothing here worth
	// persisting across a reload.
	property bool extrasVisible: false

	// Tray menus open below the bar, so walking into one means leaving the bar.
	// Bar.qml holds the extras open while this is non-zero, otherwise reaching
	// for a menu entry would take the icon that opened it off screen.
	property int openMenus: 0
}
