import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Current conditions and the next three days, opened by clicking the weather
// module.
//
// The old tooltip put three facts in a paragraph you had to read left to right.
// They are a reading and some supporting numbers, so here they are laid out as
// such: the temperature large enough to take in at a glance, the rest as a
// small table under it, and the outlook as one row per day at the bottom.
//
// The header doubles as the location control. The place name is the only thing
// on the panel that says where any of this is for, so it is also the thing you
// click to change it -- a settings button somewhere else would have been a
// second answer to the same question.
Panel {
	id: root

	readonly property var d: WeatherState.data

	open: WeatherState.panelOpen
	onDismissed: WeatherState.close()
	onRefreshRequested: WeatherState.refresh()

	// The address box takes the keyboard for itself while it is up, so the card
	// has to be handed it back when the box goes away, or the panel is left
	// deaf to Escape and R.
	Connections {
		target: WeatherState

		function onEditingChanged() {
			if (!WeatherState.editing)
				root.takeFocus();
		}
	}

	// No left or right anchor: the module sits in the bar's centre group, so
	// the compositor centring the panel puts it right under it.

	RowLayout {
		Layout.fillWidth: true
		visible: !WeatherState.editing
		spacing: 6

		// The pin marks a reading that simply followed the machine here. A
		// typed-in location gets the clear button in its place, so exactly one
		// of the two is ever up and the row reads the same either way.
		BarText {
			visible: WeatherState.detecting

			text: "󰍎"
			color: Theme.dim
			font.pixelSize: Theme.fontIcon
		}

		BarText {
			// Wide enough for a long neighbourhood and city, short enough to
			// leave the stale flag somewhere to sit.
			Layout.maximumWidth: 240

			text: root.d.place ?? "Locating…"
			font.pixelSize: 13
			font.weight: Font.DemiBold
			elide: Text.ElideRight
			color: placeMouse.containsMouse ? Theme.blue : Theme.fg

			MouseArea {
				id: placeMouse

				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor

				onClicked: WeatherState.edit()
			}
		}

		BarText {
			visible: !WeatherState.detecting

			text: "󰅖"
			color: clearMouse.containsMouse ? Theme.red : Theme.dim
			font.pixelSize: Theme.fontIcon

			MouseArea {
				id: clearMouse

				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor

				onClicked: WeatherState.clearCustom()
			}
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: root.d.stale ? "stale" : ""
			color: Theme.yellow
		}
	}

	// ------------------------------------------------------------------
	// Changing where the reading is for
	//
	// Opens in place of the header rather than under it: the address you are
	// typing is going to replace the name you clicked, and showing both at once
	// invites you to wonder which one is in force.
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		visible: WeatherState.editing
		spacing: 6

		Rectangle {
			Layout.fillWidth: true
			implicitHeight: 30

			radius: 6
			color: Qt.darker(Theme.tooltipBorder, 1.25)
			border.width: 1
			border.color: address.activeFocus ? Theme.blue : "transparent"

			TextInput {
				id: address

				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 8

				verticalAlignment: TextInput.AlignVCenter
				color: Theme.fg
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontText
				selectByMouse: true
				selectionColor: Theme.blue
				enabled: !WeatherState.resolving

				// The box is a section that appears rather than a window, so
				// nothing else would hand it the keyboard. It opens on the name
				// that is in force, selected, because the common edit is
				// "somewhere else entirely" rather than a correction.
				onVisibleChanged: {
					if (visible) {
						text = root.d.place ?? "";
						selectAll();
						forceActiveFocus();
					}
				}
				onAccepted: WeatherState.resolve(text)
				// Escape backs out of the box rather than out of the panel: the
				// card's own handler would close the lot, which is not what
				// someone abandoning an address meant.
				Keys.onEscapePressed: event => {
					WeatherState.cancelEdit();
					event.accepted = true;
				}

				BarText {
					anchors.verticalCenter: parent.verticalCenter
					visible: address.text === ""

					text: "neighbourhood, city"
					color: Theme.disabled
				}
			}
		}

		BarText {
			Layout.fillWidth: true

			text: WeatherState.resolving ? "Looking it up…" : WeatherState.error !== "" ? WeatherState.error : "enter to use it · esc to keep the current one"
			color: WeatherState.error !== "" && !WeatherState.resolving ? Theme.red : Theme.dim
			wrapMode: Text.Wrap
		}
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 12

		BarText {
			text: root.d.icon ?? ""
			font.pixelSize: 34
		}

		BarText {
			text: `${root.d.temp ?? "?"}°`
			font.pixelSize: 28
			font.weight: Font.DemiBold
		}

		BarText {
			Layout.fillWidth: true

			text: root.d.desc ?? ""
			font.pixelSize: 13
			wrapMode: Text.Wrap
		}
	}

	// Tighter than the panel's own section spacing: the three readings are one
	// block, not three.
	ColumnLayout {
		Layout.fillWidth: true
		visible: WeatherState.available
		spacing: 4

		Reading {
			label: "Feels like"
			value: `${root.d.feels ?? "?"}°`
		}

		Reading {
			label: "Humidity"
			value: `${root.d.humidity ?? "?"}%`
		}

		Reading {
			label: "Wind"
			value: root.d.wind ?? "?"
		}
	}

	BarText {
		Layout.fillWidth: true
		visible: !WeatherState.available

		text: "No reading yet — nothing has reached Open-Meteo since login."
		wrapMode: Text.Wrap
	}

	// ------------------------------------------------------------------
	// The next three days
	//
	// Three rows and no more: this is the "do I need a jacket this week"
	// question, and Open-Meteo's sixteen days of it would be a scrolling list
	// nobody reads past the top of.
	// ------------------------------------------------------------------

	ColumnLayout {
		Layout.fillWidth: true
		visible: (root.d.forecast?.length ?? 0) > 0
		spacing: 6

		BarText {
			text: "Next three days"
			color: Theme.dim
		}

		Repeater {
			model: root.d.forecast ?? []

			delegate: RowLayout {
				required property var modelData

				Layout.fillWidth: true
				spacing: 8

				BarText {
					// Fixed, so the icons line up under each other rather than
					// stepping in and out with the length of the weekday.
					Layout.preferredWidth: 30

					text: modelData.day
					font.weight: Font.DemiBold
				}

				BarText {
					text: modelData.icon
					font.pixelSize: Theme.fontIcon
				}

				BarText {
					Layout.fillWidth: true

					text: modelData.desc
					color: Theme.dim
					elide: Text.ElideRight
				}

				// The high is the number the day gets remembered by; the low
				// goes dim beside it rather than on a line of its own.
				BarText {
					text: `${modelData.hi}°`
				}

				BarText {
					text: `${modelData.lo}°`
					color: Theme.dim
				}
			}
		}
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: WeatherState.available ? `updated ${root.d.updated ?? ""}` : ""
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: "r refresh · esc close"
		}
	}

	// One label/value pair, the value hard against the right edge so the
	// numbers line up under each other.
	component Reading: RowLayout {
		id: reading

		property string label: ""
		property string value: ""

		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: reading.label
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: reading.value
		}
	}
}
