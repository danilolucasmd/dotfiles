import QtQuick
import qs
import qs.components

// Charge on the bar, everything else a click away in BatteryPanel. The reading
// lives in BatteryState, which the panel and the super+B binding share.
//
// It sat behind the extras chevron while it was a glyph with a hover tooltip.
// A laptop's charge is not an occasional question, so it has a permanent seat
// now, and it is shaped like the volume module beside it: glyph at icon size,
// number at text size, rather than the whole string set at 16px the way the
// tucked-away version was.
BarItem {
	id: root

	readonly property int percent: BatteryState.percent
	readonly property bool charging: BatteryState.charging

	// waybar never declared `states`, so the .warning / .critical rules in its
	// style.css could not fire. The thresholds they clearly intended are these.
	readonly property bool low: !charging && percent <= 30
	readonly property bool critical: !charging && percent <= 15

	readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

	active: BatteryState.present
	rightMargin: Theme.gap
	highlighted: BatteryState.panelOpen

	// No tooltip. The old one was the whole UI here -- a percentage and a time
	// remaining, on a hover you had to hold still for -- and the panel says all
	// of that properly, per pack, with the health and the profile besides.
	onClicked: BatteryState.toggle()

	Row {
		spacing: 8

		BarText {
			anchors.verticalCenter: parent.verticalCenter

			text: {
				if (root.charging)
					return "󰂄";
				const i = Math.min(9, Math.max(0, Math.floor(root.percent / 10)));
				return root.icons[i];
			}
			// `fg` while charging rather than green: the glyph has already
			// changed shape to say the cable is in, and the bar reserves colour
			// for the thing you need to act on.
			color: root.critical ? Theme.red : root.low ? Theme.yellow : Theme.fg
			font.pixelSize: Theme.fontIcon
		}

		BarText {
			anchors.verticalCenter: parent.verticalCenter

			// No reserved width. There was one, against the label twitching as
			// the number crosses 9% / 99%, but a reserve is padding: it sits
			// between this module's last glyph and the next one, on top of the
			// margin that is meant to be the whole gap, and it is only ever the
			// right size at 100%. What it bought, the cluster being anchored
			// right, was the modules to the *left* of this one holding still
			// across a 99 -> 100 step -- once a charge. A gap that is wrong the
			// rest of the time is the worse trade.
			text: `${root.percent}%`
			color: root.critical ? Theme.red : root.low ? Theme.yellow : Theme.fg
		}
	}
}
