import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Current conditions, opened by clicking the weather module.
//
// The old tooltip put the same three facts in a paragraph you had to read
// left to right. They are a reading and two supporting numbers, so here they
// are laid out as such: the temperature large enough to take in at a glance,
// the rest as a small table under it.
Panel {
	id: root

	readonly property var d: WeatherState.data

	open: WeatherState.panelOpen
	onDismissed: WeatherState.close()
	onRefreshRequested: WeatherState.refresh()

	// No left or right anchor: the module sits in the bar's centre group, so
	// the compositor centring the panel puts it right under it.

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: root.d.place ?? ""
			font.pixelSize: 13
			font.weight: Font.DemiBold
		}

		Item {
			Layout.fillWidth: true
		}

		BarText {
			text: root.d.stale ? "stale" : ""
			color: Theme.yellow
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

	// Tighter than the panel's own section spacing: the two readings are one
	// block, not two.
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
	}

	BarText {
		Layout.fillWidth: true
		visible: !WeatherState.available

		text: "No reading yet — nothing has reached Open-Meteo since login."
		wrapMode: Text.Wrap
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
