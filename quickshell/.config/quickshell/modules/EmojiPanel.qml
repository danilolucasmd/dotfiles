import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs
import qs.components

// The emoji picker, opened by super+E.
//
// Laid out the way every emoji keyboard is -- "Frequently Used" first, then the
// eight standard categories in CLDR order under their headings. See
// EmojiState.qml for why this exists rather than walker's symbols provider,
// which had the same emoji in alphabetical-by-name order.
Panel {
	id: root

	// Its own layer namespace, not the "quickshell:panel" every other panel
	// shares: copy-and-paste.sh waits for exactly this surface to go away
	// before it types ctrl+v, and a panel left open elsewhere must not be able
	// to hold that wait open.
	WlrLayershell.namespace: "quickshell:emoji"

	// Eight to a row, as on macOS. At the panel's 360 that lands each cell at
	// ~41px, which is a comfortable target and leaves the glyph room to breathe.
	readonly property int columns: 8
	readonly property int cellSize: Math.floor((cardWidth - pad * 2) / columns)

	property string query: ""

	// The keyboard cursor, as an index into `grid.flat`. Held flat rather than
	// as a row and column because the rows are ragged -- every section ends in a
	// short one -- so a row/column pair would need clamping at every edge
	// anyway, and this way the pointer and the arrows share one number.
	property int cursor: 0

	// Everything the list draws, worked out in one pass: the flat rows the
	// ListView takes as its model, the flat list of emoji the cursor indexes
	// into, and where each of those sits in the rows. Separate bindings would
	// walk 1500 entries once each and could disagree with one another halfway
	// through a keystroke.
	readonly property var grid: {
		const sections = [];
		const q = query.trim().toLowerCase();

		if (q === "") {
			if (EmojiState.frequent.length > 0)
				sections.push({
					name: "Frequently Used",
					emoji: EmojiState.frequent
				});
			for (const c of EmojiState.categories)
				sections.push(c);
		} else {
			const terms = q.split(/\s+/);
			const hits = [];
			for (const c of EmojiState.categories)
				for (const e of c.emoji) {
					const name = e.n.toLowerCase();
					// Name first, then the CLDR keywords -- which are what make
					// "lol" find 😂 and "hi" find 👋, neither of which says so
					// in its name.
					const words = e.k ?? "";
					const hay = `${name} ${words}`;
					if (!terms.every(t => hay.includes(t)))
						continue;
					// Ranked, because substring matching alone puts "lollipop"
					// above 😂 for "lol". A whole word wins over a fragment of
					// a longer one: what was typed is far more likely to be the
					// word than the start of some other one.
					const exactWord = (` ${words} `).includes(` ${q} `);
					hits.push({
						e: e,
						// The tiebreak keeps CLDR order inside a rank. It is
						// not decoration: QML's JS sort is not a stable one, so
						// without it equally-ranked hits come back in whatever
						// order the sort happened to leave them.
						at: hits.length,
						rank: name === q ? 0 : (exactWord ? 1 : (name.startsWith(q) ? 2 : 3))
					});
				}
			hits.sort((a, b) => (a.rank - b.rank) || (a.at - b.at));
			if (hits.length > 0)
				sections.push({
					name: hits.length === 1 ? "1 result" : `${hits.length} results`,
					emoji: hits.map(h => h.e)
				});
		}

		const rows = [];
		const flat = [];
		const rowOf = [];
		const colOf = [];

		for (const s of sections) {
			rows.push({
				header: s.name
			});

			for (let i = 0; i < s.emoji.length; i += columns) {
				const chunk = s.emoji.slice(i, i + columns);
				const base = flat.length;
				for (let j = 0; j < chunk.length; j++) {
					flat.push(chunk[j]);
					rowOf.push(rows.length);
					colOf.push(j);
				}
				rows.push({
					emoji: chunk,
					base: base
				});
			}
		}

		return {
			rows: rows,
			flat: flat,
			rowOf: rowOf,
			colOf: colOf
		};
	}

	readonly property var current: grid.flat[cursor] ?? null

	// Along the row, and off the end of one row onto the next: the grid reads
	// as one long strip broken into rows, so left at column 0 should land on
	// the last emoji of the row above rather than doing nothing.
	function step(delta: int): void {
		cursor = Math.max(0, Math.min(grid.flat.length - 1, cursor + delta));
	}

	// Up and down keep the column. The rows the cursor can land on are only the
	// emoji ones, so this walks past the headings rather than counting them,
	// and a short last row catches the cursor at its own end.
	function stepRow(delta: int): void {
		if (grid.flat.length === 0)
			return;

		const col = grid.colOf[cursor];
		for (let r = grid.rowOf[cursor] + delta; r >= 0 && r < grid.rows.length; r += delta) {
			const row = grid.rows[r];
			if (!row.emoji)
				continue;
			cursor = row.base + Math.min(col, row.emoji.length - 1);
			return;
		}
	}

	function choose(): void {
		if (current)
			EmojiState.pick(current.c);
	}

	open: EmojiState.panelOpen
	onDismissed: EmojiState.close()

	// A fresh picker every time: a query left over from the last open would
	// hide the whole grid behind a search nobody remembers making.
	onOpenChanged: {
		if (open) {
			// The field, not `query`: `query` follows the field, so clearing
			// only the property leaves the box still reading "lol" over a grid
			// that has gone back to everything.
			search.text = "";
			cursor = 0;
			list.positionViewAtBeginning();
		}
	}

	// The panel hands the keyboard to its card on open; the picker wants it in
	// the search field instead. A Connections rather than an `onVisibleChanged`
	// here so the card's own handler still runs -- this one just gets the last
	// word on where focus ends up.
	Connections {
		target: root

		function onVisibleChanged() {
			if (root.visible)
				search.forceActiveFocus();
		}
	}

	Rectangle {
		Layout.fillWidth: true
		implicitHeight: 30

		radius: 6
		color: Qt.darker(Theme.tooltipBorder, 1.25)
		border.width: 1
		border.color: search.activeFocus ? Theme.blue : "transparent"

		TextInput {
			id: search

			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 8

			verticalAlignment: TextInput.AlignVCenter
			color: Theme.fg
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontText
			selectByMouse: true
			selectionColor: Theme.blue

			onTextChanged: {
				root.query = text;
				// Whatever was under the cursor is not in the new list, and the
				// first hit is what someone typing a name is after.
				root.cursor = 0;
				list.positionViewAtBeginning();
			}

			// Keys.on* runs before the field's own handling, which is the only
			// way the arrows can drive the grid instead of the text caret.
			Keys.onLeftPressed: event => {
				root.step(-1);
				event.accepted = true;
			}
			Keys.onRightPressed: event => {
				root.step(1);
				event.accepted = true;
			}
			Keys.onUpPressed: event => {
				root.stepRow(-1);
				event.accepted = true;
			}
			Keys.onDownPressed: event => {
				root.stepRow(1);
				event.accepted = true;
			}
			Keys.onReturnPressed: event => {
				root.choose();
				event.accepted = true;
			}
			Keys.onEnterPressed: event => {
				root.choose();
				event.accepted = true;
			}
			// The card's Escape handler is out of reach while the field holds
			// the keyboard, so the field closes the panel itself.
			Keys.onEscapePressed: event => {
				EmojiState.close();
				event.accepted = true;
			}

			BarText {
				anchors.verticalCenter: parent.verticalCenter
				visible: search.text === ""

				text: "Search emoji"
				color: Theme.disabled
			}
		}
	}

	// The grid, headings and all, as one flat model: a single ListView scrolls
	// and keeps the cursor in view for free, where a Column of Repeaters inside
	// a Flickable would need both worked out by hand.
	ListView {
		id: list

		Layout.fillWidth: true
		// Eight rows of emoji and their headings, and no taller; past that it
		// scrolls. Shorter when the content is shorter, so a search with four
		// hits is a small card rather than a screenful of nothing.
		Layout.preferredHeight: Math.min(contentHeight, 320)
		visible: root.grid.rows.length > 0

		clip: true
		boundsBehavior: Flickable.StopAtBounds
		currentIndex: root.grid.rowOf[root.cursor] ?? 0
		// Keeps the cursor on screen when the arrows walk it past an edge.
		highlightRangeMode: ListView.ApplyRange
		preferredHighlightBegin: 0
		preferredHighlightEnd: height
		highlightMoveDuration: 120

		model: root.grid.rows

		delegate: Item {
			id: row

			required property var modelData

			readonly property bool isHeader: modelData.header !== undefined

			width: list.width
			implicitHeight: isHeader ? 28 : root.cellSize

			// A section heading, in the same weight as the panel's own.
			BarText {
				anchors.left: parent.left
				anchors.bottom: parent.bottom
				anchors.bottomMargin: 5
				visible: row.isHeader

				text: row.modelData.header ?? ""
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			Row {
				visible: !row.isHeader

				Repeater {
					model: row.modelData.emoji ?? []

					Rectangle {
						id: cell

						required property var modelData
						required property int index

						readonly property int flatIndex: row.modelData.base + index

						width: root.cellSize
						height: root.cellSize

						radius: 6
						color: root.cursor === flatIndex ? Theme.tooltipBorder : "transparent"

						// The pointer drives the same cursor the keys do rather
						// than lighting a second cell of its own.
						HoverHandler {
							onHoveredChanged: {
								if (hovered)
									root.cursor = cell.flatIndex;
							}
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor

							onClicked: EmojiState.pick(cell.modelData.c)
						}

						Text {
							anchors.centerIn: parent

							// No font.family: the bar's Nerd Font has its own
							// monochrome versions of some of these, and letting
							// fontconfig pick is what gets the colour emoji font.
							text: cell.modelData.c
							font.pixelSize: 22
						}
					}
				}
			}
		}
	}

	// Nothing matched. Said plainly rather than left as an empty card, which
	// reads as the picker having broken.
	BarText {
		Layout.fillWidth: true
		Layout.topMargin: 8
		Layout.bottomMargin: 8
		visible: root.grid.rows.length === 0

		text: EmojiState.categories.length === 0 ? "No emoji data — run scripts/gen-emoji-data.py" : `No emoji for “${root.query}”`
		color: Theme.dim
		horizontalAlignment: Text.AlignHCenter
		wrapMode: Text.Wrap
	}

	// What the cursor is on, spelled out. The grid is glyphs alone, and half of
	// them are only distinguishable from the one beside them by name.
	BarText {
		Layout.fillWidth: true
		visible: root.current !== null

		text: root.current?.n ?? ""
		color: Theme.dim
		horizontalAlignment: Text.AlignHCenter
		elide: Text.ElideRight
	}
}
