pragma Singleton

import Quickshell
import Quickshell.Io
import qs.components

// The Claude Code usage reading, and whether its panel is up.
//
// This used to live inside the bar module, which was fine while a tooltip was
// the whole UI. Now three things need it — the bar glyph, the panel, and the
// super+A IPC handler, which has to be able to open the panel without the
// pointer ever touching the bar — so the reading and the open flag sit here
// instead of being reached for through the bar's object tree.
Singleton {
	id: root

	readonly property var data: usage.data
	// One entry per rate-limit window the reading carried; see agent-usage.sh.
	readonly property var windows: data.windows ?? []
	// The script prints empty text when it has no reading at all to show.
	readonly property bool available: (data.text ?? "") !== ""

	property bool panelOpen: false

	function refresh(): void {
		usage.refresh();
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		// Opening is the one moment a tick is clearly worth spending: the
		// numbers are about to be read closely rather than glanced at.
		if (panelOpen)
			usage.refresh();
	}

	function close(): void {
		panelOpen = false;
	}

	JsonScript {
		id: usage

		command: [`${Paths.scripts}/agent-usage.sh`]
		intervalMs: 15000
	}

	// The statusLine feed is the freshest of the script's three sources, and it
	// lands whenever Claude Code redraws rather than on our timer — so watch the
	// file and re-read the moment it moves.
	FileView {
		path: `${Paths.cache}/quickshell/agent-usage-statusline.json`
		watchChanges: true
		printErrors: false
		onFileChanged: usage.refresh()
	}
}
