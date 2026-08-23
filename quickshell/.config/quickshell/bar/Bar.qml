import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
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
			anchors.fill: parent

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
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Weather {}
				Clock {}
			}

			RowLayout {
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Media {}
				Recording {}
				KeyboardLayout {}
				Mic {}
				Volume {}
				Bluetooth {}
				Network {}
				Battery {}
				Tray {}
				AgentUsage {}
				Updates {}
				Notifications {}
			}
		}
	}
}
