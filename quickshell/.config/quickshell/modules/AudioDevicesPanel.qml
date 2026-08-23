import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The output and input pickers, opened by clicking the volume and mic modules.
// One component, mounted twice: the two lists differ only in which default
// they move and whether the rows carry a mute switch.
Panel {
	id: root

	// false = sinks (the volume module), true = sources (the mic module).
	property bool inputs: false

	readonly property var devices: inputs ? AudioState.sources : AudioState.sinks
	readonly property var current: inputs ? AudioState.source : AudioState.sink

	// The keyboard cursor. The pointer moves it too, so there is only ever one
	// highlighted row however you arrived at it.
	property int cursor: 0

	open: inputs ? AudioState.inputsOpen : AudioState.outputsOpen
	onDismissed: {
		if (inputs)
			AudioState.inputsOpen = false;
		else
			AudioState.outputsOpen = false;
	}
	// Opening puts the cursor on the device in use, which is where you are
	// counting from when you go looking for another one.
	onOpenChanged: {
		if (open)
			cursor = Math.max(0, devices.findIndex(n => current && n.id === current.id));
	}
	// A device can appear or disappear while the panel is up.
	onDevicesChanged: cursor = Math.max(0, Math.min(cursor, devices.length - 1))
	onKeyPressed: event => {
		if (press(event.key, (event.modifiers & Qt.ShiftModifier) !== 0))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// key + shift rather than something only a real key event can reach.
	function press(key: int, shift: bool): bool {
		const count = devices.length;
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
			AudioState.setDefault(devices[cursor], inputs);
			break;
		case Qt.Key_M:
			// Muting is an input-side idea: a speaker you are not listening to
			// is just a speaker turned down.
			if (!inputs)
				return false;
			if (shift)
				AudioState.toggleAllSources();
			else
				AudioState.toggleNodeMute(devices[cursor]);
			break;
		default:
			return false;
		}
		return true;
	}

	// Both modules sit in the bar's right cluster, so the panel drops from the
	// same corner.
	anchors.right: true
	margins.right: 8

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: root.inputs ? "Input" : "Output"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

	}

	ColumnLayout {
		Layout.fillWidth: true
		// Tighter than the panel's own section spacing: the rows are one list,
		// not a stack of sections.
		spacing: 2

		Repeater {
			model: root.devices

			delegate: Device {}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.devices.length === 0

			text: root.inputs ? "No input devices." : "No output devices."
			wrapMode: Text.Wrap
		}
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			// Mute-everything, for the case the per-device switches above are
			// the long way round: silence the lot unless they are already
			// silent.
			Action {
				visible: root.inputs && root.devices.length > 0

				text: AudioState.allSourcesMuted ? "Unmute all" : "Mute all"

				onTriggered: AudioState.toggleAllSources()
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
			visible: root.devices.length > 0

			text: root.inputs ? "j/k move · enter select · m mute · M all" : "j/k move · enter select"
			elide: Text.ElideRight
		}
	}

	// One device. The whole row is the switch — clicking anywhere but the mute
	// glyph makes this the default.
	component Device: Rectangle {
		id: device

		required property var modelData
		required property int index

		readonly property bool isCurrent: modelData && root.current && modelData.id === root.current.id
		readonly property bool isMuted: modelData.audio?.muted ?? false

		Layout.fillWidth: true
		implicitHeight: 28

		radius: 6
		color: root.cursor === index ? Theme.tooltipBorder : "transparent"

		// The pointer drives the same cursor the keys do rather than lighting a
		// second row of its own.
		HoverHandler {
			onHoveredChanged: {
				if (hovered)
					root.cursor = device.index;
			}
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: AudioState.setDefault(device.modelData, root.inputs)
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

				text: device.isCurrent ? "󰄬" : ""
				color: Theme.blue
			}

			BarText {
				Layout.fillWidth: true

				text: AudioState.label(device.modelData)
				color: device.isMuted ? Theme.dim : Theme.fg
				font.weight: device.isCurrent ? Font.DemiBold : Font.Normal
				elide: Text.ElideRight
			}

			// Per-device mute, inputs only — a muted speaker you are not
			// listening to is just a speaker with the volume down, but a
			// muted microphone is the thing you actually want to check.
			BarText {
				visible: root.inputs

				text: device.isMuted ? "󰍭" : "󰍬"
				color: device.isMuted ? Theme.red : Theme.fg
				font.pixelSize: Theme.fontIcon

				MouseArea {
					anchors.fill: parent
					anchors.margins: -4
					cursorShape: Qt.PointingHandCursor

					// Sits above the row's own MouseArea, so muting a device
					// does not also make it the default.
					onClicked: AudioState.toggleNodeMute(device.modelData)
				}
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
