pragma Singleton

import Quickshell
import Quickshell.Io

// Keep awake: while it is on, the screen does not blank or lock and the machine
// does not suspend itself. Toggled from the launcher, from `qs ipc call
// keepAwake toggle`, or by clicking the mug in the bar.
//
// The mechanism is one logind inhibitor lock -- `systemd-inhibit --what=idle`
// held open for as long as the toggle is on. hypridle watches logind's
// `BlockInhibited` property and skips every one of its listeners while an idle
// lock is held, which is the whole policy in one place: no hyprlock at 300s, no
// `dpms off` at 330s, and no `lid.sh idle` at 600s, since that suspend is a
// thing hypridle asks for rather than something logind does on its own. Nothing
// in hypridle.conf has to know this exists.
//
// `--what=idle` and not `idle:sleep` on purpose. Closing the lid with no
// external monitor still suspends on battery, which is a laptop going into a
// bag, not a machine going idle -- blocking that would leave it running warm in
// there because of a toggle flipped hours earlier for a download. Keep awake is
// about the machine deciding to sleep on its own; asking it to sleep still
// works.
//
// `enabled` is an alias onto the process rather than a bool of its own, for the
// same reason NightLightState does it: the lock lives and dies with the process
// holding it, so a systemd-inhibit that died takes the bar glyph with it
// instead of leaving it lit over a machine that is free to lock again. The same
// cost applies too -- quickshell tears its children down when it reloads, so
// saving a file in here drops the lock.
Singleton {
	id: root

	readonly property alias enabled: inhibit.running

	function toggle(): void {
		inhibit.running = !inhibit.running;
	}

	function disable(): void {
		inhibit.running = false;
	}

	Process {
		id: inhibit

		// systemd-inhibit holds the lock for the lifetime of the command it
		// runs, so the command is one that does nothing forever. It kills its
		// child on SIGTERM, which is what quickshell sends when `running` goes
		// false, so no `sleep` is left behind.
		command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Keep awake", "--mode=block", "sleep", "infinity"]
	}
}
