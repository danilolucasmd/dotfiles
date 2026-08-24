import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs
import qs.components

// What is playing, with a scrubber and a transport — the macOS now-playing
// card, opened by clicking the media module or on shift + the play key.
//
// One player at a time; MediaState explains why there is no list.
Panel {
	id: root

	readonly property MprisPlayer player: MediaState.active
	readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing

	readonly property bool canSeek: (player?.canSeek ?? false) && length > 0
	readonly property real length: (player?.lengthSupported ?? false) ? player.length : 0

	// Where the handle has been dragged to, or -1 when it is not being dragged.
	// The scrubber follows this rather than the player while a drag is in
	// flight, so the handle does not snap back to wherever playback has got to
	// between the press and the release.
	property real scrubbing: -1

	readonly property real position: {
		if (scrubbing >= 0)
			return scrubbing;
		return (player?.positionSupported ?? false) ? player.position : 0;
	}
	readonly property real progress: length > 0 ? Math.min(1, Math.max(0, position / length)) : 0

	open: MediaState.panelOpen
	onDismissed: MediaState.panelOpen = false
	// A drag that was still in flight when the panel went away is not one to
	// resume the next time it opens.
	onOpenChanged: scrubbing = -1
	onKeyPressed: event => {
		if (press(event.key, (event.modifiers & Qt.ShiftModifier) !== 0))
			event.accepted = true;
	}

	// Split out of the handler so the panel's keys are one plain function of
	// key + shift rather than something only a real key event can reach.
	function press(key: int, shift: bool): bool {
		if (!player)
			return false;

		switch (key) {
		case Qt.Key_Space:
		case Qt.Key_Return:
		case Qt.Key_Enter:
			if (player.canTogglePlaying)
				player.togglePlaying();
			break;
		case Qt.Key_N:
			if (player.canGoNext)
				player.next();
			break;
		case Qt.Key_P:
			if (player.canGoPrevious)
				player.previous();
			break;
		// Seeking by the keyboard is relative, which is what `seek` is for —
		// no clamping to do, since a player that is asked to run off either end
		// stops at it.
		case Qt.Key_L:
		case Qt.Key_Right:
			if (player.canSeek)
				player.seek(shift ? 30 : 5);
			break;
		case Qt.Key_H:
		case Qt.Key_Left:
			if (player.canSeek)
				player.seek(shift ? -30 : -5);
			break;
		default:
			return false;
		}
		return true;
	}

	// mm:ss, and h:mm:ss once there is an hour to show — a three-hour stream
	// should not report its position as 187 minutes.
	function formatTime(seconds: real): string {
		const total = Math.max(0, Math.floor(seconds));
		const s = total % 60;
		const m = Math.floor(total / 60) % 60;
		const h = Math.floor(total / 3600);
		const pad = n => n < 10 ? `0${n}` : `${n}`;
		return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
	}

	// The media module sits in the bar's right cluster, so the panel drops from
	// the same corner.
	anchors.right: true
	margins.right: 8

	// MPRIS players report a position when asked, not as it moves: the property
	// is a reading taken on demand, so the clock only ticks while something is
	// watching it. Re-reading twice a second is enough for a bar that is
	// closed most of the time, and stops entirely when it is.
	Timer {
		running: root.open && root.playing && (root.player?.positionSupported ?? false)
		interval: 500
		repeat: true

		onTriggered: root.player.positionChanged()
	}

	RowLayout {
		Layout.fillWidth: true
		visible: root.player !== null
		spacing: 12

		// Cover art where there is any: Brave hands over a thumbnail of the
		// video, Spotify the album. Cropped to a square rather than letter-
		// boxed — a 150x83 YouTube still would otherwise leave the row half
		// empty — with a glyph standing in when a player sends nothing.
		Rectangle {
			Layout.preferredWidth: 48
			Layout.preferredHeight: 48

			radius: 8
			color: Theme.bg
			clip: true

			BarText {
				anchors.centerIn: parent
				visible: art.status !== Image.Ready

				text: "󰎈"
				color: Theme.dim
				font.pixelSize: 22
			}

			Image {
				id: art

				anchors.fill: parent

				source: root.player?.trackArtUrl ?? ""
				fillMode: Image.PreserveAspectCrop
				sourceSize.width: 96
				sourceSize.height: 96
				asynchronous: true
				// Players rewrite the art in place from track to track, so a
				// cached copy would be the previous song's.
				cache: false
			}
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 2

			BarText {
				Layout.fillWidth: true

				text: root.player?.trackTitle || root.player?.identity || ""
				font.pixelSize: 13
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			// The artist, and which application it is coming out of — with a
			// browser in the list the title alone does not say where to go
			// looking for it.
			BarText {
				Layout.fillWidth: true

				text: {
					const artist = root.player?.trackArtist ?? "";
					const name = root.player?.identity ?? "";
					return artist && name ? `${artist} · ${name}` : artist || name;
				}
				color: Theme.dim
				elide: Text.ElideRight
			}
		}
	}

	// The scrubber and its two clocks, a tighter group than the panel's own
	// section spacing — the times label the bar, they are not a section of
	// their own.
	ColumnLayout {
		Layout.fillWidth: true
		visible: root.player !== null && root.length > 0
		spacing: 4

		Item {
			id: scrubber

			Layout.fillWidth: true
			// Taller than the bar it draws, so the pointer does not have to
			// find a 4px target.
			implicitHeight: 14

			Rectangle {
				id: track

				anchors.left: parent.left
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter

				height: 4
				radius: 2
				color: Theme.track

				Rectangle {
					width: parent.width * root.progress
					height: parent.height

					radius: parent.radius
					color: Theme.fg
				}
			}

			Rectangle {
				x: track.width * root.progress - width / 2
				anchors.verticalCenter: parent.verticalCenter
				visible: root.canSeek

				width: 10
				height: 10
				radius: 5
				color: Theme.fg
			}

			MouseArea {
				id: drag

				anchors.fill: parent
				enabled: root.canSeek
				cursorShape: Qt.PointingHandCursor

				// Press and drag both move the handle without touching the
				// player; the seek goes out once, on release, rather than as a
				// stream of them across the drag.
				onPressed: event => root.scrubbing = at(event.x)
				onPositionChanged: event => {
					if (pressed)
						root.scrubbing = at(event.x);
				}
				onReleased: {
					if (root.scrubbing >= 0)
						root.player.position = root.scrubbing;
					root.scrubbing = -1;
				}
				onCanceled: root.scrubbing = -1

				function at(x: real): real {
					return Math.min(1, Math.max(0, x / width)) * root.length;
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				text: root.formatTime(root.position)
				color: Theme.dim
			}

			Item {
				Layout.fillWidth: true
			}

			BarText {
				text: root.formatTime(root.length)
				color: Theme.dim
			}
		}
	}

	// Transport, centred under the scrubber. A control the player cannot offer
	// keeps its slot greyed rather than dropping it, so the buttons stay put
	// between tracks — a YouTube video reports no next track, a playlist does.
	RowLayout {
		Layout.alignment: Qt.AlignHCenter
		visible: root.player !== null
		spacing: 24

		Transport {
			enabled: root.player?.canGoPrevious ?? false

			text: "󰒮"

			onTriggered: root.player.previous()
		}

		Transport {
			enabled: root.player?.canTogglePlaying ?? false

			text: root.playing ? "󰏤" : "󰐊"
			font.pixelSize: 28

			onTriggered: root.player.togglePlaying()
		}

		Transport {
			enabled: root.player?.canGoNext ?? false

			text: "󰒭"

			onTriggered: root.player.next()
		}
	}

	BarText {
		Layout.fillWidth: true
		visible: root.player === null

		text: "Nothing playing."
		wrapMode: Text.Wrap
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			Item {
				Layout.fillWidth: true
			}

			BarText {
				text: "esc close"
			}
		}

		BarText {
			Layout.fillWidth: true
			visible: root.player !== null

			text: "space play/pause · n/p track · h/l seek"
			elide: Text.ElideRight
		}
	}

	// One transport glyph.
	component Transport: BarText {
		id: transport

		signal triggered

		// The label is set by the caller; only the colour and size are decided
		// here, and the size only as a default the play button overrides.
		color: !enabled ? Theme.disabled : area.containsMouse ? Theme.blue : Theme.fg
		font.pixelSize: 22

		MouseArea {
			id: area

			anchors.fill: parent
			anchors.margins: -6
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor

			onClicked: transport.triggered()
		}
	}
}
