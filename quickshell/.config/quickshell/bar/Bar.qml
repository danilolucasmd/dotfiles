import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.modules

// One bar per screen. waybar's three groups become three anchored rows: the
// centre group is centred on the bar, not on whatever is left over between the
// other two, which is what waybar's modules-center did.
Variants {
	model: Quickshell.screens

	PanelWindow {
		required property var modelData

		screen: modelData

		anchors {
			top: true
			left: true
			right: true
		}

		implicitHeight: Theme.barHeight
		color: Theme.bg

		Item {
			id: content

			anchors.fill: parent

			// Moving the pointer off the bar tidies the extras away again.
			// A HoverHandler rather than a MouseArea: it reports the bar as
			// hovered even while the pointer sits on a module's own MouseArea,
			// and it never takes a click off one.
			HoverHandler {
				id: barHover
			}

			readonly property bool keepExtras: barHover.hovered || BarState.openMenus > 0

			onKeepExtrasChanged: {
				if (keepExtras)
					collapse.stop();
				else
					collapse.restart();
			}

			// Leaving the bar folds the extras away, but not instantly: a hand
			// on its way to a tray icon dips off the bar all the time. Coming
			// back restarts the countdown from scratch.
			Timer {
				id: collapse

				interval: 1000
				onTriggered: BarState.extrasVisible = false
			}

			RowLayout {
				anchors.left: parent.left
				// waybar reproduced the old #workspaces group padding by
				// putting margin-left: 10px on the first button.
				anchors.leftMargin: 10
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Workspaces {}
			}

			RowLayout {
				id: centre

				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Weather {}
				Clock {}
			}

			// The recording dot sits beside the clock but not *in* the centre
			// group: anchored to its right edge rather than laid out in the
			// row, so it comes and goes without the date and time sliding over
			// to make room for it.
			Recording {
				anchors.left: centre.right
				anchors.verticalCenter: parent.verticalCenter
			}

			// The night light glyph gets the other side of the centre group,
			// anchored for the same reason: both of these are indicators that
			// appear and vanish mid-session, and the clock is the one thing on
			// the bar whose position the eye actually relies on.
			NightLight {
				anchors.right: centre.left
				anchors.verticalCenter: parent.verticalCenter
			}

			RowLayout {
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				ExtrasToggle {}

				// Folded away behind the chevron: the modules worth having but
				// not worth a permanent seat. Only the tray now, which is the
				// one that grows with whatever happens to be running — network
				// moved out to a seat of its own when it got a panel.
				//
				// The group is a window onto a right-aligned row, so animating
				// the window's width slides the modules out from behind the
				// always-visible ones instead of popping them into place. The
				// cluster is anchored right, so the chevron glides left along
				// with them and nothing to the right of them moves at all.
				Item {
					id: extras

					property real openWidth: BarState.extrasVisible ? row.implicitWidth : 0

					Behavior on openWidth {
						NumberAnimation {
							duration: 200
							easing.type: Easing.OutCubic
						}
					}

					Layout.preferredWidth: openWidth
					Layout.preferredHeight: Theme.barHeight
					clip: true

					RowLayout {
						id: row

						anchors.right: parent.right
						width: implicitWidth
						height: parent.height
						spacing: 0

						Tray {}

						Divider {
							Layout.rightMargin: Theme.gap
						}
					}
				}

				// Always on screen, in the order they're glanced at.
				Media {}
				KeyboardLayout {}
				Volume {}
				Network {}
				Bluetooth {}
				Battery {}
				// The only module here that is about the screen it is drawn on
				// rather than about the machine, so it is told which one that
				// is: its wheel dims that monitor, and clicking it opens the
				// panel already pointed at it.
				Display {
					screenName: modelData.name
				}
				Performance {}
				AgentUsage {}
				Updates {}
				Notifications {}
			}
		}
	}
}
