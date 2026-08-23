import qs
import qs.components

// Open-Meteo for Pinheiros, São Paulo. Kept as a script: there is nothing
// native to migrate it to, and the coordinates are hardcoded on purpose
// because every geo-IP endpoint reports the Proton VPN exit node instead.
// Click re-fetches, as the old pkill -RTMIN+10 binding did.
BarItem {
	id: root

	readonly property var d: weather.data

	active: (d.text ?? "") !== ""
	tooltip: d.tooltip ?? ""

	onClicked: weather.refresh()

	JsonScript {
		id: weather

		command: [`${Paths.scripts}/weather.sh`]
		intervalMs: 900000
	}

	BarText {
		text: root.d.text ?? ""
	}
}
