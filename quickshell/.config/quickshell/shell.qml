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

	// `qs ipc call agentUsage toggle`, which is what super+A runs. Hyprland
	// binds are the only sensible place for a global shortcut here — the
	// wlr global-shortcuts protocol would need a portal Hyprland does not
	// wire up to its own keybind config.
	IpcHandler {
		target: "agentUsage"

		function toggle(): void {
			AgentUsageState.toggle();
		}
	}
}
