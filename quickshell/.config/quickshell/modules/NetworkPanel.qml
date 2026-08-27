import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs
import qs.components

// The network panel, opened by clicking the bar module or by super+shift+W.
//
// Three things the glyph in the bar cannot say: which of the two links is
// actually carrying the traffic, what that link is doing right now, and what
// else the radio can see. The middle one is the reason the counters exist —
// "is it the network or is it the site" is the question anyone asks first, and
// a ping and a loss figure answer it without opening a terminal.
Panel {
	id: root

	readonly property var wifiDevice: NetworkState.wifiDevice
	readonly property var wiredDevice: NetworkState.wiredDevice

	// The list, headers and all, as one flat model: a single ListView scrolls
	// and keeps the cursor in view for free, where two Repeaters in a Flickable
	// would need both worked out by hand.
	readonly property var rows: {
		const out = [];
		if (NetworkState.knownNetworks.length > 0) {
			out.push({
				header: "Known networks"
			});
			for (const n of NetworkState.knownNetworks)
				out.push({
					net: n
				});
		}
		if (NetworkState.otherNetworks.length > 0) {
			out.push({
				header: "Other networks"
			});
			for (const n of NetworkState.otherNetworks)
				out.push({
					net: n
				});
		}
		return out;
	}

	// The keyboard cursor, held as the network's name rather than as a row
	// index: the list is sorted by signal strength and rescanned the whole time
	// the panel is up, so an index would slide onto a different network every
	// time two access points swapped places. The pointer moves it too, so there
	// is only ever one highlighted row however you arrived at it.
	property string cursorName: ""

	// Where that name currently sits, or the first row anyone can do anything
	// with — and -1 when there is nothing in range at all.
	readonly property int cursor: {
		const i = rows.findIndex(r => r.net && r.net.name === cursorName);
		return i >= 0 ? i : rows.findIndex(r => r.net);
	}

	// The network being joined for the first time, while its password is being
	// typed and until it either associates or is refused.
	property var pending: null
	property string error: ""
	// Submitted, waiting on the supplicant. The prompt stays up — a refusal
	// comes back here and the password is still in the box.
	property bool awaiting: false

	open: NetworkState.panelOpen
	onDismissed: NetworkState.close()
	onRefreshRequested: NetworkState.reset()
	// Opening puts the cursor on the network in use, which is where you are
	// counting from when you go looking for another one.
	onOpenChanged: {
		if (open) {
			cursorName = NetworkState.wifiNetwork?.name ?? "";
			cancelPrompt();
		}
	}
	onKeyPressed: event => {
		if (press(event.key))
			event.accepted = true;
	}

	// The module sits in the bar's right cluster, so the panel drops from the
	// same corner rather than from the middle of the screen.
	anchors.right: true
	margins.right: 8

	// Split out of the handler so the panel's keys are one plain function of
	// the key rather than something only a real key event can reach.
	function press(key: int): bool {
		switch (key) {
		case Qt.Key_J:
		case Qt.Key_Down:
			step(1);
			return true;
		case Qt.Key_K:
		case Qt.Key_Up:
			step(-1);
			return true;
		case Qt.Key_Space:
		case Qt.Key_Return:
		case Qt.Key_Enter:
			activate(rows[cursor]?.net ?? null);
			return true;
		case Qt.Key_W:
			NetworkState.toggleWifi();
			return true;
		case Qt.Key_D:
			NetworkState.wifiNetwork?.disconnect();
			return true;
		case Qt.Key_F:
			forget(rows[cursor]?.net ?? null);
			return true;
		case Qt.Key_S:
			NetworkState.toggleSpeedTest();
			return true;
		default:
			return false;
		}
	}

	// Headers are passed over rather than landed on: they are not rows anyone
	// can do anything with.
	function step(delta: int): void {
		const count = rows.length;
		if (count === 0)
			return;
		let i = cursor < 0 ? (delta > 0 ? -1 : 0) : cursor;
		for (let n = 0; n < count; n++) {
			i = (i + delta + count) % count;
			if (rows[i].net) {
				cursorName = rows[i].net.name;
				return;
			}
		}
	}

	function activate(net: var): void {
		if (!net || net.connected || net.stateChanging)
			return;
		// A network NetworkManager already holds settings for needs nothing
		// typed, and an open one has nothing to type.
		if (net.known || !NetworkState.secured(net)) {
			net.connect();
			return;
		}
		pending = net;
		error = "";
		awaiting = false;
		psk.text = "";
		psk.forceActiveFocus();
	}

	function submit(): void {
		if (!pending || psk.text === "")
			return;
		error = "";
		awaiting = true;
		pending.connectWithPsk(psk.text);
	}

	function cancelPrompt(): void {
		pending = null;
		error = "";
		awaiting = false;
		psk.text = "";
		// The field had the keyboard; without this the panel would have no way
		// of hearing its own keys again, Escape included.
		takeFocus();
	}

	function forget(net: var): void {
		if (net?.known)
			net.forget();
	}

	// One of the two throughput cells: the figure once it has been measured,
	// an ellipsis while the phase that measures it is running, and a dash for
	// a run nobody has asked for — a zero would be a claim about the link.
	function speedValue(bytesPerSecond: real, phase: string): string {
		if (bytesPerSecond > 0)
			return NetworkState.formatSpeed(bytesPerSecond);
		if (NetworkState.speedRunning && NetworkState.speedPhase === phase)
			return "…";
		return "—";
	}

	// ------------------------------------------------------------------
	// The links
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 10

		Link {
			visible: root.wiredDevice !== null

			icon: "󰈀"
			active: NetworkState.wiredUp
			primary: NetworkState.wiredUp
			// Always "Ethernet": NetworkManager's own name for the profile is
			// not something Quickshell carries, and the device's network is
			// named after the interface, which the subtitle already says.
			title: "Ethernet"
			subtitle: {
				const dev = root.wiredDevice;
				if (!dev)
					return "";
				if (dev.connected) {
					const speed = dev.linkSpeed > 0 ? ` · ${dev.linkSpeed} Mb/s` : "";
					return `${dev.name}${speed}`;
				}
				// A cable that is in but has no address is a different fault
				// from no cable at all, and only one of them is worth going to
				// look at the socket for.
				return dev.hasLink ? `${dev.name} · cable in, no address` : `${dev.name} · unplugged`;
			}
		}

		Link {
			visible: root.wifiDevice !== null

			icon: NetworkState.wifiUp ? NetworkState.strengthIcon(NetworkState.signal) : "󰤯"
			active: NetworkState.wifiUp
			primary: NetworkState.wifiUp && !NetworkState.wiredUp
			title: NetworkState.wifiUp ? (NetworkState.wifiNetwork?.name || root.wifiDevice?.name || "Wi-Fi") : "Wi-Fi"
			subtitle: {
				if (NetworkState.wifiBlocked)
					return "blocked by the hardware switch";
				if (!NetworkState.wifiEnabled)
					return "off";
				if (NetworkState.wifiUp)
					return `${NetworkState.securityLabel(NetworkState.wifiNetwork)} · ${NetworkState.signal}%`;
				return "not connected";
			}

			// The radio switch sits on the row it switches rather than in the
			// card's corner, so it is obvious which of the two links it is
			// about.
			switchVisible: true
			switchChecked: NetworkState.wifiEnabled
			switchEnabled: !NetworkState.wifiBlocked

			onSwitchToggled: NetworkState.toggleWifi()
		}

		BarText {
			Layout.fillWidth: true
			visible: !root.wifiDevice && !root.wiredDevice

			text: "No network devices. NetworkManager reports nothing it manages."
			color: Theme.dim
			wrapMode: Text.Wrap
		}
	}

	// ------------------------------------------------------------------
	// What the active link is doing
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		visible: NetworkState.online
		spacing: 5

		StatRow {
			leftLabel: "Ping"
			leftValue: NetworkState.ping > 0 ? `${Math.round(NetworkState.ping)} ms` : "—"
			// A ping that is merely slow is still a ping; only a link dropping
			// packets is worth a colour.
			rightLabel: "Packet loss"
			rightValue: `${Math.round(NetworkState.packetLoss)}%`
			rightColor: NetworkState.packetLoss >= 20 ? Theme.red : NetworkState.packetLoss > 0 ? Theme.yellow : Theme.fg
		}

		StatRow {
			leftLabel: "Receiving"
			leftValue: NetworkState.formatRate(NetworkState.rxRate)
			rightLabel: "Sending"
			rightValue: NetworkState.formatRate(NetworkState.txRate)
		}

		// The kernel's own counters, so these are totals since boot rather than
		// since the panel was opened — which is the figure worth having, and
		// the only one available without keeping a tally of our own.
		StatRow {
			leftLabel: "Downloaded"
			leftValue: NetworkState.formatBytes(NetworkState.lastSample?.rx ?? 0)
			rightLabel: "Uploaded"
			rightValue: NetworkState.formatBytes(NetworkState.lastSample?.tx ?? 0)
		}

		StatRow {
			leftLabel: "IPv4"
			leftValue: NetworkState.address || "—"
			rightLabel: "Gateway"
			rightValue: NetworkState.gateway || "—"
		}

		StatRow {
			leftLabel: "DNS"
			leftValue: NetworkState.dns || "—"
			// One wide column: a link with two resolvers has no room left for a
			// second pair.
			single: true
		}
	}

	// ------------------------------------------------------------------
	// What the link can do
	//
	// The counters above say what the link is carrying, which on an idle
	// machine is nothing whatever the line is worth. This section is the other
	// question — how fast is it — and it is a button rather than another
	// reading because answering it means moving a couple of hundred megabytes.
	// ------------------------------------------------------------------

	ColumnLayout {
		id: speed

		// How far through the current phase the bar is drawn. Time against the
		// duration the script declared rather than bytes against a total:
		// nothing reports progress mid-transfer, but the phase is cut off at a
		// fixed number of seconds, so the clock is the honest measure of it.
		property real sweep: 0

		Layout.fillWidth: true
		visible: NetworkState.online
		spacing: 5

		// Receiving / Sending up there and Download / Upload down here are both
		// a link speed, in the same typeface, in the same two-column row -- so
		// without a rule the second pair reads as more of the first rather than
		// as an answer to a different question. Above it is what the link is
		// carrying; below it is what it can do when asked. The same rule divides
		// the performance panel's disk test from that drive's live rates.
		//
		// Theme.line, the bar's own hairline, which lands near #6d6d6d on this
		// card. The card's #3f3f3f border colour disappears into the surface at
		// one pixel.
		Rectangle {
			Layout.fillWidth: true
			Layout.bottomMargin: 7

			implicitHeight: 1
			color: Theme.line
		}

		StatRow {
			leftLabel: "Download"
			leftValue: root.speedValue(NetworkState.speedDownload, "download")
			leftColor: NetworkState.speedPhase === "download" ? Theme.dim : Theme.fg
			rightLabel: "Upload"
			rightValue: root.speedValue(NetworkState.speedUpload, "upload")
			rightColor: NetworkState.speedPhase === "upload" ? Theme.dim : Theme.fg
		}

		// Only once a run has produced them: an empty pair of cells above the
		// button would read as a link with no latency rather than as a test
		// nobody has asked for yet.
		StatRow {
			visible: NetworkState.speedLatency > 0

			leftLabel: "Latency"
			leftValue: `${Math.round(NetworkState.speedLatency)} ms`
			rightLabel: "Jitter"
			rightValue: `${Math.round(NetworkState.speedJitter)} ms`
		}

		// The edge that answered, on a row of its own: an airport code and a
		// city name have no chance of sharing a half-width cell with anything.
		StatRow {
			visible: NetworkState.speedServer !== ""

			leftLabel: "Server"
			leftValue: `${NetworkState.speedServer} · ${NetworkState.speedLocation}`
			single: true
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.topMargin: 2

			implicitHeight: 4
			radius: height / 2
			color: Theme.track
			// Kept in the layout rather than hidden, so the button underneath
			// does not jump down the card the moment a run starts.
			opacity: NetworkState.speedRunning ? 1 : 0

			Behavior on opacity {
				NumberAnimation {
					duration: 150
				}
			}

			Rectangle {
				width: speed.sweep * parent.width
				height: parent.height
				radius: parent.radius
				color: Theme.blue
			}
		}

		// Each phase gets its own sweep of the bar: the script says how long
		// the one it is starting will take, and the line it prints is what
		// starts the animation.
		NumberAnimation {
			id: sweepAnimation

			target: speed
			property: "sweep"
			from: 0
			to: 1
			easing.type: Easing.InOutSine
		}

		Connections {
			target: NetworkState

			function onSpeedPhaseChanged(): void {
				sweepAnimation.stop();
				if (NetworkState.speedSeconds > 0) {
					sweepAnimation.duration = NetworkState.speedSeconds * 1000;
					sweepAnimation.start();
				} else {
					// The two phases that measure nothing: "" is a run being
					// cleared before it starts, "done" is one that has ended —
					// so the bar is empty for the first and full for the
					// second, rather than snapping back as it fades out.
					speed.sweep = NetworkState.speedPhase === "" ? 0 : 1;
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.topMargin: 2
			spacing: 8

			Run {
				label: NetworkState.speedRunning ? "Cancel" : NetworkState.speedPhase !== "" ? "Test again" : "Speed test"

				onClicked: NetworkState.toggleSpeedTest()
			}

			BarText {
				Layout.fillWidth: true

				text: {
					if (NetworkState.speedError !== "")
						return NetworkState.speedError;
					switch (NetworkState.speedPhase) {
					case "latency":
						return "Measuring latency…";
					case "download":
						return "Measuring download…";
					case "upload":
						return "Measuring upload…";
					default:
						// What a run costs, said before it is asked for: on a
						// tethered phone that is the whole decision. Time
						// rather than megabytes, because each phase runs for a
						// fixed number of seconds — the faster the link, the
						// more it moves in them.
						return NetworkState.speedRunning ? "" : "12 s at full speed";
					}
				}
				color: NetworkState.speedError !== "" ? Theme.red : Theme.dim
				elide: Text.ElideRight
			}
		}
	}

	// ------------------------------------------------------------------
	// The networks in range
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		visible: root.wifiDevice !== null
		spacing: 6

		ListView {
			id: list

			Layout.fillWidth: true
			// Tall enough for a handful of networks and no taller: a busy
			// street would otherwise give the card the height of the screen.
			// Past that the list scrolls, and j/k drag it along.
			Layout.preferredHeight: Math.min(contentHeight, 260)
			visible: root.rows.length > 0

			clip: true
			boundsBehavior: Flickable.StopAtBounds
			currentIndex: root.cursor
			// Keeps the cursor on screen when the keys walk it past the edge.
			highlightRangeMode: ListView.ApplyRange
			preferredHighlightBegin: 0
			preferredHighlightEnd: height
			highlightMoveDuration: 150

			model: root.rows

			delegate: Item {
				id: row

				required property var modelData
				required property int index

				readonly property var net: modelData.net ?? null

				width: list.width
				implicitHeight: net ? 38 : 26

				// A section heading, in the same weight as the panel's own.
				BarText {
					anchors.left: parent.left
					anchors.bottom: parent.bottom
					anchors.bottomMargin: 4
					visible: !row.net

					text: row.modelData.header ?? ""
					font.pixelSize: 13
					font.weight: Font.DemiBold
				}

				Rectangle {
					anchors.fill: parent
					anchors.bottomMargin: 2
					visible: row.net !== null

					radius: 6
					color: root.cursor === row.index ? Theme.tooltipBorder : "transparent"

					// The pointer drives the same cursor the keys do rather
					// than lighting a second row of its own.
					HoverHandler {
						onHoveredChanged: {
							if (hovered && row.net)
								root.cursorName = row.net.name;
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor

						onClicked: root.activate(row.net)
					}

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 8
						anchors.rightMargin: 8
						spacing: 8

						BarText {
							Layout.preferredWidth: 18

							text: NetworkState.strengthIcon(NetworkState.strengthOf(row.net))
							color: row.net?.connected ? Theme.blue : Theme.fg
							font.pixelSize: Theme.fontIcon
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 0

							BarText {
								Layout.fillWidth: true

								text: row.net?.name || "(hidden)"
								font.weight: row.net?.connected ? Font.DemiBold : Font.Normal
								elide: Text.ElideRight
							}

							BarText {
								Layout.fillWidth: true

								text: {
									const net = row.net;
									if (!net)
										return "";
									if (net.connected)
										return "Connected";
									if (net.stateChanging)
										return ConnectionState.toString(net.state).toLowerCase();
									const parts = [`${NetworkState.strengthOf(net)}%`, NetworkState.securityLabel(net)];
									if (net.known)
										parts.push("saved");
									return parts.join(" · ");
								}
								color: row.net?.connected ? Theme.blue : Theme.dim
								font.pixelSize: 11
								elide: Text.ElideRight
							}
						}

						BarText {
							visible: NetworkState.secured(row.net)

							text: "󰌾"
							color: Theme.dim
							font.pixelSize: Theme.fontIcon
						}
					}
				}
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.rows.length === 0

			text: NetworkState.wifiBlocked ? "Wi-Fi is blocked by the hardware switch." : !NetworkState.wifiEnabled ? "Wi-Fi is off." : "Nothing in range yet — scanning."
			color: Theme.dim
			wrapMode: Text.Wrap
		}
	}

	// ------------------------------------------------------------------
	// Joining something new
	//
	// A section of its own rather than a box that grows out of the row: the
	// list scrolls, and a prompt that can be scrolled off the screen is a
	// prompt that looks like it went away.
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		visible: root.pending !== null
		spacing: 6

		BarText {
			Layout.fillWidth: true

			text: `Password for ${root.pending?.name ?? ""}`
			font.pixelSize: 13
			font.weight: Font.DemiBold
			elide: Text.ElideRight
		}

		Rectangle {
			Layout.fillWidth: true
			implicitHeight: 30

			radius: 6
			color: Qt.darker(Theme.tooltipBorder, 1.25)
			border.width: 1
			border.color: psk.activeFocus ? Theme.blue : "transparent"

			TextInput {
				id: psk

				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 8

				verticalAlignment: TextInput.AlignVCenter
				color: Theme.fg
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontText
				echoMode: TextInput.Password
				selectByMouse: true
				selectionColor: Theme.blue
				enabled: !root.awaiting

				// The prompt is a section that appears rather than a window, so
				// nothing else would hand it the keyboard.
				onVisibleChanged: {
					if (visible)
						forceActiveFocus();
				}
				onAccepted: root.submit()
				// Escape backs out of the prompt rather than out of the panel:
				// the card's own handler would close the lot, which is not what
				// someone abandoning a password meant.
				Keys.onEscapePressed: event => {
					root.cancelPrompt();
					event.accepted = true;
				}

				BarText {
					anchors.verticalCenter: parent.verticalCenter
					visible: psk.text === "" && !root.awaiting

					text: "enter to join"
					color: Theme.disabled
				}
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.error !== "" || root.awaiting

			text: root.awaiting ? "Connecting…" : root.error
			color: root.awaiting ? Theme.dim : Theme.red
			wrapMode: Text.Wrap
		}
	}

	// A refusal comes back as a signal on the network itself, so the prompt has
	// to be listening to whichever one is being joined.
	Connections {
		target: root.pending

		function onConnectionFailed(reason) {
			root.error = NetworkState.failureLabel(reason);
			root.awaiting = false;
			psk.selectAll();
			psk.forceActiveFocus();
		}

		function onConnectedChanged() {
			if (root.pending?.connected)
				root.cancelPrompt();
		}
	}

	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 4

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				text: "w wi-fi · d disconnect · s speed · r reset"
				elide: Text.ElideRight
			}

			BarText {
				text: "esc close"
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.rows.length > 0

			text: "j/k move · enter join · f forget"
			elide: Text.ElideRight
		}
	}

	// One link: what it is, what it is doing, and whether it is the one the
	// counters below are about.
	component Link: RowLayout {
		id: link

		property string icon: ""
		property string title: ""
		property string subtitle: ""
		property bool active: false
		// The link carrying the default route. Both can be up at once; only one
		// of them is what the numbers underneath describe.
		property bool primary: false

		// The radio switch, on the row it switches. Spelled out as properties
		// rather than taken as a child: a default property alias would also
		// swallow the component's own contents.
		property bool switchVisible: false
		property bool switchChecked: false
		property bool switchEnabled: true

		signal switchToggled

		Layout.fillWidth: true
		spacing: 10

		BarText {
			Layout.preferredWidth: 24

			text: link.icon
			color: link.active ? Theme.fg : Theme.dim
			font.pixelSize: 22
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 0

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				BarText {
					Layout.fillWidth: true

					text: link.title
					color: link.active ? Theme.fg : Theme.dim
					font.pixelSize: 13
					font.weight: Font.DemiBold
					elide: Text.ElideRight
				}

				// The same tick the audio picker puts against the device in
				// use, and for the same reason.
				BarText {
					visible: link.primary

					text: "󰄬"
					color: Theme.blue
				}
			}

			BarText {
				Layout.fillWidth: true

				text: link.subtitle
				color: Theme.dim
				font.pixelSize: 11
				elide: Text.ElideRight
			}
		}

		Toggle {
			Layout.alignment: Qt.AlignVCenter
			visible: link.switchVisible

			checked: link.switchChecked
			enabled: link.switchEnabled

			onToggled: link.switchToggled()
		}
	}

	// Two readings side by side, label left and value right, each in half the
	// card. `single` gives the pair the whole width, for a value too long to
	// share it.
	component StatRow: RowLayout {
		id: stat

		property string leftLabel: ""
		property string leftValue: ""
		property color leftColor: Theme.fg
		property string rightLabel: ""
		property string rightValue: ""
		property color rightColor: Theme.fg
		property bool single: false

		Layout.fillWidth: true
		spacing: 16

		Cell {
			label: stat.leftLabel
			value: stat.leftValue
			valueColor: stat.leftColor
		}

		Cell {
			visible: !stat.single

			label: stat.rightLabel
			value: stat.rightValue
			valueColor: stat.rightColor
		}
	}

	component Cell: RowLayout {
		id: cell

		property string label: ""
		property string value: ""
		property color valueColor: Theme.fg

		Layout.fillWidth: true
		// Equal halves whatever is in them: without this the wider pair would
		// take the space and the columns would not line up down the card.
		Layout.preferredWidth: 1
		spacing: 8

		BarText {
			text: cell.label
			color: Theme.dim
		}

		BarText {
			Layout.fillWidth: true

			text: cell.value
			color: cell.valueColor
			horizontalAlignment: Text.AlignRight
			elide: Text.ElideRight
		}
	}

	// The speed test's button. The only thing on this panel that starts work
	// rather than reading something already happening, so it looks like a
	// button instead of like a row.
	component Run: Rectangle {
		id: run

		property string label: ""

		signal clicked

		implicitWidth: text.implicitWidth + 20
		implicitHeight: 26

		radius: 6
		color: hover.hovered ? Theme.tooltipBorder : Qt.darker(Theme.tooltipBorder, 1.25)

		Behavior on color {
			ColorAnimation {
				duration: 150
			}
		}

		HoverHandler {
			id: hover
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: run.clicked()
		}

		BarText {
			id: text

			anchors.centerIn: parent

			text: run.label
		}
	}

	// The radio switch. Built rather than imported: QtQuick.Controls would
	// bring a style with it, and nothing else in this shell has needed one.
	component Toggle: Rectangle {
		id: toggle

		property bool checked: false

		signal toggled

		implicitWidth: 38
		implicitHeight: 22

		radius: height / 2
		color: !enabled ? Theme.track : checked ? Theme.blue : Theme.track
		opacity: enabled ? 1 : 0.5

		Behavior on color {
			ColorAnimation {
				duration: 150
			}
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: toggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
			enabled: toggle.enabled

			onClicked: toggle.toggled()
		}

		Rectangle {
			width: parent.height - 6
			height: width
			radius: height / 2
			y: 3
			x: toggle.checked ? parent.width - width - 3 : 3

			color: toggle.checked ? Theme.bg : Theme.fg

			Behavior on x {
				NumberAnimation {
					duration: 150
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
