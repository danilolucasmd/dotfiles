pragma Singleton

import QtQuick
import Quickshell

// Lock, suspend and shut down, as three things the launcher can find by name.
//
// There is no power menu and no bar module, because the machine already has its
// power policy elsewhere: super+Escape locks, hypridle blanks and suspends on
// its own timers, and a closed lid is lid.sh's decision. What was missing was a
// way to reach the three deliberate ones by typing their name, so they are
// three desktop entries in ~/dotfiles/panels pointing back at this singleton.
//
// Lock and suspend would have worked as plain `Exec=hyprlock` /
// `Exec=systemctl suspend` lines with nothing in quickshell at all. They route
// through here anyway: shutting down has to ask first, asking means a card, and
// a card means a panel — and once one of the three is quickshell's, having the
// other two be shell-out entries would leave "what the launcher does about
// power" split across two places that do not look like each other. Nothing is
// lost by it either, since the launcher asking is itself quickshell: if this
// process is gone there is no row to pick.
Singleton {
	id: root

	// The shutdown confirm. The only one of the three that puts anything on
	// screen — see PowerPanel.qml.
	property bool panelOpen: false

	function lock(): void {
		Quickshell.execDetached(["hyprlock"]);
	}

	// No lock of our own on the way down: hypridle's `before_sleep_cmd` is
	// hyprlock, so logind's sleep hook already locks this and a second one
	// would be racing the first for the same session.
	function suspend(): void {
		Quickshell.execDetached(["systemctl", "suspend"]);
	}

	// Opens the confirm rather than pulling the plug. A launcher row is one
	// fuzzy match and one Return away from whatever was typed — which is the
	// right amount of friction for opening a window, and not for taking the
	// machine down with unsaved work on it.
	function shutdown(): void {
		panelOpen = true;
	}

	function close(): void {
		panelOpen = false;
	}

	function confirm(): void {
		panelOpen = false;
		// `systemctl poweroff` rather than logind over D-Bus: it is the same
		// call, and this way the thing that runs is the thing anyone would
		// type by hand when asking why the machine did not go down.
		Quickshell.execDetached(["systemctl", "poweroff"]);
	}
}
