pragma Singleton

import Quickshell
import qs.components

// The current conditions, and whether the weather panel is up. Split out of the
// module for the same reason AgentUsageState was: the reading is now drawn in
// two places, and the panel is a window of its own rather than a child of the
// bar item.
Singleton {
	id: root

	readonly property var data: weather.data
	readonly property bool available: (data.text ?? "") !== ""

	property bool panelOpen: false

	function refresh(): void {
		weather.refresh();
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		// A 15-minute poll means the reading on screen can be a quarter of an
		// hour old; opening the panel is the moment to go and check.
		if (panelOpen)
			weather.refresh();
	}

	function close(): void {
		panelOpen = false;
	}

	JsonScript {
		id: weather

		command: [`${Paths.scripts}/weather.sh`]
		intervalMs: 900000
	}
}
