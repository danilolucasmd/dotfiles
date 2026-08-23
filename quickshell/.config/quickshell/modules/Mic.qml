import Quickshell.Io
import qs
import qs.components

// Microphone mute state, straight off the default PipeWire source rather than
// polling `pactl` once a second. The state lives in AudioState, which the input
// picker shares.
BarItem {
	rightMargin: Theme.gap

	// Left-click opens the input picker, where every microphone can be muted
	// individually or all at once. The old click — mute the default source —
	// moved to the right button, where it keeps the script's mic-on/mic-off
	// sounds and matches the XF86AudioMute bind.
	onClicked: AudioState.toggleInputs()
	onRightClicked: toggle.running = true

	Process {
		id: toggle

		command: [`${Paths.home}/.config/sounds/scripts/toggle-mic.sh`]
	}

	BarText {
		text: AudioState.sourceMuted ? "󰍭" : "󰍬"
		color: AudioState.sourceMuted ? Theme.red : Theme.fg
		font.pixelSize: Theme.fontIcon
	}
}
