import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// The popups mako used to draw, in the bar's own colours rather than the Nord
// palette its config hardcoded. Same corner, same stacking order (newest on
// top), same per-urgency border — this is the one piece of the migration that
// had to look like what it replaced.
//
// Not a Panel: a Panel takes the keyboard and dismisses on a click anywhere
// outside itself, which are exactly the two things a notification must not do.
PanelWindow {
	id: root

	visible: NotificationsState.popups.values.length > 0
	screen: Hyprland.focusedMonitor?.screen ?? null

	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell:notifications"
	// A notification arriving mid-sentence must not eat the rest of it.
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	anchors.top: true
	anchors.right: true
	margins.top: 8
	margins.right: 8
	exclusiveZone: 0
	color: "transparent"

	// The panels' width, so a notification and the panel it lands in are the
	// same object seen twice.
	implicitWidth: 360
	// Zero-height surfaces are not a thing the compositor will map.
	implicitHeight: Math.max(1, column.height)

	// A ListView rather than a Column, for one property Column does not have:
	// the model appends, and mako sorted `-time`, so the stack has to fill
	// upwards to put the newest at the top. Reversing a copy of the model
	// instead would rebuild every card each time one arrived — and restart
	// every one of their timeouts with it.
	ListView {
		id: column

		width: parent.width
		height: contentHeight
		spacing: 8
		interactive: false
		verticalLayoutDirection: ListView.BottomToTop

		model: NotificationsState.popups

		delegate: Card {}
	}

	// One notification. It owns its own lifetime: the list is what holds it on
	// screen, so it has to finish fading before asking to be taken out of it.
	component Card: Rectangle {
		id: card

		required property var modelData

		readonly property int timeout: NotificationsState.popupTimeout(modelData)
		readonly property bool sticky: timeout === 0
		// Everything but the default action, which is not a button — it is what
		// clicking the notification itself means.
		readonly property var actions: (modelData.actions ?? []).filter(a => a.identifier !== "default")

		// Flipped on after the first frame, so the card fades in instead of
		// appearing.
		property bool shown: false
		property bool closing: false
		property bool expired: false

		function close(byTimeout: bool): void {
			expired = byTimeout;
			closing = true;
			reap.restart();
		}

		width: ListView.view ? ListView.view.width : 0
		// Full height from the first frame, and it keeps it right through the
		// fade out. Animating the height as well -- growing on arrival,
		// collapsing on the way out -- is what made this look broken: the card
		// is clipped, so a collapsing one eats its own text from the bottom up
		// while it is still visible, and every height the card passes through
		// is a layer-shell resize that Hyprland animates by scaling the buffer
		// into the box, leaving a smear of the old card over the new one.
		// Opacity is the one thing that can change here without the surface
		// changing size.
		height: content.implicitHeight + 20
		opacity: shown && !closing ? 1 : 0
		clip: true

		radius: 12
		color: Theme.tooltipBg
		border.width: 2
		border.color: NotificationsState.urgencyColor(modelData.urgency)

		Component.onCompleted: shown = true

		Behavior on opacity {
			NumberAnimation {
				duration: 180
				easing.type: Easing.OutCubic
			}
		}

		Timer {
			// mako never paused its timeouts. Resetting the clock when the
			// pointer leaves is the friendlier reading of "I am looking at it".
			running: !card.sticky && !card.closing && !hover.hovered
			interval: card.timeout
			onTriggered: card.close(true)
		}

		Timer {
			id: reap

			// Taking the card out of the list destroys it, so that has to
			// happen after the fade rather than instead of it -- the 180 above
			// plus a frame to land on. The card is at full height when it goes,
			// so the stack under it does jump up rather than sliding; it jumps
			// into space nothing is drawn in any more, which is the trade for
			// never resizing the surface under a visible card.
			interval: 220
			onTriggered: NotificationsState.closePopup(card.modelData, card.expired)
		}

		HoverHandler {
			id: hover
		}

		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: Qt.PointingHandCursor

			// Left goes to the sender, right just clears it away — mako's two
			// buttons, unchanged. Either way the notification stays in the
			// history: the popup going is not the same as being done with it.
			onClicked: event => {
				if (event.button === Qt.RightButton) {
					card.close(false);
					return;
				}
				NotificationsState.activate(card.modelData);
				card.close(false);
			}
		}

		Column {
			id: content

			x: 12
			y: 10
			width: parent.width - 24
			spacing: 4

			BarText {
				width: parent.width

				text: NotificationsState.displayName(card.modelData.appName)
				color: NotificationsState.urgencyColor(card.modelData.urgency)
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			BarText {
				width: parent.width
				visible: text !== ""

				text: card.modelData.summary
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			BarText {
				width: parent.width
				visible: text !== ""

				text: card.modelData.body
				// Apps are told markup is supported, so honour it. Long bodies
				// are cut here rather than allowed to push the stack off the
				// screen — the panel has the whole thing.
				textFormat: Text.StyledText
				wrapMode: Text.Wrap
				maximumLineCount: 4
				elide: Text.ElideRight
			}

			Row {
				spacing: 8
				topPadding: 4
				visible: card.actions.length > 0

				Repeater {
					model: card.actions

					delegate: ActionButton {
						onTriggered: card.close(false)
					}
				}
			}
		}
	}

	// An action the app offered. mako could only ever fire the default one
	// through a shell hook; these are the named buttons that came with it.
	component ActionButton: Rectangle {
		id: button

		required property var modelData

		signal triggered

		implicitWidth: label.implicitWidth + 20
		implicitHeight: label.implicitHeight + 8

		radius: 6
		color: area.containsMouse ? Theme.tooltipBorder : "transparent"
		border.width: 1
		border.color: Theme.tooltipBorder

		BarText {
			id: label

			anchors.centerIn: parent

			text: button.modelData.text
			color: area.containsMouse ? Theme.blue : Theme.fg
		}

		MouseArea {
			id: area

			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor

			onClicked: {
				button.modelData.invoke();
				button.triggered();
			}
		}
	}
}
