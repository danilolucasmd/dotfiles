pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.components

// The batteries, the power profile, the charge threshold, and whether the
// battery panel is up.
//
// A singleton for the same reason the other panels have one: the panel is a
// window of its own rather than a child of the bar module, and super+shift+B can
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

	// ------------------------------------------------------------------
	// sysfs extras
	// ------------------------------------------------------------------

	// What UPower does not carry: cycle count, capacity in watt-hours against
	// the design figure, cell voltage, and the charge threshold. One entry per
	// pack, keyed by the sysfs name that is also UPower's nativePath, so the
	// panel can put a UPower device and its sysfs row side by side.
	readonly property var info: Array.isArray(details.data) ? details.data : []

	// Applying a saved threshold is a one-shot at startup, and it cannot run
	// until both halves of the picture -- the file and the first sysfs read --
	// have arrived. They race, so either one arriving tries.
	property bool limitRestored: false
	property bool limitLoaded: false
	// The percentage the user last chose, which is not necessarily the one the
	// firmware is at: a machine without the udev rule cannot be written to
	// without a password, and startup does not ask for one.
	property int limitSaved: -1

	onInfoChanged: {
		// A drag holds the slider until sysfs catches up with it, so the knob
		// does not jump back to the old value for the one refresh in between.
		if (limitTarget >= 0 && limitActual === limitTarget)
			limitTarget = -1;
		restoreLimit();
	}

	// The packs with a threshold at all. A desktop, or a machine whose firmware
	// does not expose one, gets the section greyed out rather than a slider
	// that writes into nothing.
	readonly property var limitPacks: info.filter(i => i.limitSupported)
	readonly property bool limitSupported: limitPacks.length > 0
	// Whether the write can be done as this user. False means every change goes
	// through pkexec, which is a password prompt per gesture -- workable, but
	// the udev rule in install.sh is what makes this a slider rather than an
	// interrogation.
	readonly property bool limitDirect: limitSupported && limitPacks.every(i => i.limitWritable)

	// What the firmware is set to. Both packs are written together and so
	// agree; the lowest is the honest reading if something else has moved one.
	readonly property int limitActual: limitPacks.reduce((min, i) => Math.min(min, i.limit ?? 100), 100)

	// What the slider is holding while a drag is in flight, so the knob follows
	// the pointer rather than the round trip out to sysfs and back. -1 means
	// nothing is driving it and `limitActual` is the truth. Same arrangement as
	// the brightness slider, and for the same reason.
	property int limitTarget: -1
	readonly property int limit: limitTarget >= 0 ? limitTarget : limitActual

	// Below 20% the threshold stops being a longevity setting and starts being
	// a laptop that dies when the cable moves. 80 is the figure the cell
	// chemistry actually wants: the last fifth of the charge is where a
	// lithium pack ages fastest, and giving it up costs an hour of runtime.
	readonly property int limitFloor: 20
	readonly property int limitDefault: 80

	// Why the last write did not take. Cleared by the next attempt.
	property string limitError: ""

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
		if (panelOpen) {
			probe.reload();
			details.refresh();
		}
	}

	function close(): void {
		panelOpen = false;
	}

	// Absolute, for the slider; relative, for its keys and its wheel. Snapped
	// to 5, which is as fine as this setting is ever meant to be -- and the
	// write itself is left to the flush timer, because a drag is a hundred
	// pointer events and one process each is a hundred processes for one
	// gesture.
	function setLimit(percent: int): void {
		if (!limitSupported)
			return;
		limitError = "";
		limitTarget = Math.max(limitFloor, Math.min(100, Math.round(percent / 5) * 5));
		flush.restart();
	}

	function stepLimit(delta: int): void {
		setLimit(limit + delta);
	}

	// Hand a percentage to the script. `prompt` false is the startup path: on a
	// machine without the udev rule it fails quietly rather than opening a
	// polkit dialog at every login.
	function applyLimit(percent: int, prompt: bool): void {
		const command = [`${Paths.scripts}/charge-limit.sh`, String(percent)];
		if (!prompt)
			command.push("--no-prompt");
		applier.command = command;
		applier.running = true;
	}

	// The saved preference, put back once per session. The threshold is EC
	// state and most firmware does keep it across a reboot, but a battery
	// swap, a firmware update or a live boot all reset it to 100 -- and a
	// setting that silently stops applying is worse than one that was never
	// offered. Only ever done where the write is direct: see applyLimit.
	function restoreLimit(): void {
		if (limitRestored || !limitLoaded || !limitSupported)
			return;
		limitRestored = true;

		// Nothing chosen yet: the default is the whole point of having one, so
		// it is adopted and recorded rather than waiting to be dragged to.
		if (limitSaved < 0) {
			limitSaved = limitDefault;
			store.setText(JSON.stringify({
				limit: limitSaved
			}));
		}

		if (limitSaved !== limitActual && limitDirect)
			applyLimit(limitSaved, false);
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

	// The sysfs row for a UPower device, or null before the first read has
	// landed. Matched on the sysfs name, which both sides call the same thing.
	function infoFor(battery: var): var {
		const name = battery?.nativePath ?? "";
		return info.find(i => i.name === name) ?? null;
	}

	// A number the script may have reported as null -- a pack whose firmware
	// does not count cycles, or does not publish a voltage -- with its unit.
	// Absent stays absent: printing "0 cycles" on a pack that keeps no count is
	// a claim, and a wrong one.
	function figure(value: var, unit: string, decimals: int): string {
		if (value === null || value === undefined)
			return "";
		return `${Number(value).toFixed(decimals)}${unit}`;
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

	// Voltage and the charge figures move while you watch them, so the panel
	// polls; with the panel shut this is only keeping the threshold and the
	// cycle count current, which change on the order of days.
	JsonScript {
		id: details

		command: [`${Paths.scripts}/battery-info.sh`]
		intervalMs: root.panelOpen ? 3000 : 60000
	}

	// The chosen threshold, so it survives a reboot that clears the EC. Read
	// blocking, like the weather panel's saved location: loaded the usual
	// asynchronous way it would land after the first sysfs read, and the
	// restore would be deciding against a preference it did not have yet.
	FileView {
		id: store

		path: `${Paths.state}/quickshell/charge-limit.json`
		blockLoading: true
		printErrors: false
		atomicWrites: true

		onLoaded: {
			try {
				const saved = JSON.parse(text());
				if (Number.isFinite(saved?.limit))
					root.limitSaved = saved.limit;
			} catch (e) {
				// An unparseable file is a file written by something that is
				// not this. Treated as nothing saved, which adopts the default.
			}
		}
		// blockLoading means the read is done by the time this runs, whether it
		// found a file or not -- and a path that does not exist yet is the
		// first run, which is a state the restore has an answer for rather
		// than an error.
		Component.onCompleted: root.limitLoaded = true
	}

	// FileView will not create the directory it writes into. Several singletons
	// make it at startup; none can rely on another having loaded first, and
	// mkdir -p costs nothing twice.
	Process {
		command: ["mkdir", "-p", `${Paths.state}/quickshell`]
		running: true
	}

	Process {
		id: applier

		stdout: StdioCollector {
			onStreamFinished: {
				let result = {};
				try {
					result = JSON.parse(text);
				} catch (e) {
					// A script that printed nothing usable -- it was killed, or
					// bash is not where it was. Reported as a refusal, since
					// from the panel's side that is what it is.
				}

				if (result.ok) {
					// sysfs is the truth the slider settles on; the drag's
					// value is held until this read confirms it.
					details.refresh();
				} else {
					root.limitError = result.error || "could not be applied";
					root.limitTarget = -1;
				}
			}
		}
	}

	// A drag is a hundred pointer events; this collapses them into one write,
	// a beat after the pointer stops. Long enough that dragging across the
	// strip does not spawn a process per step, short enough that letting go
	// and watching the number take is one motion.
	Timer {
		id: flush

		interval: 400

		onTriggered: {
			if (root.limitTarget < 0)
				return;
			root.limitSaved = root.limitTarget;
			store.setText(JSON.stringify({
				limit: root.limitSaved
			}));
			root.applyLimit(root.limitTarget, true);
		}
	}
}
