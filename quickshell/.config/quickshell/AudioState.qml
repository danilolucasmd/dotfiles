pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default sink, and whether the volume OSD is up.
//
// A singleton because the volume is now read in two places — the bar module and
// the OSD — and because the OSD has to appear for changes the bar had no part
// in: the XF86AudioRaiseVolume/LowerVolume binds run `wpctl`, and the only
// thing that hears about those is PipeWire itself.
Singleton {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool muted: sink?.audio?.muted ?? false
	readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
	readonly property string deviceName: sink?.description || sink?.nickname || sink?.name || "Output"

	// Shared by the bar module and the OSD so the two never disagree about
	// which speaker is drawn.
	readonly property string icon: {
		if (muted)
			return "󰝟";
		if (volume < 34)
			return "󰕿";
		if (volume < 67)
			return "󰖀";
		return "󰕾";
	}

	property bool osdShown: false

	// The first reading arrives a moment after launch, and a sink switch brings
	// a whole new set of numbers with it. Neither is something the user did, so
	// neither should flash the OSD; both re-arm it instead.
	property bool armed: false

	onVolumeChanged: {
		if (armed)
			show();
	}
	onMutedChanged: {
		if (armed)
			show();
	}
	onSinkChanged: {
		armed = false;
		arm.restart();
	}

	// Volume/mute state is only tracked for nodes something is holding on to.
	PwObjectTracker {
		objects: [root.sink]
	}

	// Unguarded, unlike the change handlers above: a click on the bar module is
	// the user asking for the OSD outright.
	function show(): void {
		osdShown = true;
		hide.restart();
	}

	function step(delta: int): void {
		if (!sink?.audio)
			return;
		sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta / 100));
		// Already at the rail: the volume does not change, so nothing would
		// bring the OSD up, but the keypress still deserves an answer.
		show();
	}

	function toggleMute(): void {
		if (sink?.audio)
			sink.audio.muted = !sink.audio.muted;
	}

	Timer {
		id: hide

		interval: 1500

		onTriggered: root.osdShown = false
	}

	Timer {
		id: arm

		interval: 1000
		running: true

		onTriggered: root.armed = true
	}
}
