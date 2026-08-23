import Quickshell.Services.Mpris
import qs
import qs.components

// Now playing: a bare glyph, the track in the tooltip, dimmed while paused.
//
// Replaces the `playerctl --follow` script with MPRIS directly. playerctl's
// default player is "most recently active"; the nearest equivalent here is to
// prefer whatever is actually playing and fall back to a paused player, which
// picks the same one in every case that matters (a single active player, or
// one playing while another sits paused).
BarItem {
	id: root

	readonly property MprisPlayer player: {
		const players = Mpris.players.values;
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

	readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing

	active: player !== null
	leftMargin: Theme.gap
	rightMargin: Theme.gap

	tooltip: {
		if (!player)
			return "";
		const artist = player.trackArtist ?? "";
		const title = player.trackTitle ?? "";
		const name = player.identity ?? "";
		let track = name;
		if (artist && title)
			track = `${artist} — ${title}`;
		else if (title)
			track = title;
		return `${playing ? "Playing" : "Paused"} (${name}): ${track}`;
	}

	onClicked: player?.togglePlaying()
	onWheelUp: player?.next()
	onWheelDown: player?.previous()

	BarText {
		text: root.playing ? "󰐊" : "󰏤"
		color: root.playing ? Theme.fg : Theme.dim
		font.pixelSize: Theme.fontIcon
	}
}
