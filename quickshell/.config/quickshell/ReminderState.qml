pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Reminders: the pending list, the clock that fires them, and the two panels
// that write and read them.
//
// A reminder is a notification sent to your own future self, and that is
// deliberately all it is -- there is no calendar, no repeat and no date. The
// question it answers is "not now, but in a bit", which is the one thing a
// sticky note on the desk was for and the one thing nothing else here does:
// the calendar panel is a read-only view of the month, and a `sleep 600 &&
// notify-send` typed at a prompt dies with the terminal it was typed in.
//
// Two windows share this singleton rather than having one each, because they
// are two views of the same list: ReminderPanel.qml writes one and
// ReminderListPanel.qml shows what is still pending. That is also why there is
// one IPC target with two functions in shell.qml rather than two targets.
//
// Firing is deliberately not a QML Timer per reminder. The list outlives the
// session -- it is on disk -- so the thing that decides whether a reminder is
// due has to be a comparison against the wall clock, not a countdown that
// started when the shell did. A reminder that came due while the machine was
// asleep or shut down fires on the first tick after it comes back, which is
// late but is the only honest answer; a timer would have silently lost it.
Singleton {
	id: root

	// [{ uid, text, due, created }], soonest first. `due` and `created` are
	// epoch milliseconds.
	property var reminders: []

	readonly property int count: reminders.length

	// The compose panel and the list panel. Separate windows, so separate
	// flags -- see components/Panel.qml.
	property bool panelOpen: false
	property bool listOpen: false

	// Where the compose panel is: 0 is the message, 1 is the delay. One field
	// asked twice rather than two fields and a Tab between them, because the
	// whole interaction is meant to be type, enter, type, enter.
	property int step: 0
	// The message, held between the two steps.
	property string draft: ""

	// The snooze buttons on a fired reminder and the shortcuts the compose
	// panel offers, which are the same five answers to the same question and so
	// are one list. The keys are what reminder-notify.sh passes back as the
	// chosen action, so they are the minute counts themselves and the labels
	// are only what is drawn.
	readonly property var presets: [
		{
			minutes: 5,
			label: "5m"
		},
		{
			minutes: 15,
			label: "15m"
		},
		{
			minutes: 30,
			label: "30m"
		},
		{
			minutes: 60,
			label: "1h"
		},
		{
			minutes: 180,
			label: "3h"
		}
	]

	// The wall clock, republished once a second so every countdown on screen
	// moves together and none of them has a timer of its own.
	property double now: Date.now()

	function toggle(): void {
		if (panelOpen) {
			close();
			return;
		}

		// Always back to the message: a compose panel reopened halfway through
		// asking for minutes, for a message typed some time ago, is asking a
		// question with no visible context.
		draft = "";
		step = 0;
		panelOpen = true;
	}

	function close(): void {
		panelOpen = false;
	}

	function toggleList(): void {
		listOpen = !listOpen;
	}

	function closeList(): void {
		listOpen = false;
	}

	// Enter on the message. An empty one is not an error, it is nothing to be
	// reminded about, so the panel simply does not move on.
	function submitMessage(text: string): bool {
		const body = String(text ?? "").trim();
		if (body === "")
			return false;

		draft = body;
		step = 1;
		return true;
	}

	// Enter on the delay. Minutes, plainly -- "90" rather than "1h30", because
	// a parser that understands one shape has to be explained and one that
	// understands none does not.
	function submitDelay(text: string): bool {
		const minutes = parseInt(String(text ?? "").trim(), 10);
		if (!(minutes > 0))
			return false;

		add(draft, minutes);
		close();
		return true;
	}

	// Escape at the delay step. The message is the part that took typing, so
	// the first Escape goes back to it and only the second one closes.
	function back(): bool {
		if (step === 0)
			return false;

		step = 0;
		return true;
	}

	function add(text: string, minutes: int): void {
		const body = String(text ?? "").trim();
		if (body === "" || !(minutes > 0))
			return;

		const at = Date.now();
		const rec = {
			// The wall clock alone is not unique: two reminders can be
			// scheduled inside the same millisecond by the preset buttons.
			uid: `${at}-${Math.floor(Math.random() * 1000000)}`,
			text: body,
			created: at,
			due: at + minutes * 60000
		};

		// Kept sorted here rather than in the panel, so the list panel and the
		// firing loop agree on what "next" means.
		reminders = reminders.concat([rec]).sort((a, b) => a.due - b.due);
		persist();
	}

	function remove(rec: var): void {
		reminders = reminders.filter(r => r.uid !== rec.uid);
		persist();
	}

	function clear(): void {
		reminders = [];
		persist();
	}

	// A snooze, handed back by reminder-notify.sh over `qs ipc`. The reminder
	// itself is long gone by then -- it was taken off the list the moment it
	// fired -- so this is a new one carrying the same text, which is also what
	// makes a snoozed reminder show up in the list panel with a fresh
	// countdown.
	//
	// Minutes arrive as a string because that is what the IPC call carries;
	// `add` does the parsing that `submitDelay` does for the keyboard.
	function snooze(message: string, minutes: string): void {
		add(message, parseInt(String(minutes ?? ""), 10));
	}

	// Come due: off the list, then out to the script. Taking it off first is
	// what stops a reminder firing twice if the notification hangs around --
	// the popup is sticky, so it can be on screen for hours.
	function tick(): void {
		now = Date.now();

		const due = reminders.filter(r => r.due <= now);
		if (due.length === 0)
			return;

		reminders = reminders.filter(r => r.due > now);
		persist();

		for (const rec of due)
			Quickshell.execDetached([`${Paths.scripts}/reminder-notify.sh`, rec.text]);
	}

	// What is left, for the list panel. Rounded rather than truncated so a
	// reminder set for five minutes reads "5m 00s" and not "4m 59s".
	function countdown(due: double): string {
		const left = Math.max(0, Math.round((due - now) / 1000));
		const h = Math.floor(left / 3600);
		const m = Math.floor((left % 3600) / 60);
		const s = left % 60;

		// One unit of precision below whatever the leading one is: seconds
		// ticking under an hours reading is noise, and a bare "2m" hides
		// whether it is about to go off.
		if (h > 0)
			return `${h}h ${String(m).padStart(2, "0")}m`;
		if (m > 0)
			return `${m}m ${String(s).padStart(2, "0")}s`;
		return `${s}s`;
	}

	// The clock time it lands at, which is the reading you actually plan
	// around once the countdown is longer than a few minutes.
	function dueAt(due: double): string {
		const at = new Date(due);
		const today = new Date(now);
		const when = Qt.formatDateTime(at, "HH:mm");
		return at.toDateString() === today.toDateString() ? when : `${Qt.formatDateTime(at, "ddd")} ${when}`;
	}

	function persist(): void {
		store.setText(JSON.stringify(reminders));
	}

	// Once a second, and only while there is something to count down. Nothing
	// else in the shell needs this clock, so an idle machine with no reminders
	// set does not run it at all.
	Timer {
		running: root.reminders.length > 0
		interval: 1000
		repeat: true
		triggeredOnStart: true

		onTriggered: root.tick()
	}

	// Read blocking, like the emoji tally and for a sharper reason: the timer
	// above starts the moment the list is non-empty, and a list loaded a frame
	// late is a list that spent that frame looking empty. Blocking also means
	// anything that came due while the shell was down has already been loaded
	// by the time the first tick runs, so it fires at once rather than being
	// skipped.
	FileView {
		id: store

		path: `${Paths.state}/quickshell/reminders.json`
		blockLoading: true
		printErrors: false
		// The file is rewritten whole to remove one line of it; a half-written
		// list is worse than a stale one.
		atomicWrites: true

		onLoaded: {
			try {
				const list = JSON.parse(text());
				root.reminders = Array.isArray(list) ? list.sort((a, b) => a.due - b.due) : [];
			} catch (e) {
				// Unreadable means written by something that is not this. An
				// empty list is a visible failure -- the panel says there are
				// none -- where a crash here would take the bar with it.
				root.reminders = [];
			}
		}
	}

	// FileView will not create the directory it writes into, and no singleton
	// here can rely on another having started first.
	Process {
		command: ["mkdir", "-p", `${Paths.state}/quickshell`]
		running: true
	}
}
