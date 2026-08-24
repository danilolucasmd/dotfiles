import QtQuick
import qs
import qs.components

// Sink volume. This was two waybar modules (pulseaudio#icon and
// pulseaudio#text) purely so each could carry its own font size and margin;
// here it is one module with a Row. The reading itself lives in AudioState,
// which the OSD shares.
//
// Scrolling adjusts the volume, which waybar's pulseaudio module did for free.
BarItem {
	rightMargin: Theme.gap

	// Left-click picks the output device; the OSD still appears on its own
	// whenever the volume actually moves, which is what it is for. Mute is on
	// the right button — muting on a stray left click is a thing you then have
	// to notice and undo.
	onClicked: AudioState.toggleOutputs()
	onRightClicked: AudioState.toggleMute()

	onWheelUp: AudioState.step(5)
	onWheelDown: AudioState.step(-5)

	Row {
		spacing: 8

		BarText {
			anchors.verticalCenter: parent.verticalCenter

			text: AudioState.icon
			font.pixelSize: 18
		}

		BarText {
			anchors.verticalCenter: parent.verticalCenter

			// waybar reserved 30px here against the label twitching as the
			// number crosses 9% / 99%. Dropped for the reason given in Battery:
			// it padded the gap to the module beside it. The cost lands harder
			// here than there, because the wheel crosses those boundaries often
			// -- the modules to the left step a character's width when it does.
			text: `${AudioState.volume}%`
		}
	}
}
