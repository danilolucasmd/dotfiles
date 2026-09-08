import qs
import qs.components

// Visible only while something is pending, which is the only state worth a
// seat: a permanent glyph saying "nothing is coming" would be reporting the
// normal condition of the machine forever. The same rule the night light glyph
// and the recording dot follow, and the reason Bar.qml anchors all three off
// the centre group rather than laying them out in it.
//
// An alarm clock rather than a bell, because the bell two thirds of the way
// along the right cluster is the notification history and a reminder arriving
// *is* a notification -- two bells on one bar would be the same badge twice
// with different counts.
BarItem {
	// The 8px the clock keeps between itself and the weather glyph, so the
	// centre group reads as evenly spaced whether this is showing or not.
	rightMargin: 8

	active: ReminderState.count > 0
	highlighted: ReminderState.listOpen
	// The countdown, which is the thing actually worth knowing and the thing
	// the glyph has no room for. Rebuilt every second along with the clock in
	// ReminderState, so a tooltip left open counts down while it is up.
	tooltip: {
		const next = ReminderState.reminders[0];
		if (!next)
			return "";

		const head = `${next.text} in ${ReminderState.countdown(next.due)}`;
		const rest = ReminderState.count - 1;
		return rest > 0 ? `${head} · ${rest} more` : head;
	}

	onClicked: ReminderState.toggleList()

	BarText {
		// The glyph alone, no badge. The module being on screen at all is the
		// whole message -- unlike the bell, which stays put through an empty
		// history and needs a number to say which state it is in. How many
		// there are, and when the first one lands, is what the tooltip and the
		// panel are for.
		text: "󰀠"
		// Blue is otherwise unused in the bar, so this reads as its own thing
		// rather than as a quieter notification badge; peach is what the list
		// panel paints a countdown under a minute, and the glyph agrees with it.
		color: ReminderState.reminders[0] && ReminderState.reminders[0].due - ReminderState.now < 60000 ? Theme.peach : Theme.blue
		// Theme.fontText, not the 16 of Theme.fontIcon most glyph modules use.
		// There is a lot of ink in this one -- a clock face with two bells on
		// top of it -- so at the icon size it read a size larger than the
		// weather glyph beside it and than the temperature next to that. The
		// keep-awake mug is held at 14 for the same reason; this one needed the
		// whole way down to the text size to sit level with its neighbours.
		font.pixelSize: Theme.fontText
	}
}
