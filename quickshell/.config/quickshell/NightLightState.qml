pragma Singleton

import Quickshell
import Quickshell.Io

// The blue-light filter: hyprsunset holding a warm gamma ramp on every output,
// toggled from the launcher, from `qs ipc call nightLight toggle`, or by
// clicking the glyph it puts in the bar.
//
// There is no daemon sitting idle for this. hyprsunset ships a systemd user
// unit that would run all session and be told to go neutral when the filter is
// off, but the filter *is* the process: the ramp lives on the wlr-gamma-control
// object hyprsunset holds, and the compositor hands the outputs back their
// original ramp the moment that client disconnects. So running it only while
// the filter is on costs nothing extra, and makes "is the night light on" a
// question with one answer rather than two that can disagree.
//
// That is why `enabled` is an alias onto the process rather than a bool of its
// own: hyprsunset dying, or never starting because the package is missing,
// takes the bar glyph with it instead of leaving it lit over a screen that is
// no longer tinted.
//
// The one visible consequence: quickshell tears its children down when it
// reloads, so saving a file in here turns the filter off. That is a cost paid
// while editing the shell, not while using it.
Singleton {
	id: root

	// 4000K, which is GNOME's night-light default and about as warm as the
	// screen gets before white text starts reading as orange. hyprsunset's own
	// default is 6000K -- a filter so slight it is hard to tell from neutral,
	// which is the wrong default for something whose whole job is to be
	// visibly on.
	readonly property int temperature: 4000

	readonly property alias enabled: sunset.running

	function toggle(): void {
		sunset.running = !sunset.running;
	}

	function disable(): void {
		sunset.running = false;
	}

	Process {
		id: sunset

		command: ["hyprsunset", "-t", `${root.temperature}`]
	}
}
