pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The clipboard history: the entries, the capture switch, and what the launcher
// does to a chosen one.
//
// The store behind this is cliphist, fed by the two `wl-paste --watch` processes
// that scripts/clipboard.sh starts. It replaced elephant's clipboard provider
// when walker went; every action here is a subcommand of that script, because
// an entry is addressed by a cliphist id and cliphist itself wants the whole
// listing line back to delete one. See the script for that seam.
//
// There is no panel of its own. super+V opens the launcher already switched to
// its clipboard mode, which is the same window every other query goes through
// -- the history is a list you search, and the launcher is the thing that
// searches lists.
Singleton {
	id: root

	// [{ id, kind: "text"|"image", preview, app, at, ext?, path?, width?,
	// height?, size? }], newest first. Empty until the first load; see
	// `reload`. `app` and `at` are the note scripts/clipboard.sh takes at copy
	// time -- cliphist stores neither -- and are "" and 0 for anything copied
	// before it started taking them.
	property var entries: []

	// Whether the wl-paste watchers are up. False is a deliberate pause rather
	// than a failure, and the panel says so -- a history that has silently
	// stopped recording looks exactly like one nobody has copied into.
	property bool watching: true

	// "all" | "text" | "image". The old ctrl+i, which cycled the same three.
	property string filter: "all"

	readonly property var shown: filter === "all" ? entries : entries.filter(e => e.kind === filter)

	readonly property string script: `${Paths.scripts}/clipboard.sh`

	// The selected text entry as it was actually copied, newlines and all, for
	// the preview pane. `entries` cannot carry this: cliphist's listing folds
	// every entry onto one line, which is what makes it a listing, so the real
	// text costs a `decode` and is only ever fetched for the one row the cursor
	// is on. Images need none of this -- their file is already on disk.
	property string previewText: ""

	// { chars, words, bytes, truncated } for the same entry, which is the rest
	// of what the decode came back with. Counts over the whole entry and not
	// over the 4KB `previewText` holds; null counts mean the entry was past the
	// script's cap and nothing honest can be said about them.
	property var previewInfo: ({})

	// Which entry `previewText` belongs to -- the row the cursor is on now.
	property int previewId: -1

	// Which entry the decode currently in flight was launched for. The same
	// number as `previewId` almost always, and different for exactly as long as
	// it takes a fork to answer a cursor that has since moved: that gap is what
	// this exists to catch, so a late decode is dropped rather than drawn under
	// whatever row the cursor reached in the meantime.
	property int decodingId: -1

	// Called every time the launcher enters clipboard mode rather than on a
	// timer: the list is only ever looked at while the panel is up, and the
	// listing decodes any image it has not cached yet, which is not work to
	// repeat in the background.
	function reload(): void {
		list.running = true;
		probe.running = true;
		// The ids survive a reload, but a deleted entry's would not, and
		// nothing here is worth keeping across one.
		previewId = -1;
		previewText = "";
		previewInfo = {};
	}

	// Onto the clipboard and into the window that had focus. Fire-and-forget:
	// the script backgrounds its own wait for the launcher's layer surface to
	// go away, and nothing here has anything to do once it has started.
	function paste(id: int): void {
		Quickshell.execDetached([script, "paste", String(id)]);
	}

	// ctrl+o on an image, which opens it in tensaku. Silently does nothing on a
	// text entry, and the panel only offers it on an image.
	function edit(id: int): void {
		Quickshell.execDetached([script, "edit", String(id)]);
	}

	function remove(id: int): void {
		mutate.command = [script, "delete", String(id)];
		mutate.running = true;
	}

	function wipe(): void {
		mutate.command = [script, "wipe"];
		mutate.running = true;
	}

	// Debounced, because holding Down walks the list faster than a fork can
	// answer and every intermediate row would be one. 90ms is under the point
	// where the pane feels like it is trailing the cursor.
	function loadPreview(id: int): void {
		if (id === previewId)
			return;

		previewId = id;
		// What the last row decoded to is left on screen until this row answers,
		// rather than blanked here. Clearing looked correct and read as a
		// flicker: every step through the list emptied the pane and dropped the
		// four count rows out of the information block for the length of a fork,
		// so walking ten entries was ten blinks. The stale text is only ever up
		// for the debounce plus the decode, and it is replaced, never appended
		// to.
		previewDebounce.restart();
	}

	function togglePause(): void {
		// Flipped here rather than waiting for the probe to come back, so the
		// indicator changes on the keystroke; the probe confirms it a moment
		// later and is the one that wins if the pkill did not take.
		watching = !watching;
		Quickshell.execDetached([script, watching ? "watch" : "pause"]);
		probe.running = true;
	}

	function cycleFilter(): void {
		filter = filter === "all" ? "text" : (filter === "text" ? "image" : "all");
	}

	Process {
		id: list

		command: [root.script, "list"]

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.entries = JSON.parse(text).entries ?? [];
				} catch (e) {
					// An empty list is a visible failure that points at the
					// script; throwing here would take the shell with it.
					root.entries = [];
				}
			}
		}
	}

	Timer {
		id: previewDebounce

		interval: 90
		onTriggered: {
			// Anything still running is answering a row the cursor has already
			// left, and this is the same Process object it would have to be
			// restarted on anyway.
			decode.running = false;
			root.decodingId = root.previewId;
			decode.command = [root.script, "preview", String(root.previewId)];
			decode.running = true;
		}
	}

	Process {
		id: decode

		stdout: StdioCollector {
			onStreamFinished: {
				// A decode the cursor has already moved off, dropped rather
				// than drawn under whatever row it reached in the meantime.
				if (root.decodingId !== root.previewId)
					return;

				try {
					const info = JSON.parse(text);
					root.previewText = info.text ?? "";
					root.previewInfo = info;
				} catch (e) {
					root.previewText = "";
					root.previewInfo = {};
				}
			}
		}
	}

	Process {
		id: probe

		command: [root.script, "status"]

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.watching = JSON.parse(text).watching === true;
				} catch (e) {
				}
			}
		}
	}

	// Delete and wipe, which are the two that change what `list` would say.
	// Reloading on exit rather than optimistically dropping the row locally:
	// cliphist is the only thing that knows whether the delete took.
	Process {
		id: mutate

		onExited: root.reload()
	}
}
