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

# j/k and <C-d>/<C-u> scroll whatever is scrollable under the middle of the
# view, the way Vimium does. qutebrowser's own commands only reach the page:
# `scroll` presses arrow keys, which Google Docs turns into caret moves, and
# `scroll-page` scrolls the window through qutebrowser's injected helper, which
# does nothing where an inner pane scrolls (Docs, Slack) and breaks on sites
# that wipe the helper (GitHub, AliExpress). Instant, like Vimium's jumps;
# 60px is Vimium's step.
def _scroll_js(step):
    return (
        "jseval -q (() => {"
        " let el = document.elementFromPoint(innerWidth / 2, innerHeight / 2);"
        " const root = (e) => !e || e === document.body || e === document.documentElement;"
        " while (!root(el)) {"
        "  const o = getComputedStyle(el).overflowY;"
        "  if (/(auto|scroll|overlay)/.test(o) && el.scrollHeight > el.clientHeight) break;"
        "  el = el.parentElement;"
        " }"
        " if (root(el)) el = document.scrollingElement;"
        " const view = el === document.scrollingElement ? innerHeight : el.clientHeight;"
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
config.bind("bt", "cmd-set-text -s :open -t")

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
config.bind("bT", "reopen")
