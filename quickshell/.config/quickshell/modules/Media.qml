import Quickshell.Services.Mpris
import qs
import qs.components

// Now playing: a bare play/pause glyph, with the now-playing card a click away.
//
// Replaces the `playerctl --follow` script with MPRIS directly. Which player
// the glyph speaks for is MediaState's decision, since the panel shows the same
// one.
BarItem {
	id: root

	readonly property MprisPlayer player: MediaState.active
	readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing

	active: player !== null
	rightMargin: Theme.gap
	highlighted: MediaState.panelOpen

	// The tooltip that named the track is gone: the panel says all of it, with
	// a scrubber the tooltip could never have held. Play/pause moved to the
	// right button along with it, for the reason the volume module's mute did —
	// pausing on a stray left click is a thing you then have to notice and undo.
	onClicked: MediaState.toggle()
	onRightClicked: player?.togglePlaying()
	onWheelUp: player?.next()
	onWheelDown: player?.previous()

	// The glyph is the *action*, not the state — pause while it is playing,
	// play while it is paused, the same way round as the panel's transport and
	// every other player. It read as a status light before, which is why it
	// looked inverted: a play triangle sitting there while music played.
	//
	// And it stays `fg` either way. Dimming the paused one said "paused" a
	// second time, in the register the bar otherwise reserves for a module with
	// nothing to say — the glyph already carries it.
	BarText {
		text: root.playing ? "󰏤" : "󰐊"
		font.pixelSize: Theme.fontIcon
	}
}
