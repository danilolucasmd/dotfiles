import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The layout picker, opened by clicking the keyboard module. Same shape as the
// audio pickers: a list of what you could switch to, with the one in use
// ticked, walked with j/k or pointed at.
Panel {
	id: root

	readonly property var layouts: KeyboardState.layouts
	// Watched rather than read straight from the singleton: a window has an
	// `active` of its own, so the follow below needs a name that is ours.
	readonly property int liveIndex: KeyboardState.activeIndex

	// The keyboard cursor. The pointer moves it too, so there is only ever one
	// highlighted row however you arrived at it.
	property int cursor: 0

	open: KeyboardState.panelOpen
	revealed: KeyboardState.revealed
	onDismissed: KeyboardState.close()
	// The whole reason this panel takes the keyboard the moment alt+space is
	// pressed rather than when it becomes visible: a modifier coming back up is
	// not something Hyprland dispatches a bind for, so the surface holding the
	// keyboard is the only thing that hears it.
	onKeyReleased: event => {
		if (KeyboardState.held && (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)) {
			KeyboardState.release();
			event.accepted = true;
		}
	}
	// Opening puts the cursor on the layout in use, which is where you are
	// counting from when you go looking for another one.
	onOpenChanged: {
		if (open)
			cursor = Math.max(0, KeyboardState.activeIndex);
	}
	onLayoutsChanged: cursor = Math.max(0, Math.min(cursor, layouts.length - 1))
	// alt+space moves the layout itself rather than a selection, so while it is
	// driving the highlight just follows.
	onLiveIndexChanged: {
		if (KeyboardState.held)
			cursor = KeyboardState.activeIndex;
	}
	onKeyPressed: event => {
		if (press(event.key))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// the key rather than something only a real key event can reach.
	function press(key: int): bool {
		const count = layouts.length;
		if (count === 0)
			return false;

		switch (key) {
		case Qt.Key_J:
		case Qt.Key_Down:
			cursor = (cursor + 1) % count;
			break;
		case Qt.Key_K:
		case Qt.Key_Up:
			cursor = (cursor + count - 1) % count;
			break;
		case Qt.Key_Space:
		case Qt.Key_Return:
		case Qt.Key_Enter:
			KeyboardState.setLayout(cursor);
			break;
		default:
			return false;
		}
		return true;
	}

	// The module sits in the bar's right cluster, so the panel drops from the
	// same corner as the audio ones.
	anchors.right: true
	margins.right: 8

	BarText {
		Layout.fillWidth: true

		text: "Keyboard layout"
		font.pixelSize: 13
		font.weight: Font.DemiBold
	}

	ColumnLayout {
		Layout.fillWidth: true
		// Tighter than the panel's own section spacing: the rows are one list,
		// not a stack of sections.
		spacing: 2

		Repeater {
			model: root.layouts

			delegate: Entry {}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.layouts.length === 0

			text: "No layouts."
			wrapMode: Text.Wrap
		}
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			Layout.fillWidth: true
			visible: root.layouts.length > 0

			text: KeyboardState.held ? "alt+space next" : "j/k move · enter select"
			elide: Text.ElideRight
		}

		BarText {
			text: KeyboardState.held ? "release alt to keep" : "esc close"
		}
	}

	// One layout. The whole row is the switch.
	component Entry: Rectangle {
		id: entry

		required property var modelData
		required property int index

		readonly property bool isCurrent: index === KeyboardState.activeIndex

		Layout.fillWidth: true
		implicitHeight: 28

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

			onClicked: KeyboardState.setLayout(entry.index)
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 8
			spacing: 8

			BarText {
				// Fixed, so every name starts at the same x whether or not it
				// is the one in use.
				Layout.preferredWidth: 12

				text: entry.isCurrent ? "󰄬" : ""
				color: Theme.blue
			}

			BarText {
				// The badge the bar shows for this layout, so the row and the
				// module read as the same thing.
				Layout.preferredWidth: 24

				text: entry.modelData.code
				font.weight: entry.isCurrent ? Font.DemiBold : Font.Normal
			}

			BarText {
				Layout.fillWidth: true

				// The same name whether or not this is the live layout — one
				// that moved as you switched read as the row changing under
				// you.
				text: entry.modelData.name
				color: Theme.dim
				elide: Text.ElideRight
			}
		}
	}
}
