import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// The Claude Code usage panel, opened by clicking the bar module or by super+A.
//
// It replaced the module's hover tooltip. A tooltip could only ever be two
// lines of prose you had to hold the pointer still to read; the number that
// matters here is really a comparison — how much of the window you have burned
// against how much of it has elapsed — and that wants a meter with the pace
// marked on it, not a sentence.
//
// One window, on whichever monitor has focus, rather than one per screen: it is
// summoned by a keybind as often as by a click, and a keybind has no screen of
// its own to open on.
PanelWindow {
	id: root

	// Breathing room inside the card, on all four sides.
	readonly property int pad: 14

	visible: AgentUsageState.panelOpen
	screen: Hyprland.focusedMonitor?.screen ?? null

	// Overlay, so it is not buried by a fullscreen window. exclusiveZone 0
	// keeps it from reserving space of its own while still being placed under
	// the bar's own zone rather than behind it.
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell:agent-usage"
	// OnDemand rather than Exclusive: the focus grab below hands it the
	// keyboard while it is up, and taking the keyboard outright would mean a
	// panel left open silently swallowing everything typed at the terminal.
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

	anchors.top: true
	anchors.right: true
	margins.top: 8
	margins.right: 8
	exclusiveZone: 0
	color: "transparent"

	implicitWidth: card.implicitWidth
	implicitHeight: card.implicitHeight

	// Clicking anywhere outside dismisses, and the keyboard comes here while it
	// is up so Escape and R land. Without the grab the panel would be a window
	// you had to remember to close.
	HyprlandFocusGrab {
		windows: [root]
		active: root.visible
		onCleared: AgentUsageState.close()
	}

	Rectangle {
		id: card

		implicitWidth: 360
		implicitHeight: layout.implicitHeight + root.pad * 2

		radius: 10
		color: Theme.tooltipBg
		border.width: 1
		border.color: Theme.tooltipBorder

		focus: true
		Keys.onEscapePressed: AgentUsageState.close()
		Keys.onPressed: event => {
			if (event.key === Qt.Key_R)
				AgentUsageState.refresh();
		}

		ColumnLayout {
			id: layout

			anchors.fill: parent
			anchors.margins: root.pad
			spacing: 14

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Label {
					text: "Claude Code"
					font.pixelSize: 13
					font.weight: Font.DemiBold
				}

				Item {
					Layout.fillWidth: true
				}

				Label {
					text: AgentUsageState.data.source ?? ""
				}
			}

			Repeater {
				model: AgentUsageState.windows

				delegate: Meter {}
			}

			Label {
				Layout.fillWidth: true
				visible: !AgentUsageState.available

				text: "No usage reading yet. Start a Claude Code session, or sign in again."
				wrapMode: Text.Wrap
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Label {
					text: {
						const d = AgentUsageState.data;
						if (!AgentUsageState.available)
							return "";
						const prefix = d.stale ? "stale, last read " : "updated ";
						return prefix + root.ago(d.ageSeconds ?? 0);
					}
					color: AgentUsageState.data.stale ? Theme.yellow : Theme.fg
				}

				Item {
					Layout.fillWidth: true
				}

				Label {
					text: "r refresh · esc close"
				}
			}
		}
	}

	// "42s" / "7m" / "3h" — deliberately coarse, because the number this dates
	// only ever moves in whole percent.
	function ago(seconds: int): string {
		if (seconds < 60)
			return `${seconds}s ago`;
		if (seconds < 3600)
			return `${Math.round(seconds / 60)}m ago`;
		return `${Math.round(seconds / 3600)}h ago`;
	}

	// The same thresholds the bar glyph uses, applied per window rather than to
	// the worse of the two.
	function meterColor(w: var): color {
		if (AgentUsageState.data.stale)
			return Theme.dim;
		if (w.pct >= 90)
			return Theme.red;
		if (w.pct >= 70)
			return Theme.yellow;
		if (w.pace >= 0 && w.pct > w.pace)
			return Theme.peach;
		return Theme.green;
	}

	component Label: Text {
		color: Theme.fg
		font.family: Theme.fontFamily
		font.pixelSize: Theme.fontText
		textFormat: Text.PlainText
		renderType: Text.NativeRendering
	}

	// One rate-limit window: what has been spent, against how much of the
	// window has gone by.
	component Meter: ColumnLayout {
		id: meter

		required property var modelData

		readonly property color accent: root.meterColor(modelData)
		// Straight-line extrapolation of the current burn to the reset. Only
		// worth printing once the window has run long enough for the rate to
		// mean anything — in the first minutes after a reset a single prompt
		// projects to several hundred percent.
		readonly property int projected: modelData.pace >= 10 ? Math.round(modelData.pct / modelData.pace * 100) : -1

		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Label {
				text: meter.modelData.label
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			Label {
				text: meter.modelData.span
			}

			Item {
				Layout.fillWidth: true
			}

			Label {
				text: `${meter.modelData.pct}%`
				color: meter.accent
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
				width: Math.min(1, meter.modelData.pct / 100) * track.width
				height: track.height
				radius: track.radius
				color: meter.accent

				Behavior on width {
					NumberAnimation {
						duration: 250
						easing.type: Easing.OutCubic
					}
				}
			}

			// Where the fill would be if the allowance were being spent evenly
			// across the window. Left of it is ahead of pace, right of it is
			// spare — which is the whole reason this panel exists. It stands
			// proud of the track rather than cutting through it, so a fill that
			// happens to end near the mark still reads as two separate things.
			Rectangle {
				visible: meter.modelData.pace >= 0
				x: Math.min(1, meter.modelData.pace / 100) * (track.width - width)
				y: -3
				width: 2
				height: track.height + 6
				radius: 1
				color: Theme.fg
				opacity: 0.6
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			Label {
				Layout.fillWidth: true

				text: {
					const w = meter.modelData;
					const parts = [];
					if (w.pace >= 0)
						parts.push(w.pct > w.pace ? "ahead of pace" : "on pace");
					if (meter.projected >= 0)
						parts.push(meter.projected > 200 ? "200%+ at reset" : `~${meter.projected}% at reset`);
					return parts.join(" · ");
				}
				// A projection past 100% is the one thing here worth raising a
				// voice about: it means this window runs out before it resets.
				color: meter.projected > 100 ? meter.accent : Theme.fg
				elide: Text.ElideRight
			}

			Label {
				text: meter.modelData.resetsIn
			}
		}
	}
}
