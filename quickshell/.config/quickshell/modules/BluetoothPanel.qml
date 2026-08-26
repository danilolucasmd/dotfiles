import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The Bluetooth panel, opened by clicking the bar module or by super+B.
//
// The module used to open buds-tui in a terminal on a click, on the reasoning
// that connecting the earbuds is what taking them out of the case already
// does. That held right up until anything else needed connecting: a second
// headset, a controller, a phone, a device being paired for the first time.
// None of those were a click away from the bar, and all of them are here.
// buds-tui is still the only thing that knows per-bud battery and ANC mode,
// and is still `buds` in a terminal -- it is just no longer what the bar does.
//
// The list is two sections because BlueZ draws that line itself: a device it
// holds pairing keys for behaves differently from one it has merely seen
// sweeping the air, and only the first kind can be forgotten.
Panel {
	id: root

	// The list, headers and all, as one flat model: a single ListView scrolls
	// and keeps the cursor in view for free, where two Repeaters in a
	// Flickable would need both worked out by hand.
	readonly property var rows: {
		const out = [];
		if (BluetoothState.paired.length > 0) {
			out.push({
				header: "Paired"
			});
			for (const d of BluetoothState.paired)
				out.push({
					dev: d
				});
		}
		if (BluetoothState.nearby.length > 0) {
			out.push({
				header: "Available"
			});
			for (const d of BluetoothState.nearby)
				out.push({
					dev: d
				});
		}
		return out;
	}

	// The keyboard cursor, held as the device's address rather than as a row
	// index: discovery adds and drops rows the whole time the panel is up, and
	// an index would slide onto a different device every time one appeared
	// above it. The pointer moves it too, so there is only ever one
	// highlighted row however you arrived at it.
	property string cursorAddress: ""

	// Where that address currently sits, or the first row anyone can do
	// anything with -- and -1 when the adapter has found nothing at all.
	readonly property int cursor: {
		const i = rows.findIndex(r => r.dev && r.dev.address === cursorAddress);
		return i >= 0 ? i : rows.findIndex(r => r.dev);
	}

	// The device a first-time pairing is in flight on. Held so the panel can
	// hear it finish, and so it knows which one to connect afterwards --
	// pairing and connecting are two calls, and BlueZ does not chain them.
	property var pairing: null
	property string error: ""

	open: BluetoothState.panelOpen
	onDismissed: BluetoothState.close()
	onRefreshRequested: BluetoothState.wantDiscovery = true
	// Opening puts the cursor on a connected device, which is what you are
	// counting from when you go looking for another one.
	onOpenChanged: {
		if (open) {
			cursorAddress = BluetoothState.connected[0]?.address ?? "";
			pairing = null;
			error = "";
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
			activate(rows[cursor]?.dev ?? null);
			return true;
		case Qt.Key_B:
			BluetoothState.toggleAdapter();
			return true;
		case Qt.Key_S:
			BluetoothState.toggleDiscovery();
			return true;
		// No disconnect key. The network panel has one because enter there
		// joins and nothing else; here enter is a toggle, so a `d` would be a
		// second name for what the row's own action already does.
		case Qt.Key_F:
			forget(rows[cursor]?.dev ?? null);
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
			if (rows[i].dev) {
				cursorAddress = rows[i].dev.address;
				return;
			}
		}
	}

	// One key for the whole row, because there is only ever one obvious thing
	// to do with a device: drop it if it is up, bring it up if BlueZ already
	// has its keys, and pair it if it does not.
	function activate(dev: var): void {
		if (!dev || dev.pairing)
			return;
		error = "";
		if (dev.connected) {
			dev.disconnect();
			return;
		}
		if (BluetoothState.known(dev)) {
			dev.connect();
			return;
		}
		pairing = dev;
		dev.pair();
	}

	function forget(dev: var): void {
		if (!BluetoothState.known(dev))
			return;
		if (pairing === dev)
			pairing = null;
		dev.forget();
	}

	// ------------------------------------------------------------------
	// The adapter
	// ------------------------------------------------------------------

	RowLayout {
		Layout.fillWidth: true
		spacing: 10

		BarText {
			Layout.preferredWidth: 24

			text: BluetoothState.icon
			color: BluetoothState.enabled ? Theme.fg : Theme.dim
			font.pixelSize: 22
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 0

			BarText {
				Layout.fillWidth: true

				text: "Bluetooth"
				color: BluetoothState.enabled ? Theme.fg : Theme.dim
				font.pixelSize: 13
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			BarText {
				Layout.fillWidth: true

				text: {
					if (!BluetoothState.available)
						return "no adapter";
					if (BluetoothState.blocked)
						return "blocked by rfkill";
					if (!BluetoothState.enabled)
						return "off";
					const n = BluetoothState.connected.length;
					if (n > 0)
						return BluetoothState.connected.map(d => BluetoothState.label(d)).join(", ");
					return BluetoothState.discovering ? "scanning…" : "nothing connected";
				}
				color: Theme.dim
				font.pixelSize: 11
				elide: Text.ElideRight
			}
		}

		// The switch sits on the row it switches, the same way the Wi-Fi one
		// does in the network panel, rather than floating in the card's
		// corner where it could be about anything on the card.
		Toggle {
			Layout.alignment: Qt.AlignVCenter

			checked: BluetoothState.enabled
			enabled: BluetoothState.available && !BluetoothState.blocked && !BluetoothState.settling

			onToggled: BluetoothState.toggleAdapter()
		}
	}

	// ------------------------------------------------------------------
	// The devices
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		ListView {
			id: list

			Layout.fillWidth: true
			// Tall enough for a handful of devices and no taller: a sweep in a
			// block of flats picks up dozens, and the card would otherwise
			// grow to the height of the screen. Past that the list scrolls,
			// and j/k drag it along.
			Layout.preferredHeight: Math.min(contentHeight, 300)
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

				readonly property var dev: modelData.dev ?? null

				width: list.width
				implicitHeight: dev ? 38 : 26

				// A section heading, in the same weight as the adapter row's
				// title above it.
				BarText {
					anchors.left: parent.left
					anchors.bottom: parent.bottom
					anchors.bottomMargin: 4
					visible: !row.dev

					text: row.modelData.header ?? ""
					font.pixelSize: 13
					font.weight: Font.DemiBold
				}

				Rectangle {
					anchors.fill: parent
					anchors.bottomMargin: 2
					visible: row.dev !== null

					radius: 6
					color: root.cursor === row.index ? Theme.tooltipBorder : "transparent"

					// The pointer drives the same cursor the keys do rather
					// than lighting a second row of its own.
					HoverHandler {
						onHoveredChanged: {
							if (hovered && row.dev)
								root.cursorAddress = row.dev.address;
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor

						onClicked: root.activate(row.dev)
					}

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 8
						anchors.rightMargin: 8
						spacing: 8

						BarText {
							Layout.preferredWidth: 18

							text: BluetoothState.deviceIcon(row.dev)
							color: row.dev?.connected ? Theme.blue : Theme.fg
							font.pixelSize: Theme.fontIcon
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 0

							BarText {
								Layout.fillWidth: true

								text: BluetoothState.label(row.dev)
								font.weight: row.dev?.connected ? Font.DemiBold : Font.Normal
								elide: Text.ElideRight
							}

							BarText {
								Layout.fillWidth: true

								text: BluetoothState.stateLabel(row.dev)
								color: row.dev?.connected ? Theme.blue : Theme.dim
								font.pixelSize: 11
								elide: Text.ElideRight
							}
						}

						// The same tick the audio picker puts against the
						// device in use, and for the same reason.
						BarText {
							visible: row.dev?.connected ?? false

							text: "󰄬"
							color: Theme.blue
						}
					}
				}
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.rows.length === 0

			text: {
				if (!BluetoothState.available)
					return "No Bluetooth adapter. BlueZ reports nothing it manages.";
				if (BluetoothState.blocked)
					return "Bluetooth is blocked by rfkill.";
				if (!BluetoothState.enabled)
					return "Bluetooth is off.";
				return BluetoothState.discovering ? "Nothing in range yet — scanning." : "Nothing paired. Press s to scan.";
			}
			color: Theme.dim
			wrapMode: Text.Wrap
		}
	}

	// A pairing that did not take. Worth saying out loud rather than leaving
	// the row to sit there looking unchanged -- see the Connections below for
	// why it is the likeliest outcome on a device that wants a code.
	BarText {
		Layout.fillWidth: true
		visible: root.error !== ""

		text: root.error
		color: Theme.red
		wrapMode: Text.Wrap
		font.pixelSize: 11
	}

	// Pairing is two calls and a wait, and BlueZ reports the outcome only by
	// moving properties: `pairing` drops back to false either way, and
	// `paired` says which way it went.
	//
	// Quickshell registers no org.bluez.Agent1, so a device that wants a
	// passkey confirmed has nobody to confirm it and the pairing is refused.
	// Devices that pair without one -- most audio, most mice -- go through
	// here fine; the rest genuinely need `bluetoothctl`, and saying so is
	// more use than a row that quietly stays in the Available list.
	Connections {
		target: root.pairing

		function onPairingChanged() {
			const dev = root.pairing;
			if (!dev || dev.pairing)
				return;
			if (BluetoothState.known(dev)) {
				// Pairing does not connect. For a headset the two are the same
				// intent, so the panel finishes the job.
				root.error = "";
				dev.connect();
			} else {
				root.error = `Could not pair ${BluetoothState.label(dev)} — a device that asks for a code needs \`bluetoothctl pair\`.`;
			}
			root.pairing = null;
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

				text: `b bluetooth · s ${BluetoothState.discovering ? "stop scan" : "scan"}`
				elide: Text.ElideRight
			}

			BarText {
				text: "esc close"
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.rows.length > 0

			text: "j/k move · enter connect · f forget"
			elide: Text.ElideRight
		}
	}

	// The radio switch. Built rather than imported, for the reason the network
	// panel's twin gives: QtQuick.Controls would bring a style with it, and
	// nothing else in this shell has needed one.
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
