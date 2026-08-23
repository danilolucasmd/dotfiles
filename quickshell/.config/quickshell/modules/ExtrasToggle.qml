import qs
import qs.components

// The chevron that opens the collapsed half of the right cluster.
//
// It stays the leftmost thing in the cluster in both states, so it reads as the
// edge the extras fold into. Pointing left means "there is more out this way";
// once open it points back right, at the direction they fold away in.
BarItem {
	id: root

	rightMargin: Theme.gap
	tooltip: BarState.extrasVisible ? "Hide extras" : "Show extras"

	onClicked: BarState.extrasVisible = !BarState.extrasVisible

	BarText {
		text: BarState.extrasVisible ? "󰅂" : "󰅁"
		font.pixelSize: 20
	}
}
