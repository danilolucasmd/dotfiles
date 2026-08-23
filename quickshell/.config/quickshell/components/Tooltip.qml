import QtQuick
import Quickshell
import qs

// waybar drew tooltips for us; Quickshell has no built-in, so this is the one
// shared implementation every module hangs off its BarItem.
PopupWindow {
	id: root

	required property Item owner
	property string text: ""
	property bool shown: false

	// Long tooltips (the notification history, a big update list) would
	// otherwise grow a popup wider than the screen, so the text wraps instead.
	readonly property int maxWidth: 520

	// Anchor to the module's own box and hang the popup off its bottom edge;
	// with no left/right edge in the flags the compositor centres it for us.
	anchor.item: owner
	anchor.rect.width: owner ? owner.width : 0
	// The extra 4px is the gap between the bar and the tooltip.
	anchor.rect.height: owner ? owner.height + 4 : 0
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	// Modules at either end of the bar would otherwise hang off the screen.
	anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.ResizeY

	visible: shown && text !== ""
	color: "transparent"

	implicitWidth: label.width + 20
	implicitHeight: label.height + 14

	Rectangle {
		anchors.fill: parent
		radius: 8
		color: Theme.tooltipBg
		border.width: 1
		border.color: Theme.tooltipBorder

		Text {
			id: label

			anchors.centerIn: parent
			width: Math.min(implicitWidth, root.maxWidth)
			text: root.text
			color: Theme.fg
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontText
			textFormat: Text.PlainText
			wrapMode: Text.Wrap
			lineHeight: 1.25
		}
	}
}
