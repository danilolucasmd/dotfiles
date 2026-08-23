//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import qs
import qs.bar
import qs.modules

// Status bar for Hyprland, replacing waybar. See ~/dotfiles/quickshell.
ShellRoot {
	Bar {}

	// Not part of the bar: a panel opens on the focused monitor, which is not
	// necessarily the one whose bar was clicked, and super+A can summon the
	// usage one without the bar being involved at all.
	AgentUsagePanel {}
	WeatherPanel {}
	CalendarPanel {}

	AudioDevicesPanel {}
	AudioDevicesPanel {
		inputs: true
	}

	// Not a panel: a readout that shows itself when the volume moves.
	VolumeOsd {}

	// `qs ipc call <panel> toggle`, which is what super+A and super+C run.
	// Hyprland binds are the only sensible place for a global shortcut here —
	// the wlr global-shortcuts protocol would need a portal Hyprland does not
	// wire up to its own keybind config.
	IpcHandler {
		target: "agentUsage"

		function toggle(): void {
			AgentUsageState.toggle();
		}
	}

	// One target, two panels: `qs ipc call audio inputs` / `… outputs`, which
	// is what super+I and super+O run.
	IpcHandler {
		target: "audio"

		function inputs(): void {
			AudioState.toggleInputs();
		}

		function outputs(): void {
			AudioState.toggleOutputs();
		}
	}

	IpcHandler {
		target: "calendar"

		function toggle(): void {
			CalendarState.toggle();
		}
	}
}
