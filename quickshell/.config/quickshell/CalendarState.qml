pragma Singleton

import Quickshell

// Whether the calendar panel is up. A singleton for the same reason the other
// panels have one: the panel is a window of its own rather than a child of the
// clock module, so the two need somewhere to meet.
Singleton {
	property bool panelOpen: false

	function toggle(): void {
		panelOpen = !panelOpen;
	}

	function close(): void {
		panelOpen = false;
	}
}
