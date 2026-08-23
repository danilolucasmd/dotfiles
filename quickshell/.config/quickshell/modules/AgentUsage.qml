import Quickshell.Io
import qs
import qs.components

// Claude Code rate-limit usage: the 5h session window on the bar, the weekly
// window in the tooltip. The script stays — it reconciles three sources of
// truth and backs off a rate-limited endpoint, none of which Quickshell has
// an opinion about.
//
// What did change: the statusLine feed used to wake the module with
// `pkill -RTMIN+11 waybar`. Here the module watches that cache file instead,
// so the freshest source pushes an update with no signal plumbing.
BarItem {
	id: root

	readonly property var d: usage.data

	active: (d.text ?? "") !== ""
	tooltip: d.tooltip ?? ""
	rightMargin: Theme.gap

	onClicked: usage.refresh()
	onRightClicked: browser.running = true

	JsonScript {
		id: usage

		command: [`${Paths.scripts}/agent-usage.sh`]
		intervalMs: 15000
	}

	Process {
		id: browser

		command: ["xdg-open", "https://claude.ai/settings/usage"]
	}

	FileView {
		path: `${Paths.cache}/quickshell/agent-usage-statusline.json`
		watchChanges: true
		printErrors: false
		onFileChanged: usage.refresh()
	}

	BarText {
		text: root.d.text ?? ""

		color: {
			switch (root.d["class"] ?? "") {
			case "stale":
				return Theme.dim;
			case "critical":
				return Theme.red;
			case "warning":
				return Theme.yellow;
			case "ahead":
				return Theme.peach;
			default:
				return Theme.fg;
			}
		}
	}
}
