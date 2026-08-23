import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

// Sink volume, read from PipeWire directly. This was two waybar modules
// (pulseaudio#icon and pulseaudio#text) purely so each could carry its own
// font size and margin; here it is one module with a Row.
//
// Scrolling adjusts the volume, which waybar's pulseaudio module did for free.
BarItem {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool muted: sink?.audio?.muted ?? false
	readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)

	rightMargin: 10

	PwObjectTracker {
		objects: [root.sink]
	}

	onClicked: {
		if (sink?.audio)
			sink.audio.muted = !sink.audio.muted;
	}

	onWheelUp: step(5)
	onWheelDown: step(-5)

	function step(delta: int): void {
		if (!sink?.audio)
			return;
		sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta / 100));
	}

	Row {
		spacing: 8

		BarText {
			anchors.verticalCenter: parent.verticalCenter
			font.pixelSize: 18
			text: {
				if (root.muted)
					return "󰝟";
				if (root.volume < 34)
					return "󰕿";
				if (root.volume < 67)
					return "󰖀";
				return "󰕾";
			}
		}

		BarText {
			anchors.verticalCenter: parent.verticalCenter
			// waybar reserved 30px here so the label stops twitching as the
			// number crosses 9% / 99%.
			width: Math.max(30, implicitWidth)
			text: `${root.volume}%`
		}
	}
}
