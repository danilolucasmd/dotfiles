import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// The volume readout that appears for a moment whenever the volume moves —
// the media keys, a scroll over the bar module, a click on it.
//
// Deliberately not a Panel: those are things you open and read at your own
// pace, with a focus grab and a keyboard. This is the opposite — it takes no
// focus, answers no keys, cannot be clicked, and takes itself away.
PanelWindow {
	id: root

	readonly property int cardWidth: 260
	readonly property int pad: 12

	// Snaps in and drifts out, which is the shape of the gesture: the reading
	// is wanted the instant the key is hit, and lingers only until the eye has
	// had it.
	property real fade: AudioState.osdShown ? 1 : 0

	Behavior on fade {
		NumberAnimation {
			duration: AudioState.osdShown ? 120 : 320
			easing.type: Easing.OutCubic
		}
	}

	// Mapped while there is anything to see, so the fade-out gets to finish
	// before the window goes.
	visible: fade > 0.01
	screen: Hyprland.focusedMonitor?.screen ?? null

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell:osd"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	// Under the bar on the right, so it comes out of the module it belongs to
	// rather than landing in the middle of whatever is being read.
	anchors.top: true
	anchors.right: true
	margins.top: 8
	margins.right: 8
	exclusiveZone: 0
	color: "transparent"

	// Click-through: a readout that swallowed clicks for a second and a half
	// after every volume key would be a trap.
	mask: Region {}

	implicitWidth: card.implicitWidth
	implicitHeight: card.implicitHeight

	Rectangle {
		id: card

		implicitWidth: root.cardWidth
		implicitHeight: layout.implicitHeight + root.pad * 2

		radius: 12
		color: Theme.tooltipBg
		border.width: 1
		border.color: Theme.tooltipBorder
		opacity: root.fade

		ColumnLayout {
			id: layout

			anchors.fill: parent
			anchors.margins: root.pad
			spacing: 8

			BarText {
				Layout.fillWidth: true

				text: AudioState.deviceName
				// The same colour as the glyph and the fill, so the card dims as
				// one thing when the sink is muted.
				color: AudioState.muted ? Theme.dim : Theme.fg
				horizontalAlignment: Text.AlignHCenter
				elide: Text.ElideRight
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 10

				BarText {
					text: AudioState.icon
					color: AudioState.muted ? Theme.dim : Theme.fg
					font.pixelSize: 18
				}

				Rectangle {
					id: track

					Layout.fillWidth: true
					implicitHeight: 6

					radius: height / 2
					color: Theme.track

					Rectangle {
						width: Math.min(1, AudioState.volume / 100) * track.width
						height: track.height
						radius: track.radius
						color: AudioState.muted ? Theme.dim : Theme.fg

						// Only the level animates; the panel appearing is the
						// fade's job, so the bar must not also grow from zero
						// every time the OSD comes up.
						Behavior on width {
							NumberAnimation {
								duration: 120
								easing.type: Easing.OutCubic
							}
						}
					}
				}

				BarText {
					// Fixed, so the track does not twitch as the number crosses
					// 9% and 99% — the same 30px the bar module reserves.
					Layout.preferredWidth: 30

					text: `${AudioState.volume}%`
					color: AudioState.muted ? Theme.dim : Theme.fg
					horizontalAlignment: Text.AlignRight
				}
			}
		}
	}
}
