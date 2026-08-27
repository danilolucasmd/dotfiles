pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

// The keybind cheatsheet behind super+shift+slash.
//
// The list is built from `hyprctl binds -j` at open time by scripts/keybinds.py,
// so it is never a second copy of hyprland.conf that could drift -- adding a
// `bindd` is all it takes for it to appear here. It used to be that script's own
// job to draw the sheet, by padding a key column to a fixed width and piping the
// lot into `walker --dmenu`; when walker went the drawing came here and the
// script kept the half it was always better at.
//
// Selecting a row runs the bind, so the sheet doubles as a command palette.
Singleton {
	id: root

	property bool panelOpen: false
	property string query: ""
	property int cursor: 0

	// [{ keys: [...], description, note, dispatcher, arg }], in hyprctl's order,
	// which is the order they appear in hyprland.conf.
	readonly property var binds: source.data.binds ?? []

	readonly property var results: {
		const q = query.trim().toLowerCase();
		if (q === "")
			return binds;

		// Every word has to land somewhere in the row, but not in the same
		// place: "super v clip" should find the clipboard bind, and the words
		// are split across the keys and the description.
		const terms = q.split(/\s+/);
		return binds.filter(b => {
			const hay = `${b.keys.join(" ")} ${b.description} ${b.note}`.toLowerCase();
			return terms.every(t => hay.includes(t));
		});
	}

	readonly property var current: results[cursor] ?? null

	function toggle(): void {
		if (panelOpen) {
			close();
			return;
		}
		// Rebuilt on every open rather than on a timer: the bind table only
		// changes when hyprland.conf does, and this is the one moment anybody
		// is looking at it.
		source.refresh();
		query = "";
		cursor = 0;
		panelOpen = true;
	}

	function close(): void {
		panelOpen = false;
	}

	// Closing first is not cosmetic: the sheet holds a focus grab, and a good
	// third of what it can run is `exec` on something that wants the keyboard
	// -- this panel's own bind included.
	function run(bind: var): void {
		if (!bind || bind.dispatcher === "")
			return;

		panelOpen = false;
		Hyprland.dispatch(bind.arg === "" ? bind.dispatcher : `${bind.dispatcher} ${bind.arg}`);
	}

	JsonScript {
		id: source

		command: [`${Paths.scripts}/keybinds.py`]
	}
}
