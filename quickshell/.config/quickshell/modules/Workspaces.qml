import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs

// The persistent 1..5 workspace buttons.
//
// waybar needed a Python daemon on Hyprland's event socket, a per-button shell
// script and a SIGRTMIN signal to keep these five boxes correct. Quickshell
// tracks Hyprland's workspace list itself, so focus and fullscreen are plain
// properties and the whole thing is a binding.
RowLayout {
	// waybar gave each box `margin: 5px 1px`, i.e. 2px between adjacent boxes.
	spacing: 2

	Repeater {
		model: 5

		delegate: Item {
			id: button

			required property int index
			readonly property int wsId: index + 1

			readonly property HyprlandWorkspace ws: {
				const all = Hyprland.workspaces.values;
				for (let i = 0; i < all.length; i++)
					if (all[i].id === button.wsId)
						return all[i];
				return null;
			}

			readonly property bool active: ws?.focused ?? false
			readonly property bool fullscreen: ws?.hasFullscreen ?? false

			// waybar box geometry: min-width 15 + 2px padding + 1px border on
			// each side. Slightly taller than waybar's 20px, still leaving 4px
			// of margin above and below on the 30px bar.
			implicitWidth: 21
			implicitHeight: 23
			Layout.alignment: Qt.AlignVCenter

			// The fill was clipped to the content box, so it stops 3px short of
			// the outer edge (1px border + 2px padding). That gap is what keeps
			// the dashed fullscreen border visible on the active button too.
			Rectangle {
				anchors.fill: parent
				anchors.margins: 3
				radius: 3
				color: button.active ? Theme.fg : "transparent"
			}

			// A workspace holding a fullscreen window: dashed bright border,
			// focused or not. Rectangle can't dash, so this is drawn by hand.
			Canvas {
				anchors.fill: parent
				visible: button.fullscreen
				onVisibleChanged: requestPaint()

				onPaint: {
					const ctx = getContext("2d");
					ctx.reset();
					ctx.strokeStyle = Theme.fg;
					ctx.lineWidth = 1;
					ctx.setLineDash([2, 2]);
					ctx.beginPath();
					ctx.roundedRect(0.5, 0.5, width - 1, height - 1, 6, 6);
					ctx.stroke();
				}
			}

			Text {
				anchors.centerIn: parent
				text: button.wsId
				color: button.active ? Theme.bg : Theme.fg
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontText
				font.weight: Font.DemiBold
				renderType: Text.NativeRendering
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				onClicked: Hyprland.dispatch(`workspace ${button.wsId}`)
			}
		}
	}
}
