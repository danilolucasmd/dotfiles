pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Everything the bar knows about audio: the default sink and source, the list
// of devices behind each of them, and whether either of the two transient
// windows (the volume OSD, the device panel) is up.
//
// A singleton because the reading is drawn in several places at once, and
// because the OSD has to appear for changes the bar had no part in: the
// XF86AudioRaiseVolume/LowerVolume binds run `wpctl`, and the only thing that
// hears about those is PipeWire itself.
Singleton {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool muted: sink?.audio?.muted ?? false
	readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
	readonly property string deviceName: label(sink)

	readonly property PwNode source: Pipewire.defaultAudioSource

	// The pickable devices. `isStream` drops the applications playing and
	// recording — those are nodes too — and a node with no audio interface is
	// something like a MIDI bridge, which cannot be a default anything.
	readonly property var sinks: nodeList(true)
	readonly property var sources: nodeList(false)

	readonly property bool allSourcesMuted: sources.length > 0 && sources.every(n => n.audio?.muted ?? false)

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
	property bool devicesOpen: false
	// Which section of the device panel the cursor starts in. Not a filter --
	// outputs and inputs are both on screen whichever way it was opened.
	property bool devicesInputs: false

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

	// Volume/mute state is only tracked for nodes something is holding on to,
	// and the panel draws the mute state of every device, not just the
	// default one.
	PwObjectTracker {
		objects: [...root.sinks, ...root.sources]
	}

	function nodeList(wantSinks: bool): var {
		return Pipewire.nodes.values.filter(n => n.isSink === wantSinks && !n.isStream && n.audio).sort((a, b) => label(a).localeCompare(label(b)));
	}

	// PipeWire names a node three ways and any of them can be empty; bluez
	// devices in particular often carry only the raw node name.
	function label(node: var): string {
		return node ? (node.description || node.nickname || node.name || "Unknown device") : "";
	}

	// Unguarded, unlike the change handlers above: a click is the user asking
	// for the OSD outright.
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

	// Writing `preferred…` is what actually moves the default: PipeWire keeps
	// it as metadata, and `defaultAudioSink`/`Source` are the read-only result.
	function setDefault(node: var, isInput: bool): void {
		if (isInput)
			Pipewire.preferredDefaultAudioSource = node;
		else
			Pipewire.preferredDefaultAudioSink = node;
	}

	function toggleNodeMute(node: var): void {
		if (node?.audio)
			node.audio.muted = !node.audio.muted;
	}

	// One switch for the lot: mute everything unless everything is already
	// muted, in which case bring it all back.
	function toggleAllSources(): void {
		const mute = !allSourcesMuted;
		for (const node of sources) {
			if (node.audio)
				node.audio.muted = mute;
		}
	}

	// Two ways in to one panel. Asking again for the section already showing
	// puts it away; asking for the other one moves the cursor over instead of
	// closing something that was never in the way.
	function toggleOutputs(): void {
		toggleDevices(false);
	}

	function toggleInputs(): void {
		toggleDevices(true);
	}

	function toggleDevices(inputs: bool): void {
		if (devicesOpen && devicesInputs === inputs) {
			devicesOpen = false;
			return;
		}
		devicesInputs = inputs;
		devicesOpen = true;
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
