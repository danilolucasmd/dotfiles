import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// What is still pending, on super+ctrl+N, with the countdown on each. See
// ReminderState.qml.
//
// The half of the feature that makes the other half trustworthy: once a
// reminder is set it is invisible until it goes off, and something invisible
// that you are relying on is something you end up re-checking by setting a
// second one. This is where you look instead.
Panel {
	id: root

	readonly property var reminders: ReminderState.reminders

	// The keyboard cursor. The pointer moves it too, so there is only ever one
	// highlighted row however you arrived at it -- the same arrangement as the
	// notification history.
	property int cursor: 0

	cardWidth: 420
	// Top centre, with the compose card it is the other half of. See there.

	open: ReminderState.listOpen
	onDismissed: ReminderState.closeList()
	// Soonest first, and the soonest is what you opened this for.
	onOpenChanged: {
		if (open)
			cursor = 0;
	}
	// A reminder deleted from under the cursor, or one firing while the panel
	// is up.
	onRemindersChanged: cursor = Math.max(0, Math.min(cursor, reminders.length - 1))
	onKeyPressed: event => {
		if (press(event.key, (event.modifiers & Qt.ShiftModifier) !== 0))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// key + shift rather than something only a real key event can reach.
	function press(key: int, shift: bool): bool {
		// The one key that works on an empty list, because an empty list is
		// exactly when you want it.
		if (key === Qt.Key_N) {
			ReminderState.closeList();
			ReminderState.toggle();
			return true;
		}

		const count = reminders.length;
		if (count === 0)
			return false;

		switch (key) {
		case Qt.Key_J:
		case Qt.Key_Down:
			cursor = Math.min(cursor + 1, count - 1);
			break;
		case Qt.Key_K:
		case Qt.Key_Up:
			cursor = Math.max(cursor - 1, 0);
			break;
		case Qt.Key_D:
			// The same shape as the notification history's d / D: the row, or
			// the lot.
			if (shift)
				ReminderState.clear();
			else
				ReminderState.remove(reminders[cursor]);
			break;
		default:
			return false;
		}
		return true;
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: "Reminders"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			visible: root.reminders.length > 0

			text: `${root.reminders.length}`
			color: Theme.dim
		}
	}

	ListView {
		id: list

		Layout.fillWidth: true
		Layout.preferredHeight: Math.min(contentHeight, 340)
		visible: root.reminders.length > 0

		clip: true
		spacing: 2
		model: root.reminders
		currentIndex: root.cursor
		boundsBehavior: Flickable.StopAtBounds

		onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

		delegate: Entry {}
	}

	BarText {
		Layout.fillWidth: true
		visible: root.reminders.length === 0

		text: "Nothing pending."
		wrapMode: Text.Wrap
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: root.reminders.length > 0 ? "j/k move · d delete · D all · n new" : "n new"
			color: Theme.dim
			elide: Text.ElideRight
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: "esc close"
			color: Theme.dim
		}
	}

	// One pending reminder: what it says, then when it lands and how long that
	// is from now.
	component Entry: Rectangle {
		id: entry

		required property var modelData
		required property int index

		// Under a minute, in the colour the bar uses for "about to matter".
		readonly property bool imminent: modelData.due - ReminderState.now < 60000

		width: ListView.view ? ListView.view.width : 0
		implicitHeight: lines.implicitHeight + 12

		radius: 6
		color: root.cursor === index ? Theme.tooltipBorder : "transparent"

		HoverHandler {
			onHoveredChanged: {
				if (hovered)
					root.cursor = entry.index;
			}
		}

		ColumnLayout {
			id: lines

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			anchors.leftMargin: 8
			anchors.rightMargin: 8
			spacing: 1

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				BarText {
					Layout.fillWidth: true

					text: entry.modelData.text
					elide: Text.ElideRight
				}

				// The countdown is monospace anyway -- the whole shell is --
				// so it does not jump about as the seconds tick down.
				BarText {
					text: ReminderState.countdown(entry.modelData.due)
					color: entry.imminent ? Theme.peach : Theme.fg
				}

				// Only on the row you are on: a column of them would read as
				// decoration, and there is a key for this.
				BarText {
					visible: root.cursor === entry.index

					text: "󰅖"
					color: drop.containsMouse ? Theme.red : Theme.dim

					MouseArea {
						id: drop

						anchors.fill: parent
						anchors.margins: -4
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor

						onClicked: ReminderState.remove(entry.modelData)
					}
				}
			}

			// The clock time it lands at. The countdown answers "how long",
			// this answers "so what else is happening then", and past about
			// ten minutes that is the one being asked.
			BarText {
				Layout.fillWidth: true

				text: ReminderState.dueAt(entry.modelData.due)
				color: Theme.dim
				elide: Text.ElideRight
			}
		}
	}
}
