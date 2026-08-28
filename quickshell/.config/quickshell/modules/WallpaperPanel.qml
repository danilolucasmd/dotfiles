import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// The wallpaper picker. See WallpaperState.qml for the collection and what
// choosing one does.
//
// The only panel here that is not built on components/Panel.qml, and the reason
// is the whole point of it: a wallpaper cannot be judged in a 360px card. This
// covers the screen and previews the selection at the size it will actually be
// used, with the strip floating over the bottom of it -- so the panel is not a
// card raised from the bar but a full-screen view, and Panel's card, its width
// and its top anchor would all have to be undone to get here. What it does
// borrow is the two things Panel exists for, the focus grab and Escape; they are
// a dozen lines and are spelled out below.
//
// It stops at the bar's exclusive zone rather than covering the screen outright.
// Anchored to all four edges with exclusiveZone 0, layer-shell hands back the
// screen minus everyone else's reservation, which leaves the bar up while
// picking -- the wallpaper runs under the bar in real life too, so hiding it
// would preview a screen that never exists.
PanelWindow {
	id: root

	readonly property int pad: 14
	// 16:9 at a size where a wallpaper is still recognisable in a row of
	// twenty-odd. Wider and only a handful fit on a 1080p screen at once.
	readonly property int thumbWidth: 160
	readonly property int thumbHeight: 90
	readonly property int thumbSpacing: 10

	// What the strip would like to be, measured from the collection rather than
	// read off the ListView's own contentWidth. The card is sized from this and
	// the strip is sized from the card, so taking it from the strip would be
	// the card measuring the thing it is sizing -- which settled, when it was
	// written that way, on a strip 108 pixels *wide in the negative* and a
	// positionViewAtIndex that scrolled to nonsense.
	readonly property int stripWidth: Math.max(WallpaperState.wallpapers.length * (thumbWidth + thumbSpacing) - thumbSpacing, 0)

	visible: WallpaperState.panelOpen
	// One picker, on whichever monitor has focus, like every panel here: it is
	// opened from the launcher and has no bar module whose screen it could take.
	screen: Hyprland.focusedMonitor?.screen ?? null

	WlrLayershell.layer: WlrLayer.Overlay
	// Its own namespace rather than the "quickshell:panel" the bar's cards
	// share, so anything that waits on a particular surface -- copy-and-paste.sh
	// does -- cannot be held open by this one.
	WlrLayershell.namespace: "quickshell:wallpaper"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	exclusiveZone: 0
	color: "transparent"

	onVisibleChanged: {
		if (visible) {
			surface.forceActiveFocus();
			preview.reset();
		}
	}

	// Clicking the bar, the only thing outside this window, closes it. The grab
	// is also what hands the keyboard over while the picker is up.
	HyprlandFocusGrab {
		windows: [root]
		active: root.visible
		onCleared: WallpaperState.close()
	}

	Item {
		id: surface

		anchors.fill: parent
		focus: true

		Keys.onPressed: event => {
			switch (event.key) {
			// h and l next to the arrows, because the strip is walked far more
			// than anything else here is and the hand is already on the home
			// row. No search field to type into, so a bare letter is free to
			// mean this.
			case Qt.Key_Right:
			case Qt.Key_Down:
			case Qt.Key_L:
				WallpaperState.step(1);
				break;
			case Qt.Key_Left:
			case Qt.Key_Up:
			case Qt.Key_H:
				WallpaperState.step(-1);
				break;
			case Qt.Key_Home:
				WallpaperState.cursor = 0;
				break;
			case Qt.Key_End:
				WallpaperState.cursor = Math.max(WallpaperState.wallpapers.length - 1, 0);
				break;
			case Qt.Key_Return:
			case Qt.Key_Enter:
				WallpaperState.apply();
				break;
			case Qt.Key_Escape:
				WallpaperState.close();
				break;
			default:
				return;
			}

			event.accepted = true;
		}

		// The wallpaper that is actually up, held still for as long as the
		// picker is open, so that the panel's first frame is indistinguishable
		// from the desktop it covers. It is only ever seen then: once the
		// preview below has decoded anything at all it covers this for good.
		Image {
			anchors.fill: parent

			source: WallpaperState.current === "" ? "" : `file://${WallpaperState.current}`
			fillMode: Image.PreserveAspectCrop
			// Decoded at screen size and no larger: these are 2560px files and
			// the panel is showing one of them on a 1080p screen.
			sourceSize.width: root.width
			sourceSize.height: root.height
			asynchronous: true
			smooth: true
		}

		// The selection, over the top, fading in as it arrives.
		//
		// Two layers rather than one, and that is the whole substance of this.
		// An asynchronous Image has nothing to draw between being given a source
		// and finishing the decode, and this one decodes a 2560px JPEG at screen
		// size on every keypress. A single Image faded in on `status === Ready`
		// therefore goes transparent for the length of every decode, and what
		// shows through is the backdrop -- the wallpaper you already have -- so
		// stepping from one candidate to the next flashed the current wallpaper
		// between them. `retainWhileLoading` fixes that flash but has no fade in
		// it at all: it swaps the content of the one layer in a single frame.
		//
		// So: the next selection is always decoded into whichever layer is not
		// being shown, and only once it is ready does it come to the front and
		// fade in over the other. The one it is covering stays at full opacity
		// underneath for the whole animation, which is the part that matters --
		// fade both at once and the middle of the crossfade is half-transparent,
		// which puts the backdrop back on screen and the flash back with it.
		Item {
			id: preview

			anchors.fill: parent

			readonly property string target: WallpaperState.selected ? `file://${WallpaperState.selected.path}` : ""
			// The layer being shown. The other one is the spare the next
			// selection is decoded into.
			property Item front: first
			readonly property Item back: front === first ? second : first

			// Cleared before it is set, so the assignment is always a change.
			// Stepping back onto a wallpaper the spare layer is still holding is
			// otherwise the same url twice: no reload, no statusChanged, and the
			// swap below never fires -- which showed up as the preview sticking on
			// the previous wallpaper whenever you walked back and forth between two
			// of them. The reload it forces is cheap; Qt has the decoded pixmap
			// cached under the same url and size.
			onTargetChanged: {
				back.source = "";
				back.source = target;
			}

			// Both layers emptied on every open. Without it, reopening the
			// picker fades from whatever was last browsed -- a stale image from
			// the previous session of the panel -- to the current wallpaper.
			// Emptied, the backdrop is what shows until the first decode lands,
			// and the backdrop is the current wallpaper, which is what the
			// picker opens on anyway.
			function reset(): void {
				first.source = "";
				second.source = "";
				first.opacity = 1;
				second.opacity = 1;
				first.z = 1;
				second.z = 0;
				front = first;
			}

			function reveal(layer: var): void {
				if (front === layer)
					return;

				front.z = 0;
				layer.z = 1;
				layer.opacity = 0;
				front = layer;

				fade.target = layer;
				fade.restart();
			}

			NumberAnimation {
				id: fade

				property: "opacity"
				to: 1
				duration: 180
				easing.type: Easing.OutQuad
			}

			Image {
				id: first

				anchors.fill: parent
				z: 1

				fillMode: Image.PreserveAspectCrop
				sourceSize.width: root.width
				sourceSize.height: root.height
				asynchronous: true
				smooth: true

				// Ready fires for the layer that was loading in the background;
				// bringing it forward here is what starts the fade.
				onStatusChanged: {
					if (status === Image.Ready)
						preview.reveal(first);
				}
			}

			Image {
				id: second

				anchors.fill: parent
				z: 0

				fillMode: Image.PreserveAspectCrop
				sourceSize.width: root.width
				sourceSize.height: root.height
				asynchronous: true
				smooth: true

				onStatusChanged: {
					if (status === Image.Ready)
						preview.reveal(second);
				}
			}
		}

		// Anywhere that is not the strip dismisses. Declared before the card so
		// the card sits on top of it; the card blocks it with a swallowing
		// MouseArea of its own.
		MouseArea {
			anchors.fill: parent

			onClicked: WallpaperState.close()
		}

		// Something for the strip to read against. A wallpaper can be anything,
		// white sand included, and the card alone was not enough on the bright
		// ones.
		Rectangle {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.bottom: parent.bottom

			height: card.height + 120

			gradient: Gradient {
				GradientStop {
					position: 0
					color: "transparent"
				}
				GradientStop {
					position: 1
					color: "#cc000000"
				}
			}
		}

		Rectangle {
			id: card

			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 40

			// As wide as the strip needs, up to what the screen allows -- a
			// collection of four should not draw an empty card the width of the
			// display, and one of forty has to stop somewhere and scroll.
			width: Math.min(parent.width - 80, root.stripWidth + root.pad * 2)
			implicitHeight: column.implicitHeight + root.pad * 2

			radius: 10
			color: Theme.tooltipBg
			border.width: 1
			border.color: Theme.tooltipBorder

			// Keeps a click on the card from reaching the dismissal area under
			// it. The thumbnails have their own handlers and sit above this.
			MouseArea {
				anchors.fill: parent
			}

			Column {
				id: column

				anchors.fill: parent
				anchors.margins: root.pad

				spacing: 10

				BarText {
					width: parent.width

					text: {
						if (WallpaperState.wallpapers.length === 0)
							return "No wallpapers in ~/.config/wallpapers";
						if (!WallpaperState.selected)
							return "";
						// The one thing that says which wallpaper is already
						// up. Without it there is no telling, from a preview
						// that fills the screen, whether Return would change
						// anything -- the strip carried a second mark for this
						// and it was noise beside the label.
						return WallpaperState.cursor === WallpaperState.currentIndex ? `${WallpaperState.selected.name} · current` : WallpaperState.selected.name;
					}
					color: Theme.fg
					horizontalAlignment: Text.AlignHCenter
					elide: Text.ElideRight
				}

				ListView {
					id: strip

					width: parent.width
					height: root.thumbHeight + 4
					visible: WallpaperState.wallpapers.length > 0

					orientation: ListView.Horizontal
					clip: true
					// Driven by the keys and by clicking, never by dragging:
					// the state singleton owns the cursor, and a flick that
					// moved the selection would be a second thing writing it.
					interactive: false
					spacing: root.thumbSpacing

					model: WallpaperState.wallpapers

					// Puts the selection back in the middle of the strip. Called
					// for the two moments a keypress is not doing it: the model
					// being replaced, and the strip finally having a width.
					//
					// forceLayout first because both of those are moments when
					// the view has pending work -- positionViewAtIndex on a
					// view that has not laid its delegates out yet scrolls to a
					// position computed from a contentWidth of zero.
					function recentre(): void {
						currentIndex = WallpaperState.cursor;
						forceLayout();
						positionViewAtIndex(currentIndex, ListView.Center);
					}

					// A highlight band exactly one thumbnail wide in the middle
					// of the strip, so walking the collection scrolls it past a
					// fixed point rather than marching a highlight to the edge
					// and only then scrolling. This is what animates a keypress;
					// recentre() above is for the jump that is not a keypress.
					//
					// ApplyRange and not StrictlyEnforceRange, which is the same
					// band enforced from both sides and looks like the obvious
					// choice. It is not: StrictlyEnforceRange assigns
					// currentIndex as it settles, and a view that writes its own
					// selection fights whatever else is setting it. ApplyRange
					// only ever reads it. The visible difference is at the two
					// ends, where ApplyRange lets the selection sit off-centre
					// rather than padding half a strip with nothing.
					highlightRangeMode: ListView.ApplyRange
					preferredHighlightBegin: (width - root.thumbWidth) / 2
					preferredHighlightEnd: (width + root.thumbWidth) / 2
					highlightMoveDuration: 140

					onModelChanged: Qt.callLater(strip.recentre)

					// The one that actually catches the open. A layer-shell
					// window has no size until the compositor has mapped it, so
					// everything above runs first against a card measured from a
					// zero-width screen -- the strip was 108 pixels wide in the
					// negative when this was left out, and the selection landed
					// wherever that arithmetic sent it.
					onWidthChanged: Qt.callLater(strip.recentre)

					// The selection is assigned here rather than bound to the
					// cursor with `currentIndex: WallpaperState.cursor`, which
					// is what this was and which quietly stopped working on the
					// second open. Replacing the model makes the view reset
					// currentIndex to 0 by itself, and a binding only recovers
					// from that when its dependency changes -- so a listing that
					// put the cursor back on the wallpaper it was already on
					// left the strip parked at the top of the collection while
					// the preview and the name showed the real selection.
					Connections {
						target: WallpaperState

						function onCursorChanged(): void {
							strip.currentIndex = WallpaperState.cursor;
						}
					}

					delegate: Rectangle {
						id: thumb

						required property var modelData
						required property int index

						readonly property bool selected: WallpaperState.cursor === index

						width: root.thumbWidth
						height: root.thumbHeight + 4

						color: "transparent"

						Image {
							anchors.fill: parent
							anchors.margins: 2

							source: `file://${thumb.modelData.path}`
							fillMode: Image.PreserveAspectCrop
							// Thumbnail-sized textures, not twenty-odd
							// full-screen ones: the strip holds the whole
							// collection at once.
							sourceSize.width: root.thumbWidth * 2
							sourceSize.height: root.thumbHeight * 2
							asynchronous: true
							smooth: true
							// The unselected ones are held back so the middle
							// of the strip reads as the choice rather than as
							// one of twenty equal tiles.
							opacity: thumb.selected ? 1 : 0.5
						}

						// Drawn over the image rather than as the image's own
						// border, so the frame does not eat two pixels of the
						// picture it is framing.
						Rectangle {
							anchors.fill: parent

							color: "transparent"
							border.width: 2
							border.color: thumb.selected ? Theme.blue : "transparent"
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							hoverEnabled: true

							// Hover previews, click commits. The full-screen
							// preview means hovering is already the useful
							// half, and a click that only moved the cursor
							// would be a click that appeared to do nothing.
							onEntered: WallpaperState.cursor = thumb.index
							onClicked: {
								WallpaperState.cursor = thumb.index;
								WallpaperState.apply();
							}
						}
					}
				}

				BarText {
					width: parent.width
					visible: WallpaperState.wallpapers.length > 0

					text: "← → or h l choose · Return set · Esc cancel"
					color: Theme.dim
					font.pixelSize: 10
					horizontalAlignment: Text.AlignHCenter
				}
			}
		}
	}
}
