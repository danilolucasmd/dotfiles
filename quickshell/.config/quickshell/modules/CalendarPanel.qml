import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// A month at a glance, opened by clicking the clock.
//
// The tooltip it replaced could only spell out the date the bar was already
// showing. What you actually go to a date for is the thing the bar cannot
// answer — which day the 14th falls on, how far off next Friday is — and that
// wants a grid.
Panel {
	id: root

	// Months away from the current one. Reset whenever the panel opens, so it
	// always comes up on today however it was left.
	property int offset: 0

	readonly property date today: clock.date
	readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
	readonly property int firstDay: Qt.locale().firstDayOfWeek

	// The month padded out to whole weeks — leading days borrowed from the
	// previous month, trailing from the next — and only as many rows as this
	// particular month needs, so February does not leave an empty band.
	readonly property var cells: {
		const lead = (shown.getDay() - firstDay + 7) % 7;
		const days = new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate();
		const out = [];
		for (let i = 0, n = Math.ceil((lead + days) / 7) * 7; i < n; i++)
			out.push(new Date(shown.getFullYear(), shown.getMonth(), 1 - lead + i));
		return out;
	}

	open: CalendarState.panelOpen
	onOpenChanged: {
		if (open)
			offset = 0;
	}
	onDismissed: CalendarState.close()
	// The panel has nothing to fetch, so the refresh key means the other thing
	// it could sensibly mean here: back to this month.
	onRefreshRequested: offset = 0
	onKeyPressed: event => {
		if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
			root.offset--;
		else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
			root.offset++;
		else
			return;
		event.accepted = true;
	}

	// Minutes is enough: the only thing the panel takes from the clock is which
	// day is today, and it has to notice midnight passing while it is open.
	SystemClock {
		id: clock

		precision: SystemClock.Minutes
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		Arrow {
			text: "‹"

			onTriggered: root.offset--
		}

		BarText {
			Layout.fillWidth: true

			text: Qt.formatDateTime(root.shown, "MMMM yyyy")
			horizontalAlignment: Text.AlignHCenter
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Arrow {
			text: "›"

			onTriggered: root.offset++
		}
	}

	GridLayout {
		Layout.fillWidth: true

		columns: 7
		columnSpacing: 0
		rowSpacing: 2

		Repeater {
			model: 7

			delegate: BarText {
				required property int index

				Layout.fillWidth: true

				// Starting from the locale's own first day, so the columns match
				// whatever calendar the rest of the desktop draws.
				text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat)
				horizontalAlignment: Text.AlignHCenter
				color: Theme.dim
			}
		}

		Repeater {
			model: root.cells

			delegate: Day {}
		}
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: Qt.formatDateTime(root.today, "dddd, d MMMM")
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: root.offset === 0 ? "← → month · esc close" : "r today · esc close"
		}
	}

	// A month step for when the panel was opened with the mouse and the
	// keyboard is not where your hand is. The hit area is grown past the glyph,
	// which is too small a target on its own.
	component Arrow: BarText {
		id: arrow

		signal triggered

		font.pixelSize: 16
		color: area.containsMouse ? Theme.fg : Theme.dim

		MouseArea {
			id: area

			anchors.fill: parent
			anchors.margins: -6
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor

			onClicked: arrow.triggered()
		}
	}

	// One cell. Days belonging to the neighbouring months are kept rather than
	// blanked — a week that runs across the month boundary is still a week —
	// but dimmed so the month itself stays the thing you read.
	component Day: Item {
		id: day

		required property var modelData

		readonly property bool inMonth: modelData.getMonth() === root.shown.getMonth()
		readonly property bool isToday: modelData.toDateString() === root.today.toDateString()

		Layout.fillWidth: true
		implicitHeight: 26

		Rectangle {
			anchors.centerIn: parent
			width: 24
			height: 24
			radius: width / 2
			visible: day.isToday
			color: Theme.blue
		}

		BarText {
			anchors.centerIn: parent

			text: `${day.modelData.getDate()}`
			color: day.isToday ? Theme.bg : (day.inMonth ? Theme.fg : Theme.dim)
			font.weight: day.isToday ? Font.DemiBold : Font.Normal
		}
	}
}
