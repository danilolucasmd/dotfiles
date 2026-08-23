import Quickshell
import qs
import qs.components

// waybar: "{:%a %d %b %H:%M}", with 8px of clearance to the weather module on
// its left and 16px to the right edge of the centre group.
BarItem {
	leftMargin: 8
	rightMargin: 16
	// The bar has room for "Sat 22 Aug" and no more, so the one thing hovering
	// adds is the date written out in full.
	tooltip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")

	SystemClock {
		id: clock

		precision: SystemClock.Minutes
	}

	BarText {
		text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
		font.bold: true
	}
}
