import qs
import qs.components

// Open-Meteo, for wherever the machine is -- or for the address typed into the
// panel, which is the answer when a VPN has geolocation convinced we are in
// Zurich. Kept as a script: there is nothing native to migrate it to.
//
// The bar carries the glyph and the temperature; everything else, the location
// control included, is a click away in WeatherPanel, which replaced the hover
// tooltip.
BarItem {
	active: WeatherState.available
	highlighted: WeatherState.panelOpen

	onClicked: WeatherState.toggle()

	BarText {
		text: WeatherState.data.text ?? ""
	}
}
