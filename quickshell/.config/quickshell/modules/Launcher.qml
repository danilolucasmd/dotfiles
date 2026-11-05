import qs
import qs.components

// The launcher as a click target, for when super+space is out of reach: a
// Moonlight stream from the Switch brings a controller and a pointer, not a
// keyboard, and without this nothing on screen opens it.
BarItem {
	rightMargin: Theme.gap
	highlighted: LauncherState.panelOpen

	onClicked: LauncherState.toggle()

	BarText {
		text: "󰀻"
	}
}
