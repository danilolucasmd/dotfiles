pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components

// The monitors Hyprland is driving, the backlight behind whichever one the
// panel is pointed at, and whether that panel is up.
//
// A singleton for the reason the other panels have one: the panel is a window
// of its own rather than a child of the bar module, and super+D can summon it
// without the bar being involved at all.
//
// Quickshell's own `Hyprland.monitors` is not enough here. It learns names from
// the event socket but leaves `lastIpcObject` empty and `scale` at 0 — measured
// on 0.3.1, `refreshMonitors()` included — and the panel needs the half of the
// monitor JSON it never fills in: the transform, the refresh rate, and the mode
// list. So this reads `hyprctl monitors -j` itself, the way KeyboardState reads
// `hyprctl devices -j`, and re-reads on the events that can move it.
Singleton {
	id: root

	// Every monitor Hyprland has, straight out of the JSON. Plain objects
	// rather than Quickshell's HyprlandMonitor, so `transform`, `refreshRate`
	// and `availableModes` are all just there.
	readonly property var monitors: Array.isArray(query.data) ? query.data : []

	readonly property var focused: monitors.find(m => m.focused) ?? monitors[0] ?? null

	// Which monitor the panel is pointed at. Pinned when the panel opens — to
	// the screen whose bar was clicked, or to the focused monitor when a
	// keybind opened it — and moved after that only by the panel's own tabs.
	// An empty name, or one that has since been unplugged, falls back to focus.
	property string selectedName: ""
	readonly property var selected: monitors.find(m => m.name === selectedName) ?? focused

	property bool panelOpen: false

	// The scales the panel offers. Not every one fits every monitor — a scale
	// has to divide the mode into a whole number of logical pixels, or Hyprland
	// refuses it — so `scaleFits` greys out the ones that do not. These six all
	// divide 1920x1080, which is what both screens here are.
	readonly property var scales: [1, 1.25, 1.5, 1.6, 2, 3]

	// ------------------------------------------------------------------
	// Backlight
	// ------------------------------------------------------------------

	// brightnessctl is driven with the same curve the XF86MonBrightness binds
	// use (`-e4 -n2`, in hyprland.conf), so the panel's percentage and the
	// keys' percentage are the same number rather than two scales for one
	// slider. The exponent has to be applied here too when going the other way:
	// sysfs reports the raw value, and 36% of the range is 78% of the curve.
	readonly property int curve: 4
	// brightnessctl's floor, as a raw value. Keeps the screen off the bottom
	// stop, which on this panel is indistinguishable from off.
	readonly property int floorValue: 2

	readonly property var backlights: Array.isArray(lights.data) ? lights.data : []

	readonly property var backlight: backlightFor(selected?.name ?? "")
	// An external monitor has no backlight the kernel can drive: the panel says
	// so rather than offering a slider that does nothing.
	readonly property bool dimmable: backlight !== null

	readonly property int maxValue: backlight?.max ?? 0
	readonly property int rawValue: parseInt(view.text()) || 0

	// What sysfs currently says, on the curve.
	readonly property int actual: maxValue > 0 ? Math.round(100 * Math.pow(Math.max(0, Math.min(maxValue, rawValue)) / maxValue, 1 / curve)) : 0

	// What the slider is holding while a drag is in flight, so the knob follows
	// the pointer rather than the round trip through brightnessctl and back out
	// of sysfs. -1 means nothing is driving it and `actual` is the truth.
	property int target: -1
	property int written: -1

	readonly property int level: target >= 0 ? target : actual

	function backlightFor(name: string): var {
		return backlights.find(b => b.connector === name) ?? null;
	}

	// Absolute, for the slider. The write itself is left to the flush timer:
	// a drag is a hundred pointer events, and one brightnessctl per event is a
	// hundred processes for one gesture.
	function setLevel(percent: int): void {
		if (!dimmable)
			return;
		target = Math.max(0, Math.min(100, Math.round(percent)));
	}

	// Relative, for the bar module's scroll wheel, on a named screen rather
	// than on the selection — the bar is per-monitor, so scrolling dims the one
	// under the pointer whatever the panel happens to be showing. Handed to
	// brightnessctl as a delta so it needs no reading of its own.
	function step(name: string, delta: int): void {
		const light = backlightFor(name);
		if (!light)
			return;
		Quickshell.execDetached(["brightnessctl", "-q", "-d", light.device, `-e${curve}`, `-n${floorValue}`, "set", delta > 0 ? `${delta}%+` : `${-delta}%-`]);
	}

	// ------------------------------------------------------------------
	// Monitor rules
	// ------------------------------------------------------------------

	// The rates this monitor offers at the resolution it is running, best last.
	//
	// availableModes lists 119.88, 119.98 and 120.00 as three separate modes,
	// which is one choice as far as anyone picking between them is concerned.
	// They collapse to a single button at the nearest whole hertz, carrying the
	// fastest of the group — asking for 120 and getting 119.88 is the right
	// outcome on a monitor that has nothing truer to offer.
	function ratesFor(monitor: var): var {
		if (!monitor)
			return [];

		const prefix = `${monitor.width}x${monitor.height}@`;
		const best = {};
		for (const mode of monitor.availableModes ?? []) {
			if (!mode.startsWith(prefix))
				continue;
			const hz = parseFloat(mode.slice(prefix.length));
			if (!isFinite(hz))
				continue;
			const bucket = Math.round(hz);
			if (!(bucket in best) || hz > best[bucket])
				best[bucket] = hz;
		}
		return Object.keys(best).map(k => best[k]).sort((a, b) => a - b);
	}

	// Whether Hyprland will take this scale on this monitor. It insists the
	// mode divide into a whole number of logical pixels and refuses outright
	// otherwise, so the panel greys the button rather than offering a press
	// that does nothing but log an error.
	//
	// Both axes, because a rotated monitor is laid out with them swapped; the
	// mode the scale divides is the same either way round.
	function scaleFits(monitor: var, scale: real): bool {
		if (!monitor || scale <= 0)
			return false;
		for (const pixels of [monitor.width, monitor.height]) {
			const logical = pixels / scale;
			if (Math.abs(logical - Math.round(logical)) > 0.001)
				return false;
		}
		return true;
	}

	function setScale(monitor: var, scale: real): void {
		if (monitor)
			write(monitor, scale, monitor.transform, monitor.refreshRate);
	}

	function setTransform(monitor: var, transform: int): void {
		if (monitor)
			write(monitor, monitor.scale, transform, monitor.refreshRate);
	}

	function setRate(monitor: var, rate: real): void {
		if (monitor)
			write(monitor, monitor.scale, monitor.transform, rate);
	}

	// One `monitor` rule, spelled out in full. The keyword replaces the rule
	// wholesale rather than patching it, so every field goes out on every
	// change, including the position — which the panel does not offer and must
	// therefore not disturb.
	//
	// Runtime only, deliberately: this writes nothing, so a `hyprctl reload` or
	// the next login puts hyprland.conf back in charge. The panel says as much
	// in its footer.
	function write(monitor: var, scale: real, transform: int, rate: real): void {
		const mode = `${monitor.width}x${monitor.height}@${rate.toFixed(2)}Hz`;
		const rule = `${monitor.name},${mode},${monitor.x}x${monitor.y},${trim(scale)},transform,${transform}`;
		Quickshell.execDetached(["hyprctl", "keyword", "monitor", rule]);
		// Hyprland applies the rule a beat later, and says nothing on the event
		// socket when it has: the panel finds out by looking again.
		settleMonitors.restart();
	}

	// 1, 1.25, 1.5 — not 1.000000. The same string labels the button and goes
	// into the rule, so the two can never disagree about what was asked for.
	function trim(value: real): string {
		return String(Number(value.toFixed(4)));
	}

	// ------------------------------------------------------------------

	function toggle(screenName: string): void {
		panelOpen = !panelOpen;
		if (!panelOpen)
			return;

		// Opening is the moment to look: a monitor may have been plugged in, or
		// its rule changed from a terminal, since the last time anyone asked.
		query.refresh();
		lights.refresh();
		select(screenName || (focused?.name ?? ""));
	}

	function close(): void {
		panelOpen = false;
	}

	function select(name: string): void {
		// A drag that was in flight belongs to the monitor it started on.
		target = -1;
		written = -1;
		selectedName = name;
	}

	JsonScript {
		id: query

		command: ["hyprctl", "monitors", "-j"]
	}

	JsonScript {
		id: lights

		command: [`${Paths.scripts}/backlights.sh`]
	}

	// The selected monitor's level, live. sysfs does deliver a change
	// notification for this file, so the panel sees the brightness keys move
	// the slider without polling for it — but the notification arrives before
	// the re-read does, hence the explicit reload.
	FileView {
		id: view

		path: root.backlight ? `/sys/class/backlight/${root.backlight.device}/brightness` : ""
		watchChanges: true
		printErrors: false

		onFileChanged: reload()
	}

	// The pending slider write, at a rate a backlight can actually keep up
	// with. Fires immediately on the first movement so the screen answers the
	// press, then coalesces everything after it.
	Timer {
		id: flush

		interval: 40
		repeat: true
		triggeredOnStart: true
		running: root.target >= 0 && root.dimmable

		onTriggered: {
			if (root.target === root.written) {
				// Nothing new since the last tick: the gesture is over. Armed
				// once and then left alone — restarting it on every idle tick
				// is restarting it faster than it can fire, which is a slider
				// that never hands back to the reading and a timer that never
				// stops.
				if (!settle.running)
					settle.restart();
				return;
			}
			settle.stop();
			root.written = root.target;
			Quickshell.execDetached(["brightnessctl", "-q", "-d", root.backlight.device, `-e${root.curve}`, `-n${root.floorValue}`, "set", `${root.target}%`]);
		}
	}

	// Long enough after the last write for sysfs to have caught up, at which
	// point the slider can go back to reading rather than remembering. Also the
	// way out of a value brightnessctl clamped and will never report back.
	Timer {
		id: settle

		interval: 400

		onTriggered: {
			root.target = -1;
			root.written = -1;
		}
	}

	Timer {
		id: settleMonitors

		interval: 250

		onTriggered: query.refresh()
	}

	Connections {
		target: Hyprland

		// A monitor coming or going changes the tabs; focus moving changes
		// which one an unpinned panel would land on. Hyprland says nothing
		// about a rule being applied, which is what settleMonitors is for.
		function onRawEvent(event: HyprlandEvent): void {
			if (event.name.startsWith("monitor") || event.name.startsWith("focusedmon"))
				settleMonitors.restart();
		}
	}
}
