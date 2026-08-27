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
	NotificationsPanel {}
	MediaPanel {}
	EmojiPanel {}

	AudioDevicesPanel {}
	NetworkPanel {}
	BluetoothPanel {}
	KeyboardLayoutPanel {}
	PerformancePanel {}
	BatteryPanel {}
	DisplayPanel {}

	// Neither is a panel: both show themselves rather than being opened, and
	// neither may take the keyboard.
	VolumeOsd {}
	NotificationPopups {}

	// `qs ipc call <panel> toggle`, which is what super+A, super+B, super+C and
	// super+N run.
	// Hyprland binds are the only sensible place for a global shortcut here —
	// the wlr global-shortcuts protocol would need a portal Hyprland does not
	// wire up to its own keybind config.
	//
	// A new handler here wants two things outside this file: the `bindd` in
	// hyprland.conf, and a desktop entry in ~/dotfiles/panels, which is what
	// puts the panel in the walker launcher under its own name. See
	// panels/README.md.
	IpcHandler {
		target: "agentUsage"

		function toggle(): void {
			AgentUsageState.toggle();
		}
	}

	// One target, one panel, two ways in: `qs ipc call audio inputs` / `…
	// outputs` open it with the cursor in that section, which is what super+I
	// and super+O run.
	IpcHandler {
		target: "audio"

		function inputs(): void {
			AudioState.toggleInputs();
		}

		function outputs(): void {
			AudioState.toggleOutputs();
		}
	}

	// alt+space is a Hyprland bind rather than an xkb option now, so that
	// holding alt after it can put the layout picker up: `cycle` on every
	// press, `release` when alt comes back up.
	IpcHandler {
		target: "keyboard"

		function toggle(): void {
			KeyboardState.toggle();
		}

		function cycle(): void {
			KeyboardState.cycle();
		}

		function release(): void {
			KeyboardState.release();
		}
	}

	IpcHandler {
		target: "notifications"

		function toggle(): void {
			NotificationsState.toggle();
		}
	}

	// super+E. Not a bar module -- there is nothing about the emoji picker worth
	// a permanent glyph -- so the keybind and the launcher entry are the only
	// ways in.
	IpcHandler {
		target: "emoji"

		function toggle(): void {
			EmojiState.toggle();
		}
	}

	IpcHandler {
		target: "media"

		function toggle(): void {
			MediaState.toggle();
		}
	}

	IpcHandler {
		target: "weather"

		function toggle(): void {
			WeatherState.toggle();
		}
	}

	IpcHandler {
		target: "calendar"

		function toggle(): void {
			CalendarState.toggle();
		}
	}

	IpcHandler {
		target: "battery"

		function toggle(): void {
			BatteryState.toggle();
		}
	}

	// No screen to pass: a keybind has none, so the panel opens pointed at the
	// focused monitor. Clicking the bar module names the screen its bar is on.
	IpcHandler {
		target: "display"

		function toggle(): void {
			DisplayState.toggle("");
		}
	}

	IpcHandler {
		target: "network"

		function toggle(): void {
			NetworkState.toggle();
		}
	}

	IpcHandler {
		target: "bluetooth"

		function toggle(): void {
			BluetoothState.toggle();
		}
	}

	IpcHandler {
		target: "performance"

		function toggle(): void {
			PerformanceState.toggle();
		}
	}

	// The one handler here that opens nothing: it flips the blue-light filter,
	// which is a setting rather than a card, and the only thing it puts on
	// screen is the bar glyph that says it is on. It still wants the desktop
	// entry in ~/dotfiles/panels — being reachable by name from the launcher is
	// the whole point of a toggle with no keybind.
	IpcHandler {
		target: "nightLight"

		function toggle(): void {
			NightLightState.toggle();
		}
	}

	// The other one that opens nothing: it holds a logind idle inhibitor for as
	// long as it is on, so the screen stays up and the machine stays awake. The
	// bar mug is always there to click, but the launcher entry is what the
	// toggle was asked for -- it has no keybind.
	IpcHandler {
		target: "keepAwake"

		function toggle(): void {
			KeepAwakeState.toggle();
		}
	}
}
