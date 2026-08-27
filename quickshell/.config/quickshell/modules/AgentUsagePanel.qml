import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// The coding-agent usage panel, opened by clicking the bar module or by super+A.
//
// It replaced the module's hover tooltip. A tooltip could only ever be two
// lines of prose you had to hold the pointer still to read; the numbers that
// matter here are really comparisons — how much of the window you have burned
// against how much of it has elapsed, and what today is costing against what
// the rest of the week did — and those want meters and bars, not sentences.
//
// Three sections, in the order the questions get asked. How much is left, from
// the rate-limit windows the provider reports. Where the week went, by day.
// What is spending it, by model. The last two come from the transcripts rather
// than from any endpoint: a percentage of an allowance Anthropic does not
// publish cannot be compared against yesterday, and token counts can.
Panel {
	id: root

	open: AgentUsageState.panelOpen
	onDismissed: AgentUsageState.close()
	onRefreshRequested: AgentUsageState.refresh()
	// Left and right walk the agent tabs. They are the only keys the panel
	// wants beyond the ones Panel already claims, and h/l come along because
	// every other list in this shell takes them.
	onKeyPressed: event => {
		switch (event.key) {
		case Qt.Key_Left:
		case Qt.Key_H:
			AgentUsageState.cycle(-1);
			break;
		case Qt.Key_Right:
		case Qt.Key_L:
			AgentUsageState.cycle(1);
			break;
		default:
			return;
		}
		event.accepted = true;
	}

	// The module sits in the bar's right cluster, so the panel drops from the
	// same corner rather than from the middle of the screen.
	anchors.right: true
	margins.right: 8

	readonly property var agent: AgentUsageState.agent
	readonly property var tokens: AgentUsageState.tokens
	readonly property var byDay: tokens.byDay ?? []
	readonly property var byModel: tokens.byModel ?? []

	// Who you are looking at. The icon is the agent's own, so this row is the
	// first thing that changes when the tabs are used — a header that only said
	// "Claude Code" would make switching agents a silent act.
	RowLayout {
		Layout.fillWidth: true
		spacing: 10

		BarText {
			text: root.agent.icon ?? ""
			color: Theme.peach
			font.pixelSize: 22
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 1

			BarText {
				Layout.fillWidth: true

				text: root.agent.name ?? "No agent"
				font.pixelSize: 15
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			BarText {
				Layout.fillWidth: true
				visible: text !== ""

				text: root.agent.plan ?? ""
				color: Theme.dim
				elide: Text.ElideRight
			}
		}
	}

	// Only worth drawing when there is something to switch between. One agent
	// is the normal case here, and a single tab that cannot be left is a
	// control that does nothing.
	RowLayout {
		Layout.fillWidth: true
		visible: AgentUsageState.agents.length > 1
		spacing: 6

		Repeater {
			model: AgentUsageState.agents

			delegate: Tab {}
		}
	}

	Section {
		label: "Limits"
		visible: AgentUsageState.limits.length > 0

		Repeater {
			model: AgentUsageState.limits

			delegate: Meter {}
		}
	}

	// The seven days, oldest first. Weekday names rather than dates: the
	// question is "was yesterday heavy", and a bar chart answers that with the
	// shape before the numbers are read at all.
	Section {
		label: "Tokens by day"
		visible: root.byDay.length > 0

		Repeater {
			model: root.byDay

			delegate: TokenRow {
				rows: root.byDay
				// Today is the only row you can still change, so it is the one
				// the eye should land on.
				emphasiseLast: true
			}
		}
	}

	// The same seven days, split by model instead of by day, so the two
	// sections add up. This is where a habit shows: an expensive model left
	// selected for work that did not need it is invisible in the daily totals
	// and obvious here.
	Section {
		label: "Tokens by model"
		visible: root.byModel.length > 0

		Repeater {
			model: root.byModel

			delegate: TokenRow {
				rows: root.byModel
				// Wider than the day column: "Sat" and "Today" fit in anything,
				// "Sonnet 4.5" and "GPT-5 Mini" do not.
				labelWidth: 78
			}
		}
	}

	BarText {
		Layout.fillWidth: true
		visible: !AgentUsageState.available

		text: AgentUsageState.agents.length === 0 ? "No coding agent installed." : "No usage reading yet. Start a session, or sign in again."
		wrapMode: Text.Wrap
	}

	RowLayout {
		Layout.fillWidth: true
		spacing: 8

		// This shares its line with the key hint, and the two together only
		// just fit the card: the old "stale, last read 9h ago" ran a pixel over,
		// at which point the layout squeezed both texts below their implicit
		// width and cut them off mid-word. So the stale wording is kept as short
		// as the fresh one — the colour is already carrying the warning — and
		// this takes the slack itself, so any future copy elides here rather
		// than shoving the hint off the card.
		BarText {
			Layout.fillWidth: true

			text: {
				if (!AgentUsageState.available)
					return "";
				const prefix = root.agent.stale ? "stale · " : "updated ";
				return prefix + root.ago(root.agent.ageSeconds ?? 0);
			}
			color: root.agent.stale ? Theme.yellow : Theme.fg
			elide: Text.ElideRight
		}

		BarText {
			text: AgentUsageState.agents.length > 1 ? "←→ agent · r · esc" : "r refresh · esc close"
		}
	}

	// The tallest bar in a section, which every other bar in it is drawn as a
	// fraction of. Scaling each section to its own peak rather than to a shared
	// one is deliberate: the two are different quantities that happen to share
	// a unit, and a model list scaled to the busiest *day* would be a row of
	// stubs.
	function peakOf(rows: var): real {
		let m = 0;
		for (const r of rows)
			m = Math.max(m, r.tokens);
		return m;
	}

	// "7.9M" / "1.0B" — token counts run to ten figures and the panel is 360px
	// wide, so they are always abbreviated. One decimal place throughout, since
	// the comparison between two bars is the point and a "1B" next to a "952.4M"
	// reads as the smaller of the two.
	function abbrev(n: int): string {
		if (n >= 1e9)
			return `${(n / 1e9).toFixed(1)}B`;
		if (n >= 1e6)
			return `${(n / 1e6).toFixed(1)}M`;
		if (n >= 1e3)
			return `${(n / 1e3).toFixed(1)}K`;
		return `${n}`;
	}

	// "42s" / "7m" / "3h" / "5d" / "2w" — deliberately coarse, because the number
	// this dates only ever moves in whole percent. It rolls all the way up to
	// years: a reading with no timestamp at all dates itself to the epoch, and
	// "496536h ago" is a worse way to say that than "56y ago". Each unit floors
	// rather than rounds, so an age just under a boundary cannot render as the
	// full next unit ("24h ago", "7d ago").
	function ago(seconds: int): string {
		const units = [
			[60, 1, "s"],
			[3600, 60, "m"],
			[86400, 3600, "h"],
			[604800, 86400, "d"],
			[2592000, 604800, "w"],
			[31536000, 2592000, "mo"],
			[Infinity, 31536000, "y"],
		];
		for (const [limit, size, suffix] of units)
			if (seconds < limit)
				return `${Math.floor(seconds / size)}${suffix} ago`;
		return "";
	}

	// The same thresholds the bar glyph uses, applied per window rather than to
	// the worst of them.
	function meterColor(w: var): color {
		if (root.agent.stale)
			return Theme.dim;
		if (w.pct >= 90)
			return Theme.red;
		if (w.pct >= 70)
			return Theme.yellow;
		if (w.pace >= 0 && w.pct > w.pace)
			return Theme.peach;
		return Theme.green;
	}

	// A titled group. The heading is small, dim and uppercased rather than the
	// bold used inside the groups, so that three sections stacked in one card
	// still read as three lists and not as nine headings.
	component Section: ColumnLayout {
		id: section

		property string label

		default property alias body: rows.data

		Layout.fillWidth: true
		spacing: 8

		BarText {
			text: section.label.toUpperCase()
			color: Theme.dim
			font.pixelSize: 10
			font.letterSpacing: 1
		}

		ColumnLayout {
			id: rows

			Layout.fillWidth: true
			spacing: 8
		}
	}

	// One agent, as a button in the tab strip.
	component Tab: Rectangle {
		id: tab

		required property var modelData

		readonly property bool current: modelData.id === root.agent.id

		Layout.fillWidth: true
		implicitHeight: 26

		radius: 6
		color: current ? Theme.tooltipBorder : "transparent"
		border.width: 1
		border.color: current ? Theme.tooltipBorder : Theme.line

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: AgentUsageState.selectedId = tab.modelData.id
		}

		BarText {
			anchors.centerIn: parent
			width: parent.width - 12

			text: tab.modelData.name ?? ""
			color: tab.current ? Theme.fg : Theme.dim
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
		}
	}

	// One rate-limit window: what has been spent, against how much of the
	// window has gone by.
	component Meter: ColumnLayout {
		id: meter

		required property var modelData

		readonly property color accent: root.meterColor(modelData)
		// Straight-line extrapolation of the current burn to the reset. Only
		// worth printing once the window has run long enough for the rate to
		// mean anything — in the first minutes after a reset a single prompt
		// projects to several hundred percent.
		readonly property int projected: modelData.pace >= 10 ? Math.round(modelData.pct / modelData.pace * 100) : -1

		Layout.fillWidth: true
		spacing: 6

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			BarText {
				text: meter.modelData.label
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}

			BarText {
				text: meter.modelData.span
				color: Theme.dim
			}

			Item {
				Layout.fillWidth: true
			}

			BarText {
				text: `${meter.modelData.pct}%`
				color: meter.accent
				font.pixelSize: 15
				font.weight: Font.DemiBold
			}
		}

		Rectangle {
			id: track

			Layout.fillWidth: true
			implicitHeight: 6

			radius: height / 2
			color: Theme.track

			Rectangle {
				width: Math.min(1, meter.modelData.pct / 100) * track.width
				height: track.height
				radius: track.radius
				color: meter.accent

				Behavior on width {
					NumberAnimation {
						duration: 250
						easing.type: Easing.OutCubic
					}
				}
			}

			// Where the fill would be if the allowance were being spent evenly
			// across the window. Left of it is ahead of pace, right of it is
			// spare — which is the whole reason this panel exists. It stands
			// proud of the track rather than cutting through it, so a fill that
			// happens to end near the mark still reads as two separate things.
			Rectangle {
				visible: meter.modelData.pace >= 0
				x: Math.min(1, meter.modelData.pace / 100) * (track.width - width)
				y: -3
				width: 2
				height: track.height + 6
				radius: 1
				color: Theme.fg
				opacity: 0.6
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 8

			BarText {
				Layout.fillWidth: true

				// The projection supersedes the pace phrase rather than joining
				// it: "ahead of pace" and "~131% at reset" say the same thing,
				// the second of them precisely, and the two together ran past
				// the countdown and elided mid-word on the weekly window.
				text: {
					const w = meter.modelData;
					if (meter.projected >= 0)
						return meter.projected > 200 ? "200%+ at reset" : `~${meter.projected}% at reset`;
					if (w.pace >= 0)
						return w.pct > w.pace ? "ahead of pace" : "on pace";
					return "";
				}
				// A projection past 100% is the one thing here worth raising a
				// voice about: it means this window runs out before it resets.
				color: meter.projected > 100 ? meter.accent : Theme.dim
				elide: Text.ElideRight
			}

			BarText {
				text: `${meter.modelData.resetsIn} left`
				color: Theme.dim
			}
		}
	}

	// One bar in a token breakdown: a label, the bar, and the count. Both
	// breakdowns are the same row twice — a weekday and a model name are the
	// same shape of thing here, and the only difference is which of them gets
	// emphasised.
	component TokenRow: RowLayout {
		id: row

		required property var modelData
		required property int index
		// The whole section, not just this row: a bar is scaled against the
		// section's tallest, not against 100%, because there is no ceiling on a
		// token count and the only honest comparison a bar can draw is against
		// the others beside it. Passed in whole rather than as a precomputed
		// peak so that `index` stays inside this component — a delegate cannot
		// see it from the use site.
		required property var rows
		property bool emphasiseLast: false
		property int labelWidth: 46

		readonly property real peak: root.peakOf(rows)
		readonly property bool emphasised: emphasiseLast && index === rows.length - 1

		Layout.fillWidth: true
		spacing: 8

		// Fixed rather than sized to the text, so every bar in a section starts
		// at the same x — the whole point of the section is comparing their
		// lengths, which a ragged left edge undoes.
		BarText {
			Layout.preferredWidth: row.labelWidth

			text: row.modelData.label
			color: row.emphasised ? Theme.fg : Theme.dim
			font.weight: row.emphasised ? Font.DemiBold : Font.Normal
			elide: Text.ElideRight
		}

		Rectangle {
			id: bar

			Layout.fillWidth: true
			implicitHeight: 6

			radius: height / 2
			color: Theme.track

			Rectangle {
				width: row.peak > 0 ? row.modelData.tokens / row.peak * bar.width : 0
				height: bar.height
				radius: bar.radius
				color: row.emphasised ? Theme.peach : Theme.blue

				Behavior on width {
					NumberAnimation {
						duration: 250
						easing.type: Easing.OutCubic
					}
				}
			}
		}

		// Also fixed, and right-aligned, so the counts form a column that can
		// be read down. They are all the same order of magnitude on any normal
		// week, which makes the digits themselves a second comparison.
		BarText {
			Layout.preferredWidth: 52

			text: root.abbrev(row.modelData.tokens)
			color: row.emphasised ? Theme.fg : Theme.dim
			font.weight: row.emphasised ? Font.DemiBold : Font.Normal
			horizontalAlignment: Text.AlignRight
		}
	}
}
