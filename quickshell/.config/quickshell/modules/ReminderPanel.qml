import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Writing a reminder, on super+shift+N. See ReminderState.qml for what happens
// to it afterwards.
//
// One field asked twice -- the message, then the minutes -- rather than a form
// with two boxes and a Tab between them. The whole point of the panel is that
// it is four keystrokes and gone, and a form is something you have to look at
// to fill in.
Panel {
	id: root

	// Wider than a bar panel's 360 because the message is a sentence, narrower
	// than the launcher's 620 because there is no list under it.
	cardWidth: 420
	// Position left at the Panel default: top centre, under the bar, which is
	// where the emoji picker sits. The two are the same kind of thing -- a
	// keybind summons them, no bar module raises them -- so they open in the
	// same place rather than each having a spot of its own.

	open: ReminderState.panelOpen
	onDismissed: ReminderState.close()

	Connections {
		target: root

		function onVisibleChanged() {
			if (root.visible) {
				field.clear();
				field.takeFocus();
			}
		}
	}

	// The same box is the message box and the minutes box, so it has to be
	// emptied when the step changes as well as when the panel opens -- and the
	// keyboard put back on it, because a preset chip clicked with the mouse
	// takes focus away from it.
	Connections {
		target: ReminderState

		function onStepChanged() {
			field.clear();
			field.takeFocus();
		}
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: "Reminder"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		// Which of the two questions is being asked. Two words rather than a
		// progress dot: the panel is only two steps deep and the words say
		// what to type.
		BarText {
			text: ReminderState.step === 0 ? "what" : "when"
			color: Theme.dim
		}
	}

	// The message, echoed back while the minutes are being typed. Without it
	// the second step is an empty box asking for a number with nothing on
	// screen saying what the number is about.
	BarText {
		Layout.fillWidth: true
		visible: ReminderState.step === 1

		text: ReminderState.draft
		color: Theme.dim
		wrapMode: Text.Wrap
		maximumLineCount: 2
		elide: Text.ElideRight
	}

	SearchField {
		id: field

		placeholder: ReminderState.step === 0 ? "Remind me to…" : "In how many minutes?"

		onKeyPressed: event => {
			switch (event.key) {
			case Qt.Key_Return:
			case Qt.Key_Enter:
				if (ReminderState.step === 0)
					ReminderState.submitMessage(text);
				else
					ReminderState.submitDelay(text);
				break;
			case Qt.Key_Escape:
				// Back to the message first, closed second -- the message is
				// the part that took typing. See ReminderState.back().
				if (!ReminderState.back())
					ReminderState.close();
				break;
			default:
				return;
			}

			event.accepted = true;
		}
	}

	// The five delays that are asked for often enough to be worth a click, and
	// the same five a fired reminder offers as snoozes. Only on the second
	// step: on the first they would be answering a question that has not been
	// asked yet.
	RowLayout {
		Layout.fillWidth: true
		visible: ReminderState.step === 1
		spacing: 6

		Repeater {
			model: ReminderState.presets

			delegate: Rectangle {
				id: chip

				required property var modelData

				implicitWidth: label.implicitWidth + 20
				implicitHeight: 24

				radius: 6
				color: area.containsMouse ? Theme.tooltipBorder : "transparent"
				border.width: 1
				border.color: Theme.tooltipBorder

				BarText {
					id: label

					anchors.centerIn: parent

					text: chip.modelData.label
					color: area.containsMouse ? Theme.blue : Theme.fg
				}

				MouseArea {
					id: area

					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor

					onClicked: {
						ReminderState.add(ReminderState.draft, chip.modelData.minutes);
						ReminderState.close();
					}
				}
			}
		}

		Item {
			Layout.fillWidth: true
		}
	}

	BarText {
		Layout.fillWidth: true

		text: ReminderState.step === 0 ? "enter next · esc close" : "enter set · esc back"
		color: Theme.dim
		elide: Text.ElideRight
	}
}
