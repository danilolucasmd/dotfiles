pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// The wallpaper picker: the collection, where the cursor is in it, and setting
// the one it lands on.
//
// The collection is ~/.config/wallpapers, which is the `wallpapers` stow
// package -- so what the picker offers is exactly what a fresh clone would
// bring, and dropping an image in the repo is all it takes to add one. See
// scripts/wallpaper.sh for how a choice is made to stick.
Singleton {
	id: root

	property bool panelOpen: false
	// Which one the panel is previewing. Not the applied one: moving the cursor
	// changes nothing on screen but the preview, and it is `apply()` that
	// commits.
	property int cursor: 0

	// [{ path, real, name }], in the order the strip draws them, which is the
	// directory's own collation order.
	readonly property var wallpapers: source.data.wallpapers ?? []
	// The one hyprpaper is actually showing, fully resolved -- compare it
	// against `real` and never against `path`.
	readonly property string current: source.data.current ?? ""

	readonly property var selected: wallpapers[cursor] ?? null

	// Where the applied one sits in the strip, which is where the panel opens
	// and what the name line says "current" against. -1 when hyprpaper is
	// showing something that is not in the collection at all, which is not an
	// error worth reporting: it just means nothing is labelled and the picker
	// opens at the top.
	readonly property int currentIndex: indexOf(current, wallpapers)

	// Taking the two halves as arguments rather than reading the properties is
	// what makes this usable from the listing handler below. Called there on a
	// payload that has only just been parsed, the derived properties above are
	// not reliably caught up yet -- the first version read `currentIndex` and
	// reopened the picker on the *previously* applied wallpaper, with the green
	// mark correctly on the new one two thumbnails away.
	function indexOf(real: string, list: var): int {
		for (let i = 0; i < list.length; i++)
			if (list[i].real === real)
				return i;
		return -1;
	}

	function toggle(): void {
		if (panelOpen) {
			close();
			return;
		}
		// Re-listed on every open rather than on a timer: the directory only
		// changes when the repo does, and the *active* wallpaper is the half
		// that matters -- it can have been changed by hand since the last open.
		source.refresh();
		panelOpen = true;
	}

	function close(): void {
		panelOpen = false;
	}

	function step(delta: int): void {
		const n = wallpapers.length;
		if (n === 0)
			return;
		// Wraps both ways, so the strip is a ring: the last one is one press
		// left of the first, which is the whole point of a picker you walk
		// rather than search.
		cursor = (cursor + delta % n + n) % n;
	}

	function apply(): void {
		const wallpaper = selected;
		if (!wallpaper)
			return;

		setter.command = [`${Paths.scripts}/wallpaper.sh`, "set", wallpaper.path];
		setter.running = true;
		panelOpen = false;
	}

	JsonScript {
		id: source

		command: [`${Paths.scripts}/wallpaper.sh`, "list"]

		// Every listing puts the cursor back on what is up. That covers the
		// open -- the panel is meant to start on the current wallpaper, which
		// is what makes it look like the desktop until you move -- and it
		// covers the case where the collection changed under a cursor that is
		// now pointing at a different image than it was.
		onDataChanged: root.cursor = Math.max(root.indexOf(source.data.current ?? "", source.data.wallpapers ?? []), 0)
	}

	Process {
		id: setter
	}
}
