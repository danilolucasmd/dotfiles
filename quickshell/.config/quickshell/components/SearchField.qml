import QtQuick
import QtQuick.Layouts
import qs

// The search box at the top of a panel that filters a list.
//
// Pulled out of the emoji picker when the launcher and the keybind sheet turned
// out to want the same three things from it: the rounded field, the placeholder
// that disappears on the first keystroke, and -- the part worth sharing -- keys
// reaching the parent *before* the text caret gets them. A panel whose list is
// driven by the arrows cannot have Up and Down moving the cursor inside the
// query instead, and every one of these has a list.
//
// The parent listens on `keyPressed` and accepts what it wants:
//
//     onKeyPressed: event => {
//         if (event.key === Qt.Key_Down) { next(); event.accepted = true; }
//     }
//
// Anything left unaccepted falls through to the field and is typed, so a panel
// only has to name the keys it actually steers with.
Rectangle {
	id: root

	property alias text: input.text
	property string placeholder: "Search"

	// Emitted before the field handles the key. Accept the event to keep it
	// from reaching the caret.
	signal keyPressed(var event)

	function takeFocus(): void {
		input.forceActiveFocus();
	}

	function clear(): void {
		input.text = "";
	}

	Layout.fillWidth: true
	implicitHeight: 34

	radius: 6
	color: Qt.darker(Theme.tooltipBorder, 1.25)
	border.width: 1
	border.color: input.activeFocus ? Theme.blue : "transparent"

	TextInput {
		id: input

		anchors.fill: parent
		anchors.leftMargin: 10
		anchors.rightMargin: 10

		verticalAlignment: TextInput.AlignVCenter
		color: Theme.fg
		font.family: Theme.fontFamily
		font.pixelSize: Theme.fontText
		selectByMouse: true
		selectionColor: Theme.blue
		// One line that scrolls rather than wrapping into a second: the field
		// is a query box, and a query long enough to wrap is one the list has
		// already narrowed to nothing.
		clip: true

		// Keys.onPressed on the input runs ahead of the input's own handling,
		// which is the only place a parent can get first refusal on a key.
		Keys.onPressed: event => root.keyPressed(event)

		BarText {
			anchors.verticalCenter: parent.verticalCenter
			visible: input.text === ""

			text: root.placeholder
			color: Theme.disabled
		}
	}
}
