import qs
import qs.components

// Visible only while wf-recorder is running. Bar.qml parks it just off the
// right edge of the centre group, so the clock's own 16px margin is the gap
// it sits in and the module needs no margin of its own.
BarItem {
	id: root

	readonly property var d: recording.data

	active: (d.text ?? "") !== ""
	tooltip: d.tooltip ?? ""

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
