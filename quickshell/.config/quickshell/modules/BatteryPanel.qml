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
// its own meter and its own readings underneath.
//
// Three questions, in the order they get asked: what is left (the meter), what
// state the pack is in (the figures under it -- capacity against design, cycle
// count, cell voltage), and what to do about it (the charge limit, and the
// power profile). The middle one is the reason this panel exists at all:
// "charge" is a number the bar already shows, and "this pack has done 1738
// cycles and holds 17.5 of its 24 Wh" is the one that explains it.
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
		switch (key) {
		case Qt.Key_H:
		case Qt.Key_Left:
			if (!BatteryState.profilesAvailable)
				return false;
			BatteryState.setProfile(Math.max(PowerProfile.PowerSaver, BatteryState.profile - 1));
			return true;
		case Qt.Key_L:
		case Qt.Key_Right:
			if (!BatteryState.profilesAvailable)
				return false;
			const top = BatteryState.hasPerformance ? PowerProfile.Performance : PowerProfile.Balanced;
			BatteryState.setProfile(Math.min(top, BatteryState.profile + 1));
			return true;
		// The limit moves on j/k the way the profile moves on h/l: the two
		// controls sit one above the other and are stepped along the axis they
		// are drawn on.
		case Qt.Key_K:
		case Qt.Key_Up:
			if (!BatteryState.limitSupported)
				return false;
			BatteryState.stepLimit(5);
			return true;
		case Qt.Key_J:
		case Qt.Key_Down:
			if (!BatteryState.limitSupported)
				return false;
			BatteryState.stepLimit(-5);
			return true;
		}
		return false;
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
		spacing: 14

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
	// Charge limit
	// ------------------------------------------------------------------

	// The one setting on this panel that is about the pack rather than about
	// the machine's speed, and the only thing here that materially changes how
	// fast the packs above wear out.
	ColumnLayout {
		Layout.fillWidth: true
		visible: root.batteries.length > 0
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				text: "Charge limit"
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			Item {
				Layout.fillWidth: true
			}

			BarText {
				visible: BatteryState.limitSupported

				text: `${BatteryState.limit}%`
				color: BatteryState.limit >= 100 ? Theme.dim : Theme.blue
				font.pixelSize: 15
				font.weight: Font.DemiBold
			}
		}

		Slider {
			visible: BatteryState.limitSupported

			// Below the floor the setting stops being about longevity and
			// starts being a laptop that dies when the cable moves.
			from: BatteryState.limitFloor
			to: 100
			step: 5
			value: BatteryState.limit

			onMoved: percent => BatteryState.setLimit(percent)
		}

		RowLayout {
			Layout.fillWidth: true
			visible: BatteryState.limitSupported
			spacing: 8

			BarText {
				Layout.fillWidth: true

				// What the number means, in the terms the decision is actually
				// made in: a pack that lives on a desk charger ages on the top
				// fifth of its charge, and this is what stops it going there.
				text: BatteryState.limit >= 100 ? "Charges to full — the hardest place for a pack to sit" : `Stops charging at ${BatteryState.limit}% — kinder to a pack that lives on the cable`
				color: Theme.dim
				wrapMode: Text.Wrap
			}
		}

		// The threshold is root-owned out of the box, so without the udev rule
		// every change is a password prompt. Worth saying before the prompt
		// appears, rather than leaving it to look like a bug.
		BarText {
			Layout.fillWidth: true
			visible: BatteryState.limitSupported && !BatteryState.limitDirect

			text: "Root-owned — each change asks polkit. Install the udev rule from install.sh to set it directly."
			color: Theme.dim
			wrapMode: Text.Wrap
		}

		BarText {
			Layout.fillWidth: true
			visible: BatteryState.limitError !== ""

			text: `Not applied — ${BatteryState.limitError}`
			color: Theme.yellow
			wrapMode: Text.Wrap
		}

		BarText {
			Layout.fillWidth: true
			visible: !BatteryState.limitSupported

			text: "Not available — this firmware exposes no charge threshold."
			color: Theme.dim
			wrapMode: Text.Wrap
		}
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

			text: {
				const keys = [];
				if (BatteryState.profilesAvailable)
					keys.push("h/l profile");
				if (BatteryState.limitSupported)
					keys.push("j/k limit");
				return keys.join(" · ");
			}
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

	// Cycles are wear that has already happened, so the colouring is the same
	// kind of statement health makes: a pack past its rated life is worth
	// knowing about, not worth alarming over. 300 is the design life of the
	// cells in a machine of this age; 1000 is well past it.
	function cycleColor(count: int): color {
		if (count >= 1000)
			return Theme.peach;
		if (count >= 500)
			return Theme.yellow;
		return Theme.fg;
	}

	// One pack: the meter, and under it the readings that explain what the
	// meter is a percentage *of*.
	component Pack: ColumnLayout {
		id: pack

		required property var modelData

		// The sysfs half of the picture. Null until the first read lands, a
		// beat after the shell starts, which the cells below print as blanks
		// rather than as zeroes.
		readonly property var info: BatteryState.infoFor(modelData)

		readonly property int percent: Math.round((modelData.percentage ?? 0) * 100)
		readonly property bool charging: modelData.state === UPowerDeviceState.Charging || modelData.state === UPowerDeviceState.FullyCharged
		readonly property int health: Math.round(modelData.healthPercentage ?? 0)
		readonly property color accent: root.chargeColor(percent, charging)

		// UPower's rate is the same figure as sysfs power_now and arrives on
		// its own change signal, so it is the livelier of the two; the sysfs
		// one is the fallback for the moment before UPower has a reading.
		readonly property real rate: modelData.changeRate || pack.info?.power || 0

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

			// Which pack this physically is. Two batteries of the same size
			// from two vendors wear at different rates -- the one at 65% here
			// is the SMP, the one at 92% the LGC -- and this is the line that
			// says which is which when one of them is due for replacing.
			BarText {
				Layout.fillWidth: true

				text: {
					const i = pack.info;
					if (!i)
						return "";
					return [i.manufacturer, i.model].filter(part => part).join(" ");
				}
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

			// Where charging stops, drawn on the track it stops on. A limit
			// the pack is already sitting at explains a machine that reads 80%
			// on the cable and never moves -- which otherwise looks like a
			// charger that has given up.
			Rectangle {
				visible: BatteryState.limitSupported && BatteryState.limit < 100
				x: Math.min(1, BatteryState.limit / 100) * (track.width - width)
				width: 2
				height: track.height

				color: Theme.blue
			}
		}

		// The pack's own state, which need not match the machine's: on the
		// cable this laptop charges BAT1 while BAT0 sits full.
		//
		// Lowercased: UPower title-cases it ("Fully Charged"), which reads as a
		// heading rather than as the aside it is. Everything else the panel
		// says in this register is lowercase.
		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				text: UPowerDeviceState.toString(pack.modelData.state).toLowerCase()
				color: Theme.dim
				elide: Text.ElideRight
			}

			// The pack's own estimate, where UPower has gathered enough
			// history for one. Per pack, because on this machine they empty in
			// series rather than together.
			BarText {
				text: {
					const seconds = pack.charging ? (pack.modelData.timeToFull ?? 0) : (pack.modelData.timeToEmpty ?? 0);
					const left = BatteryState.duration(seconds);
					if (!left)
						return "";
					return pack.charging ? `${left} to full` : `${left} left`;
				}
				color: Theme.dim
			}
		}

		// Six readings, three to a row: what it holds now, what it can hold,
		// and what it has been through. Two lines each -- the label small and
		// dim above the figure -- because the alternative at this width is six
		// "label value" pairs that wrap, and a wrapped table is not a table.
		GridLayout {
			Layout.fillWidth: true
			Layout.topMargin: 2
			visible: pack.info !== null

			columns: 3
			columnSpacing: 8
			rowSpacing: 6

			// Energy rather than percent: 8 Wh is a figure you can compare
			// against the 17.5 the pack can hold and the 24 it was born with.
			Stat {
				label: "charge"
				value: BatteryState.figure(pack.info?.energyNow, " Wh", 1)
			}

			// UPower's own health figure, which is energy-full over
			// energy-full-design -- the same two numbers the capacity cell
			// prints, as the ratio they make.
			Stat {
				label: "health"
				value: pack.modelData.healthSupported ? `${pack.health}%` : ""
				accent: root.healthColor(pack.health)
			}

			// The wear that caused the health figure. A pack at 73% with 1738
			// cycles is a pack that has been used; the same 73% at 89 cycles
			// is a pack that has gone wrong.
			Stat {
				label: "cycles"
				value: pack.info?.cycleCount !== null && pack.info?.cycleCount !== undefined ? String(pack.info.cycleCount) : ""
				accent: root.cycleColor(pack.info?.cycleCount ?? 0)
			}

			// What it can hold now against what it was built to hold. The
			// design figure is the pack's advertised size, so this is both the
			// "how big is this battery" answer and the wear, in one cell.
			Stat {
				label: "capacity"
				value: {
					const full = BatteryState.figure(pack.info?.energyFull, "", 1);
					const design = BatteryState.figure(pack.info?.energyDesign, " Wh", 1);
					return full && design ? `${full}/${design}` : full || design;
				}
			}

			// Terminal voltage. It sags as the pack drains and as it ages, and
			// a cell that will not come up near its design voltage on the
			// cable is the one about to be declared dead by the firmware.
			Stat {
				label: "voltage"
				value: BatteryState.figure(pack.info?.voltage, " V", 2)
			}

			// What this pack in particular is taking or giving. Per pack,
			// because that is the only way to see which of the two the charger
			// is actually working on.
			Stat {
				label: pack.charging ? "charging at" : "draw"
				value: pack.rate > 0 ? `${pack.rate.toFixed(1)} W` : "idle"
				accent: pack.rate > 0 ? Theme.fg : Theme.dim
			}
		}
	}

	// One cell of a pack's readings: what it is, then what it says.
	component Stat: ColumnLayout {
		id: stat

		property string label: ""
		property string value: ""
		property color accent: Theme.fg

		Layout.fillWidth: true
		// Equal thirds. Without it the columns are sized by their contents and
		// the three rows of cells do not line up with each other.
		Layout.preferredWidth: 0
		spacing: 0

		BarText {
			Layout.fillWidth: true

			text: stat.label
			color: Theme.dim
			font.pixelSize: 11
			elide: Text.ElideRight
		}

		BarText {
			Layout.fillWidth: true

			// A blank where the firmware reports nothing, rather than a zero:
			// "0 cycles" on a pack that keeps no count is a claim, and a wrong
			// one.
			text: stat.value || "—"
			color: stat.value ? stat.accent : Theme.disabled
			elide: Text.ElideRight
		}
	}

	// The charge-limit slider. Shaped like the display panel's brightness one
	// -- the grab area is the whole strip, the knob's travel is the strip less
	// its own width -- but stepped and floored, because this is a setting with
	// a range that means something rather than a continuous dial.
	component Slider: Item {
		id: slider

		property int from: 0
		property int to: 100
		property int step: 5
		property int value: 0

		signal moved(int percent)

		Layout.fillWidth: true
		// Taller than the groove it draws: the grab area is the whole strip,
		// so the knob does not have to be hit to be moved.
		implicitHeight: 20

		readonly property real fraction: {
			const span = to - from;
			return span > 0 ? Math.max(0, Math.min(1, (value - from) / span)) : 0;
		}

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

			x: (slider.width - width) * slider.fraction
			anchors.verticalCenter: parent.verticalCenter

			width: 14
			height: 14
			radius: height / 2
			color: Theme.fg

			// Smooths the keyboard's steps and the snap onto the step grid; a
			// drag is already following the pointer, so animating it would
			// only lag behind it.
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
			onWheel: event => slider.moved(slider.value + (event.angleDelta.y > 0 ? slider.step : -slider.step))
		}

		// Where the pointer is, on the scale the knob is drawn across, snapped
		// to the step. The snapping is left to the receiver as well, so a value
		// arriving from a key or the wheel lands on the same grid.
		function pick(x: real): void {
			const travel = slider.width - handle.width;
			if (travel <= 0)
				return;
			const at = Math.max(0, Math.min(1, (x - handle.width / 2) / travel));
			slider.moved(Math.round(slider.from + at * (slider.to - slider.from)));
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
