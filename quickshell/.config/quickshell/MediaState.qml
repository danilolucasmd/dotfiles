pragma Singleton

import Quickshell
import Quickshell.Services.Mpris

// Which player the bar module and its panel speak for.
//
// One player, not a list. MPRIS has no finer grain to offer for the case that
// prompted this: Brave and Firefox each publish a single bus name for the whole
// browser (the name carries the browser's pid) pointed at whichever tab holds
// the active media session, so three YouTube tabs are one player that follows
// the tab you last touched. Separate applications *are* separate players — that
// part works — but the panel shows the active one rather than a list of them.
Singleton {
	id: root

	property bool panelOpen: false

	readonly property var players: Mpris.players.values

	// playerctl's default player is "most recently active"; the nearest
	// equivalent here is to prefer whatever is actually playing and fall back
	// to a paused player, which picks the same one in every case that matters
	// (a single active player, or one playing while another sits paused).
	readonly property MprisPlayer active: {
		let paused = null;
		for (let i = 0; i < players.length; i++) {
			const p = players[i];
			if (p.playbackState === MprisPlaybackState.Playing)
				return p;
			if (!paused && p.playbackState === MprisPlaybackState.Paused)
				paused = p;
		}
		return paused;
	}

	function toggle(): void {
		panelOpen = !panelOpen;
	}

	function close(): void {
		panelOpen = false;
	}
}
