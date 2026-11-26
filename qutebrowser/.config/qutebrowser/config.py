# Bindings ported from vimium/vimium-c-options.json, the Vimium C keymap used on
# Brave, so the same fingers work in both browsers. qutebrowser's own defaults
# already cover most of Vimium's (j/k/h/l, gg/G, f/F, yy, /, n/N, gi, gt/gT,
# g0/g$, gu/gU, and <C-u>/<C-d> as half-page scrolls, which is what Vimium's
# scrollPageUp/Down are), so only the keys the Vimium config changes are here.
#
# Vimium's unmaps (J K u d r p P o O B T ge) are deliberately not ported yet:
# qutebrowser's defaults on those keys stay until it is clear which are wanted.

# autoconfig.yml is where qutebrowser saves what is changed from inside the
# browser (`:set`, `:config-cycle`), and it is read first, so anything this
# file sets globally still wins over it. What it is loaded for is the per-site
# dark mode switch below: a value scoped to one site is not something this
# file sets, so it survives. It is machine-local state, like history, and stays
# out of the repo; a setting worth keeping everywhere belongs in this file.
config.load_autoconfig(True)

# Vimium C's switchFocus jumps into the page's input. Without a focused-input
# memory to toggle back to, the closest qutebrowser has is gi's first-input hint.
config.bind("gI", "hint inputs --first")

# j/k and <C-d>/<C-u> scroll the page, and fall back to an inner pane only when
# the page itself cannot move that way. qutebrowser's own commands only reach
# the page: `scroll` presses arrow keys, which Google Docs turns into caret
# moves, and `scroll-page` scrolls the window through qutebrowser's injected
# helper, which does nothing where an inner pane scrolls (Docs, Slack) and
# breaks on sites that wipe the helper (GitHub, AliExpress). Instant, like
# Vimium's jumps; 60px is Vimium's step.
#
# Page first, because picking the pane under the middle of the view (the first
# version of this) got captured: a code block or comment box that scrolled
# past the middle took over the keys, and once it hit its end the page never
# moved again. Now the page scrolls whenever it can, which keeps the keys on
# it, and the pane under the middle is used only when the page cannot move:
# app layouts where the page is a fixed frame (Docs, Slack, Gmail), or the
# page already at its end. Even then the walk climbs out to the first
# ancestor that can still move in that direction, so a pane at its end hands
# over instead of swallowing the key.
def _scroll_js(step):
    down = not step.startswith("-")
    return (
        "jseval -q (() => {"
        " const doc = document.scrollingElement;"
        " const span = (e) => e === doc ? innerHeight : e.clientHeight;"
        f" const moves = (e) => {'e.scrollTop + span(e) < e.scrollHeight - 1' if down else 'e.scrollTop > 0'};"
        " const root = (e) => !e || e === document.body || e === document.documentElement;"
        " let el = doc;"
        " if (!moves(doc)) {"
        "  el = document.elementFromPoint(innerWidth / 2, innerHeight / 2);"
        "  while (!root(el)) {"
        "   const o = getComputedStyle(el).overflowY;"
        "   if (/(auto|scroll|overlay)/.test(o) && el.scrollHeight > el.clientHeight && moves(el)) break;"
        "   el = el.parentElement;"
        "  }"
        "  if (root(el)) el = doc;"
        " }"
        " const view = span(el);"
        f" el.scrollBy({{ top: {step}, behavior: 'instant' }});"
        " })()"
    )


config.bind("j", _scroll_js("60"))
config.bind("k", _scroll_js("-60"))
config.bind("<Ctrl-d>", _scroll_js("view / 2"))
config.bind("<Ctrl-u>", _scroll_js("-view / 2"))

# Vimium's hint alphabet and look. Fourteen characters give 196 two-letter
# labels, where qutebrowser's nine home-row keys run out at 81 and start
# handing out three-letter ones on any busy page. Every label on a page has the
# same length, as in Vimium, and is shown in capitals.
config.set("hints.chars", "sadfjklewcmpgh")
config.set("hints.uppercase", True)

# Shift on the hint's last letter opens the link in a new tab, as in Vimium,
# where it is the habit: type the label, hold Shift for its final key. Hint
# mode binds each label lowercase, so a shifted letter matched nothing and the
# hint never fired. The parser now drops Shift before matching and remembers
# it, and a hint fired by a shifted key that would have opened in place opens
# in a tab instead (background, per tabs.background). Hints started for
# yanking, downloading or anything else that is not a click are left alone.
from qutebrowser.browser import hints as _hints
from qutebrowser.keyinput import modeparsers
from qutebrowser.qt.core import Qt
from qutebrowser.qt.gui import QKeyEvent

if not hasattr(modeparsers.HintKeyParser, "_original_handle"):
    modeparsers.HintKeyParser._original_handle = modeparsers.HintKeyParser.handle
    _hints.HintManager._original_fire = _hints.HintManager._fire


def _hint_handle(self, e, *, dry_run=False):
    shifted = bool(e.modifiers() & Qt.KeyboardModifier.ShiftModifier) and e.text().isalpha()
    if shifted:
        e = QKeyEvent(e.type(), e.key(), e.modifiers() & ~Qt.KeyboardModifier.ShiftModifier,
                      e.text().lower(), e.isAutoRepeat(), e.count())
    if not dry_run:
        self._hintmanager._shift_fired = shifted
    return modeparsers.HintKeyParser._original_handle(self, e, dry_run=dry_run)


def _hint_fire(self, keystr):
    if getattr(self, "_shift_fired", False) and self._context.target in (
            _hints.Target.normal, _hints.Target.current):
        self._context.target = _hints.Target.tab
    return _hints.HintManager._original_fire(self, keystr)


modeparsers.HintKeyParser.handle = _hint_handle
_hints.HintManager._fire = _hint_fire

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
config.bind("bd", "tab-close")
# qutebrowser closes the tab on a bare `d` by default, one stray keypress from
# losing the page. Closing takes `bd` (or Ctrl+W) instead.
config.unbind("d")
config.bind("bt", "cmd-set-text -s :open -t")
# Vimium's new-tab key. A single-key binding fires at once, so this shadows
# qutebrowser's t-prefixed defaults: th/tl (back/forward in a new tab) and the
# ts/tc/ti/tp per-site toggles for JavaScript, cookies, images and plugins.
config.bind("t", "cmd-set-text -s :open -t")

# <C-r> reloads like r, but in every mode a page can hold the keyboard in, so
# it also works while typing in a field or in passthrough.
for mode in ("normal", "insert", "passthrough", "caret"):
    config.bind("<Ctrl-r>", "reload", mode=mode)

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

# <C-v> pastes, as in every other browser. qutebrowser's default puts
# passthrough mode there, which a paste into a field that never switched to
# insert mode kept triggering; the key now goes to the page, and passthrough
# has no key at all: `:mode-enter passthrough` when a page needs it.
config.bind("<Ctrl-v>", "fake-key <Ctrl-v>")

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
# URL pattern without a restart, so this flips it for the current host only,
# and the choice is saved to autoconfig.yml so the site stays that way.
for mode in ("normal", "insert"):
    config.bind(
        "<Alt-Shift-A>",
        "config-cycle -p -u *://{url:host}/* colors.webpage.darkmode.enabled false true ;; reload",
        mode=mode,
    )
# DevTools ignores preferred_color_scheme, which is a per-page Blink setting
# the inspector does not get, and its own theme choice is lost when it closes.
# This Chromium switch makes the browser itself report a dark system theme,
# which DevTools' default "System preference" theme follows.
config.set("qt.args", ["force-dark-mode"])

# Google sign-in refuses embedded Chromium ("Couldn't sign you in: this browser
# or app may not be secure"). qutebrowser's own quirk already shows
# accounts.google.com a Firefox user agent, but with the Firefox version frozen
# at qutebrowser's release, and an outdated Firefox is refused the same way
# (qutebrowser issue 5182: a current version is what users report working). So
# the quirk is replaced by one that follows Firefox's four-week release train
# from a known release (146, 2025-12-09), stepping on 30 days so it lags a
# release rather than claiming one that is not out yet. Only the request header
# changes: page scripts and the Sec-CH-UA client hints still say Chromium, and
# turning the hints off (disable-features=UserAgentClientHint) was tried and
# does nothing on this Chromium.
import datetime

_firefox = 146 + (datetime.date.today() - datetime.date(2025, 12, 9)).days // 30
config.set("content.site_specific_quirks.skip", ["ua-google"])
config.set(
    "content.headers.user_agent",
    f"Mozilla/5.0 (X11; Linux x86_64; rv:{_firefox}.0) Gecko/20100101 Firefox/{_firefox}.0",
    "https://accounts.google.com/*",
)
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

# Tabs show just the page title: no index (tab numbers are on g0/g$ and Alt+n
# anyway). Pinned tabs, which show only their favicon, keep just the audio
# mark. qutebrowser hardcodes that mark as "[A] " / "[M] " on the tab widget
# class; the Nerd Font speaker glyphs (the font above has them) replace it with
# the icon Chrome shows. A class attribute, so a qutebrowser internal again.
# The leading space is the gap after the favicon: qutebrowser has no setting
# for it and draws the title flush against the icon.
config.set("tabs.title.format", " {audio}{current_title}")
config.set("tabs.title.format_pinned", "{audio}")
from qutebrowser.mainwindow import tabwidget

tabwidget.TabWidget.AUDIBLE_STRING = "\U000f057e "
tabwidget.TabWidget.MUTE_STRING = "\U000f0581 "

# Tabs: inactive ones sink into the bar, the active one is raised with bright
# text. No load indicator line: loading shows in the status bar's progress.
config.set("tabs.padding", {"top": 5, "bottom": 5, "left": 8, "right": 8})
config.set("tabs.indicator.width", 0)

# A 1px divider on the right edge of every tab, in the border colour, so
# neighbouring tabs of the same background read as separate. qutebrowser has
# no setting for it, so the tab bar's paint is wrapped to draw the lines after
# its own drawing: a qutebrowser internal, like the audio mark above.
from qutebrowser.qt.gui import QColor, QPainter

if not hasattr(tabwidget.TabBar, "_original_paint"):
    tabwidget.TabBar._original_paint = tabwidget.TabBar.paintEvent


def _paint_with_dividers(self, event):
    tabwidget.TabBar._original_paint(self, event)
    painter = QPainter(self)
    painter.setPen(QColor(BORDER))
    current = self.currentIndex()
    # The divider after tab i sits between i and i + 1, so the last tab has
    # none: there is nothing after it to divide from. Next to the active tab
    # its raised background already marks the edge, as in Chrome.
    for i in range(self.count() - 1):
        if current in (i, i + 1):
            continue
        rect = self.tabRect(i)
        painter.drawLine(rect.right(), rect.top() + 6, rect.right(), rect.bottom() - 6)
    painter.end()


tabwidget.TabBar.paintEvent = _paint_with_dividers
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
config.bind("bT", "reopen")

# Chrome-style inline completion for the address prompt (t, <C-t>, o). While a
# single word is typed, the rest of the most recent history or bookmark address
# that starts with it is filled in after the cursor, selected, so typing on
# replaces it and Backspace drops it; Enter then goes there. "youtu" shows
# "youtube.com" and opens the site's root rather than whatever page of it was
# visited last; a prefix with a path in it ("github.com/qute") completes to the
# full entry. Several words stay a search, a row picked with Tab is opened as
# picked, and other commands run as typed. Like `reopen`, this reads
# qutebrowser internals: the command line and the history database.
import re
from urllib.parse import urlparse

from qutebrowser.browser import history
from qutebrowser.mainwindow.statusbar import command as statuscommand
from qutebrowser.qt.core import QTimer
from qutebrowser.utils import usertypes

_OPEN_RE = re.compile(r"(:open(?:\s+-\S+)*\s+)(\S+)")


def _candidates(typed):
    """History newest first, then bookmarks, containing what was typed."""
    escaped = re.sub(r"([\\%_])", r"\\\1", typed)
    query = history.web_history.database.query(
        "SELECT url FROM CompletionHistory WHERE url LIKE :pat ESCAPE '\\' "
        "ORDER BY last_atime DESC LIMIT 500"
    )
    for row in query.run(pat=f"%{escaped}%"):
        yield row.url
    yield from objreg.get("bookmark-manager").marks


def _best_match(typed):
    """The (url, shown) completing a typed address prefix, or None.

    History is read straight from its database rather than from the completion
    list on screen, which is filled on a timer and so may still hold the
    results for the previous keystroke.
    """
    # A row picked with Tab puts its full URL, scheme included, on the command
    # line, and no candidate's bare address starts with a scheme: so a picked
    # row is opened as picked without having to ask the completion widget.
    typed = typed.lower()
    for url in _candidates(typed):
        bare = re.sub(r"^[a-z]+://(www\.)?", "", url, flags=re.I)
        if not bare.lower().startswith(typed):
            continue
        if "/" in typed:
            return url, bare
        parts = urlparse(url)
        host = re.sub(r"^www\.", "", parts.netloc, flags=re.I)
        return f"{parts.scheme}://{parts.netloc}/", host
    return None


def _complete_inline(cmd, typed_text):
    # The user has typed on since this was scheduled; that keystroke has its own.
    if cmd.text() != typed_text:
        return
    m = _OPEN_RE.fullmatch(typed_text)
    if not m:
        return
    prefix, typed = m.groups()
    match = _best_match(typed)
    if match is None or len(match[1]) <= len(typed):
        return
    shown = typed + match[1][len(typed):]
    cmd.setText(prefix + shown)
    cmd.setSelection(len(prefix) + len(typed), len(shown) - len(typed))
    cmd._inline_state["at"] = len(prefix) + len(typed)


def _hook_command_line(cmd):
    if hasattr(cmd, "_inline_state"):
        return
    # "at" is where the selected suggestion starts while one is showing.
    state = cmd._inline_state = {"cur": "", "prev": "", "at": None}

    def changed(text):
        state["prev"], state["cur"] = state["cur"], text

    def edited(text):
        # textEdited and textChanged fire in an order Qt does not promise, so
        # the text before this edit is whichever of the two is not this one.
        before = state["cur"] if state["cur"] != text else state["prev"]
        at, state["at"] = state["at"], None
        # Backspace on a suggestion removes just the suggestion; completing
        # again would put it straight back. Any other deletion is left alone
        # too; typing over a suggestion (shorter, but not this) completes anew.
        if at is not None and text == before[:at]:
            return
        if at is None and len(text) < len(before):
            return
        # After the completer's own update, which runs on a zero timer.
        QTimer.singleShot(10, lambda: _complete_inline(cmd, text))

    cmd.textChanged.connect(changed)
    cmd.textEdited.connect(edited)


if not hasattr(statuscommand.Command, "_original_init"):
    statuscommand.Command._original_init = statuscommand.Command.__init__


def _command_init(self, *args, **kwargs):
    statuscommand.Command._original_init(self, *args, **kwargs)
    _hook_command_line(self)
    _patch_notifications()


statuscommand.Command.__init__ = _command_init
# Windows already open when this file is re-sourced.
for _win in list(objreg.window_registry):
    _hook_command_line(objreg.get("status-command", scope="window", window=_win))


objects.commands.pop("command-accept-inline", None)


@cmdutils.register(name="command-accept-inline", modes=[usertypes.KeyMode.command])
@cmdutils.argument("win_id", value=cmdutils.Value.win_id)
def command_accept_inline(win_id: int) -> None:
    """Accept the command line, completing a typed address prefix from history."""
    cmd = objreg.get("status-command", scope="window", window=win_id)
    m = _OPEN_RE.fullmatch(cmd.text())
    match = _best_match(m.group(2)) if m else None
    if match is not None:
        cmd.setText(m.group(1) + match[0])
    cmd.command_accept()


config.bind("<Return>", "command-accept-inline", mode="command")

# Notifications from a web app (webapps/qutebrowser-app.sh exports
# QUTE_WEBAPP_NAME) are signed with the app's name, where qutebrowser hardcodes
# "qutebrowser" as the app name every notification daemon titles them with, and
# carry the app's window class as their desktop entry in place of
# org.qutebrowser.qutebrowser. The launcher also turns off the origin URL that
# would head the body, and the desktop entry is what replaces it for
# quickshell's focus-sender.sh: an exact class match takes a clicked
# notification to the app's own window. The main browser is untouched, since
# its notifications come from any site and the URL is the only thing saying
# which.
#
# The patch cannot simply import the notification module here. At startup
# config.py runs before qutebrowser has loaded it, and qutebrowser deletes every
# module config.py was first to import once the file is done (so a re-source
# starts clean), which leaves the patch on a copy nobody uses. So it is applied
# when the first window's command line is built (by then the module is
# qutebrowser's own) and straight away when the module is already loaded, as on
# a :config-source.
import os
import sys

from qutebrowser.qt.gui import QGuiApplication

_WEBAPP_NAME = os.environ.get("QUTE_WEBAPP_NAME")
_NOTIFICATION_MODULE = "qutebrowser.browser.webengine.notification"


def _patch_notifications():
    from qutebrowser.browser.webengine import notification

    adapter = notification.DBusNotificationAdapter
    if not hasattr(adapter, "_original_notify"):
        adapter._original_notify = adapter._call_notify_wrapper

    def notify_as_webapp(self, *, appname, hints, **kwargs):
        if _WEBAPP_NAME:
            appname = _WEBAPP_NAME
            hints["desktop-entry"] = QGuiApplication.desktopFileName()
        return adapter._original_notify(self, appname=appname, hints=hints, **kwargs)

    adapter._call_notify_wrapper = notify_as_webapp


if _NOTIFICATION_MODULE in sys.modules:
    _patch_notifications()
