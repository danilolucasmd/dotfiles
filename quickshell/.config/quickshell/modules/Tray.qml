import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.components

// StatusNotifierItem tray. Left click activates, right click opens the item's
// menu, middle click runs its secondary action.
RowLayout {
	// waybar's tray had "spacing": 16, and the group carried the same 16px
	// right margin as its neighbours.
	spacing: Theme.gap
	Layout.rightMargin: Theme.gap

	Repeater {
		model: SystemTray.items

		delegate: BarItem {
			id: entry

			required property SystemTrayItem modelData

			tooltip: modelData.tooltipTitle || modelData.title || modelData.id

			onClicked: event => {
				if (event.button === Qt.MiddleButton)
					modelData.secondaryActivate();
				else
					modelData.activate();
			}

			onRightClicked: {
				if (modelData.hasMenu)
					menu.open();
			}

			IconImage {
				implicitSize: 18
				source: entry.modelData.icon
			}

			QsMenuAnchor {
				id: menu

				menu: entry.modelData.menu
				anchor.item: entry
				anchor.rect.y: entry.height

				// The menu opens below the bar, so the pointer has to leave the
				// bar to reach it. Tell the bar to hold the extras open while
				// it is up, or the icon that opened it folds away mid-reach.
				onVisibleChanged: BarState.openMenus += visible ? 1 : -1
				Component.onDestruction: {
					if (visible)
						BarState.openMenus -= 1;
				}
			}
		}
	}
}
