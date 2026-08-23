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

	// Notification bodies arrive with markup and hard newlines in them, so each
	// entry is flattened to a single line — a tooltip is a glance, not a reader.
	function flatten(s: string): string {
		return (s ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
	}

	tooltip: {
		if (count === 0)
			return "No past notifications";
		// Newest first, same 12-line cap the old tooltip used.
		return entries.slice(-12).reverse().map(n => {
			let body = flatten(n.body);
			if (body.length > 80)
				body = `${body.slice(0, 80)}…`;
			return `• ${flatten(n.summary)}${body ? ` — ${body}` : ""}`;
		}).join("\n");
	}

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
