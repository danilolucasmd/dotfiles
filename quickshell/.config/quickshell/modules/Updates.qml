import qs
import qs.components

// Pending package updates, official repos + AUR. Hidden when there are none.
BarItem {
	id: root

	readonly property var d: updates.data

	active: (d.text ?? "") !== ""
	tooltip: d.tooltip ?? ""
	rightMargin: Theme.gap

	onClicked: updates.refresh()

	JsonScript {
		id: updates

		command: [`${Paths.scripts}/updates.sh`]
		intervalMs: 1800000
	}

	BarText {
		text: root.d.text ?? ""
		color: Theme.yellow
	}
}
