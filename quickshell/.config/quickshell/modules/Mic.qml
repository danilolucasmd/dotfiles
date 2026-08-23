import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import qs.components

// Microphone mute state, straight off the default PipeWire source rather than
// polling `pactl` once a second.
BarItem {
	id: root

	readonly property PwNode source: Pipewire.defaultAudioSource
	readonly property bool muted: source?.audio?.muted ?? false

	rightMargin: Theme.gap
	tooltip: muted ? "Microphone muted" : "Microphone live"

	// Volume/mute state is only tracked for nodes something is holding on to.
	PwObjectTracker {
		objects: [root.source]
	}

	onClicked: toggle.running = true

	Process {
		id: toggle

		command: [`${Paths.home}/.config/sounds/scripts/toggle-mic.sh`]
	}

	BarText {
		text: root.muted ? "󰍭" : "󰍬"
		color: root.muted ? Theme.red : Theme.fg
		font.pixelSize: Theme.fontIcon
	}
}
