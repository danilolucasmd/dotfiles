pragma Singleton

import Quickshell
import Quickshell.Io
import qs.components

// Every coding agent's usage reading, which of them the panel is looking at,
// and whether the panel is up.
//
// This used to live inside the bar module, which was fine while a tooltip was
// the whole UI. Now four things need it — the bar glyph, the panel, the super+A
// IPC handler, which has to be able to open the panel without the pointer ever
// touching the bar, and the token history, which is fetched on a cadence of its
// own — so the reading and the open flag sit here instead of being reached for
// through the bar's object tree.
//
// Nothing here is written against Claude Code specifically. The scripts hand
// over a list of agents, each with its own name, icon and windows, and this
// picks one; Claude Code is simply the only provider installed. See
// scripts/agents/README.md.
Singleton {
	id: root

	// Every agent installed on this machine, whether or not it has a reading.
	readonly property var agents: usage.data.agents ?? []
	// Which of them the panel is drawing. Kept as an id rather than an index so
	// that an agent appearing or disappearing — a first Codex run, a signed-out
	// account — does not silently slide the selection onto its neighbour.
	property string selectedId: ""

	readonly property var agent: {
		for (const a of agents)
			if (a.id === selectedId)
				return a;
		return agents[0] ?? ({});
	}

	// One entry per rate-limit window the reading carried; see agents/README.md.
	readonly property var limits: agent.limits ?? []
	// The selected agent's token history, or an empty object while the panel is
	// shut and the parse has never been paid for.
	readonly property var tokens: (history.data.agents ?? ({}))[agent.id ?? ""] ?? ({})

	// Whether there is a number to put on the bar at all. An agent that is
	// installed but silent is worth a panel and not worth a bar module.
	readonly property bool available: agent.available ?? false

	// What the bar module draws: the selected agent, not a fixed one, so the tab
	// left open in the panel is the number on the bar. The percentage is the
	// first window that agent reported, which every provider orders
	// shortest-first — that is the one that actually bites, and the rest are a
	// click away.
	readonly property int pct: limits[0]?.pct ?? -1
	readonly property string text: available ? `${agent.icon ?? ""} ${pct}%` : ""

	// The bar's colour, worked out over every window rather than the one shown:
	// a weekly window about to run out matters even on a session that has
	// barely started. Staleness outranks all of it — dimmed, because a stale
	// high number is not something to alarm about.
	readonly property string cls: {
		if (!available)
			return "";
		if (agent.stale)
			return "stale";
		let worst = 0;
		for (const w of limits)
			worst = Math.max(worst, w.pct);
		if (worst >= 90)
			return "critical";
		if (worst >= 70)
			return "warning";
		const first = limits[0];
		if (first && first.pace >= 0 && first.pct > first.pace)
			return "ahead";
		return "normal";
	}

	property bool panelOpen: false

	function refresh(): void {
		usage.refresh();
		history.refresh();
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		// Opening is the one moment a tick is clearly worth spending: the
		// numbers are about to be read closely rather than glanced at.
		if (panelOpen)
			refresh();
	}

	function close(): void {
		panelOpen = false;
	}

	// Step the selection along the agent list, wrapping. The panel's left/right
	// keys use this; its tabs set `selectedId` directly. Nothing is refetched —
	// one run of the script carries every agent, so switching tabs is only ever
	// a change of which slice of the reading is drawn.
	function cycle(step: int): void {
		if (agents.length < 2)
			return;
		let i = 0;
		for (let n = 0; n < agents.length; n++)
			if (agents[n].id === agent.id)
				i = n;
		selectedId = agents[(i + step + agents.length) % agents.length].id;
	}

	JsonScript {
		id: usage

		command: [`${Paths.scripts}/agent-usage.sh`]
		intervalMs: 15000
	}

	// The token history is parsed out of the session transcripts, which costs
	// over a second on a cold cache and nothing at all while no session is
	// writing. It is also invisible unless the panel is open — so the timer only
	// runs then, and opening the panel is what pays for the first parse.
	JsonScript {
		id: history

		command: [`${Paths.scripts}/agent-tokens.sh`]
		intervalMs: root.panelOpen ? 30000 : 0
	}

	// The statusLine feed is the freshest of the limits script's three sources,
	// and it lands whenever Claude Code redraws rather than on our timer — so
	// watch the file and re-read the moment it moves.
	FileView {
		path: `${Paths.cache}/quickshell/agent-usage-statusline.json`
		watchChanges: true
		printErrors: false
		onFileChanged: usage.refresh()
	}
}
