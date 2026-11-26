# Bindings ported from vimium/vimium-c-options.json, the Vimium C keymap used on
# Brave, so the same fingers work in both browsers. qutebrowser's own defaults
# already cover most of Vimium's (j/k/h/l, gg/G, f/F, yy, /, n/N, gi, gt/gT,
# g0/g$, gu/gU, and <C-u>/<C-d> as half-page scrolls, which is what Vimium's
# scrollPageUp/Down are), so only the keys the Vimium config changes are here.
#
# Vimium's unmaps (J K u d r p P o O B T ge) are deliberately not ported yet:
# qutebrowser's defaults on those keys stay until it is clear which are wanted.

# config.py is the source of truth. `:set` still works for the running session,
# but qutebrowser writes those to autoconfig.yml, which is not read back on the
# next start: a setting worth keeping belongs in this file instead.
config.load_autoconfig(False)

# Vimium C's switchFocus jumps into the page's input. Without a focused-input
# memory to toggle back to, the closest qutebrowser has is gi's first-input hint.
config.bind("gI", "hint inputs --first")

# Vimium's hint alphabet and look. Fourteen characters give 196 two-letter
# labels, where qutebrowser's nine home-row keys run out at 81 and start
# handing out three-letter ones on any busy page. Every label on a page has the
# same length, as in Vimium, and is shown in capitals.
config.set("hints.chars", "sadfjklewcmpgh")
config.set("hints.uppercase", True)

# History
config.bind("<Ctrl-o>", "back")
config.bind("<Ctrl-i>", "forward")

# Tab manipulation. H and L are back/forward by default in qutebrowser, the
# opposite of the Vimium keymap, which moves them to <C-o>/<C-i> above.
config.bind("L", "tab-next")
config.bind("H", "tab-prev")
for mode in ("normal", "insert"):
    config.bind("<Alt-l>", "tab-next", mode=mode)
    config.bind("<Alt-h>", "tab-prev", mode=mode)
# qutebrowser fires a key the moment it exactly matches a binding, so the
# default `b` (quickmark prompt) would swallow every b-chord below. It is the
# one default given up for them; `:quickmark-load` and `B` still reach it.
config.unbind("b")
config.bind("bo", "tab-only")
# --prev keeps the tabs before the current one, so everything to its right goes.
config.bind("br", "tab-only --prev")
config.bind("bH", "tab-move -")
config.bind("bL", "tab-move +")

# Brave's address-bar keys. <C-l> opens the current URL with the URL itself
# selected, as Chrome does, so typing replaces it and an arrow key edits it.
# cmd-set-text cannot select, so the selection is made by keypresses sent to
# the command line: Home, past "open " (five characters; the command line never
# lets the cursor sit before its ":" prompt, so Home lands after it), Shift-End.
config.bind(
    "<Ctrl-l>",
    "cmd-set-text :open {url:pretty} ;; "
    "fake-key -g <Home><Right><Right><Right><Right><Right><Shift-End>",
)
config.bind("<Ctrl-t>", "cmd-set-text -s :open -t")

# Google as the engine behind the address bar. auto_search "naive" is what
# makes typed text that does not look like a URL go to it, as in Chrome; it is
# the default, set here so the behaviour does not hang on qutebrowser's choice.
config.set("url.searchengines", {"DEFAULT": "https://www.google.com/search?q={}"})
config.set("url.auto_search", "naive")
config.set("url.default_page", "https://www.google.com/")
config.set("url.start_pages", ["https://www.google.com/"])

# Dark mode, in two layers. preferred_color_scheme tells sites (and DevTools,
# which follows the system preference) that dark is wanted, so anything with a
# real dark theme uses it. darkmode.enabled is Chromium's forced dark mode, the
# Dark Reader equivalent, for every site without one; "smart" image policy
# leaves photos alone. Both need a restart to take effect.
config.set("colors.webpage.preferred_color_scheme", "dark")
config.set("colors.webpage.darkmode.enabled", True)
config.set("colors.webpage.darkmode.policy.images", "smart")
# Dark Reader's per-site switch. QtWebEngine 6.7+ applies darkmode.enabled per
# URL pattern without a restart, so this flips it for the current host only.
# -t keeps the override to this session, like everything set outside this file.
for mode in ("normal", "insert"):
    config.bind(
        "<Alt-Shift-A>",
        "config-cycle -p -t -u *://{url:host}/* colors.webpage.darkmode.enabled false true ;; reload",
        mode=mode,
    )
# DevTools ignores preferred_color_scheme, which is a per-page Blink setting
# the inspector does not get, and its own theme choice is lost when it closes.
# This Chromium switch makes the browser itself report a dark system theme,
# which DevTools' default "System preference" theme follows.
config.set("qt.args", ["force-dark-mode"])
# The colour a page shows before it paints; white here is a flash on every load.
config.set("colors.webpage.bg", "#2c292f")

# Theme. The base is ghostty's background, so the browser and terminal read as
# one surface; text, font and the Catppuccin accents are the quickshell bar's
# (Theme.qml), with mauve as the lead accent because it belongs with a purple
# base. Layers step lighter for raised things (selected tab, completion row)
# and darker for the bars around them.
BASE = "#2c292f"
MANTLE = "#231f26"
RAISED = "#3d3744"
BORDER = "#4a4452"
FG = "#dddddd"
DIM = "#8a8590"
MAUVE = "#cba6f7"
GREEN = "#a6e3a1"
BLUE = "#89b4fa"
PEACH = "#fab387"
YELLOW = "#f9e2af"
RED = "#f38ba8"
ON_ACCENT = "#1e1b22"

config.set("fonts.default_family", "JetBrainsMono Nerd Font")
config.set("fonts.default_size", "10pt")

# Tabs: inactive ones sink into the bar, the active one is raised with bright
# text, and the load indicator runs mauve to green, red on failure.
config.set("tabs.padding", {"top": 5, "bottom": 5, "left": 8, "right": 8})
config.set("tabs.indicator.width", 2)
config.set("colors.tabs.bar.bg", MANTLE)
for parity in ("odd", "even"):
    config.set(f"colors.tabs.{parity}.bg", MANTLE)
    config.set(f"colors.tabs.{parity}.fg", DIM)
    config.set(f"colors.tabs.selected.{parity}.bg", RAISED)
    config.set(f"colors.tabs.selected.{parity}.fg", "#ffffff")
    config.set(f"colors.tabs.pinned.{parity}.bg", MANTLE)
    config.set(f"colors.tabs.pinned.{parity}.fg", MAUVE)
    config.set(f"colors.tabs.pinned.selected.{parity}.bg", RAISED)
    config.set(f"colors.tabs.pinned.selected.{parity}.fg", MAUVE)
config.set("colors.tabs.indicator.start", MAUVE)
config.set("colors.tabs.indicator.stop", GREEN)
config.set("colors.tabs.indicator.error", RED)

# Statusbar: base colour in normal mode, and each other mode gets its own
# accent so the mode is visible at a glance without reading the label.
config.set("statusbar.padding", {"top": 4, "bottom": 4, "left": 6, "right": 6})
config.set("colors.statusbar.normal.bg", BASE)
config.set("colors.statusbar.normal.fg", FG)
config.set("colors.statusbar.command.bg", BASE)
config.set("colors.statusbar.command.fg", FG)
config.set("colors.statusbar.insert.bg", GREEN)
config.set("colors.statusbar.insert.fg", ON_ACCENT)
config.set("colors.statusbar.passthrough.bg", BLUE)
config.set("colors.statusbar.passthrough.fg", ON_ACCENT)
for caret in ("caret", "caret.selection"):
    config.set(f"colors.statusbar.{caret}.bg", PEACH)
    config.set(f"colors.statusbar.{caret}.fg", ON_ACCENT)
config.set("colors.statusbar.progress.bg", MAUVE)
config.set("colors.statusbar.url.fg", FG)
config.set("colors.statusbar.url.hover.fg", BLUE)
config.set("colors.statusbar.url.success.http.fg", FG)
config.set("colors.statusbar.url.success.https.fg", GREEN)
config.set("colors.statusbar.url.warn.fg", YELLOW)
config.set("colors.statusbar.url.error.fg", RED)

# Completion (the :open list): mauve marks the selected row and the typed
# match, categories sit a step darker than the rows.
config.set("colors.completion.fg", FG)
config.set("colors.completion.odd.bg", BASE)
config.set("colors.completion.even.bg", BASE)
config.set("colors.completion.category.bg", MANTLE)
config.set("colors.completion.category.fg", MAUVE)
config.set("colors.completion.category.border.top", MANTLE)
config.set("colors.completion.category.border.bottom", BORDER)
config.set("colors.completion.item.selected.bg", RAISED)
config.set("colors.completion.item.selected.fg", "#ffffff")
config.set("colors.completion.item.selected.border.top", RAISED)
config.set("colors.completion.item.selected.border.bottom", RAISED)
config.set("colors.completion.item.selected.match.fg", MAUVE)
config.set("colors.completion.match.fg", MAUVE)
config.set("colors.completion.scrollbar.bg", BASE)
config.set("colors.completion.scrollbar.fg", BORDER)

config.set("colors.keyhint.bg", MANTLE)
config.set("colors.keyhint.fg", FG)
config.set("colors.keyhint.suffix.fg", MAUVE)

for level, accent in (("info", BLUE), ("warning", YELLOW), ("error", RED)):
    config.set(f"colors.messages.{level}.bg", RAISED)
    config.set(f"colors.messages.{level}.border", accent)
    config.set(f"colors.messages.{level}.fg", accent if level != "info" else FG)

config.set("colors.prompts.bg", MANTLE)
config.set("colors.prompts.fg", FG)
config.set("colors.prompts.border", f"1px solid {BORDER}")
config.set("colors.prompts.selected.bg", RAISED)
config.set("colors.prompts.selected.fg", "#ffffff")

config.set("colors.downloads.bar.bg", MANTLE)
config.set("colors.downloads.start.bg", MAUVE)
config.set("colors.downloads.stop.bg", GREEN)
config.set("colors.downloads.error.bg", RED)
for part in ("start", "stop", "error"):
    config.set(f"colors.downloads.{part}.fg", ON_ACCENT)

config.set("colors.contextmenu.menu.bg", MANTLE)
config.set("colors.contextmenu.menu.fg", FG)
config.set("colors.contextmenu.selected.bg", RAISED)
config.set("colors.contextmenu.selected.fg", "#ffffff")
config.set("colors.contextmenu.disabled.fg", DIM)
config.set("colors.tooltip.bg", MANTLE)
config.set("colors.tooltip.fg", FG)

# Private windows (<C-S-n>, or `:open -p`) keep no history, cookies or session.
# The statusbar is the only chrome qutebrowser recolours for them, so it goes
# Brave-incognito purple to make the mode unmistakable.
config.set("colors.statusbar.private.bg", "#6b3fa0")
config.set("colors.statusbar.command.private.bg", "#5a3389")

# Chrome's <C-S-t>: reopen the last closed tab, or, in a window that has
# closed none yet, bring back the tabs that were open when the browser last
# quit. qutebrowser only offers the second half as auto_save.session, which
# restores on every launch instead of on request, so it is built here from two
# internals: the quit-time session hook is wrapped to save the open windows
# under _reopen, and a `reopen` command loads it. Both are qutebrowser
# internals, not config API, so a qutebrowser upgrade is what would break them.
# Private windows are never saved, so they only ever undo.
from qutebrowser.api import cmdutils, message
from qutebrowser.misc import objects, sessions
from qutebrowser.utils import objreg

REOPEN_SESSION = "_reopen"

if not hasattr(sessions, "_original_shutdown"):
    sessions._original_shutdown = sessions.shutdown


def _shutdown_saving_reopen(session, last_window):
    manager = sessions.session_manager
    if manager is not None and session is None:
        data = manager._last_window_session if last_window else manager._save_all()
        # Closing a private window last leaves nothing to save; keep the
        # previous session rather than overwrite it with an empty one.
        if data and any(window["tabs"] for window in data["windows"]):
            try:
                manager.save(REOPEN_SESSION, last_window=last_window)
            except sessions.SessionError as e:
                message.error(f"Failed to save tabs for reopen: {e}")
    sessions._original_shutdown(session, last_window)


sessions.shutdown = _shutdown_saving_reopen

# Dropped first so `:config-source` can re-register it instead of failing.
objects.commands.pop("reopen", None)


@cmdutils.register(name="reopen")
@cmdutils.argument("win_id", value=cmdutils.Value.win_id)
def reopen(win_id: int) -> None:
    """Reopen the last closed tab, or the tabs from the last browser session."""
    tabbed_browser = objreg.get("tabbed-browser", scope="window", window=win_id)
    manager = sessions.session_manager
    if tabbed_browser.undo_stack:
        tabbed_browser.undo()
        return
    if tabbed_browser.is_private or not manager.exists(REOPEN_SESSION):
        raise cmdutils.CommandError("Nothing to undo")
    tabs = tabbed_browser.widgets()
    untouched = len(tabs) == 1 and len(tabs[0].history) <= 1
    try:
        manager.load(REOPEN_SESSION, temp=True)
        manager.delete(REOPEN_SESSION)
    except sessions.SessionError as e:
        raise cmdutils.CommandError(f"Failed to reopen tabs: {e}")
    # The window it was pressed in holds only the start page, so the restored
    # windows replace it, as in Chrome.
    if untouched:
        objreg.get("main-window", scope="window", window=win_id).close()


config.bind("<Ctrl-Shift-T>", "reopen")

# 1Password fill, the stand-in for its browser extension, which qutebrowser
# cannot run. <C-\> asks the `op` CLI (signed in through the desktop app's CLI
# integration) for the Login items whose website matches the page: exactly one
# is filled straight away, otherwise the command line opens on `1password-fill`
# and qutebrowser's own completion list is the picker, so nothing outside the
# browser is needed on either Linux or macOS. Like `reopen`, the command and its
# completion use qutebrowser internals.
#
# op runs through QProcess so a slow CLI, or the app waiting on its approval
# prompt, never freezes the browser. Secrets go to the page through
# run_js_async rather than a :jseval command, so they never pass through the
# command parser, history or logs. A one-time code, when the item has one, is
# copied for the step after the password.
import json
import shutil
import sys
from urllib.parse import urlparse

from qutebrowser.commands import runners
from qutebrowser.completion.models import completionmodel, listcategory
from qutebrowser.qt.core import QProcess
from qutebrowser.utils import utils

# An app launched from the macOS Dock gets a PATH without Homebrew on it.
OP = shutil.which("op") or next(
    (p for p in ("/opt/homebrew/bin/op", "/usr/local/bin/op") if shutil.which(p)),
    "op",
)

SYSTEMD_RUN = shutil.which("systemd-run")

# Every op call goes through one long-lived helper process instead of starting
# op from qutebrowser, for two reasons:
#
# - A qutebrowser started from the launcher gets every op it runs, even through
#   sh, refused by the 1Password app ("InvalidClientInfo" in the app's journal),
#   while one started from a terminal does not; the cause was not found. On
#   Linux the helper runs as a transient systemd service, which takes
#   qutebrowser out of op's ancestry entirely and is accepted.
# - The app asks for approval per calling process, so a fresh process per call
#   meant a prompt for the login list and another for the login itself. With
#   every op a child of the same helper, one approval covers the helper's life.
#
# The protocol is one JSON line each way: op's arguments in, its exit code,
# stdout and stderr out. Requests are answered in order.
_OP_HELPER = """
import json, subprocess, sys
for line in sys.stdin:
    r = subprocess.run([sys.argv[1], *json.loads(line)], capture_output=True, text=True)
    print(json.dumps({"code": r.returncode, "out": r.stdout, "err": r.stderr}), flush=True)
"""

_op = {"proc": None, "buffer": b"", "pending": []}
_login_choices = {}


def _op_helper():
    proc = _op["proc"]
    if proc is not None and proc.state() != QProcess.ProcessState.NotRunning:
        return proc
    proc = QProcess()
    _op.update(proc=proc, buffer=b"", pending=[])

    def read():
        _op["buffer"] += bytes(proc.readAllStandardOutput())
        while b"\n" in _op["buffer"] and _op["pending"]:
            line, _op["buffer"] = _op["buffer"].split(b"\n", 1)
            reply = json.loads(line)
            on_success = _op["pending"].pop(0)
            if reply["code"] != 0:
                message.error(f"1Password: {reply['err'].strip() or 'op failed'}")
            else:
                on_success(reply["out"])

    def died(*_):
        if _op["pending"]:
            message.error("1Password: the op helper stopped")
        _op["pending"].clear()

    proc.readyReadStandardOutput.connect(read)
    proc.finished.connect(died)
    proc.errorOccurred.connect(died)
    helper = [sys.executable, "-I", "-c", _OP_HELPER, OP]
    if SYSTEMD_RUN:
        proc.start(SYSTEMD_RUN, ["--user", "--pipe", "--quiet", "--collect", "--", *helper])
    else:
        proc.start(helper[0], helper[1:])
    return proc


def _run_op(args, on_success):
    proc = _op_helper()
    _op["pending"].append(on_success)
    proc.write((json.dumps(args) + "\n").encode())


def _host(url):
    host = (urlparse(url if "//" in url else "https://" + url).hostname or "").lower()
    return host[4:] if host.startswith("www.") else host


def _matches(page_host, item):
    for link in item.get("urls") or []:
        item_host = _host(link.get("href", ""))
        if item_host and (page_host == item_host or page_host.endswith("." + item_host)):
            return True
    return False


def _label(item):
    user = item.get("additional_information")
    return f"{item['title']} ({user})" if user else item["title"]


_FILL_JS = """
(function (user, pass) {
    const shown = (el) => {
        const s = getComputedStyle(el);
        return el.offsetWidth > 0 && el.offsetHeight > 0
            && s.visibility !== "hidden" && s.display !== "none";
    };
    const textual = (el) => ["text", "email", "tel", ""].includes(el.type);
    const looksLikeUser = (el) => textual(el) && (el.autocomplete === "username"
        || /user|email|login|account|identifier/i.test(
            [el.name, el.id, el.autocomplete, el.placeholder,
             el.getAttribute("aria-label")].join(" ")));
    // The native setter plus bubbling input/change events is what frameworks
    // that track the value themselves (React, Vue) recognise as typing.
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    const fill = (el, value) => {
        el.focus();
        setter.call(el, value);
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
    };
    // Sites built from web components (Reddit) keep their inputs inside shadow
    // roots, which querySelectorAll on the document does not enter.
    const collect = (root, found = []) => {
        for (const el of root.querySelectorAll("*")) {
            if (el.tagName === "INPUT") found.push(el);
            if (el.shadowRoot) collect(el.shadowRoot, found);
        }
        return found;
    };
    const inputs = collect(document).filter(shown);
    const pw = inputs.find((el) => el.type === "password");
    let userField;
    if (pw) {
        const before = inputs.slice(0, inputs.indexOf(pw)).filter(textual).reverse();
        userField = before.find(looksLikeUser) || before[0];
    } else {
        // Two-step logins (Google, Microsoft) ask for the email on its own page.
        userField = inputs.find(looksLikeUser) || inputs.find(textual);
    }
    if (userField && user) fill(userField, user);
    if (pw && pass) fill(pw, pass);
    return Boolean((userField && user) || (pw && pass));
})(%s, %s)
"""


def _fill(win_id, item_id, page_url):
    def got_item(out):
        item = json.loads(out)
        fields = item.get("fields") or []
        value = lambda purpose: next(
            (f.get("value") for f in fields if f.get("purpose") == purpose), None
        )
        tab = objreg.get("tabbed-browser", scope="window", window=win_id).widget.currentWidget()
        if tab is None or tab.url().toString() != page_url:
            message.error("1Password: the page changed, nothing was filled")
            return

        def done(filled):
            if not filled:
                message.error("1Password: no login fields found on this page")
                return
            totp = next((f.get("totp") for f in fields if f.get("type") == "OTP"), None)
            if totp:
                utils.set_clipboard(totp)
                message.info(f"Filled {item['title']}; one-time code copied")
            else:
                message.info(f"Filled {item['title']}")

        code = _FILL_JS % (json.dumps(value("USERNAME")), json.dumps(value("PASSWORD")))
        tab.run_js_async(code, done)

    _run_op(["item", "get", item_id, "--format", "json", "--reveal"], got_item)


def _login_completion(*args, info):
    model = completionmodel.CompletionModel(column_widths=(50, 50, 0))
    rows = ((label, host) for label, (_id, host) in _login_choices.items())
    model.add_category(listcategory.ListCategory("1Password", rows))
    return model


objects.commands.pop("1password-fill", None)


@cmdutils.register(name="1password-fill", maxsplit=0)
@cmdutils.argument("win_id", value=cmdutils.Value.win_id)
@cmdutils.argument("login", completion=_login_completion)
def onepassword_fill(win_id: int, login: str = None) -> None:
    """Fill the page's login from 1Password, or pick one from a list."""
    tab = objreg.get("tabbed-browser", scope="window", window=win_id).widget.currentWidget()
    page_url = tab.url().toString()
    if login:
        chosen = _login_choices.get(login) or next(
            (v for k, v in _login_choices.items() if login.lower() in k.lower()), None
        )
        if chosen is None:
            raise cmdutils.CommandError(f"1Password: no login named {login}")
        _fill(win_id, chosen[0], page_url)
        return

    def got_list(out):
        items = json.loads(out)
        page_host = _host(page_url)
        matching = [i for i in items if _matches(page_host, i)]
        if len(matching) == 1:
            _fill(win_id, matching[0]["id"], page_url)
            return
        # None matched: offer every login, for one saved without this site's URL.
        _login_choices.clear()
        for item in sorted(matching or items, key=lambda i: i["title"].lower()):
            urls = item.get("urls") or [{}]
            _login_choices[_label(item)] = (item["id"], _host(urls[0].get("href", "")))
        runners.CommandRunner(win_id).run_safely("cmd-set-text -s :1password-fill")

    _run_op(["item", "list", "--categories", "Login", "--format", "json"], got_list)


# <Ctrl> is the Command key in qutebrowser on macOS, so this is <C-\> on Linux
# and Cmd-\ on macOS: 1Password's own fill shortcut on each.
for mode in ("normal", "insert"):
    config.bind("<Ctrl-\\>", "1password-fill", mode=mode)
