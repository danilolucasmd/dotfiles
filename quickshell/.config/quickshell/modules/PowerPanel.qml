import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The shutdown confirm, and the only thing PowerState ever draws.
//
// Locking and suspending are undone by typing a password and by opening the
// lid; a poweroff is undone by whatever was open not having been saved. So the
// launcher's Shut down row opens this instead of running anything, and the card
// is deliberately the plainest one in the shell: a question, what it costs, and
// two buttons.
Panel {
	id: root

	// 0 is Cancel, 1 is Shut down. The selection starts on Cancel and not on
	// the button the row was reaching for, which is the whole confirmation:
	// a stray fuzzy match answered with a reflexive second Return has to land
	// on the harmless one, or the card is only a delay.
	property int cursor: 0

	cardWidth: 300
	// Lower than a bar panel's 8px. Nothing raised this from a module up there,
	// and a question belongs nearer the middle of the screen than the edge it
	// was not asked from.
	margins.top: 200

	open: PowerState.panelOpen
	onDismissed: PowerState.close()

	// Back to Cancel on every open. A card that remembers the selection would
	// be one that confirms itself the second time it is asked. Through
	// Connections rather than a plain `onVisibleChanged` here: Panel already
	// handles that signal to put the keyboard back on the card, and a handler
	// declared in a derived component replaces the base one rather than running
	// beside it -- which would leave this card deaf to Return and Escape both.
	Connections {
		target: root

		function onVisibleChanged() {
			if (root.visible)
				root.cursor = 0;
		}
	}

	onKeyPressed: event => {
		switch (event.key) {
		case Qt.Key_Left:
		case Qt.Key_Right:
		case Qt.Key_Tab:
		case Qt.Key_Backtab:
			root.cursor = 1 - root.cursor;
			break;
		case Qt.Key_Return:
		case Qt.Key_Enter:
			if (root.cursor === 1)
				PowerState.confirm();
			else
				PowerState.close();
			break;
		default:
			return;
		}

		event.accepted = true;
	}

	BarText {
		Layout.fillWidth: true

		text: "Shut down?"
		font.weight: Font.DemiBold
		horizontalAlignment: Text.AlignHCenter
	}

	BarText {
		Layout.fillWidth: true

		text: "Everything open closes without saving."
		color: Theme.dim
		font.pixelSize: 10
		horizontalAlignment: Text.AlignHCenter
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 10

		Button {
			label: "Cancel"
			selected: root.cursor === 0

			onPicked: PowerState.close()
		}

		Button {
			label: "Shut down"
			selected: root.cursor === 1
			// The only red control in the shell, and it earns it: this is the
			// one button here that cannot be taken back.
			danger: true

			onPicked: PowerState.confirm()
		}
	}

	// Hovering moves the selection rather than only highlighting under the
	// pointer, so the keyboard and the mouse cannot disagree about which button
	// Return would press.
	component Button: Rectangle {
		id: button

		property string label: ""
		property bool selected: false
		property bool danger: false

		signal picked

		Layout.fillWidth: true
		implicitHeight: 30

		radius: 6
		color: selected ? Theme.tooltipBorder : Qt.darker(Theme.tooltipBorder, 1.25)
		border.width: 1
		border.color: selected && danger ? Theme.red : "transparent"

		HoverHandler {
			onHoveredChanged: {
				if (hovered)
					root.cursor = button.danger ? 1 : 0;
			}
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: button.picked()
		}

		BarText {
			anchors.centerIn: parent

			text: button.label
			color: button.danger ? Theme.red : Theme.fg
			font.weight: button.selected ? Font.DemiBold : Font.Normal
		}
	}
}
