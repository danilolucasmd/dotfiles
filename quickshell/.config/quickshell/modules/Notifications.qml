import qs
import qs.components

// Bell with a count of stored (un-dismissed) past notifications.
//
// It used to watch the JSONL file mako's capture hook appended to, which was
// itself a stand-in for history mako did not keep. Now the shell is the daemon,
// so the badge is just a count of what it is holding.
BarItem {
	rightMargin: Theme.gap

	// No hover tooltip: it listed the same history the panel shows, but
	// flattened to one line an entry and gone the moment you looked away.

	onClicked: NotificationsState.toggle()

	BarText {
		text: NotificationsState.count > 0 ? `󰂚 ${NotificationsState.count}` : "󰂜"
		color: NotificationsState.count > 0 ? Theme.yellow : Theme.dim
	}
}
