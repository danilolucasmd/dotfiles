pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// The batteries, the power profile, and whether the battery panel is up.
//
// A singleton for the same reason the other panels have one: the panel is a
// window of its own rather than a child of the bar module, and super+B can
// summon it without the bar being involved at all.
//
// UPower.displayDevice is the machine's *aggregate* -- one percentage covering
// every pack, which is what the bar glyph wants. This laptop has two, so the
// panel needs the packs themselves; hence both live here.
Singleton {
	id: root

	// The internal packs, in a stable order. UPower hands its device list back
	// in whatever order it enumerated them, which need not be BAT0 then BAT1
	// across a reload -- sorting on nativePath keeps the panel's rows from
	// swapping places under you.
	readonly property var batteries: {
		const all = UPower.devices?.values ?? [];
		return all.filter(d => d.isLaptopBattery && d.isPresent).sort((a, b) => a.nativePath.localeCompare(b.nativePath));
	}

	// What the bar reads: the aggregate, so a machine with two half-full packs
	// says 50% rather than picking one of them and being wrong about the other.
	readonly property var display: UPower.displayDevice
	readonly property bool present: display?.isLaptopBattery ?? false
	readonly property int percent: Math.round((display?.percentage ?? 0) * 100)
	// FullyCharged counts as charging: it means the cable is in, which is the
	// distinction the glyph and the low thresholds care about.
	readonly property bool charging: display?.state === UPowerDeviceState.Charging || display?.state === UPowerDeviceState.FullyCharged

	// Seconds to empty (discharging) or to full (charging); 0 when UPower has
	// not gathered enough history to say, which it has not in the first minutes
	// after the cable moves.
	readonly property int secondsLeft: charging ? (display?.timeToFull ?? 0) : (display?.timeToEmpty ?? 0)

	// Whether power-profiles-daemon is installed. Without it PowerProfiles
	// still answers -- it just reports a fixed Balanced that nothing can move
	// -- so the panel has to be able to tell "balanced" from "no daemon" and
	// say so, rather than offering buttons that do nothing. See the probe below.
	readonly property bool profilesAvailable: probe.loaded

	readonly property int profile: PowerProfiles.profile
	// Not every machine offers all three; one with no performance profile gets
	// two buttons rather than a dead third.
	readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
	// "Performance is being held back because the machine is hot, or in your
	// lap." Worth printing: otherwise selecting Performance looks like it did
	// nothing at all.
	readonly property int degradation: PowerProfiles.degradationReason

	property bool panelOpen: false

	function setProfile(p: int): void {
		if (profilesAvailable)
			PowerProfiles.profile = p;
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		// Opening is the moment to re-check: the daemon may have been installed
		// since the shell came up, and this is the one place its absence shows.
		// watchChanges cannot be relied on for that -- it is watching a path
		// that does not exist yet.
		if (panelOpen)
			probe.reload();
	}

	function close(): void {
		panelOpen = false;
	}

	// "5h 12m", "12m", or "" when UPower has no estimate to give.
	function duration(seconds: int): string {
		if (seconds <= 0)
			return "";
		const h = Math.floor(seconds / 3600);
		const m = Math.round(seconds % 3600 / 60);
		return h > 0 ? `${h}h ${m}m` : `${m}m`;
	}

	// What the panel calls a pack: BAT0, BAT1. nativePath is the sysfs name,
	// which is exactly that.
	function label(battery: var): string {
		return battery?.nativePath || "Battery";
	}

	// Is the daemon *running* is the wrong question: it is D-Bus activated, so
	// it sits stopped until something asks it something -- including quickshell
	// itself, at startup. Probing with `systemctl is-active` therefore races the
	// shell's own activation of it and reports a missing daemon that is merely
	// idle. Worse, probing over D-Bus to find out would start it.
	//
	// The question that actually matters is whether it is *installed*, and this
	// file is what makes the bus name activatable -- the same name quickshell
	// reaches for. Present means PowerProfiles works; absent is the
	// "not activatable" it logs on a machine without the package. A file read,
	// so nothing is spawned and nothing is woken up.
	FileView {
		id: probe

		path: "/usr/share/dbus-1/system-services/org.freedesktop.UPower.PowerProfiles.service"
		watchChanges: true
		printErrors: false
	}
}
