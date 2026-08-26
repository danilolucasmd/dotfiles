import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs
import qs.components

// The battery panel, opened by clicking the bar module or by super+shift+B.
//
// It replaced the module's hover tooltip, which could only ever say one
// percentage and one time estimate. This machine has two packs that wear at
// different rates -- one at 65% of its design capacity, one at 92% -- and the
// aggregate the bar shows hides that completely, so the panel gives each pack
// its own meter and prints what is left of its capacity underneath.
Panel {
	id: root

	readonly property var batteries: BatteryState.batteries

	open: BatteryState.panelOpen
	onDismissed: BatteryState.close()
	onKeyPressed: event => {
		if (press(event.key))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// the key rather than something only a real key event can reach.
	function press(key: int): bool {
		if (!BatteryState.profilesAvailable)
			return false;

		const top = BatteryState.hasPerformance ? PowerProfile.Performance : PowerProfile.Balanced;
		switch (key) {
		case Qt.Key_H:
		case Qt.Key_Left:
			BatteryState.setProfile(Math.max(PowerProfile.PowerSaver, BatteryState.profile - 1));
			break;
		case Qt.Key_L:
		case Qt.Key_Right:
			BatteryState.setProfile(Math.min(top, BatteryState.profile + 1));
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

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: "Battery"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		// The aggregate, spelled out: the state in words and the estimate the
		// bar has no room for.
		BarText {
			text: {
				const left = BatteryState.duration(BatteryState.secondsLeft);
				if (BatteryState.charging)
					return left ? `charging · ${left} to full` : "charging";
				return left ? `${left} remaining` : "on battery";
			}
			color: Theme.dim
			elide: Text.ElideRight
		}
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 12

		Repeater {
			model: root.batteries

			delegate: Pack {}
		}
	}

	BarText {
		Layout.fillWidth: true
		visible: root.batteries.length === 0

		text: "No battery. UPower reports nothing that is a laptop pack."
		wrapMode: Text.Wrap
	}

	// ------------------------------------------------------------------
	// Power profile
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		BarText {
			text: "Power profile"
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		RowLayout {
			Layout.fillWidth: true
			visible: BatteryState.profilesAvailable
			spacing: 6

			Profile {
				value: PowerProfile.PowerSaver
				icon: "󰾆"
				label: "Saver"
			}

			Profile {
				value: PowerProfile.Balanced
				icon: "󰗑"
				label: "Balanced"
			}

			Profile {
				// A machine that offers no performance profile gets two
				// buttons rather than a third that cannot be pressed.
				visible: BatteryState.hasPerformance

				value: PowerProfile.Performance
				icon: "󰓅"
				label: "Perf"
			}
		}

		// Selecting Performance on a hot or lap-detected machine appears to do
		// nothing -- the profile takes, the clocks do not. Say why.
		BarText {
			Layout.fillWidth: true
			visible: BatteryState.profilesAvailable && BatteryState.degradation !== PerformanceDegradationReason.None

			text: BatteryState.degradation === PerformanceDegradationReason.HighTemperature ? "Performance held back — running hot" : "Performance held back — lap detected"
			color: Theme.yellow
			wrapMode: Text.Wrap
		}

		BarText {
			Layout.fillWidth: true
			visible: !BatteryState.profilesAvailable

			text: "Not available — install power-profiles-daemon and enable the service."
			color: Theme.dim
			wrapMode: Text.Wrap
		}
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			Layout.fillWidth: true
			visible: BatteryState.profilesAvailable

			text: "h/l profile"
			elide: Text.ElideRight
		}

		BarText {
			text: "esc close"
		}
	}

	// The fill colour of a charge meter, and of the number over it. Green for
	// fine, because the meters elsewhere in this shell read that way round;
	// charging is green too, since a pack on the cable is not a pack to worry
	// about however low it currently sits.
	function chargeColor(pct: int, charging: bool): color {
		if (charging)
			return Theme.green;
		if (pct <= 15)
			return Theme.red;
		if (pct <= 30)
			return Theme.yellow;
		return Theme.green;
	}

	// How much of its design capacity a pack still holds. A worn pack is not an
	// emergency -- there is nothing to do about it today -- so this only ever
	// warns, never alarms.
	function healthColor(pct: int): color {
		if (pct < 60)
			return Theme.peach;
		if (pct < 80)
			return Theme.yellow;
		return Theme.fg;
	}

	// One pack: what it is holding now, and how much of its original capacity
	// that is out of.
	component Pack: ColumnLayout {
		id: pack

		required property var modelData

		readonly property int percent: Math.round((modelData.percentage ?? 0) * 100)
		readonly property bool charging: modelData.state === UPowerDeviceState.Charging || modelData.state === UPowerDeviceState.FullyCharged
		readonly property int health: Math.round(modelData.healthPercentage ?? 0)
		readonly property color accent: root.chargeColor(percent, charging)

		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			BarText {
				text: BatteryState.label(pack.modelData)
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			// The pack's own state, which need not match the machine's: on the
			// cable this laptop charges BAT1 while BAT0 sits full.
			//
			// Lowercased: UPower title-cases it ("Fully Charged"), which reads
			// as a second heading sitting next to the pack's name. Everything
			// else the panel says in this register is lowercase.
			BarText {
				Layout.fillWidth: true

				text: UPowerDeviceState.toString(pack.modelData.state).toLowerCase()
				color: Theme.dim
				elide: Text.ElideRight
			}

			BarText {
				text: `${pack.percent}%`
				color: pack.accent
				font.pixelSize: 15
				font.weight: Font.DemiBold
			}
		}

		Rectangle {
			id: track

			Layout.fillWidth: true
			implicitHeight: 6

			radius: height / 2
			color: Theme.track

			Rectangle {
				width: Math.min(1, pack.percent / 100) * track.width
				height: track.height
				radius: track.radius
				color: pack.accent

				Behavior on width {
					NumberAnimation {
						duration: 250
						easing.type: Easing.OutCubic
					}
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			// The wear. UPower computes it as energy-full over energy-full-design,
			// so a pack reporting no design capacity has nothing to say here
			// rather than saying 0%.
			BarText {
				Layout.fillWidth: true

				text: pack.modelData.healthSupported ? `health ${pack.health}%` : ""
				color: root.healthColor(pack.health)
				elide: Text.ElideRight
			}

			// What it is drawing or taking right now. Per pack, because that is
			// the only way to see which of the two the charger is actually
			// working on.
			BarText {
				text: {
					const rate = pack.modelData.changeRate ?? 0;
					return rate > 0 ? `${rate.toFixed(1)} W` : "";
				}
				color: Theme.dim
			}
		}
	}

	// One profile, as a pill. The whole pill is the switch.
	component Profile: Rectangle {
		id: profile

		property int value: 0
		property string icon: ""
		property string label: ""

		readonly property bool isCurrent: BatteryState.profile === value

		Layout.fillWidth: true
		implicitHeight: 30

		radius: 6
		// Every pill carries a surface, not just the chosen one: three buttons
		// where two are invisible until pointed at does not read as a choice
		// between three things. The selected one is the card's own row colour
		// with a blue edge; the rest sit a shade under it, and hovering lifts
		// one to the selected fill the way the list panels light a row.
		color: isCurrent || hover.hovered ? Theme.tooltipBorder : Qt.darker(Theme.tooltipBorder, 1.25)
		border.width: 1
		border.color: isCurrent ? Theme.blue : "transparent"

		HoverHandler {
			id: hover
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: BatteryState.setProfile(profile.value)
		}

		RowLayout {
			anchors.centerIn: parent
			spacing: 6

			BarText {
				text: profile.icon
				color: profile.isCurrent ? Theme.blue : Theme.fg
				font.pixelSize: Theme.fontIcon
			}

			BarText {
				text: profile.label
				color: profile.isCurrent ? Theme.blue : Theme.fg
				font.weight: profile.isCurrent ? Font.DemiBold : Font.Normal
			}
		}
	}
}
