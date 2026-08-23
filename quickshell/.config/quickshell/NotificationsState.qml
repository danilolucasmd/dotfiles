pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon, its history, and whether the panel is up.
//
// This is what mako used to be. Owning org.freedesktop.Notifications outright
// collapses three moving parts into one: the daemon, the `on-notify` hook that
// shelled out to `makoctl list -j` to append JSONL, and the walker menu that
// read the file back. Only the file survives, and only because history should
// outlive a reboot.
//
// Two lists, deliberately different in kind:
//
//   popups  — the server's own list of live Notification objects. A
//             notification is tracked for exactly as long as its popup is up,
//             so closing the popup is what lets go of it. The app's own
//             actions exist only here, which was also as far as mako could
//             ever reach.
//   records — plain data, written to disk, what the panel browses. Nothing in
//             it points at a live object, so nothing dangles when the sending
//             app closes a notification or the config reloads underneath it.
Singleton {
	id: root

	// mako's history file was kept to `tail -n 200`; no reason to differ.
	readonly property int keep: 200

	property var records: []
	// A model rather than an array of our own: it updates a row at a time, so
	// a notification arriving does not rebuild the popups already on screen
	// (and restart every one of their timeouts).
	readonly property var popups: server.trackedNotifications

	readonly property int count: records.length

	property bool panelOpen: false

	function toggle(): void {
		panelOpen = !panelOpen;
	}

	function close(): void {
		panelOpen = false;
	}

	// Track changes and their kind: worth a glance as they go past, not worth
	// keeping. mako gave the mpd category two seconds and capture.sh dropped it
	// from the history outright; `transient` is the spec's own name for the
	// same idea, so both take that path.
	function isFleeting(notif: var): bool {
		return notif.transient || (notif.hints?.category ?? "") === "mpd";
	}

	// A notification has arrived. Everything that decides how it is treated is
	// decided here, once, so the popup and the panel never disagree about it.
	function receive(notif: var): void {
		// The server drops a notification the moment this handler returns
		// unless it is claimed. The popup needs it alive to invoke actions.
		notif.tracked = true;

		const rec = {
			uid: `${Date.now()}-${notif.id}`,
			time: Math.floor(Date.now() / 1000),
			app: notif.appName ?? "",
			summary: notif.summary ?? "",
			body: notif.body ?? "",
			urgency: notif.urgency,
			// What the panel needs to find the sender's window later, once the
			// notification object itself is long gone.
			entry: notif.desktopEntry ?? ""
		};

		if (!isFleeting(notif)) {
			records = [rec].concat(records).slice(0, keep);
			persist();
		}
	}

	// How long the popup stays up. mako ignored the timeout apps asked for
	// (`ignore-timeout=1`) and applied its own, and left urgent ones up until
	// they were dealt with. Both rules kept.
	function popupTimeout(notif: var): int {
		if (notif.urgency === NotificationUrgency.Critical)
			return 0;
		return isFleeting(notif) ? 2000 : 5000;
	}

	// Timed out, or clicked away. Letting go of the notification is what takes
	// the popup off screen; the distinction between the two is reported back to
	// the sending app, which is the only reason to carry it this far.
	function closePopup(notif: var, expired: bool): void {
		// The object can die between the card starting its fade and the fade
		// finishing — the app closes it, or the config reloads underneath it.
		if (!notif || typeof notif.expire !== "function")
			return;

		if (expired)
			notif.expire();
		else
			notif.dismiss();
	}

	// Clicking a popup. The window match runs first and the app's own default
	// action is the fallback, which is the opposite of what mako did — because
	// Brave stamps desktop-entry=brave-browser on every notification and its
	// default action raises the *browser*, when a WhatsApp message belongs to
	// the web-app window. The script knows which case it is looking at and says
	// so in its exit status.
	function activate(notif: var): void {
		const fallback = (notif.actions ?? []).find(a => a.identifier === "default") ?? null;
		focus.fallback = fallback;
		find({
			entry: notif.desktopEntry ?? "",
			app: notif.appName ?? "",
			summary: notif.summary ?? "",
			body: notif.body ?? ""
		}, fallback !== null);
	}

	// The panel's rows are plain records with no live object behind them, so
	// there is no action to fall back on and a rough match beats none.
	function focusSender(rec: var): void {
		focus.fallback = null;
		find(rec, false);
	}

	// Still a script: matching a notification against the window list is a pile
	// of heuristics that reads better in jq than in QML, and it is the file
	// mako called, minus the makoctl half.
	function find(rec: var, hasDefault: bool): void {
		focus.command = [`${Paths.scripts}/focus-sender.sh`, rec.entry ?? "", rec.app ?? "", rec.summary ?? "", rec.body ?? "", hasDefault ? "1" : "0"];
		focus.running = true;
	}

	function dismiss(rec: var): void {
		records = records.filter(r => r.uid !== rec.uid);
		persist();
	}

	function clear(): void {
		records = [];
		persist();
	}

	// What the notification actually said, as one line of plain text.
	//
	// Chromium hands a web notification's origin over as the first line of the
	// body — `web.whatsapp.com`, a blank line, then the message — and it is the
	// one thing on that row nobody is reading. A bare hostname alone on the
	// first line is specific enough to drop, and general enough to cover every
	// site Brave sends for.
	function content(rec: var): string {
		const body = String(rec.body ?? "");
		const cut = body.indexOf("\n");
		if (cut !== -1 && /^[a-z0-9-]+(\.[a-z0-9-]+)+$/i.test(body.slice(0, cut).trim())) {
			const rest = plain(body.slice(cut + 1));
			// Unless the origin was the whole body, in which case it is all
			// there is to show.
			if (rest !== "")
				return rest;
		}
		return plain(body);
	}

	// Apps are told markup is supported, and the popup renders it. The panel
	// flattens a body to one line of a dense list, where a half-elided <i> is
	// worse than no italics at all — so there it is stripped back to text.
	function plain(markup: string): string {
		return String(markup ?? "").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/\s+/g, " ").trim();
	}

	// Low / normal / critical, in the same three colours mako's per-urgency
	// border rules used.
	function urgencyColor(urgency: int): color {
		if (urgency === NotificationUrgency.Critical)
			return Theme.red;
		if (urgency === NotificationUrgency.Low)
			return Theme.dim;
		return Theme.peach;
	}

	function persist(): void {
		store.setText(records.map(r => JSON.stringify(r)).join("\n"));
	}

	function restore(text: string): void {
		const out = [];
		for (const line of text.split("\n")) {
			if (!line)
				continue;
			try {
				out.push(JSON.parse(line));
			} catch (e) {
			}
		}
		records = out;
	}

	NotificationServer {
		id: server

		// A reload is a config change, not a new session: the popups on screen
		// belong to the code being replaced, and the history they matter to is
		// on disk either way.
		keepOnReload: false

		// What we can actually honour. Advertising persistence is how an app
		// learns it need not re-send: this one really does keep them.
		persistenceSupported: true
		bodySupported: true
		bodyMarkupSupported: true
		actionsSupported: true
		// mako drew no icons either (`icons=0`), and action icons are named
		// against themes this system has no icon set for.
		imageSupported: false
		actionIconsSupported: false
		inlineReplySupported: false
		// Category is how music players label a track change, and it is the
		// only hint any of this reads.
		extraHints: ["category"]

		onNotification: notif => root.receive(notif)
	}

	FileView {
		id: store

		path: `${Paths.state}/quickshell/notifications.jsonl`
		printErrors: false
		// The panel rewrites the whole file to dismiss one line of it; a
		// half-written history is worse than a stale one.
		atomicWrites: true

		onLoaded: root.restore(text())
	}

	Process {
		// FileView will not create the directory it writes into, and this is
		// the first thing in the config to want one of its own.
		command: ["mkdir", "-p", `${Paths.state}/quickshell`]
		running: true
	}

	Process {
		id: focus

		// The default action to hand the notification back to if no window
		// matched it. Null once used, and null anyway if the notification was
		// closed while the script ran — a destroyed object reads back as null,
		// which is exactly the guard this needs.
		property var fallback: null

		onExited: code => {
			const action = fallback;
			fallback = null;
			if (code !== 0 && action)
				action.invoke();
		}
	}
}
