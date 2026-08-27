pragma Singleton

import Quickshell
import Quickshell.Io
import qs.components

// The current conditions, where they are for, and whether the weather panel is
// up. Split out of the module for the same reason AgentUsageState was: the
// reading is now drawn in two places, and the panel is a window of its own
// rather than a child of the bar item.
Singleton {
	id: root

	readonly property var data: weather.data
	readonly property bool available: (data.text ?? "") !== ""

	// The address typed into the panel, as {lat, lon, place}, or null while the
	// reading is following the machine around. Persisted, because a location
	// you went to the trouble of typing should still be there tomorrow.
	property var custom: null
	readonly property bool detecting: custom === null

	property bool panelOpen: false

	// The address box the panel opens over the place name, and what the last
	// lookup had to say about what was typed into it.
	property bool editing: false
	property bool resolving: false
	property string error: ""

	function refresh(): void {
		weather.refresh();
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		// A 15-minute poll means the reading on screen can be a quarter of an
		// hour old; opening the panel is the moment to go and check.
		if (panelOpen)
			weather.refresh();
		else
			cancelEdit();
	}

	function close(): void {
		panelOpen = false;
		cancelEdit();
	}

	function edit(): void {
		error = "";
		editing = true;
	}

	function cancelEdit(): void {
		editing = false;
		resolving = false;
		error = "";
	}

	// Resolve what was typed before adopting it. A typo therefore leaves the
	// current reading alone and puts the complaint under the box, rather than
	// swapping the panel over to a location that turns out not to exist.
	function resolve(query: string): void {
		const q = query.trim();
		if (q === "" || resolving)
			return;

		error = "";
		resolving = true;
		lookup.command = [`${Paths.scripts}/weather-place.sh`, q];
		lookup.running = true;
	}

	// Back to following the machine. The saved file is emptied rather than
	// deleted: FileView owns the path either way, and "null" is a location that
	// reads back as no location.
	function clearCustom(): void {
		if (!custom)
			return;

		custom = null;
		store.setText("null");
		cancelEdit();
		refresh();
	}

	// Read blocking, and declared ahead of the script below, so that a saved
	// location is already in hand when the first fetch of the session starts.
	// Loaded the usual asynchronous way it would land a beat too late, and
	// every login would show one reading for the wrong place.
	FileView {
		id: store

		path: `${Paths.state}/quickshell/weather-location.json`
		blockLoading: true
		printErrors: false
		atomicWrites: true

		onLoaded: {
			try {
				const saved = JSON.parse(text());
				if (saved?.place)
					root.custom = saved;
			} catch (e) {
				// An unparseable file is a file written by something that is
				// not this; leaving it alone and geolocating is the harmless
				// reading of that.
			}
		}
	}

	// FileView will not create the directory it writes into. The notification
	// store makes the same directory at startup, but neither singleton can rely
	// on the other having loaded first, and mkdir -p costs nothing twice.
	Process {
		command: ["mkdir", "-p", `${Paths.state}/quickshell`]
		running: true
	}

	JsonScript {
		id: weather

		command: root.custom ? [`${Paths.scripts}/weather.sh`, String(root.custom.lat), String(root.custom.lon), root.custom.place] : [`${Paths.scripts}/weather.sh`]
		intervalMs: 900000
	}

	Process {
		id: lookup

		stdout: StdioCollector {
			onStreamFinished: {
				root.resolving = false;

				let found = {};
				try {
					found = JSON.parse(text);
				} catch (e) {
					// A script that printed nothing at all -- it was killed, or
					// jq is missing -- falls through to the same message as an
					// address nobody has heard of.
				}

				if (!found.place) {
					root.error = found.error ?? "Nothing found for that address.";
					return;
				}

				root.custom = found;
				store.setText(JSON.stringify(found));
				root.editing = false;
				root.refresh();
			}
		}
	}
}
