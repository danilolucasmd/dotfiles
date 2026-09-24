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
	// The surface stays at the clipboard's width whichever mode is up, so
	// typing or deleting a `:c` changes the card and not the window under it.
	// See `surfaceWidth` in Panel.qml for what a resizing surface costs.
	surfaceWidth: 900

	// Centred, both ways. Panel anchors its top edge and lets the compositor
	// centre the other axis; unsetting that anchor leaves neither edge anchored,
	// which is what makes layer-shell centre the surface outright. The launcher
	// is summoned from anywhere by a keybind and has no bar module it should
	// appear to hang from, unlike every other panel here.
	//
	// A card centred on a fixed point only stays still if it is a fixed size,
	// which is the other half of why `rowsHeight` is a constant.
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

	// Eight rows, always, however few of them are filled. Sizing the list to
	// its results instead -- which is what this did -- meant the card resized
	// on every keystroke that narrowed the list, and a layer-shell surface that
	// resizes while it is on screen is one Hyprland animates by scaling its
	// buffer into the box: the old, taller card left smeared under the new one
	// for the length of the animation. A card that never changes height is
	// never animated, and the search field stops walking down the screen as the
	// list empties under it besides.
	readonly property int rowsHeight: 8 * 46

	// The information block is a fixed five rows of space whatever it has to put
	// in them. The rows themselves vary -- five for an image, seven for text,
	// fewer again while the decode that fills the counts is still in flight --
	// and a block that sized itself to them moved the rule above it and resized
	// the preview under the cursor on every step through the list.
	//
	// Five and not the seven that text can produce: the block is worth a fifth
	// of the pane and no more, and the two rows that do not fit scroll rather
	// than taking the room from the thing they describe. The same trade as
	// `rowsHeight`, for the same reason.
	readonly property int infoRows: 5
	readonly property int infoRowHeight: 16
	readonly property int infoSpacing: 3

	// The entry the preview pane is drawing, looked up in full: the row record
	// the list draws is flattened for one delegate to handle every mode, and
	// the pane wants the dimensions and the byte size that flattening dropped.
	readonly property var previewEntry: LauncherState.mode !== "clipboard" ? null : (ClipboardState.entries.find(e => e.id === LauncherState.current?.ref) ?? null)

	// Every row the information block can hold, in the order they are drawn.
	// The Repeater's model, and constant on purpose: a model rebuilt per entry
	// makes the Repeater destroy and recreate every delegate as the cursor
	// walks the list, which reloads the application icon and blinks all seven
	// labels even between two entries whose rows are identical. This list never
	// changes, so the delegates outlive the cursor and only their text moves.
	//
	// Longer than the block is tall: an image entry and a text one share only
	// three of these, and `infoRows` reserves the room for the longest of the
	// two sets rather than for the union, which cannot occur.
	readonly property var infoSlots: ["Application", "Content type", "Dimensions", "Image size", "Characters", "Words", "Lines", "Text size", "Copied"]

	// label -> value for the entry under the cursor. A label this leaves out is
	// a row that is not drawn: an "Application" reading "unknown" for every
	// entry copied before the note-taking existed is a column of noise.
	readonly property var info: {
		const e = previewEntry;
		if (!e)
			return ({});

		const rows = {};

		// The desktop entry behind the window class, for the name a human would
		// use. heuristicLookup is what forgives the case and the reverse-DNS
		// id, the same as in windows mode.
		if (e.app)
			rows["Application"] = DesktopEntries.heuristicLookup(e.app)?.name ?? e.app;

		if (e.kind === "image") {
			rows["Content type"] = `Image (${e.ext.toUpperCase()})`;
			rows["Dimensions"] = `${e.width}×${e.height}`;
			rows["Image size"] = e.size;
		} else {
			const i = ClipboardState.previewInfo;
			// What the entry is for, when that is something other than prose: a
			// link is the one worth calling out, because it is the entry you
			// most often hold several near-identical copies of.
			rows["Content type"] = /^\w+:\/\/\S+$/.test(ClipboardState.previewText.trim()) ? "Link" : "Text";
			// Null for an entry past the script's 1MiB cap, where the only
			// honest count is none. "1" for a single line rather than dropping
			// the row: three text entries in a row should differ in their
			// numbers and not in which numbers they have.
			if (i.chars != null) {
				rows["Characters"] = String(i.chars);
				rows["Words"] = String(i.words);
				rows["Lines"] = String(i.lines);
			}
			if (i.bytes !== undefined)
				rows["Text size"] = root.humanSize(i.bytes, i.truncated === true);
		}

		// 0 is an entry copied before the note-taking, not the epoch.
		if (e.at)
			rows["Copied"] = root.stamp(e.at);

		return rows;
	}

	// The application row's icon, kept beside the values rather than in them:
	// it is the one field that is not a string, and the one delegate that draws
	// it can ask for it by name.
	readonly property string infoIcon: {
		const e = previewEntry;
		return e?.app ? (DesktopEntries.heuristicLookup(e.app)?.icon ?? "") : "";
	}

	// cliphist's own units for an image, applied to a text entry so the two
	// kinds of entry do not report their weight in two different ways. `atLeast`
	// is the capped decode: the number is a floor, and saying so beats quoting
	// 1.0 MB for a 40MB paste.
	function humanSize(bytes: int, atLeast: bool): string {
		const units = ["B", "KiB", "MiB"];
		let v = bytes;
		let u = 0;
		while (v >= 1024 && u < units.length - 1) {
			v /= 1024;
			u++;
		}
		return `${u === 0 ? v : v.toFixed(1)} ${units[u]}${atLeast ? "+" : ""}`;
	}

	// A clock for today and a date for anything older. The history is walked
	// back days at a time, and "14:32" against six other 14:32s says nothing.
	function stamp(epoch: int): string {
		const d = new Date(epoch * 1000);
		const sameDay = d.toDateString() === new Date().toDateString();
		return Qt.formatDateTime(d, sameDay ? "HH:mm" : "MMM d, HH:mm");
	}

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

		spacing: 12

	// The list and the line that stands in for it when nothing matched, in one
	// slot rather than one after the other: a "no results" line of its own
	// below the list would be height the card gains and loses, which is the
	// resize this is all arranged to avoid.
	Item {
		Layout.fillWidth: true
		Layout.fillHeight: true

		BarText {
			anchors.centerIn: parent
			visible: LauncherState.results.length === 0

			text: LauncherState.query === "" ? "" : `No results for \u201c${LauncherState.term}\u201d`
			color: Theme.dim
		}

	ListView {
		id: list

		anchors.fill: parent

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

			Image {
				Layout.fillWidth: true
				Layout.fillHeight: true
				visible: root.previewEntry?.kind === "image"

				source: root.previewEntry?.kind === "image" ? `file://${root.previewEntry.path}` : ""
				fillMode: Image.PreserveAspectFit
				// Centred in what is left of the pane above the information
				// block. The block is a fixed height, so the space this is
				// centred in is the same for every image and a wide screenshot
				// and a tall one are both simply in the middle of it.
				horizontalAlignment: Image.AlignHCenter
				verticalAlignment: Image.AlignVCenter
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

			// Everything about the entry that is not the entry: where it came
			// from, what it is, how big. Raycast's clipboard history has the
			// same block and it is the half of the pane that answers "which of
			// these three screenshots is the one I want" without reading the
			// picture -- the application and the time do that on their own.
			//
			// Under the preview rather than over it, so the preview keeps the
			// top of the pane whichever kind of entry is up. Its height is
			// `infoRows` whatever it holds; see there.
			Rectangle {
				Layout.fillWidth: true
				visible: root.previewEntry !== null

				implicitHeight: 1
				color: Theme.tooltipBorder
			}

			// Five rows of space and however many rows the entry has, which is
			// seven for a text one. A Flickable and not the ListView the rest of
			// this file reaches for: a ListView keeps the height of a delegate
			// it has hidden and pads the spacing around it either way, so the
			// four slots an entry has no value for would show as a gap. A
			// ColumnLayout drops an invisible child outright, and there is no
			// cursor here for a ListView to be tracking.
			Flickable {
				id: infoFlick

				Layout.fillWidth: true
				// Both, and not just the preferred height: a layout nested in a
				// layout defaults to filling it, so this would have taken the
				// surplus the preview is supposed to get and the rule above it
				// would sit directly under a two-line entry and halfway down the
				// pane for an image -- the drift this block exists to stop.
				Layout.fillHeight: false
				Layout.preferredHeight: root.infoRows * root.infoRowHeight + (root.infoRows - 1) * root.infoSpacing
				Layout.maximumHeight: Layout.preferredHeight
				visible: root.previewEntry !== null

				contentHeight: infoColumn.implicitHeight
				boundsBehavior: Flickable.StopAtBounds
				// Nothing to drag when it all fits, so an entry with four rows
				// cannot be scrolled off its own block by a stray wheel.
				interactive: contentHeight > height
				clip: true

			ColumnLayout {
				id: infoColumn

				width: infoFlick.width

				spacing: root.infoSpacing

				Repeater {
					model: root.infoSlots

					RowLayout {
						id: row

						required property string modelData

						// This slot's value for the entry under the cursor, and
						// whether the entry has one at all. A row an image has
						// and a text entry does not simply stops drawing: the
						// delegate itself stays.
						readonly property string value: root.info[modelData] ?? ""

						visible: value !== ""

						Layout.fillWidth: true
						// Stated rather than implicit, so the reservation above
						// is a count of rows this size and not an estimate of
						// what a label happens to measure. fillHeight off for
						// the same reason it is off on the block: a nested
						// layout fills by default, and five rows sharing seven
						// rows of space are five rows in the wrong places.
						Layout.fillHeight: false
						Layout.preferredHeight: root.infoRowHeight
						spacing: 8

						BarText {
							text: row.modelData
							color: Theme.dim
							font.pixelSize: 11
						}

						// The gap, so the value sits against the right edge and
						// the values line up as a column of their own however
						// long the labels beside them are.
						Item {
							Layout.fillWidth: true
						}

						Image {
							// The one row that has an icon. Bound to the name
							// rather than carried in `info`, so the value map
							// stays strings and this delegate is the only thing
							// that knows an icon exists.
							visible: row.modelData === "Application" && root.infoIcon !== ""

							Layout.preferredWidth: 14
							Layout.preferredHeight: 14

							// `check`, so a class the icon theme has nothing for
							// leaves the slot empty rather than drawing a broken
							// image beside a perfectly good name.
							source: visible ? Quickshell.iconPath(root.infoIcon, true) : ""
							fillMode: Image.PreserveAspectFit
							sourceSize.width: 28
							asynchronous: true
							smooth: true
						}

						BarText {
							// A window title is not in here, but an application
							// name can still be long; the label must not be the
							// thing that gets pushed off the row.
							Layout.maximumWidth: 240

							text: row.value
							font.pixelSize: 11
							elide: Text.ElideRight
						}
					}
				}
			}

				// What says there is more under the fold, since the rows carry
				// no scrollbar and a block cut off at a row boundary looks
				// exactly like a block that ended there.
				Rectangle {
					// A Flickable parents its children to the content item, so
					// this scrolls with the rows unless it is told to follow the
					// viewport: hence `contentY` rather than an anchor to the
					// bottom, which would put it at the bottom of the content.
					x: 0
					y: infoFlick.contentY + infoFlick.height - height

					width: infoFlick.width
					height: 14
					visible: infoFlick.contentHeight - infoFlick.contentY > infoFlick.height + 1

					gradient: Gradient {
						GradientStop {
							position: 0
							color: "transparent"
						}
						GradientStop {
							position: 1
							color: pane.color
						}
					}
				}
			}
		}
	}

	}

	// A rule, not the bar's Divider -- that one is a vertical hairline between
	// bar modules and knows nothing about spanning a card.
	Rectangle {
		Layout.fillWidth: true
		Layout.topMargin: -4

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
