pragma Singleton

import QtQuick
import Quickshell

// Lock, suspend, restart and shut down, as four things the launcher can find by
// name.
//
// There is no power menu and no bar module, because the machine already has its
// power policy elsewhere: super+Escape locks, hypridle blanks and suspends on
// its own timers, and a closed lid is lid.sh's decision. What was missing was a
// way to reach the four deliberate ones by typing their name, so they are four
// desktop entries in ~/dotfiles/panels pointing back at this singleton.
//
// Lock and suspend would have worked as plain `Exec=hyprlock` /
// `Exec=systemctl suspend` lines with nothing in quickshell at all. They route
// through here anyway: shutting down has to ask first, asking means a card, and
// a card means a panel — and once one of the four is quickshell's, having the
// rest be shell-out entries would leave "what the launcher does about power"
// split across two places that do not look like each other. Nothing is lost by
// it either, since the launcher asking is itself quickshell: if this process is
// gone there is no row to pick.
Singleton {
	id: root

	// Which of the two confirmable actions the card is currently asking about:
	// "shutdown", "reboot", or "" while it is closed. One card serves both
	// because the question is the same one — the machine goes down with whatever
	// is open unsaved — and a second card differing only in two nouns would be
	// two places to fix the next time the wording or the key handling changes.
	property string pending: ""

	// What the panel binds its `open` to. Derived rather than set alongside
	// `pending`, so the two cannot disagree about whether the card is up.
	readonly property bool panelOpen: pending !== ""

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
		pending = "shutdown";
	}

	// Asks the same as shutdown does, and for the same reason: a restart loses
	// exactly as much unsaved work as a poweroff, and only differs in what the
	// machine does after it has gone down.
	function reboot(): void {
		pending = "reboot";
	}

	function close(): void {
		pending = "";
	}

	function confirm(): void {
		// Read before clearing: `pending` is what is being confirmed.
		const action = pending === "reboot" ? "reboot" : "poweroff";
		pending = "";
		// `systemctl poweroff` / `systemctl reboot` rather than logind over
		// D-Bus: it is the same call, and this way the thing that runs is the
		// thing anyone would type by hand when asking why the machine did not go
		// down.
		Quickshell.execDetached(["systemctl", action]);
	}
}
