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
	rightMargin: 10

	// Left-click brings up the OSD rather than muting: muting on a stray click
	// is a thing you then have to notice and undo, and the OSD is what you
	// wanted to see anyway. Mute moved to the right button.
	onClicked: AudioState.show()
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

			// waybar reserved 30px here so the label stops twitching as the
			// number crosses 9% / 99%.
			width: Math.max(30, implicitWidth)
			text: `${AudioState.volume}%`
		}
	}
}
