import Quickshell.Io
import qs
import qs.components

// Bell with a count of stored (un-dismissed) past notifications, from the
// history file mako's on-notify hook appends to.
//
// This one loses a script entirely: waybar polled every 5s and mako's capture
// hook had to fire `pkill -RTMIN+9 waybar` to make the badge feel live. A
// FileView watching the log does both jobs, so the badge updates the instant a
// notification lands and costs nothing in between.
BarItem {
	id: root

	readonly property var entries: {
		const raw = log.text();
		if (!raw)
			return [];
		const out = [];
		for (const line of raw.split("\n")) {
			if (!line)
				continue;
			try {
				out.push(JSON.parse(line));
			} catch (e) {
			}
		}
		return out;
	}

	readonly property int count: entries.length

	rightMargin: Theme.gap

	// No hover tooltip: it listed the same history the menu shows, but flattened
	// to one line an entry and gone the moment you looked away from it.

	onClicked: menu.running = true

	FileView {
		id: log

		path: `${Paths.state}/mako-history/log.jsonl`
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
	}

	Process {
		id: menu

		command: [`${Paths.scripts}/notifications-menu.sh`]
	}

	BarText {
		text: root.count > 0 ? `󰂚 ${root.count}` : "󰂜"
		color: root.count > 0 ? Theme.yellow : Theme.dim
	}
}
