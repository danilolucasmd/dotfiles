import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// The launcher, opened by super+SPACE, and by super+V already in its clipboard
// mode. See LauncherState.qml for what a query means; this file is the window.
//
// It is built on the same Panel as the bar's cards but is not one of them: it
// is wider, it sits in the upper third of the screen rather than tucked under
// the bar, and nothing in the bar opens it. That is deliberate -- a launcher
// that looked like the calendar dropdown would read as something the bar had
// raised, and it is summoned by a keybind from anywhere.
Panel {
	id: root

	// Its own layer namespace, not the "quickshell:panel" the bar's cards
	// share: copy-and-paste.sh waits for exactly this surface to go away before
	// it types ctrl+v into whatever had focus, and a bar panel left open
	// elsewhere must not be able to hold that wait open. Same reason the emoji
	// picker has one.
	WlrLayershell.namespace: "quickshell:launcher"

	// Wide enough for a full window title and its class beside an icon, which
	// is the longest row any mode produces. The bar's 360 fits neither.
	//
	// Clipboard mode is wider because it is the one mode with a second column:
	// a listing line is not enough to tell two similar entries apart, so the
	// pane on the right shows the entry in full. Widening for it rather than
	// carrying the extra 280px through every other mode, where there is nothing
	// to put in them.
	cardWidth: LauncherState.mode === "clipboard" ? 900 : 620

	// Centred, both ways. Panel anchors its top edge and lets the compositor
	// centre the other axis; unsetting that anchor leaves neither edge anchored,
	// which is what makes layer-shell centre the surface outright.
	//
	// The cost is that the card grows from its middle, so narrowing a query
	// past eight results walks the search field down a little as the list
	// shrinks under it. Worth it: the launcher is summoned from anywhere by a
	// keybind and has no bar module it should appear to hang from, unlike every
	// other panel here.
	anchors.top: false

	// The line under the list. Per mode, because the keys are per mode, and an
	// unlabelled ctrl+d that wipes a clipboard is a trap.
	readonly property string hint: ({
			apps: "Return open · Shift+Return keep open · Ctrl+P pin",
			clipboard: "Return paste · Ctrl+D delete · Ctrl+Shift+D clear · Ctrl+I filter · Ctrl+P pause · Ctrl+O edit",
			calc: "Return copy",
			windows: "Return focus",
			run: "Return run · Shift+Return run in terminal",
			web: "Return search"
		})[LauncherState.mode]

	// Eight rows and no taller, then it scrolls. Shorter when the results are,
	// so a single hit is a small card rather than a screenful of nothing under
	// it -- except in clipboard mode, where the pane beside the list has to
	// stay a preview rather than becoming a stripe when two entries matched.
	readonly property int rowsHeight: {
		const natural = Math.min(list.contentHeight, 8 * 46);
		return LauncherState.mode === "clipboard" ? Math.max(natural, 300) : natural;
	}

	// The entry the preview pane is drawing, looked up in full: the row record
	// the list draws is flattened for one delegate to handle every mode, and
	// the pane wants the dimensions and the byte size that flattening dropped.
	readonly property var previewEntry: LauncherState.mode !== "clipboard" ? null : (ClipboardState.entries.find(e => e.id === LauncherState.current?.ref) ?? null)

	function step(delta: int): void {
		const n = LauncherState.results.length;
		if (n === 0)
			return;
		// Wraps, unlike the bar panels: a launcher list is walked from the
		// bottom as often as from the top, and walker wrapped.
		LauncherState.cursor = (LauncherState.cursor + delta % n + n) % n;
	}

	open: LauncherState.panelOpen
	onDismissed: LauncherState.close()

	// The field is the launcher's whole state, so it is what `query` follows
	// and what `open()` has to be able to set. Two-way rather than a binding:
	// typing writes the query, and super+V writes the field.
	Connections {
		target: LauncherState

		function onQueryChanged() {
			if (search.text !== LauncherState.query)
				search.text = LauncherState.query;
		}
	}

	// A text entry's real content is a fork away, so it is fetched for the row
	// the cursor lands on rather than for the hundred it walked past. Images
	// need nothing: the listing already decoded their file for the thumbnail.
	Connections {
		target: LauncherState

		function onCurrentChanged() {
			// `LauncherState.current` and not `root.previewEntry`, even though
			// the latter is exactly this lookup. `previewEntry` is a second
			// binding on the same source, and QML does not promise it has been
			// re-evaluated by the time this handler runs -- reading it here
			// left the pane showing the row the cursor had just left.
			const row = LauncherState.current;
			if (LauncherState.mode !== "clipboard" || !row)
				return;

			const entry = ClipboardState.entries.find(e => e.id === row.ref);
			if (entry?.kind === "text")
				ClipboardState.loadPreview(entry.id);
		}
	}

	// Panel hands the keyboard to its card on open; the launcher wants it in
	// the field. A Connections so the card's own handler still runs and this
	// only gets the last word.
	Connections {
		target: root

		function onVisibleChanged() {
			if (root.visible)
				search.takeFocus();
		}
	}

	SearchField {
		id: search

		placeholder: LauncherState.placeholder

		onTextChanged: {
			LauncherState.query = text;
			// Whatever was under the cursor is not in the new list, and the
			// top hit is what someone still typing is aiming at.
			LauncherState.cursor = 0;
			list.positionViewAtBeginning();
		}

		onKeyPressed: event => {
			const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
			const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
			const row = LauncherState.current;

			switch (event.key) {
			case Qt.Key_Down:
				root.step(1);
				break;
			case Qt.Key_Up:
				root.step(-1);
				break;
			case Qt.Key_PageDown:
				root.step(10);
				break;
			case Qt.Key_PageUp:
				root.step(-10);
				break;
			case Qt.Key_Return:
			case Qt.Key_Enter:
				if (shift)
					LauncherState.activateAlt(row);
				else
					LauncherState.activate(row, false);
				break;
			case Qt.Key_Escape:
				LauncherState.close();
				break;
			case Qt.Key_P:
				if (!ctrl)
					return;
				if (LauncherState.mode === "clipboard")
					ClipboardState.togglePause();
				else
					LauncherState.togglePin(row);
				break;
			case Qt.Key_D:
				if (!ctrl || LauncherState.mode !== "clipboard")
					return;
				if (shift)
					ClipboardState.wipe();
				else if (row)
					ClipboardState.remove(row.ref);
				break;
			case Qt.Key_I:
				if (!ctrl || LauncherState.mode !== "clipboard")
					return;
				ClipboardState.cycleFilter();
				LauncherState.cursor = 0;
				break;
			case Qt.Key_O:
				if (!ctrl || LauncherState.mode !== "clipboard" || !row)
					return;
				LauncherState.close();
				ClipboardState.edit(row.ref);
				break;
			default:
				// Everything unclaimed falls through to the caret, which is
				// every key that is actually part of a query.
				return;
			}

			event.accepted = true;
		}
	}

	// The clipboard's two states that are not visible in the list itself: a
	// filter hiding half of it, and a paused history that is not recording.
	// Both are silent failures otherwise -- a filtered list looks like a short
	// one, and a paused one looks like a clipboard nobody has copied into.
	RowLayout {
		Layout.fillWidth: true
		Layout.topMargin: -6
		visible: LauncherState.mode === "clipboard" && (ClipboardState.filter !== "all" || !ClipboardState.watching)

		spacing: 8

		BarText {
			visible: !ClipboardState.watching

			text: "󰏤 capture paused"
			color: Theme.yellow
		}

		BarText {
			visible: ClipboardState.filter !== "all"

			text: `showing ${ClipboardState.filter} only`
			color: Theme.dim
		}

		Item {
			Layout.fillWidth: true
		}
	}

	// The list, and in clipboard mode the preview beside it. A RowLayout even
	// when there is only one thing in it, so the list is not re-parented
	// between modes -- which would throw away its scroll position and its
	// delegates every time the query gained or lost a `:`.
	RowLayout {
		Layout.fillWidth: true
		Layout.preferredHeight: root.rowsHeight
		visible: LauncherState.results.length > 0

		spacing: 12

	ListView {
		id: list

		Layout.fillWidth: true
		Layout.fillHeight: true

		clip: true
		boundsBehavior: Flickable.StopAtBounds
		currentIndex: LauncherState.cursor
		// Keeps the cursor on screen when the arrows walk it past an edge.
		highlightRangeMode: ListView.ApplyRange
		preferredHighlightBegin: 0
		preferredHighlightEnd: height
		highlightMoveDuration: 100

		model: LauncherState.results

		delegate: Rectangle {
			id: entry

			required property var modelData
			required property int index

			// The icon theme's answer, or nothing. `check` makes iconPath hand
			// back an empty string for a name the theme does not have rather
			// than a broken-image path, which is the difference between a blank
			// square and a placeholder glyph.
			readonly property string resolved: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""

			width: list.width
			implicitHeight: 46

			radius: 6
			color: LauncherState.cursor === index ? Theme.tooltipBorder : "transparent"

			HoverHandler {
				// The pointer drives the same cursor the arrows do rather than
				// lighting a second row of its own.
				onHoveredChanged: {
					if (hovered)
						LauncherState.cursor = entry.index;
				}
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor

				onClicked: LauncherState.activate(entry.modelData, false)
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 10
				anchors.rightMargin: 10
				spacing: 10

				// One slot, three things that can fill it: a decoded clipboard
				// thumbnail, an app or window icon, or -- when the theme has
				// neither -- nothing at all rather than a broken square.
				Item {
					Layout.preferredWidth: 28
					Layout.preferredHeight: 28

					Image {
						anchors.fill: parent
						visible: entry.modelData.image !== "" || entry.resolved !== ""

						source: entry.modelData.image !== "" ? `file://${entry.modelData.image}` : entry.resolved
						fillMode: Image.PreserveAspectFit
						// Decoded at the size it is drawn: a 4K screenshot
						// thumbnail is otherwise a full-resolution texture per
						// row, and the clipboard holds a hundred rows.
						sourceSize.width: 56
						sourceSize.height: 56
						asynchronous: true
						smooth: true
					}
				}

				ColumnLayout {
					Layout.fillWidth: true
					spacing: 0

					BarText {
						Layout.fillWidth: true

						text: entry.modelData.title
						elide: Text.ElideRight
						// Weighted up so the title still leads when the row has
						// a subtitle under it.
						font.weight: Font.DemiBold
					}

					BarText {
						Layout.fillWidth: true
						visible: entry.modelData.subtitle !== ""

						text: entry.modelData.subtitle
						color: Theme.dim
						font.pixelSize: 11
						elide: Text.ElideRight
					}
				}

				BarText {
					visible: entry.modelData.badge !== ""

					text: entry.modelData.badge
					color: Theme.dim
					font.pixelSize: 11
				}
			}
		}
	}

	// The preview. The list can only ever show an entry folded onto one line --
	// cliphist's own listing collapses the newlines, and a row is 46px besides
	// -- so two entries that begin the same way are indistinguishable in it.
	// This is where you find out which one you are about to paste.
	Rectangle {
		id: pane

		// Half the card each, with the list. Both sides fill and neither states
		// a preferred width, which is what makes RowLayout split the surplus
		// evenly rather than either one having a number to keep in step with
		// `cardWidth`.
		Layout.fillWidth: true
		Layout.fillHeight: true
		visible: LauncherState.mode === "clipboard"

		radius: 6
		color: Qt.darker(Theme.tooltipBorder, 1.35)
		border.width: 1
		border.color: Theme.tooltipBorder
		clip: true

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 10
			spacing: 8

			// What this is, in the terms the list could not spare the room for:
			// the pixel dimensions and weight of an image, the line count of a
			// block of text that the list showed as one line.
			BarText {
				Layout.fillWidth: true

				text: {
					const e = root.previewEntry;
					if (!e)
						return "";
					if (e.kind === "image")
						return `Image · ${e.width}×${e.height} · ${e.size}`;
					const lines = ClipboardState.previewText === "" ? 0 : ClipboardState.previewText.split("\n").length;
					return lines > 1 ? `Text · ${lines} lines` : "Text";
				}
				color: Theme.dim
				font.pixelSize: 10
				elide: Text.ElideRight
			}

			Image {
				Layout.fillWidth: true
				Layout.fillHeight: true
				visible: root.previewEntry?.kind === "image"

				source: root.previewEntry?.kind === "image" ? `file://${root.previewEntry.path}` : ""
				fillMode: Image.PreserveAspectFit
				// Top-left rather than centred, so a wide screenshot and a tall
				// one both start in the same place instead of drifting about
				// the pane as the cursor moves between them.
				horizontalAlignment: Image.AlignLeft
				verticalAlignment: Image.AlignTop
				// Decoded at pane size, not at the screenshot's own 4K.
				sourceSize.width: 860
				asynchronous: true
				smooth: true
			}

			// The text as it was copied, newlines and indentation intact, which
			// is the whole reason it is decoded rather than taken from the
			// listing. WrapAnywhere and not Wrap: a pasted URL or a base64 blob
			// is one word, and Wrap would show a single character per line.
			BarText {
				Layout.fillWidth: true
				Layout.fillHeight: true
				visible: root.previewEntry?.kind === "text"

				text: ClipboardState.previewText
				font.pixelSize: 11
				wrapMode: Text.WrapAnywhere
				// Whatever fits, then an ellipsis. The pane is for recognising
				// an entry, not for reading it -- the script caps the decode at
				// 4KB for the same reason.
				elide: Text.ElideRight
				maximumLineCount: Math.max(1, Math.floor(height / (font.pixelSize * 1.35)))
				verticalAlignment: Text.AlignTop
			}
		}
	}

	}

	// Nothing matched. Said plainly rather than left as an empty card, which
	// reads as the launcher having broken rather than as an answer.
	BarText {
		Layout.fillWidth: true
		Layout.topMargin: 10
		Layout.bottomMargin: 10
		visible: LauncherState.results.length === 0

		text: LauncherState.query === "" ? "" : `No results for “${LauncherState.term}”`
		color: Theme.dim
		horizontalAlignment: Text.AlignHCenter
	}

	// A rule, not the bar's Divider -- that one is a vertical hairline between
	// bar modules and knows nothing about spanning a card.
	Rectangle {
		Layout.fillWidth: true
		Layout.topMargin: -4
		visible: LauncherState.results.length > 0

		implicitHeight: 1
		color: Theme.tooltipBorder
	}

	BarText {
		Layout.fillWidth: true

		text: root.hint
		color: Theme.disabled
		font.pixelSize: 10
		elide: Text.ElideRight
	}
}
