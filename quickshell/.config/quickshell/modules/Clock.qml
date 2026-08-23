import Quickshell
import qs
import qs.components

// waybar: "{:%a %d %b %H:%M}", with 8px of clearance to the weather module on
// its left and 16px to the right edge of the centre group.
BarItem {
	leftMargin: 8
	rightMargin: 16

	// No tooltip: spelling out the date the bar is already showing was never
	// worth a hover, and the click opens the month in CalendarPanel instead.
	onClicked: CalendarState.toggle()

	SystemClock {
		id: clock

		precision: SystemClock.Minutes
	}

	BarText {
		text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
		font.bold: true
	}
}
