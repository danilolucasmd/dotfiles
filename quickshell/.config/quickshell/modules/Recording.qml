import qs
import qs.components

// Visible only while wf-recorder is running.
BarItem {
	id: root

	readonly property var d: recording.data

	active: (d.text ?? "") !== ""
	tooltip: d.tooltip ?? ""
	rightMargin: Theme.gap

	JsonScript {
		id: recording

		command: [`${Paths.scripts}/recording.sh`]
		intervalMs: 1000
	}

	BarText {
		text: root.d.text ?? ""
		color: Theme.red
		font.pixelSize: 10
	}
}
