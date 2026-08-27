pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// The launcher: what a query means, what it turns into, and what happens when a
// row is chosen.
//
// This replaced walker, and with it elephant -- the provider daemon walker
// talked to, which was three AUR packages and a socket protocol to put a list of
// .desktop files on screen. Everything the old setup actually did is native
// here: `DesktopEntries` is a Quickshell singleton, `Hyprland.toplevels` is
// already live, the clipboard is cliphist behind scripts/clipboard.sh, and the
// calculator is qalc, which elephant was shelling out to anyway -- badly. Its
// calc provider answered `100 usd to brl` with "14.34121571 in·€²"; `qalc -t`
// answers "BRL 514.7134299", and that is the whole of the currency fix.
//
// The prefixes are walker's, deliberately: they are in the fingers.
Singleton {
	id: root

	property bool panelOpen: false

	// The whole query including its prefix, so the field and the mode cannot
	// disagree about what is being asked.
	property string query: ""

	// Which row the keyboard is on, as an index into `results`.
	property int cursor: 0

	// Query prefix -> mode. Walker's, character for character, because the one
	// thing a launcher replacement must not do is retrain the muscle memory
	// for reaching the clipboard.
	readonly property var prefixes: ({
			":": "clipboard",
			"=": "calc",
			"$": "windows",
			">": "run",
			"@": "web"
		})

	readonly property string mode: prefixes[query.charAt(0)] ?? "apps"

	// The query with its prefix taken off. Apps mode has no prefix to remove.
	readonly property string term: mode === "apps" ? query.trim() : query.slice(1).trim()

	readonly property string placeholder: ({
			apps: "Search apps",
			clipboard: "Clipboard history",
			calc: "Calculate",
			windows: "Switch window",
			run: "Run a command",
			web: "Search the web"
		})[mode]

	// Where `@` and an unmatched apps query go. One line to change, and the
	// only opinion in this file about anything outside the machine.
	readonly property string searchUrl: "https://www.google.com/search?q="

	// app id -> { n: times launched, t: last launch, epoch ms }. What makes a
	// one-letter query open the thing that letter always opens.
	property var usage: ({})

	// App ids the user pinned with ctrl+p. They sort above everything a query
	// matched, and they are what an empty launcher opens on.
	property var pinned: []

	// The last expression handed to qalc and what came back, kept as a pair so
	// a stale answer is never drawn under a query that has moved on.
	property string calcExpr: ""
	property string calcValue: ""

	// Every executable on $PATH, for run mode. Loaded the first time `>` is
	// typed and kept for the session: it is a `compgen -c` away, but that is
	// still a fork per keystroke if it is not held onto.
	property var commands: []

	// ---------------------------------------------------------------- opening

	function toggle(): void {
		if (panelOpen)
			close();
		else
			open("");
	}

	// super+V. The same window as everything else, opened already switched --
	// the clipboard was never a second launcher, only a second thing to search.
	function toggleClipboard(): void {
		if (panelOpen && mode === "clipboard")
			close();
		else
			open(":");
	}

	function open(initial: string): void {
		query = initial;
		cursor = 0;
		if (initial.charAt(0) === ":")
			ClipboardState.reload();
		panelOpen = true;
	}

	function close(): void {
		panelOpen = false;
	}

	// ---------------------------------------------------------------- scoring

	// -1 for no match, higher is better. Three tiers, in the order someone
	// typing expects them: what starts with the query, what contains it, and
	// what merely spells it out in order ("gimp" finding "GNU Image
	// Manipulation Program" is the subsequence tier earning its keep).
	function fuzzy(text: string, needle: string): real {
		if (needle === "")
			return 0;
		if (!text)
			return -1;

		const t = text.toLowerCase();
		const at = t.indexOf(needle);

		if (at === 0)
			return 1000 - text.length * 0.5;
		if (at > 0) {
			// A hit at a word boundary is the one someone meant: "code" should
			// find "Visual Studio Code" ahead of "Barcode Reader".
			const boundary = " -_./:".includes(t.charAt(at - 1));
			return (boundary ? 700 : 400) - at - text.length * 0.5;
		}

		// Subsequence: every character in order, scored down by how far apart
		// they had to be and how late the first one lands.
		let i = 0;
		let gaps = 0;
		let first = -1;
		for (let n = 0; n < needle.length; n++) {
			const found = t.indexOf(needle.charAt(n), i);
			if (found < 0)
				return -1;
			if (first < 0)
				first = found;
			else if (found > i)
				gaps += found - i;
			i = found + 1;
		}
		return 200 - gaps - first;
	}

	// How much a launch history is worth on top of the match. Capped, and the
	// recency half decays in two steps rather than continuously -- the point is
	// that today's tools outrank last month's, not that the ninth launch
	// outranks the eighth.
	function frecency(key: string): real {
		const u = usage[key];
		if (!u)
			return 0;

		const days = (Date.now() - u.t) / 86400000;
		const recent = days < 1 ? 60 : (days < 7 ? 25 : 0);
		return Math.min(240, u.n * 40) + recent;
	}

	// ------------------------------------------------------------------- rows
	//
	// Every mode produces the same record so the panel has one delegate:
	//
	//   kind     which branch of `activate` the row belongs to
	//   title    the line in full weight
	//   subtitle the dim line under it, or ""
	//   icon     an icon theme name, resolved by the panel
	//   image    an absolute path, for the clipboard's decoded thumbnails
	//   badge    small right-aligned text: a workspace, a file size
	//   ref      whatever `activate` needs back -- an entry, an id, an address

	function appRows(): var {
		const q = term.toLowerCase();
		const hits = [];

		for (const entry of DesktopEntries.applications.values) {
			if (entry.noDisplay)
				continue;

			let score;
			if (q === "") {
				// An empty launcher is a most-used list, not an alphabet. The
				// unused tail still lists -- scrolling to it is how you find
				// the thing you have never opened -- but it sorts below
				// everything you have.
				score = frecency(entry.id);
			} else {
				// Name first, then the fields that are real but weaker
				// evidence: a generic name ("Web Browser") and the keywords a
				// .desktop file carries for exactly this.
				score = Math.max(fuzzy(entry.name, q), fuzzy(entry.genericName, q) - 150, fuzzy((entry.keywords ?? []).join(" "), q) - 250);
				if (score < 0)
					continue;
				score += frecency(entry.id);
			}

			if (pinned.includes(entry.id))
				score += 2000;

			hits.push({
				score: score,
				entry: entry
			});
		}

		// The name is the tiebreak, and it is not decoration: QML's sort is not
		// stable, so without it the untouched tail of an empty launcher --
		// every one of them scoring 0 -- reshuffles on each open.
		hits.sort((a, b) => (b.score - a.score) || a.entry.name.localeCompare(b.entry.name));

		return hits.slice(0, 50).map(h => ({
					kind: "app",
					title: h.entry.name,
					subtitle: h.entry.genericName || h.entry.comment || "",
					icon: h.entry.icon,
					image: "",
					badge: pinned.includes(h.entry.id) ? "pinned" : "",
					ref: h.entry
				}));
	}

	function clipboardRows(): var {
		const q = term.toLowerCase();

		return ClipboardState.shown.filter(e =>
			// Images have no text to match, so a query hides them rather than
			// listing every one of them under a search they cannot answer.
			q === "" ? true : (e.kind === "text" && e.preview.toLowerCase().includes(q))).slice(0, 100).map(e => ({
					kind: "clip",
					title: e.kind === "image" ? "Image" : e.preview,
					subtitle: e.kind === "image" ? `${e.width}×${e.height}` : "",
					icon: e.kind === "image" ? "" : "edit-paste",
					image: e.path ?? "",
					badge: e.size ?? "",
					ref: e.id
				}));
	}

	function windowRows(): var {
		const q = term.toLowerCase();
		const hits = [];

		for (const top of Hyprland.toplevels.values) {
			// No class means Hyprland does not count this among its clients,
			// and `hyprctl clients` is the honest definition of "a window":
			// the toplevel list also carries things nobody can switch to --
			// Nautilus' preview helper, the invisible surface wl-copy holds the
			// selection with -- and a switcher that offered those would be
			// listing the desktop's plumbing. Populated by the
			// `refreshToplevels` on entering this mode, below.
			const cls = top.lastIpcObject?.class ?? "";
			if (cls === "")
				continue;

			const score = q === "" ? 0 : Math.max(fuzzy(top.title, q), fuzzy(cls, q));
			if (score < 0)
				continue;

			hits.push({
				score: score,
				top: top,
				cls: cls
			});
		}

		hits.sort((a, b) => (b.score - a.score) || a.top.title.localeCompare(b.top.title));

		return hits.map(h => ({
					kind: "window",
					title: h.top.title,
					subtitle: h.cls,
					// The window's own app icon where the class names a desktop
					// entry, which is nearly always. heuristicLookup is what
					// forgives the case and the reverse-DNS id.
					icon: DesktopEntries.heuristicLookup(h.cls)?.icon ?? "application-x-executable",
					image: "",
					badge: h.top.workspace?.name ?? "",
					ref: h.top.address
				}));
	}

	function runRows(): var {
		if (term === "")
			return [];

		const rows = [{
				kind: "run",
				title: term,
				subtitle: "Run command",
				icon: "utilities-terminal",
				image: "",
				badge: "",
				ref: term
			}];

		// Whatever on $PATH starts with the first word, so `>` is a launcher
		// rather than a blind prompt. Only a prefix match, and only while the
		// command is still one word: past the first space the query is
		// arguments, and a completion list would be lying about what it knows.
		const head = term.split(" ")[0].toLowerCase();
		if (!term.includes(" "))
			for (const cmd of commands) {
				if (rows.length > 20)
					break;
				if (cmd.toLowerCase().startsWith(head) && cmd !== term)
					rows.push({
						kind: "run",
						title: cmd,
						subtitle: "",
						icon: "utilities-terminal",
						image: "",
						badge: "",
						ref: cmd
					});
			}

		return rows;
	}

	// Anything with a dot and no space is offered as a URL as well as a search,
	// which is the whole of walker's `open_url` action. Deliberately loose: the
	// row is an offer, and the search is right underneath it.
	function looksUrl(s: string): bool {
		return /^[a-z]+:\/\//i.test(s) || (/^[\w-]+(\.[\w-]+)+(\/|$|\?)/.test(s) && !s.includes(" "));
	}

	function webRows(): var {
		if (term === "")
			return [];

		const rows = [];
		if (looksUrl(term))
			rows.push({
				kind: "url",
				title: term,
				subtitle: "Open URL",
				// `internet-web-browser`, not the shorter `web-browser` the
				// name suggests: breeze-dark is the icon theme here (see
				// QS_ICON_THEME in hyprland.conf) and only has the long one.
				icon: "internet-web-browser",
				image: "",
				badge: "",
				ref: /^[a-z]+:\/\//i.test(term) ? term : `https://${term}`
			});

		rows.push({
			kind: "web",
			title: term,
			subtitle: "Search the web",
			icon: "system-search",
			image: "",
			badge: "",
			ref: term
		});

		return rows;
	}

	function calcRows(): var {
		// Only ever the answer to the question on screen. `calcExpr` is what
		// was sent, `term` is what is being asked; between a keystroke and
		// qalc coming back they differ, and drawing the old answer under the
		// new query is how a calculator gets caught lying.
		if (calcExpr !== term || calcValue === "")
			return [];

		return [{
				kind: "calc",
				title: calcValue,
				subtitle: term,
				icon: "accessories-calculator",
				image: "",
				badge: "copy",
				ref: calcValue
			}];
	}

	// Whether a query typed with no prefix at all is arithmetic. Strict on
	// purpose: qalc reads everything as units and will answer "firefox" with
	// "0 B" and "hello world" with "6.5E−26 B²·h²·L³", so anything short of
	// real evidence of a sum has to fall through to the app list. The `=`
	// prefix is the way to ask anyway, and it skips all of this.
	function looksMath(s: string): bool {
		if (!/\d/.test(s))
			return false;
		// digit, operator, digit -- so "wine-9" and "gtk3.0" are not sums.
		if (/\d\s*[+\-*/^%]\s*[\d(.]/.test(s))
			return true;
		// "100 usd to brl", "3 ft in cm".
		if (/\d\s*[a-z°$€£]+\s+(to|in)\s+\S/i.test(s))
			return true;
		return /\b(sqrt|sin|cos|tan|log|ln|abs|exp)\s*\(/i.test(s);
	}

	readonly property var results: {
		switch (mode) {
		case "clipboard":
			return clipboardRows();
		case "calc":
			return calcRows();
		case "windows":
			return windowRows();
		case "run":
			return runRows();
		case "web":
			return webRows();
		}

		// Apps, plus the two providers walker also had in its default set: a
		// sum answers above the app list, and a web search waits underneath in
		// case nothing here was what was meant.
		const rows = calcRows().concat(appRows());
		if (term !== "" && rows.length === 0)
			return webRows();
		return rows;
	}

	readonly property var current: results[cursor] ?? null

	// --------------------------------------------------------------- activate

	// Closing first, always, and not for the animation: the panel holds a
	// HyprlandFocusGrab while it is up, so a window opened underneath it does
	// not get the keyboard until the grab is gone, and the clipboard paste
	// waits for this exact surface to disappear before it types ctrl+v.
	function activate(row: var, keepOpen: bool): void {
		if (!row)
			return;
		if (!keepOpen)
			panelOpen = false;

		switch (row.kind) {
		case "app":
			remember(row.ref.id);
			row.ref.execute();
			break;
		case "clip":
			ClipboardState.paste(row.ref);
			break;
		case "window":
			Hyprland.dispatch(`focuswindow address:${row.ref}`);
			break;
		case "run":
			Quickshell.execDetached(["sh", "-c", row.ref]);
			break;
		case "calc":
			Quickshell.execDetached(["wl-copy", "--", row.ref]);
			break;
		case "url":
			Quickshell.execDetached(["xdg-open", row.ref]);
			break;
		case "web":
			Quickshell.execDetached(["xdg-open", searchUrl + encodeURIComponent(row.ref)]);
			break;
		}
	}

	// shift+Return. Only two modes have a second thing to do; everywhere else
	// it is the plain activation with the panel left up, which is walker's
	// `start:keep` and the fastest way to open three apps in a row.
	function activateAlt(row: var): void {
		if (!row)
			return;

		if (row.kind === "run") {
			panelOpen = false;
			// `; exec $SHELL` rather than a bare run: the point of asking for a
			// terminal is to read what it printed, and a ghostty that exits on
			// the last line of output shows nothing at all.
			Quickshell.execDetached(["ghostty", "-e", "sh", "-c", `${row.ref}; exec $SHELL`]);
			return;
		}

		if (row.kind === "clip" && ClipboardState.entries.find(e => e.id === row.ref)?.kind === "image") {
			panelOpen = false;
			ClipboardState.edit(row.ref);
			return;
		}

		activate(row, true);
	}

	function togglePin(row: var): void {
		if (!row || row.kind !== "app")
			return;

		const id = row.ref.id;
		// A new array rather than a splice: QML compares a `var` by reference,
		// so mutating in place changes nothing anything is bound to.
		pinned = pinned.includes(id) ? pinned.filter(p => p !== id) : pinned.concat([id]);
		store.setText(JSON.stringify({
			usage: usage,
			pinned: pinned
		}));
	}

	function remember(id: string): void {
		const next = Object.assign({}, usage);
		next[id] = {
			n: (usage[id]?.n ?? 0) + 1,
			t: Date.now()
		};
		usage = next;
		store.setText(JSON.stringify({
			usage: next,
			pinned: pinned
		}));
	}

	// ------------------------------------------------------------------ calc

	// Debounced rather than run on every keystroke: qalc is a fork and a parse,
	// and "100 usd to brl" is eight forks' worth of half-typed nonsense on the
	// way to being a question. 140ms is under the point where the answer feels
	// like it is lagging the typing.
	Timer {
		id: debounce

		interval: 140
		onTriggered: {
			const expr = root.term;
			if (expr === "" || (root.mode !== "calc" && !root.looksMath(expr))) {
				root.calcExpr = "";
				root.calcValue = "";
				return;
			}
			calc.command = ["qalc", "-t", "--", expr];
			calc.running = true;
		}
	}

	onTermChanged: {
		// The old answer goes the moment the question changes, so a slow qalc
		// cannot leave it standing under a query it does not answer.
		calcValue = "";
		debounce.restart();
	}

	Process {
		id: calc

		// `-t` is terse: the value alone, no echo of the input. Anything on
		// stderr is qalc complaining, and the row simply does not appear.
		stdout: StdioCollector {
			onStreamFinished: {
				const value = text.trim();
				// qalc hands back an unevaluated expression when it cannot do
				// anything with it -- "1/0" comes back as "1 / 0". A result
				// that is only the question again is not a result.
				if (value === "" || value.replace(/\s/g, "") === root.term.replace(/\s/g, ""))
					return;
				root.calcExpr = root.term;
				root.calcValue = value;
			}
		}
	}

	// ------------------------------------------------------------------ state

	// Loaded blocking so the first open is already in most-used order: read
	// asynchronously, the launcher would open on an alphabetical list and
	// reorder itself a frame later, under the fingers.
	FileView {
		id: store

		path: `${Paths.state}/quickshell/launcher-usage.json`
		blockLoading: true
		printErrors: false
		atomicWrites: true

		onLoaded: {
			try {
				const saved = JSON.parse(text());
				root.usage = saved.usage ?? ({});
				root.pinned = saved.pinned ?? [];
			} catch (e) {
				// Unreadable means written by something that is not this. A
				// fresh history costs one session's ordering and nothing else.
				root.usage = ({});
				root.pinned = [];
			}
		}
	}

	// FileView will not create the directory it writes into, and no singleton
	// here can rely on another having started first.
	Process {
		command: ["mkdir", "-p", `${Paths.state}/quickshell`]
		running: true
	}

	// $PATH, once, the first time run mode is entered. `compgen` is a bash
	// builtin, which is why this is `bash -c` and not `sh -c`.
	Process {
		id: pathScan

		command: ["bash", "-c", "compgen -c | sort -u"]
		running: false

		stdout: StdioCollector {
			onStreamFinished: root.commands = text.trim().split("\n")
		}
	}

	onModeChanged: {
		if (mode === "run" && commands.length === 0)
			pathScan.running = true;
		if (mode === "clipboard")
			ClipboardState.reload();
		// Quickshell tracks toplevels from the Wayland protocol and fills in
		// what Hyprland knows about them lazily, so an untouched window can sit
		// in the list with no class and no workspace until something asks. This
		// is that ask, and it is why `windowRows` can insist on a class.
		if (mode === "windows")
			Hyprland.refreshToplevels();
	}
}
