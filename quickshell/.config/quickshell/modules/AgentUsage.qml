import QtQuick
import qs
import qs.components

// Coding-agent rate-limit usage: the shortest window as a percentage on the
// bar, beside the agent's own glyph, and everything else — the other windows,
// the pace, the week's tokens by day and by model — a click away in
// AgentUsagePanel. The reading itself lives in AgentUsageState, which the panel
// and the super+A binding share.
BarItem {
	active: AgentUsageState.available
	rightMargin: Theme.gap
	highlighted: AgentUsageState.panelOpen

	// No tooltip: hovering used to be the only way to see the weekly window and
	// the pace, and the panel says all of that properly.
	onClicked: event => {
		if (event.button === Qt.MiddleButton)
			AgentUsageState.refresh();
		else
			AgentUsageState.toggle();
	}

	BarText {
		text: AgentUsageState.text

		color: {
			switch (AgentUsageState.cls) {
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
