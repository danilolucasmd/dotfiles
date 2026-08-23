import QtQuick
import Quickshell
import qs

// One module slot in the bar: sizes itself to its content, carries the
// left/right margins waybar expressed in CSS, hides itself when inactive
// (waybar hid a module whose text was empty), and owns the hover tooltip.
Item {
	id: root

	property string tooltip: ""
	property int leftMargin: 0
	property int rightMargin: 0
	// waybar hid any module that emitted empty text; `active: false` is that.
	property bool active: true

	default property alias content: holder.data

	signal clicked(var event)
	signal rightClicked(var event)
	signal wheelUp
	signal wheelDown

	visible: active
	implicitWidth: active ? holder.implicitWidth + leftMargin + rightMargin : 0
	implicitHeight: Theme.barHeight

	Item {
		id: holder

		anchors.left: parent.left
		anchors.leftMargin: root.leftMargin
		anchors.verticalCenter: parent.verticalCenter

		implicitWidth: childrenRect.width
		implicitHeight: childrenRect.height
		width: implicitWidth
		height: implicitHeight
	}

	MouseArea {
		id: mouse

		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		cursorShape: Qt.PointingHandCursor

		onClicked: event => {
			if (event.button === Qt.RightButton)
				root.rightClicked(event);
			else
				root.clicked(event);
		}

		onWheel: event => {
			if (event.angleDelta.y > 0)
				root.wheelUp();
			else if (event.angleDelta.y < 0)
				root.wheelDown();
		}
	}

	// Hover is a handler rather than the MouseArea's own hoverEnabled: a
	// hovered MouseArea swallows the event, and the bar as a whole watches for
	// the pointer leaving it. Handlers are non-blocking, so both see it.
	HoverHandler {
		id: hover
	}

	Tooltip {
		owner: root
		text: root.tooltip
		shown: hover.hovered
	}
}
