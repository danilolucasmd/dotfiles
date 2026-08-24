import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Past notifications, opened by clicking the bell or with super+N.
//
// This is what the walker menu was standing in for. A dmenu can only offer a
// list of one-line strings and one thing to do with the one you pick, so the
// old menu spent its label budget flattening every notification to `time app:
// summary — body` and made selecting one mean dismissing it. Here a row can be
// two lines, and picking one can mean going to the app that sent it.
Panel {
	id: root

	readonly property var records: NotificationsState.records

	// The keyboard cursor. The pointer moves it too, so there is only ever one
	// highlighted row however you arrived at it.
	property int cursor: 0

	open: NotificationsState.panelOpen
	onDismissed: NotificationsState.close()
	// Newest first, and the newest is what you opened this for.
	onOpenChanged: {
		if (open)
			cursor = 0;
	}
	// Dismissing a row, or a notification arriving while the panel is up.
	onRecordsChanged: cursor = Math.max(0, Math.min(cursor, records.length - 1))
	onKeyPressed: event => {
		if (press(event.key, (event.modifiers & Qt.ShiftModifier) !== 0))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// key + shift rather than something only a real key event can reach.
	function press(key: int, shift: bool): bool {
		const count = records.length;
		if (count === 0)
			return false;

		switch (key) {
		// Stops at both ends rather than wrapping: the history runs to 200 and
		// scrolls, so falling off the bottom back to the top loses your place
		// entirely — a short list of audio devices can afford that, this cannot.
		case Qt.Key_J:
		case Qt.Key_Down:
			cursor = Math.min(cursor + 1, count - 1);
			break;
		case Qt.Key_K:
		case Qt.Key_Up:
			cursor = Math.max(cursor - 1, 0);
			break;
		case Qt.Key_Space:
		case Qt.Key_Return:
		case Qt.Key_Enter:
			activate(records[cursor]);
			break;
		case Qt.Key_D:
			// Same shape as the input picker's m / M: the row, or the lot.
			if (shift)
				NotificationsState.clear();
			else
				NotificationsState.dismiss(records[cursor]);
			break;
		default:
			return false;
		}
		return true;
	}

	// Go to whatever sent it. Opening one is dealing with it, so the row goes
	// too — coming back to the panel to throw away the thing you just read is
	// the same work twice. The panel closes on the way out as well: the thing
	// you asked for is on another workspace, and leaving it up over there is
	// just something else to dismiss.
	function activate(rec: var): void {
		NotificationsState.focusSender(rec);
		NotificationsState.dismiss(rec);
		NotificationsState.close();
	}

	// The bell sits in the bar's right cluster, so the panel drops from the
	// same corner.
	anchors.right: true
	margins.right: 8

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: "Notifications"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			visible: root.records.length > 0

			text: `${root.records.length}`
			color: Theme.dim
		}
	}

	// Scrolls, because the history runs to 200 and the panel does not. The
	// cursor drags the view along with it.
	ListView {
		id: list

		Layout.fillWidth: true
		Layout.preferredHeight: Math.min(contentHeight, 340)
		visible: root.records.length > 0

		clip: true
		spacing: 2
		model: root.records
		currentIndex: root.cursor
		boundsBehavior: Flickable.StopAtBounds

		onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

		delegate: Entry {}
	}

	BarText {
		Layout.fillWidth: true
		visible: root.records.length === 0

		text: "No notifications."
		wrapMode: Text.Wrap
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			Action {
				visible: root.records.length > 0

				text: "Clear all"

				onTriggered: NotificationsState.clear()
			}

			Item {
				Layout.fillWidth: true
			}

			BarText {
				text: "esc close"
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.records.length > 0

			text: "j/k move · enter open · d dismiss · D all"
			elide: Text.ElideRight
		}
	}

	// One past notification. Two lines: who it is from and when, then what it
	// said — the walker menu had to fit all of that on one.
	component Entry: Rectangle {
		id: entry

		required property var modelData
		required property int index

		readonly property date when: new Date(modelData.time * 1000)
		// Notifications with no summary put everything in the body; the first
		// line still has to say something.
		readonly property string title: modelData.summary || flat
		// Bodies arrive with newlines in them — WhatsApp puts the origin, a
		// blank line, then the message — and this line is one line.
		readonly property string flat: NotificationsState.content(modelData)

		width: ListView.view ? ListView.view.width : 0
		implicitHeight: lines.implicitHeight + 12

		radius: 6
		color: root.cursor === index ? Theme.tooltipBorder : "transparent"

		// The pointer drives the same cursor the keys do rather than lighting a
		// second row of its own.
		HoverHandler {
			onHoveredChanged: {
				if (hovered)
					root.cursor = entry.index;
			}
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: root.activate(entry.modelData)
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

					text: entry.title
					// Urgency is a border colour on the popup, where there is
					// room for one. Here only the urgent case earns a colour.
					color: entry.modelData.urgency === 2 ? Theme.red : Theme.fg
					font.weight: Font.DemiBold
					elide: Text.ElideRight
				}

				BarText {
					// Today's notifications want the time; older ones want the
					// day, and by then the minute is no help.
					text: entry.when.toDateString() === new Date().toDateString() ? Qt.formatDateTime(entry.when, "HH:mm") : Qt.formatDateTime(entry.when, "d MMM")
					color: Theme.dim
				}

				// Only on the row you are on: a column of them would read as
				// decoration, and there is a key for this.
				BarText {
					visible: root.cursor === entry.index

					text: "󰅖"
					color: dismiss.containsMouse ? Theme.red : Theme.dim

					MouseArea {
						id: dismiss

						anchors.fill: parent
						anchors.margins: -4
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor

						// Above the row's own MouseArea, so throwing one away
						// does not also jump to the app that sent it.
						onClicked: NotificationsState.dismiss(entry.modelData)
					}
				}
			}

			// What it said, and nothing else — `Brave · web.whatsapp.com` in
			// front of a message is three ways of saying the row above it.
			// The app's name is worth the line only when there is no message
			// to put there, either because the body is empty or because it
			// went into the title for want of a summary.
			BarText {
				Layout.fillWidth: true
				visible: text !== ""

				text: entry.modelData.summary && entry.flat ? entry.flat : entry.modelData.app
				color: Theme.dim
				elide: Text.ElideRight
			}
		}
	}

	// A word you can click, styled like the footer text around it.
	component Action: BarText {
		id: action

		signal triggered

		color: area.containsMouse ? Theme.blue : Theme.fg

		MouseArea {
			id: area

			anchors.fill: parent
			anchors.margins: -4
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor

			onClicked: action.triggered()
		}
	}
}
