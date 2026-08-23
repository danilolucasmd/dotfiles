import QtQuick
import Quickshell
import Quickshell.Io

// Runs a script that prints one JSON object and exits, optionally on a timer.
// This is the shape the waybar custom modules already spoke, so the scripts
// that had no native Quickshell equivalent carried over untouched.
Scope {
	id: root

	property list<string> command: []
	// 0 disables the timer; refresh() then drives it.
	property int intervalMs: 0
	property var data: ({})

	function refresh(): void {
		proc.running = true;
	}

	Process {
		id: proc

		command: root.command
		running: true

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.data = JSON.parse(text);
				} catch (e) {
					// A script that printed nothing usable leaves the last
					// good reading in place rather than blanking the module.
				}
			}
		}
	}

	Timer {
		interval: root.intervalMs
		running: root.intervalMs > 0
		repeat: true
		onTriggered: proc.running = true
	}
}
