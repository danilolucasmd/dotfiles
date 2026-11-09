import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The display panel, opened by clicking the bar module or by super+D.
//
// Everything about a screen that is worth changing from the bar rather than
// from hyprland.conf: how bright it is, how fast it refreshes, how big
// everything on it is, and which way up it is. The machine has two monitors
// that want different answers to all four, so the panel is pointed at one of
// them at a time and carries tabs to move between them.
//
// Nothing here is written anywhere. Hyprland takes these as runtime keywords,
// so a reload or a fresh login goes back to what the config says — which the
// footer states, because a settings panel that quietly forgets is worse than
// one that says it will.
Panel {
	id: root

	readonly property var monitor: DisplayState.selected
	readonly property var rates: DisplayState.ratesFor(monitor)

	open: DisplayState.panelOpen
	onDismissed: DisplayState.close()
	onKeyPressed: event => {
		if (press(event.key))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// the key rather than something only a real key event can reach.
	//
	// The two continuous things are on the keyboard; the three lists of values
	// are not. Walking six scale buttons with an arrow key would mean applying
	// five monitor rules to reach the sixth, and each one of those is a screen
	// that blanks and comes back.
	function press(key: int): bool {
		const all = DisplayState.monitors;

		switch (key) {
		case Qt.Key_H:
		case Qt.Key_Left:
			if (!DisplayState.dimmable)
				return false;
			DisplayState.setLevel(DisplayState.level - 5);
			break;
		case Qt.Key_L:
		case Qt.Key_Right:
			if (!DisplayState.dimmable)
				return false;
			DisplayState.setLevel(DisplayState.level + 5);
			break;
		case Qt.Key_J:
		case Qt.Key_Down:
		case Qt.Key_K:
		case Qt.Key_Up:
			if (all.length < 2)
				return false;
			const here = Math.max(0, all.findIndex(m => monitor && m.name === monitor.name));
			const forward = key === Qt.Key_J || key === Qt.Key_Down;
			DisplayState.select(all[(here + (forward ? 1 : all.length - 1)) % all.length].name);
			break;
		default:
			return false;
		}
		return true;
	}

	// The module sits in the bar's right cluster, so the panel drops from the
	// same corner rather than from the middle of the screen.
	anchors.right: true
	margins.right: 8

	// The one piece of ornament in this shell's panels, and it earns its place:
	// the panel is about a physical object, and the glyph says which one before
	// the text does.
	RowLayout {
		Layout.fillWidth: true
		spacing: 10

		BarText {
			Layout.alignment: Qt.AlignVCenter

			text: "󰍹"
			font.pixelSize: 26
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 0

			BarText {
				text: "Display"
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			// The connector name is how hyprland.conf refers to this screen, so
			// it is the name worth printing. The mode goes with it: when a
			// monitor offers only one refresh rate its section is gone, and
			// this is then the only place the rate is said at all.
			BarText {
				Layout.fillWidth: true

				text: root.monitor ? `${root.monitor.name} · ${root.monitor.width}×${root.monitor.height} · ${Math.round(root.monitor.refreshRate)} Hz` : "no monitors"
				color: Theme.dim
				elide: Text.ElideRight
			}
		}
	}

	// Which screen the rest of the panel is talking about. One monitor needs no
	// tabs — the header already named it.
	RowLayout {
		Layout.fillWidth: true
		visible: DisplayState.monitors.length > 1
		spacing: 6

		Repeater {
			model: DisplayState.monitors

			delegate: Choice {
				required property var modelData

				label: modelData.name
				current: root.monitor?.name === modelData.name

				onPicked: DisplayState.select(modelData.name)
			}
		}
	}

	// ------------------------------------------------------------------
	// Brightness
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		Heading {
			title: "Brightness"
			value: DisplayState.dimmable ? `${DisplayState.level}%` : ""
		}

		// Absent rather than greyed out on a screen with no backlight: a dead
		// slider parked at the far left says "0%", which is a different claim
		// from "there is nothing here to set".
		Slider {
			visible: DisplayState.dimmable
			value: DisplayState.level

			onMoved: percent => DisplayState.setLevel(percent)
		}

		BarText {
			Layout.fillWidth: true
			visible: !DisplayState.dimmable

			text: "No backlight — this one is set on the monitor itself."
			color: Theme.dim
			wrapMode: Text.Wrap
		}
	}

	// ------------------------------------------------------------------
	// Refresh rate
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		// A monitor with one rate is not being asked a question.
		visible: root.rates.length > 1
		spacing: 6

		Heading {
			title: "Refresh rate"
			value: root.monitor ? `${Math.round(root.monitor.refreshRate)} Hz` : ""
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Repeater {
				model: root.rates

				delegate: Choice {
					required property real modelData

					label: `${Math.round(modelData)}Hz`
					current: root.monitor && Math.round(root.monitor.refreshRate) === Math.round(modelData)

					onPicked: DisplayState.setRate(root.monitor, modelData)
				}
			}
		}
	}

	// ------------------------------------------------------------------
	// Scale
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		Heading {
			title: "Scale"
			value: root.monitor ? `${DisplayState.trim(root.monitor.scale)}x` : ""
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Repeater {
				model: DisplayState.scales

				delegate: Choice {
					required property real modelData

					label: `${DisplayState.trim(modelData)}x`
					// Not every scale divides every mode, and Hyprland refuses
					// the ones that do not.
					enabled: DisplayState.scaleFits(root.monitor, modelData)
					current: root.monitor && Math.abs(root.monitor.scale - modelData) < 0.005

					onPicked: DisplayState.setScale(root.monitor, modelData)
				}
			}
		}
	}

	// ------------------------------------------------------------------
	// Rotation
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		Heading {
			title: "Rotation"
			value: root.monitor ? `${(root.monitor.transform % 4) * 90}°` : ""
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Repeater {
				// Hyprland's transforms 4..7 are these four again, mirrored.
				// Nothing here offers a flip — it is not something you reach
				// for from a bar — so a mirrored monitor matches no button, and
				// pressing one is the way back out of it.
				model: [0, 90, 180, 270]

				delegate: Choice {
					required property int modelData

					label: `${modelData}°`
					current: root.monitor?.transform === modelData / 90

					onPicked: DisplayState.setTransform(root.monitor, modelData / 90)
				}
			}
		}
	}

	BarText {
		Layout.fillWidth: true
		visible: DisplayState.monitors.length === 0

		text: "No monitors. Hyprland reports nothing it is driving."
		wrapMode: Text.Wrap
	}

	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		BarText {
			Layout.fillWidth: true

			text: "Runtime only — a reload restores the config."
			color: Theme.dim
			wrapMode: Text.Wrap
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				text: {
					const keys = [];
					if (DisplayState.dimmable)
						keys.push("h/l brightness");
					if (DisplayState.monitors.length > 1)
						keys.push("j/k monitor");
					return keys.join(" · ");
				}
				elide: Text.ElideRight
			}

			BarText {
				text: "esc close"
			}
		}
	}

	// A section's heading: what it is on the left, what it currently says on the
	// right. The same shape the battery panel gives its own headings.
	component Heading: RowLayout {
		id: heading

		property string title: ""
		property string value: ""

		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: heading.title
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: heading.value
			color: Theme.dim
			elide: Text.ElideRight
		}
	}

	// One option, as a pill. The whole pill is the switch.
	//
	// Lifted from the battery panel's profile buttons, because the four rows
	// here are that same idea four times over: a short list of values, one of
	// which is live. Every pill carries a surface, not just the chosen one —
	// buttons that are invisible until pointed at do not read as a choice.
	//
	// The third state is this panel's own: a value this monitor cannot take.
	// `enabled` is QML's, so setting it stops the pointer as well as dulling
	// the pill.
	component Choice: Rectangle {
		id: choice

		property string label: ""
		property bool current: false

		signal picked

		Layout.fillWidth: true
		implicitHeight: 28

		radius: 6
		color: !enabled ? Qt.darker(Theme.tooltipBorder, 1.5) : (current || hover.hovered ? Theme.tooltipBorder : Qt.darker(Theme.tooltipBorder, 1.25))
		border.width: 1
		border.color: current ? Theme.blue : "transparent"

		HoverHandler {
			id: hover
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: choice.picked()
		}

		BarText {
			anchors.centerIn: parent

			text: choice.label
			color: !choice.enabled ? Theme.disabled : (choice.current ? Theme.blue : Theme.fg)
			font.weight: choice.current ? Font.DemiBold : Font.Normal
		}
	}

	// The brightness slider. The only one in this shell — the meters elsewhere
	// are readouts, and this is the one number here you set by pointing at
	// where you want it rather than by picking from a list.
	component Slider: Item {
		id: slider

		property int value: 0

		signal moved(int percent)

		Layout.fillWidth: true
		// Taller than the groove it draws: the grab area is the whole strip,
		// so the knob does not have to be hit to be moved.
		implicitHeight: 20

		Rectangle {
			id: groove

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter

			implicitHeight: 6
			radius: height / 2
			color: Theme.track

			Rectangle {
				width: handle.x + handle.width / 2
				height: groove.height
				radius: groove.radius
				color: Theme.fg
			}
		}

		Rectangle {
			id: handle

			// The knob's travel is the strip less its own width, so 0% and 100%
			// sit flush against the ends rather than half off them.
			x: (slider.width - width) * Math.max(0, Math.min(100, slider.value)) / 100
			anchors.verticalCenter: parent.verticalCenter

			width: 14
			height: 14
			radius: height / 2
			color: Theme.fg

			// Smooths the keyboard's 5% steps and the backlight keys arriving
			// from outside; a drag is already following the pointer exactly, so
			// animating it would only lag behind it.
			Behavior on x {
				enabled: !area.pressed

				NumberAnimation {
					duration: 120
					easing.type: Easing.OutCubic
				}
			}
		}

		MouseArea {
			id: area

			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onPressed: event => slider.pick(event.x)
			onPositionChanged: event => {
				if (pressed)
					slider.pick(event.x);
			}
			onWheel: event => slider.moved(slider.value + (event.angleDelta.y > 0 ? 5 : -5))
		}

		// Where the pointer is, as a percentage of the knob's travel — the same
		// span the knob's own x is drawn across, so it lands under the cursor.
		function pick(x: real): void {
			const travel = slider.width - handle.width;
			if (travel <= 0)
				return;
			slider.moved(Math.round(100 * Math.max(0, Math.min(1, (x - handle.width / 2) / travel))));
		}
	}
}
