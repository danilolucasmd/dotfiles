import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The keybind cheatsheet, opened by super+shift+slash. See KeybindsState.qml for
// where the list comes from.
//
// Wide like the launcher and for the same reason -- a row is a run of keycaps
// and then a sentence -- but it is its own panel rather than a launcher mode:
// what it lists are not things to open, and half of them cannot be run at all.
Panel {
	id: root

	cardWidth: 620
	margins.top: 120

	function step(delta: int): void {
		const n = KeybindsState.results.length;
		if (n === 0)
			return;
		KeybindsState.cursor = (KeybindsState.cursor + delta % n + n) % n;
	}

	open: KeybindsState.panelOpen
	onDismissed: KeybindsState.close()

	Connections {
		target: root

		function onVisibleChanged() {
			if (root.visible) {
				search.clear();
				search.takeFocus();
			}
		}
	}

	SearchField {
		id: search

		placeholder: "Search keybinds"

		onTextChanged: {
			KeybindsState.query = text;
			KeybindsState.cursor = 0;
			list.positionViewAtBeginning();
		}

		onKeyPressed: event => {
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
				KeybindsState.run(KeybindsState.current);
				break;
			case Qt.Key_Escape:
				KeybindsState.close();
				break;
			default:
				return;
			}

			event.accepted = true;
		}
	}

	ListView {
		id: list

		Layout.fillWidth: true
		// Ten rows, then it scrolls. Taller than the launcher's eight because
		// nothing here is chosen by typing until it is the only one left --
		// the sheet is read as much as it is searched.
		Layout.preferredHeight: Math.min(contentHeight, 10 * 32)
		visible: KeybindsState.results.length > 0

		clip: true
		boundsBehavior: Flickable.StopAtBounds
		currentIndex: KeybindsState.cursor
		highlightRangeMode: ListView.ApplyRange
		preferredHighlightBegin: 0
		preferredHighlightEnd: height
		highlightMoveDuration: 100

		model: KeybindsState.results

		delegate: Rectangle {
			id: entry

			required property var modelData
			required property int index

			// A mouse bind has nothing to dispatch. Listed anyway -- it is
			// still a binding somebody may be hunting for -- but dimmed, and
			// Return on it does nothing.
			readonly property bool runnable: modelData.dispatcher !== ""

			width: list.width
			implicitHeight: 32

			radius: 6
			color: KeybindsState.cursor === index ? Theme.tooltipBorder : "transparent"

			HoverHandler {
				onHoveredChanged: {
					if (hovered)
						KeybindsState.cursor = entry.index;
				}
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: entry.runnable ? Qt.PointingHandCursor : Qt.ArrowCursor

				onClicked: KeybindsState.run(entry.modelData)
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 10
				spacing: 10

				// The chord, one keycap per modifier and one for the key. The
				// reason keybinds.py hands over a list rather than the
				// "SUPER + T" string walker's dmenu needed: a padded column of
				// monospace was the best that could be done there, and this is
				// what the sheet is actually for.
				// A Row inside a sized Item, not a nested RowLayout. Two reasons,
				// both found the hard way: a Layout nested in a Layout defaults
				// `fillWidth` to *true* unlike every other item, so the chord column
				// swallowed the row and shoved each description against the right
				// edge -- and once that was pinned, a RowLayout held wider than its
				// contents spreads them across the surplus, which pushed the key away
				// from its modifiers. A Row is a positioner and does neither.
				Item {
					// max(190, the chord itself). The minimum is what lines every
					// description up at the same x; a chord wider than it pushes its
					// own row out, which is rarer and less ugly than a clipped keycap.
					Layout.fillWidth: false
					Layout.minimumWidth: 190
					Layout.preferredWidth: chord.implicitWidth
					Layout.fillHeight: true

					Row {
						id: chord

						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter

						spacing: 4

						Repeater {
							model: entry.modelData.keys

							Rectangle {
								required property string modelData

								implicitWidth: cap.implicitWidth + 12
								implicitHeight: 20

								radius: 4
								color: Qt.darker(Theme.tooltipBorder, 1.25)
								border.width: 1
								border.color: Theme.tooltipBorder

								BarText {
									id: cap

									anchors.centerIn: parent

									text: parent.modelData
									font.pixelSize: 10
									color: entry.runnable ? Theme.fg : Theme.disabled
								}
							}
						}
					}
				}

				BarText {
					Layout.fillWidth: true

					text: entry.modelData.description
					color: entry.runnable ? Theme.fg : Theme.disabled
					elide: Text.ElideRight
				}

				// "submap resize", "on release". Empty on all but a handful,
				// which is the point -- see flags() in keybinds.py.
				BarText {
					visible: entry.modelData.note !== ""

					text: entry.modelData.note
					color: Theme.dim
					font.pixelSize: 10
				}
			}
		}
	}

	BarText {
		Layout.fillWidth: true
		Layout.topMargin: 10
		Layout.bottomMargin: 10
		visible: KeybindsState.results.length === 0

		text: KeybindsState.binds.length === 0 ? "No binds — check scripts/keybinds.py" : `No keybind for “${KeybindsState.query}”`
		color: Theme.dim
		horizontalAlignment: Text.AlignHCenter
	}
}
