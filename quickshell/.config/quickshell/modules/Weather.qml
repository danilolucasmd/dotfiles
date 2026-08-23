import qs
import qs.components

// Open-Meteo for Pinheiros, São Paulo. Kept as a script: there is nothing
// native to migrate it to, and the coordinates are hardcoded on purpose
// because every geo-IP endpoint reports the Proton VPN exit node instead.
//
// The bar carries the glyph and the temperature; everything else is a click
// away in WeatherPanel, which replaced the hover tooltip.
BarItem {
	active: WeatherState.available

	onClicked: WeatherState.toggle()

	BarText {
		text: WeatherState.data.text ?? ""
	}
}
