import QtQuick
import qs
import qs.components

// Claude Code rate-limit usage: the 5h session window as a percentage on the
// bar, everything else a click away in AgentUsagePanel. The reading itself
// lives in AgentUsageState, which the panel and the super+A binding share.
BarItem {
	active: AgentUsageState.available
	rightMargin: Theme.gap

	// No tooltip: hovering used to be the only way to see the weekly window and
	// the pace, and the panel says all of that properly.
	onClicked: event => {
		if (event.button === Qt.MiddleButton)
			AgentUsageState.refresh();
		else
			AgentUsageState.toggle();
	}

	BarText {
		text: AgentUsageState.data.text ?? ""

		color: {
			switch (AgentUsageState.data["class"] ?? "") {
			case "stale":
				return Theme.dim;
			case "critical":
				return Theme.red;
			case "warning":
				return Theme.yellow;
			case "ahead":
				return Theme.peach;
			default:
				return Theme.fg;
			}
		}
	}
}
