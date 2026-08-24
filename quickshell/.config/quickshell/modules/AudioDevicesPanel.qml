import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The audio device panel, opened by clicking the volume or the mic module.
// One panel with an output section and an input section: the two were separate
// pickers stacked on the same corner, which meant switching a headset over
// took two visits to the same list of the same devices. The sections differ
// only in which default they move and whether the rows carry a mute switch.
//
// Which module (or keybind) opened it decides only where the cursor lands --
// both sections are on screen either way.
Panel {
	id: root

	readonly property var sinks: AudioState.sinks
	readonly property var sources: AudioState.sources

	// The two lists as one, so the cursor is a single index that walks the
	// panel top to bottom and the keys never have to know where the section
	// boundary is.
	readonly property var rows: [...sinks.map(n => ({
					node: n,
					inputs: false
				})), ...sources.map(n => ({
					node: n,
					inputs: true
				}))]

	// The keyboard cursor. The pointer moves it too, so there is only ever one
	// highlighted row however you arrived at it.
	property int cursor: 0

	// Which section the panel was opened on. Not a filter -- just where the
	// cursor starts.
	readonly property bool section: AudioState.devicesInputs

	open: AudioState.devicesOpen
	onDismissed: AudioState.devicesOpen = false

	// Opening puts the cursor on the device in use, which is where you are
	// counting from when you go looking for another one. Hitting super+I with
	// the panel already up on the outputs moves the cursor rather than doing
	// nothing, so the section change is watched as well as the open.
	onOpenChanged: {
		if (open)
			focusSection();
	}
	onSectionChanged: {
		if (open)
			focusSection();
	}
	// A device can appear or disappear while the panel is up.
	onRowsChanged: cursor = Math.max(0, Math.min(cursor, rows.length - 1))
	onKeyPressed: event => {
		if (press(event.key, (event.modifiers & Qt.ShiftModifier) !== 0))
			event.accepted = true;
	}

	function focusSection(): void {
		const list = section ? sources : sinks;
		const current = section ? AudioState.source : AudioState.sink;
		const at = Math.max(0, list.findIndex(n => current && n.id === current.id));
		// An empty section has nothing to put the cursor on; the other one's
		// first row is the nearest thing to it.
		cursor = Math.min(rows.length - 1, (section ? sinks.length : 0) + at);
	}

	// Split out of the handler so the panel's keys are one plain function of
	// key + shift rather than something only a real key event can reach.
	function press(key: int, shift: bool): bool {
		// Mute-everything is about the input section as a whole, so it works
		// wherever the cursor happens to be sitting.
		if (key === Qt.Key_M && shift) {
			AudioState.toggleAllSources();
			return true;
		}

		const count = rows.length;
		const row = rows[cursor];
		if (count === 0 || !row)
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
			AudioState.setDefault(row.node, row.inputs);
			break;
		case Qt.Key_M:
			// Muting is an input-side idea: a speaker you are not listening to
			// is just a speaker turned down.
			if (!row.inputs)
				return false;
			AudioState.toggleNodeMute(row.node);
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

	Section {
		inputs: false
	}

	Section {
		inputs: true
		// The input rows carry on numbering where the output rows stopped.
		offset: root.sinks.length
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
				visible: root.sources.length > 0

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
			visible: root.rows.length > 0

			text: "j/k move · enter select · m mute · M all"
			elide: Text.ElideRight
		}
	}

	// One list under its heading. Both sections are the same thing twice, the
	// way the two panels used to be.
	component Section: ColumnLayout {
		id: section

		required property bool inputs
		// Where this section's first row sits in the panel-wide cursor.
		property int offset: 0

		readonly property var devices: inputs ? root.sources : root.sinks

		Layout.fillWidth: true
		// Tighter than the panel's own section spacing: the rows are one list,
		// not a stack of sections.
		spacing: 2

		BarText {
			Layout.bottomMargin: 4

			text: section.inputs ? "Input" : "Output"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Repeater {
			model: section.devices

			delegate: Device {
				inputs: section.inputs
				offset: section.offset
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: section.devices.length === 0

			text: section.inputs ? "No input devices." : "No output devices."
			wrapMode: Text.Wrap
		}
	}

	// One device. The whole row is the switch — clicking anywhere but the mute
	// glyph makes this the default.
	component Device: Rectangle {
		id: device

		required property var modelData
		required property int index
		// Passed down by the section rather than read off the node: a node
		// knows it is a sink, but the row also has to know which default it
		// moves and which list it is counted in.
		property bool inputs: false
		property int offset: 0

		readonly property var current: inputs ? AudioState.source : AudioState.sink
		readonly property bool isCurrent: modelData && current && modelData.id === current.id
		readonly property bool isMuted: modelData.audio?.muted ?? false

		Layout.fillWidth: true
		implicitHeight: 28

		radius: 6
		color: root.cursor === offset + index ? Theme.tooltipBorder : "transparent"

		// The pointer drives the same cursor the keys do rather than lighting a
		// second row of its own.
		HoverHandler {
			onHoveredChanged: {
				if (hovered)
					root.cursor = device.offset + device.index;
			}
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: AudioState.setDefault(device.modelData, device.inputs)
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
				visible: device.inputs

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
