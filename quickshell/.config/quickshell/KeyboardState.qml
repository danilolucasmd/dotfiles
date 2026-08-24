pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The configured xkb layouts, which of them is live, and whether the picker is
// up. A singleton for the same reason the audio one is: the bar module and the
// panel are separate windows, so the reading they share has to live outside
// both.
//
// Hyprland keeps the layouts as two parallel comma-lists on the keyboard
// (`layout: "us,us"`, `variant: ",intl"`), so a layout here is really just an
// index into those.
Singleton {
	id: root

	// The two comma-lists exactly as Hyprland reports them.
	property string layoutSpec: ""
	property string variantSpec: ""
	property int activeIndex: 0
	// The active layout's xkb description ("English (US)"), which Hyprland
	// hands out for the live layout only. Used for the badge fallback, never
	// for a row: a name that only the live layout knows would move down the
	// list every time you switched.
	property string keymap: ""

	// layout/variant code -> xkb description, read once from the rules list.
	property var xkbNames: ({})

	// One entry per configured layout: {index, layout, variant, code, name}.
	readonly property var layouts: {
		if (layoutSpec === "")
			return [];

		const names = layoutSpec.split(",");
		const variants = variantSpec.split(",");

		return names.map((name, i) => {
			const layout = name.trim();
			const variant = (variants[i] ?? "").trim();
			return {
				index: i,
				layout: layout,
				variant: variant,
				// The badge: us-intl is the one this keyboard types Portuguese
				// on, so it reads BR rather than a second US.
				code: variant.toLowerCase().includes("intl") ? "BR" : layout.toUpperCase(),
				name: describe(layout, variant)
			};
		});
	}

	property bool panelOpen: false
	// Set while alt is still down after an alt+space. The panel is a HUD then:
	// it shows itself, and letting go of alt puts it away.
	property bool held: false
	// Whether the card is actually drawn. A hold puts the window up on the
	// first press but shows nothing for the first moment — Hyprland dispatches
	// keybinds on a modifier being *pressed* but never on it being released
	// (measured, including `bindri`), so the only way to hear alt come back up
	// is to be the surface holding the keyboard when it does. A tap-and-let-go
	// therefore maps a window nobody sees.
	property bool revealed: false

	// What the bar draws. The fallback keeps the badge right in the moment
	// before the first read lands, and if the read ever fails.
	readonly property string code: layouts[activeIndex]?.code ?? (keymap.toLowerCase().includes("intl") ? "BR" : "US")

	// The module was clicked, so this is a panel to interact with rather than a
	// HUD: any hold still on the books ends here, which is also what stops a
	// missed alt release from leaving the panel ungrabbable.
	function toggle(): void {
		linger.stop();
		held = false;
		revealed = true;
		panelOpen = !panelOpen;
	}

	// Dismissed by a click outside, or by Escape.
	function close(): void {
		linger.stop();
		watchdog.stop();
		held = false;
		revealed = false;
		panelOpen = false;
	}

	// Deliberately through Hyprland rather than around it: kb-layout-per-app.py
	// is listening for `activelayout`, so picking a layout is remembered for the
	// focused window's class exactly like an alt+space toggle is.
	function setLayout(index: int): void {
		panelOpen = false;
		if (index !== activeIndex)
			run(String(index));
	}

	// The flip alt+space does, still on the module's right button.
	function next(): void {
		run("next");
	}

	// alt+space, which is a Hyprland bind now rather than xkb's
	// grp:alt_space_toggle — the toggle happened inside libxkbcommon, where
	// nothing could hang a panel off it.
	//
	// The switch is immediate, as it has always been; the HUD only says which
	// layout you have landed on, so a quick tap behaves exactly like before.
	function cycle(): void {
		if (layouts.length === 0)
			return;

		// Optimistic: the reading comes back from hyprctl a moment later, and
		// the highlight should not lag behind a key you are holding down.
		activeIndex = (activeIndex + 1) % layouts.length;
		run(String(activeIndex));

		// Up from the first press, drawn or not: the window is what hears alt
		// come back up.
		panelOpen = true;
		watchdog.restart();

		if (held) {
			// Second press in the same hold: you are browsing the list, so
			// stop waiting and show it.
			linger.stop();
			revealed = true;
		} else {
			held = true;
			if (!revealed)
				linger.restart();
		}
	}

	// Alt came back up, which the panel reports because it is the one holding
	// the keyboard. Only a hold of our own is put away — the panel may be open
	// because the module was clicked, and an alt pressed over that is somebody
	// else's chord.
	function release(): void {
		if (held)
			close();
	}

	function run(target: string): void {
		switcher.running = false;
		switcher.command = ["hyprctl", "switchxkblayout", "all", target];
		switcher.running = true;
	}

	function isVirtual(name: string): bool {
		return name.startsWith("hl-virtual-keyboard");
	}

	function parse(json: string): void {
		let keyboards = [];
		try {
			keyboards = JSON.parse(json).keyboards ?? [];
		} catch (e) {
			return;
		}

		// fcitx5 publishes a virtual keyboard of its own, and Hyprland marks
		// *that* one `main` whenever it exists. It tracks a layout of its own
		// and comes and goes with the input context, so reading it means the
		// bar reverting to whatever fcitx5 last thought while the real keyboard
		// stayed where you put it. kb-layout-per-app.py skips it for the same
		// reason.
		const real = keyboards.filter(k => !isVirtual(k.name ?? ""));
		const main = real.find(k => k.main) ?? real[0];
		if (!main)
			return;

		layoutSpec = main.layout ?? "";
		variantSpec = main.variant ?? "";
		activeIndex = Math.min(main.active_layout_index ?? 0, layouts.length - 1);
		keymap = main.active_keymap ?? "";
	}

	// The name a layout goes by, and the same one whether or not it is the live
	// one. xkeyboard-config's rules list is where those names come from — it is
	// what every settings panel shows — with the config spelling as the
	// fallback if it cannot be read.
	function describe(layout: string, variant: string): string {
		if (variant !== "")
			return xkbNames[`${layout}:${variant}`] ?? `${layout} (${variant})`;
		return xkbNames[layout] ?? layout;
	}

	// evdev.lst, in two sections that matter:
	//
	//   ! layout
	//     us              English (US)
	//   ! variant
	//     intl            us: English (US, intl., with dead keys)
	//
	// A variant name is scoped to a layout by that `us:` prefix — `intl` alone
	// belongs to four of them — so the map is keyed the same way.
	function readNames(lst: string): void {
		const names = {};
		let section = "";

		for (const line of lst.split("\n")) {
			if (line.startsWith("!")) {
				section = line.slice(1).trim();
				continue;
			}
			if (section !== "layout" && section !== "variant")
				continue;

			const row = line.trim();
			const split = row.search(/\s/);
			if (split < 0)
				continue;

			const code = row.slice(0, split);
			const rest = row.slice(split).trim();

			if (section === "layout") {
				names[code] = rest;
			} else {
				// "us: English (US, intl., with dead keys)"
				const colon = rest.indexOf(":");
				if (colon > 0)
					names[`${rest.slice(0, colon).trim()}:${code}`] = rest.slice(colon + 1).trim();
			}
		}

		xkbNames = names;
	}

	// Read once at startup: the names never change under a running session, and
	// a missing file just leaves the config spelling in place.
	FileView {
		path: "/usr/share/X11/xkb/rules/evdev.lst"

		onLoaded: root.readNames(text())
	}

	// A tap-and-let-go alt+space is the common case and wants no window at all,
	// so the HUD waits to see whether alt is still down.
	Timer {
		id: linger

		// Long enough that a flip you do without looking shows nothing, short
		// enough that staying on the key feels like it answered you.
		interval: 300
		onTriggered: root.revealed = true
	}

	// Insurance, not part of the design: the HUD holds the keyboard while it is
	// up, so a hold that somehow never ends must not wedge it there. Longer
	// than anyone holds alt on purpose.
	Timer {
		id: watchdog

		interval: 10000
		onTriggered: root.close()
	}

	Process {
		id: switcher
	}

	// Seeds at launch and re-reads after every switch: the event says which
	// layout is live but not where it sits in the list, and the list itself
	// changes on a Hyprland config reload.
	Process {
		id: reload

		running: true
		command: ["hyprctl", "devices", "-j"]

		stdout: StdioCollector {
			onStreamFinished: root.parse(text)
		}
	}

	// Every keyboard reports the change — there are half a dozen of them, plus
	// fcitx5's virtual one — so one read a beat later covers the lot.
	Timer {
		id: debounce

		interval: 50
		onTriggered: reload.running = true
	}

	Connections {
		target: Hyprland

		function onRawEvent(event: HyprlandEvent): void {
			// payload: KEYBOARDNAME,LAYOUTNAME. fcitx5's virtual keyboard
			// reports moves nobody asked for; re-reading on those is what made
			// a switch look like it came back on its own.
			if (event.name === "activelayout" && !root.isVirtual(event.data.split(",")[0]))
				debounce.restart();
		}
	}
}
