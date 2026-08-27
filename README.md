# Arch Linux Fresh Install – Manual & System Notes

This repository provides a reproducible setup for a fresh Arch Linux installation
using:

- pacman + yay for packages
- GNU Stow for dotfiles (user and system)
- A single `install.sh` bootstrap script

Most of the system is fully automated.
This document describes what is intentionally manual and what requires
special attention over time.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/e086451d-e5fe-48d8-bd4f-c63ac52cff3c" />

<img width="1920" height="1079" alt="image" src="https://github.com/user-attachments/assets/9160ed21-6f24-4511-8e8b-94888a4214c0" />

---

### Archinstall

If Arch is not installed yet you can follow the [Arch Linux Installation Guide](https://github.com/danilolucasmd/dotfiles/blob/arch/archinstall.md).

Then:

```bash
sudo pacman -Syu --needed git
git clone -b arch https://github.com/danilolucasmd/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Two things that are load-bearing:

- **`-b arch`.** The repo's default branch is `omarchy`; a plain `git clone`
  checks that out instead and none of this applies.
- **`~/dotfiles`.** `install.sh` refuses to run anywhere else, and
  `hyprland.conf` and the SDDM theme refer to the path directly.

`install.sh` is safe to re-run. Steps that can fail on their own — an AUR
package that stopped building, a package that has not landed in the repos yet, a
clone that timed out — stop and ask whether to skip and carry on. Answering yes
(the default) continues the install and adds the step to a list the script
prints at the end; answering `n` aborts there, which is what you want when the
thing that failed is a graphics driver rather than a nicety. Run with no
terminal attached, it skips without asking.

Package installs are batched into one `pacman` transaction, and a batch is
all-or-nothing — so a failed batch is retried one package at a time, and the
question you get is about the single package that is actually broken rather
than the whole list.

---

## 1. Nautilus Bookmarks & Preferences

Fully automated by `install.sh` — nothing to do by hand. This used to be a
manual step: add Code, Downloads and Pictures to the sidebar yourself on every
new machine, and set the view back to a list every time. Both halves are in the
`nautilus` stow package now.

The sidebar bookmarks are a plain file, `~/.config/gtk-3.0/bookmarks` — still
the GTK 3 path, which is where GTK 4 and current Nautilus read them from — so
they are a normal stow symlink, and the link survives Nautilus rewriting the
file. Bookmarking a folder in the sidebar therefore shows up as a diff in this
repo with nothing to copy back by hand, and the same list feeds the sidebar of
every app's Open/Save dialog.

The preferences cannot work that way. Nautilus keeps them in dconf, a single
binary database shared by the whole desktop, so there is no file to symlink.
`nautilus/dconf.ini` holds them as a keyfile instead and `install.sh` applies it
with `dconf load /`, which merges — it writes the keys in the file and leaves
the rest of the database alone, so it is safe to re-run and re-running it is how
you undo a preference changed by accident. What it sets: folders open as a list
rather than a grid of icons, and the GTK file dialogs show hidden files and sort
by date modified, newest first.

The keyfile is curated rather than dumped — only keys that actually differ from
their GSettings schema defaults, so it reads as a list of decisions. Window
geometry and a stale column-order list left over from an older Nautilus are
deliberately not in it.

Full write-up, including how to check whether a setting you just changed is
worth adding: `nautilus/README.md`.

---

## 2. Brave Browser Language Settings

In Brave settings:

1. Add Portuguese (Brazil) to Languages
2. Enable spell check for:
   - English
   - Portuguese (Brazil)

Vimium's exported settings live in `vimium/`. They are not stowed — the
extension keeps its options in browser storage — so import them by hand from
the extension's options page after signing in.

---

## 3. 1Password

After installation:

- Open 1Password
- Sign in
- Enable SSH agent

`install.sh` imports 1Password's code-signing key before the AUR run, because
its PKGBUILD pins `validpgpkeys` and `makepkg --noconfirm` cannot answer the
import prompt on its own.

Note the ordering: the SSH agent is not available until you have signed in, so
everything `install.sh` clones is cloned over HTTPS.

---

## 4. Proton VPN

After installation:

- Open the Proton VPN app and sign in
- `install.sh` enables NetworkManager and masks `systemd-networkd`;
  the app cannot connect if `systemd-networkd` is running instead

---

## 5. Status Bar

The bar is [quickshell](https://quickshell.org) (`quickshell/.config/quickshell`),
launched by `exec-once = qs` in `hyprland.conf`.

It replaced waybar, which has since been deleted from the repo along with its
config and its stow entry. Every module that was a polling shell script under
waybar is now native — workspaces, keyboard layout, media, volume, bluetooth,
network, battery, tray and the notification badge read Hyprland / PipeWire /
BlueZ / NetworkManager / UPower / MPRIS directly — so the polling loops, the
Hyprland event daemon and every `pkill -RTMIN+N waybar` signal are gone with
it.

`playerctl` and `upower` are installed explicitly for this reason: they used to
arrive as waybar dependencies, and the media keys and the battery module need
them regardless. `power-profiles-daemon` is there for the battery panel's
profile switch — quickshell talks to it over D-Bus, and the panel hides that
section entirely when the daemon is not running.

Eight jobs still want a script in `quickshell/.config/quickshell/scripts/`,
because no service exposes them: weather, package updates, screen-recording
state, coding-agent usage, network counters, system counters,
backlight-to-monitor discovery, and matching a notification against the window
list to find the app that sent it. `updates.sh` shells out to
`checkupdates`, which is why `pacman-contrib` is in the package list.

The right cluster is split in two. Media, keyboard layout, volume, network,
bluetooth, battery, display, performance, agent usage, updates and
notifications are always on screen; the recording indicator and the tray fold away behind a chevron that
stays the leftmost thing in the cluster. Clicking it slides them out rightward
from the chevron, with a hairline marking where they end and the always-visible
modules begin; those never shift.

Moving the pointer off the bar folds them away after a second, and coming
back restarts that countdown — a hand on its way to a tray icon dips off the bar
constantly. An open tray menu holds them regardless, since reaching one means
leaving the bar.

The network module is one glyph — an Ethernet port, or the Wi-Fi wedge at the
strength it is seeing, with Ethernet winning when both links are up. Clicking it
(or `super+shift+W`) opens a panel with both links, whatever the active one is
doing right now — ping, packet loss, throughput, since-boot totals, address,
gateway, resolvers — and the Wi-Fi networks in range, saved ones first. Joining
one that is not saved prompts for the password in the panel and reports a
refusal there. Everything but the counters comes from NetworkManager over D-Bus;
`network-stats.sh` reads `/proc/net/dev`, `ip route` and a three-packet ping,
and only runs while the panel is open.

`s` runs a speed test, which is the one thing on that panel that has to be
asked for: the counters describe traffic that is already happening, so an idle
link reads as zero whether it is a gigabit or a dead socket, and finding out
otherwise means saturating it. `speedtest.sh` measures latency and jitter, then
download, then upload, against Cloudflare's `speed.cloudflare.com` — the same
endpoint the browser tests use, reached over whatever path everything else
takes, and needing no package beyond the `curl` and `jq` already here. Each
phase runs several connections at once and sums their rates, because one TCP
stream reports its own ceiling rather than the link's on anything much past
100 Mbit. The phases are six seconds each, so a run costs twelve seconds of
saturated link — `s` again cancels it, and closing the panel does too. The
script prints a line of JSON per phase rather than one at the end, which is
what fills the download figure in while the upload is still being measured.
The panel also names the Cloudflare edge that answered, since a test served
from another continent explains a figure that would otherwise look like a
fault, and it reports a refusal as one: the endpoint rate limits a run that
comes too soon after the last, and a rejection body arrives fast enough to
otherwise read as a very slow link.

The bluetooth module is one glyph too, in three shapes: the adapter off, the
adapter on with nothing connected, and something connected. It stays the same
colour in all three — the shape already says which, and a glyph that also
changed weight made the module flicker every time the earbuds went back in
their case. Clicking it (or `super+B`) opens a panel with the adapter's
switch, what BlueZ holds pairing keys for, and what is in range; right-clicking
flips the adapter without opening anything. Rows carry the device's own icon —
BlueZ derives one from the device class, so a headset does not look like a
mouse — with its state and, where the device reports one, its battery. Enter on
a row is the one obvious thing: drop it if it is up, bring it up if BlueZ has
its keys, pair it if it does not. `f` forgets, `b` flips the adapter, `s` stops
and starts the sweep.

Discovery runs only while the panel is open, and `s` stops it inside that:
sweeping takes the radio off the air to hop channels, which an A2DP stream
sharing that radio can be heard doing. Pairing goes through BlueZ directly and
works for devices that need no confirmation, which is most audio and most mice.
Quickshell registers no `org.bluez.Agent1`, so a device that wants a passkey
confirmed has nobody to confirm it; the panel says so and points at
`bluetoothctl pair` rather than leaving the row looking unchanged.

One thing the module does not take from Quickshell's BlueZ client, because it
cannot be trusted after a resume, is whether the adapter is powered. The
adapter here is a USB dongle: waking from suspend re-enumerates it, bluetoothd
drops `/org/bluez/hci0` and publishes it again, and the `Powered: true` that
follows a few milliseconds later arrives before Quickshell has finished
subscribing to the new object — so it is delivered to nobody, and the bar and
the panel go on reporting a Bluetooth that is off while music plays through it.
`bluetooth-powered.sh` asks BlueZ directly, and the state writes the answer back
into the adapter when the two disagree. It runs when the adapter is replaced —
a burst of checks, since the dongle needs a few seconds to finish coming up —
and once more each time the panel is opened.

Until this panel existed, clicking the module opened buds-tui in a terminal —
reasonable while the only Bluetooth device here was one pair of earbuds, which
connect themselves the moment they leave the case. It stopped being reasonable
the moment anything else needed connecting. `buds` is still installed and still
the only thing that knows per-bud battery and ANC mode; it is a terminal
command again rather than something the bar launches.

The performance module is also one glyph, and it carries no number at all: it
is white while nothing is wrong, amber when a subsystem is saturated or warm,
red when something is hot or a filesystem is nearly full. Load can raise it to
amber but never to red, because a pegged processor is a compile rather than a
fault. Clicking it (or `super+shift+P`) opens a panel with a meter each for
processor, graphics, memory and the root filesystem's disk, and under each the
readings a meter cannot carry — clock, temperature, load average, power draw,
VRAM, PCIe link, cache and swap, and the drive's read and write rates. The CPU
meter has a strip of one bar per core beneath it, which is the only thing on the
panel that catches a single-threaded job pinning one core of six: that reads as
17% on the aggregate and as one full column on the strip.

There is deliberately no process list — what is running is a question btop
already answers, and this panel is for the one a glance can answer. It is not
btop's replacement so much as the reason to open btop less often.

`system-stats.sh` is what gathers it: `/proc/stat`, `/proc/meminfo`,
`/proc/diskstats`, `/proc/loadavg`, the hwmon sensors and one `nvidia-smi`, in
about 70ms. No `lm_sensors` dependency — the temperatures are read straight out
of `/sys/class/hwmon`, found by the name each driver registers rather than by a
`hwmonN` path, since that numbering is not stable across boots. The counters in
`/proc` are cumulative since boot, so every percentage and rate on the panel is
a difference between two readings, worked out in the shell the way the network
panel does it rather than by sleeping inside the script. It samples every five
seconds with the panel closed, which is what the bar glyph needs, and every
second while it is open.

`d` runs a disk speed test, which is the one thing on that panel that has to be
asked for, for the same reason the network panel's is: the read and write rates
above it are what the drive happens to be carrying, which on an idle desktop is
nothing whatever the drive is worth, and `busy` is a share of an interval rather
than a speed. `disktest.sh` writes 2 GiB and reads it back, four `dd` streams at
a time — one stream is a single thread at queue depth 1, and an NVMe answers a
single outstanding request with a fraction of the parallelism it has, so one
`dd` reports about 1000 MB/s here where four report 1500 writing and 1800
reading.
The phases run in four passes rather than one long transfer, which is what moves
the progress bar and revises the running figure on the way through.

Two things have to be got right or the number is fiction. The data written is
incompressible, generated once from `/dev/urandom` into `/dev/shm` and then
written from memory — zeros would measure the `compress=zstd` mount option, and
generating the random data inside the write phase would measure `/dev/urandom`,
which manages about 430 MB/s. And the test directory gets `chattr +C`, because
btrfs will not serve `O_DIRECT` on a compressed inode: it falls back to the page
cache, and a read phase served from the page cache reports how fast memory is.
The files are removed and recreated each run so the attribute is inherited, and
removed again at the end.

The test writes into the cache directory, which is the one place the session
owns that is on a real filesystem — not `/tmp`, which is tmpfs here and would be
measuring RAM. So the panel names the drive and mount it actually landed on
beside the figures: on a machine where the cache and the root filesystem are on
different drives, that row is the number's explanation rather than a fault.
There is no random-IOPS figure, deliberately: measuring one honestly needs a
queue depth `dd` cannot produce — forking a process per 4 KiB read times the
fork, not the drive — and `fio` is a package nothing else here needs.

One gap worth knowing about: **this board's fan speeds are not readable.** The
Z370M AORUS has an ITE IT8686E behind an ACPI resource conflict, and the
mainline kernel has no driver for it, so only the GPU fan — which comes from
`nvidia-smi` — has a number. CPU and case fans would need the out-of-tree
`it87-dkms` and `acpi_enforce_resources=lax`, neither of which is installed.

The display module is the one thing in the bar that is about the screen it is
drawn on rather than about the machine, so each screen's bar gets its own: the
wheel over the glyph dims that monitor, and clicking it opens the display panel
already pointed at it. `super+D` opens the same panel on the focused monitor,
having no screen of its own to name.

The panel carries brightness, refresh rate, scale and rotation, with tabs across
the top when more than one monitor is plugged in. Brightness is `brightnessctl`
on the same `-e4 -n2` curve the `XF86MonBrightness` keys use, so the slider and
the keys are the same percentage rather than two scales for one backlight; the
level itself is read straight out of sysfs, which delivers a change
notification, so the keys move the slider with nothing polling for it.
`backlights.sh` is what pairs a backlight with a screen — `brightnessctl -l`
names the devices but not which monitor they light, and sysfs hangs each one off
its connector's own node. A monitor with no backlight, which is every external
one without DDC/CI, gets no slider and says so.

The other three come from `hyprctl monitors -j`, which carries the transform,
the refresh rate and the mode list that Quickshell's own `Hyprland.monitors`
leaves empty. Rates are collapsed to the nearest whole hertz — 119.88, 119.98
and 120.00 are one button — and a scale that would not divide the mode into
whole logical pixels is greyed out rather than offered and refused. All three go
out as a `hyprctl keyword monitor` rule and are therefore runtime only: a
`hyprctl reload` or the next login puts `hyprland.conf`'s `monitor =` lines back
in charge, which the panel's footer says outright. Those lines say `highrr`, so
a monitor comes up at the fastest mode it offers rather than the one it
advertises — the VG279QR advertises 60Hz and does 144. That one is the exception
and is pinned to 120 by name: at 144 it does not come back from suspend.

The agent module is the percentage of the current rate-limit window a coding
agent has burned, beside that agent's own glyph. Clicking it (or `super+A`)
opens a panel in three sections, in the order the questions get asked. **Limits**
is one meter per window the agent reports — a session window and a weekly one
for Claude Code, plus a per-model weekly window on the plans that have them —
each marked with how much of the window has *elapsed*, so the gap between the
fill and the mark is whether you are spending faster than it refills, and
annotated with where that rate lands at reset. **Tokens by day** is the last
seven days as a bar each, weekday-labelled and today emphasised. **Tokens by
model** is the same seven days split the other way, which is where a habit shows
that the daily totals hide: an expensive model left selected for work that did
not need it.

The two token sections exist because a percentage cannot be compared against
yesterday — Anthropic reports a share of an allowance it does not publish, so
"71% of the session window" is not a quantity. Token counts are, and Claude Code
already writes every one of them to `~/.claude/projects/**/*.jsonl`. That is
300 MB here, and a full pass over the last eight days of it takes 1.2 seconds,
which is far too slow to sit on a 15-second refresh — so the parse is
incremental, keyed on each transcript's inode and size, and a steady-state run
touches only the file the live session is appending to (0.13s). Rows are
deduplicated by message id, which is not a nicety: resuming or compacting a
session copies its history into the new transcript, and the 7218 rows across
eight days here are only 3826 distinct messages. Summing the files as they lie
overstates every figure by nearly half. The whole thing runs only while the
panel is open.

Nothing in the panel is written against Claude Code. `scripts/agents/` holds one
script per agent, each answering a cheap `limits` and an expensive `tokens`
verb, and `agent-usage.sh` and `agent-tokens.sh` run every executable in there
and merge what comes back — so a second agent is a file dropped in that
directory and nothing else, and the panel grows a tab for it on the next tick.
Left and right walk the tabs, and the bar follows the tab you left open. Claude
Code is simply the only agent installed here. `scripts/agents/README.md` is the
contract.

Every panel is also reachable by name from the walker launcher, for the ones
whose keybind you do not have in your fingers yet. `panels/` is a stow package
of desktop entries — one per panel, each a single
`Exec=qs ipc call <target> <function>`, which is exactly what the matching
`bindd` runs — symlinked into `~/.local/share/applications` and picked up by
walker's `desktopapplications` provider with nothing to restart. Searching
`panel` or `quickshell` lists the lot. `toggle` is the right verb even from a
launcher: walker takes the keyboard when it opens, which clears the
`HyprlandFocusGrab` an open panel is holding, so the panel is always already
closed by the time the entry runs. See `panels/README.md`.

`env = QS_ICON_THEME,breeze-dark` in `hyprland.conf` is what gives the tray its
icons — Qt has no icon theme configured on this system, and breeze-dark is the
one that ships light symbolic icons for a dark bar.

---

## 6. Notifications

Quickshell is the notification daemon. It owns `org.freedesktop.Notifications`
outright: the popups, the bell in the bar and the history panel (`super+N`, or
click the bell) are one thing rather than three.

**mako is gone** — package, config and stow entry. Only one process can own the
bus name, so this was an either/or, and mako had no history of its own. If mako
is still installed from an earlier run, `sudo pacman -Rns mako` removes it;
`install.sh` no longer pulls it in.

The popups sit in the corner with per-urgency border colours (low grey, normal
peach, critical red), critical ones stay up until they are dealt with, timeouts
apps ask for are ignored in favour of ours, and track-change notifications get
two seconds and no history entry.

A popup leads with the app's name in that urgency colour, then the summary, then
the body with its markup rendered and cut at four lines. A row in the history
panel has a line less to work with, so it puts what the notification said first
and the app's name beside the timestamp — in the same urgency colour, which is
the only thing telling a low-urgency row from an ordinary one. The message goes
underneath, flattened to one line, and a notification with nothing but a summary
is a one-line row.

Clicking a notification — or hitting enter on it in the panel — jumps to the app
that sent it, through `focus-sender.sh`. The matching is better than mako's,
because notifications say more than their app name does:

- **Web apps.** Brave stamps `desktop-entry=brave-browser` on everything and its
  own default action raises the *browser*, so a WhatsApp message used to land on
  whatever tab was last open. But Brave puts the origin on the first line of the
  body (`web.whatsapp.com`), and the generated launchers carry a matching class,
  so that is matched first and the message goes to its own window.
- **The app's own action is the fallback, not the first choice.** If the origin
  names a site with no web-app window open, the script bows out and the
  notification's default action runs instead — Brave opens the tab, which is the
  right answer there. That path needs `misc:focus_on_activate = true` in
  `hyprland.conf`.
- **herdr.** It notifies through a bare `notify-send`: no desktop entry, app
  name "notify-send", and the project in the body ("dotfiles · 1 · 1 agent").
  Matching on windows cannot work here, because herdr multiplexes every project
  into one ghostty window — the class is the same whichever project notified,
  and the title names only the workspace currently on screen, so scoring the
  notification's words against it found the terminal for the project you were
  already looking at and nothing else. So the script asks herdr instead:
  `herdr workspace list` says whether that first field names a live workspace,
  `herdr workspace focus` switches to it, and the window is matched on the label
  herdr *was* showing, read before the switch because that is what the title
  still says. Clicking "claude finished / sopezinho" now lands on sopezinho.
- **The label.** Those say **Terminal** on screen rather than `notify-send`,
  which is the name of the tool and not of a sender: herdr has no option to name
  itself, and a notify-send typed at a prompt came from a terminal too, so it is
  the one label true of both. It is only the label — the record keeps the raw
  name, because that is what has to *fail* the class pass for the passes below
  it to run at all.
- **Everything else anonymous.** A `notify-send` typed at a prompt, or a tool
  that shells out to one without naming itself (`gh-dash`, through the beeep
  library). Nothing identifies these and herdr does not claim them, so all that
  is left is the text: the script scores windows by the words their titles share
  with the notification, and gives up rather than guess when none of them do.

Notifications can carry action buttons, the popups use the bar's palette, and
the history is a panel with a keyboard (`j`/`k` to move, `enter` to open, `d` to
dismiss, `D` to clear).

History lives in `~/.local/state/quickshell/notifications.jsonl`, capped at 200
entries, and survives reboots.

Claude Code's own notifications go through `preferredNotifChannel: "ghostty"` in
`claude/.claude/settings.json` — ghostty's native channel, which needs no
forwarding. herdr's toasts go to the system with `[ui.toast] delivery = "system"`
in its config.

---

## 7. Terminal Multiplexer

[herdr](https://herdr.dev) is the multiplexer (`herdr/.config/herdr/config.toml`).

**tmux is gone** — package, config, plugin list and stow entry. Anything that
integrated with it went with it:

- `nvim/.config/nvim/lua/util/herdr-nav.lua` is the old `tmux-nav.lua`
  retargeted at `herdr pane focus`. Ctrl+hjkl still moves between nvim splits
  and hands off to the neighbouring pane at the edge; `herdr pane edges` gives
  the same no-wrap guard `#{pane_at_left}` used to.
- `claudecode.nvim`'s "jump to the Claude pane" binding uses `herdr pane focus`
  the same way.
- The fzf-tab completion menu renders inline. `ftb-tmux-popup` drew it in a
  floating tmux popup and hangs outside tmux rather than falling back.
- Claude Code's tmux hooks — fourteen events routed into `tmux-agent-sidebar`,
  plus two that rang the pane tty directly — are all removed. herdr tracks agent
  panes natively.

herdr's own Claude Code integration is installed by `install.sh` with
`herdr integration install claude`. It writes
`~/.claude/hooks/herdr-agent-state.sh` and owns that file — the header says as
much, and herdr rewrites it on update — so it is deliberately not tracked here.
The `SessionStart` hook entry that calls it *is* tracked, in
`claude/.claude/settings.json`.

`herdr/.config/herdr/` is stowed with `--no-folding` for the same reason
`~/.claude` is: herdr keeps its session layout, logs, sockets and installed
plugins in there, and a folded `~/.config/herdr` symlink would write all of that
into this repo. Only `config.toml` is tracked.

One of those plugins is ours — [herdr-clone-layout](https://github.com/danilolucasmd/herdr-clone-layout),
installed by `install.sh` with `herdr plugin install
danilolucasmd/herdr-clone-layout --yes` (section 13). Every new workspace or
worktree opens with the tab and pane geometry of the one it was created from. It
needs `jq`, which is in the pacman list.

---

## 8. Claude Code

`claude/.claude/` is stowed with `--no-folding`, so `~/.claude` stays a real
directory. Claude Code keeps credentials, history, caches and file state in
there; folding it into a single symlink would send all of that into this repo.

Only two files are tracked: `CLAUDE.md` and `settings.json`. Deliberately not
tracked:

- `autoMode.environment`, a per-repo analysis cache Claude Code rewrites itself.
- `hooks/herdr-agent-state.sh`, which herdr owns (section 7).

`statusLine` runs `quickshell/.config/quickshell/scripts/agent-usage-statusline.sh`.
That is not cosmetic — it is the freshest of the three sources the bar's agent
module reads (section 5). Claude Code hands `.rate_limits` to every status-line
render, so the module gets near-live numbers for free, without touching the
OAuth usage endpoint (which rate-limits hard: ~20 requests in 30s earns a
multi-minute 429). Without the entry the module falls back to polling and goes
stale between sessions.

The other two sources fill the gaps that feed leaves. `~/.claude.json`'s
`cachedUsageUtilization` is Claude Code's own cache of the endpoint, which keeps
the number roughly current through a session with no status line. The endpoint
itself, fetched with the OAuth token in `~/.claude/.credentials.json`, is the
only source that still answers with no session running at all, and the only one
that enumerates the windows rather than naming two of them — which is what lets
a per-model weekly limit appear in the panel without the script being taught the
model names. It is polled slowly, skipped entirely while the status-line feed is
fresh, and sat out for fifteen minutes after a 429. The token goes to `curl`
over stdin rather than argv, so it stays out of `ps`.

`~/.claude/projects` is the "history" above, and it is where the panel's token
figures come from — 300 MB of session transcript here, which is the largest
thing in `~/.claude` by two orders of magnitude and the clearest single reason
this package is stowed unfolded.

Claude Code itself has no Arch package. `install.sh` runs the official installer,
which drops a versioned binary in `~/.local/share/claude` and links it into
`~/.local/bin` — which `.zshrc` puts on `PATH` (rather than relying on
`~/.profile`, which the installer writes and which is not in this repo).

### caveman

[caveman](https://github.com/JuliusBrussee/caveman) is a plugin that makes Claude answer in clipped, telegraphic prose — the same technical content in far fewer output tokens. Two keys in `settings.json` carry it: `extraKnownMarketplaces.caveman` names the GitHub repo the plugin comes from, and `enabledPlugins."caveman@caveman"` turns it on.

Those keys are declarations, not an installation. The plugin CLI still has to clone the marketplace into `~/.claude/plugins` (untracked runtime state, like everything else in there) and register the plugin, so `install.sh` runs `claude plugin marketplace add JuliusBrussee/caveman` and `claude plugin install caveman@caveman --scope user` right after stowing `claude`. Both are guarded on their own output and skip when the plugin is already there, so re-running the script costs nothing.

The ordering matters. Run those commands before the stow and the CLI writes a real `~/.claude/settings.json`, which `resolve_stow_conflicts` then moves aside as `.pre-stow`; run them after and they follow the symlink and write straight into this repo's copy — rewriting the two keys identically, leaving the tree clean.

The plugin activates itself on every session start — a `SessionStart` hook of its own, needing nothing in `settings.json.hooks` — and there is no per-session command to type. What that hook injects is the intensity level, which it resolves from `$CAVEMAN_DEFAULT_MODE`, then a `.caveman.json` checked into the repo being worked on, then `~/.config/caveman/config.json`, then its own built-in default. The `caveman` stow package is that user config, and holds one key: `defaultMode: "full"`. It matches the built-in default today, so the visible behaviour is unchanged — the point is that the level every session opens in is pinned here rather than inherited from whatever upstream currently ships. `/caveman lite|ultra|off` still switches it for the session in hand, and a project that wants its own default checks in a `.caveman.json`, which wins over this file.

The package is stowed `--no-folding`: the caveman CLI keeps its own state (login token, cavemem) in `~/.config/caveman`, and only `config.json` belongs in this repo.

To drop the plugin: `claude plugin uninstall caveman@caveman`, `claude plugin marketplace remove caveman`, then delete the `install.sh` block. The upstream repo also ships a much larger installer (`install.sh --all`) covering an MCP server, a proxy and extensions for other agents — none of that is used here, only the Claude Code plugin.

---

## 9. Nautilus Video Previews (NVIDIA)

Fully automated by `install.sh` — nothing to do by hand. Noted here because the
failure is baffling if the override ever goes missing.

Pressing <kbd>Space</kbd> on a video in Nautilus opens **sushi**, whose GL video
sink (`gtkglsink`) is broken on NVIDIA: it either errors with "Failed to
initialize OpenGL with Gtk" or renders a solid dark green rectangle. The `dbus`
stow package ships a D-Bus activation override setting
`SUSHI_USE_GST_GTKSINK=1`, which forces the working software sink.

Full write-up, including how to verify it: `dbus/README.md`.

---

## 10. Btrfs Snapshots

The disk layout in `archinstall.md` is btrfs with GRUB, so `install.sh` installs
snapper, snap-pac and grub-btrfs and enables the timeline/cleanup timers. A
snapshot is taken around every pacman transaction and appears in the GRUB menu,
so a bad upgrade is recoverable without reaching for the ISO.

The whole section is skipped if `/` is not btrfs, so the script still works on
an ext4 install — you just get no snapshots.

`snapper create-config` runs only when the config does not already exist, which
is what makes re-running the script safe.

---

## 11. GTK Cedilla Fix

`post-install.sh` makes `'` + `c` produce ç rather than ć on the us-intl layout.
`install.sh` calls it, so a fresh install needs nothing.

It patches files owned by **gtk2, gtk3 and libx11**, so a package upgrade
reverts it. Re-run `./post-install.sh` when the cedilla stops working.

---

## 12. Manual Development Toolchains

`.zshrc` puts these on `PATH`, but nothing installs them — they are large,
versioned by project, and better managed by their own tooling:

- `~/.local/share/jdks/current` (`JAVA_HOME`)
- `~/Android/Sdk` (`ANDROID_HOME`) — platform-tools, emulator, cmdline-tools
- `~/.opencode/bin`

A missing directory on `PATH` is harmless, so a fresh install works without
them.

---

## 13. Our Own Projects

Three of the tools this setup depends on are ours. `install.sh` installs all
three **from GitHub over HTTPS**, not from `~/Code` — a fresh machine has no
checkouts, and the 1Password SSH agent is not signed in that early in the run.
So none of them starts out as a development install:

| Project | Installed as | Point it at a clone |
| --- | --- | --- |
| [buds-tui](https://github.com/danilolucasmd/buds-tui) | `uv tool install --python /usr/bin/python3 git+https://…` | `uv tool install --force --python /usr/bin/python3 --editable ~/Code/buds-tui` |
| [pkg](https://github.com/danilolucasmd/pkg) | its own installer, `curl … \| sh` | `cargo install --path ~/Code/pkg --root ~/.local` |
| [herdr-clone-layout](https://github.com/danilolucasmd/herdr-clone-layout) | `herdr plugin install danilolucasmd/herdr-clone-layout --yes` | `herdr plugin link ~/Code/herdr-clone-layout` |

Details that are easy to get wrong:

- **buds-tui's `--python` is not optional.** Without it `uv` builds the tool
  against a standalone interpreter that has no Bluetooth sockets, and `buds`
  fails the moment it reaches for the earbuds. It is a terminal command — the
  quickshell Bluetooth module used to launch it and now opens its own panel
  instead.
- **`pkg` runs with `PKG_NO_MODIFY_PATH=1`.** Its installer offers to append a
  `PATH` line to your shell startup file, and `.zshrc` is a stow symlink into
  this repo — left alone it would write into the dotfiles. `~/.local/bin` is
  already exported there.
- **`pkg` installs from a prebuilt binary.** Its installer downloads the release
  asset for this platform and builds from source only if that fails. Releases
  exist from **v0.1.2** onward — `v0.1.0` and `v0.1.1` were tagged but their
  release workflow was cancelled and published nothing, so the download 404'd
  and the cargo fallback was the only path there was.
- **The rust toolchain is for development, not for installing `pkg`.**
  `install.sh` installs `rustup` (the **Rust toolchain** step) so that
  `cargo install --path ~/Code/pkg --root ~/.local` works on a fresh machine.
  It is not there to prop up the installer's cargo fallback: that fallback
  clones from the same GitHub the download just failed to reach, so it only
  helps a target with no published asset.
- **`herdr plugin link` needs a running herdr server**; `herdr plugin install`
  does not.

---

## 14. Keyboard Remapping (kanata)

`kanata` remaps the **laptop's built-in keyboard only**, porting the ergonomics
of the Lily58 (`~/Code/lily58`) onto it. External keyboards -- the Lily58 over
USB or BT, anything else plugged in -- are passed through untouched; the config
grabs `AT Translated Set 2 keyboard` by name and nothing else.

What it does, mirroring the ZMK keymap:

| | |
|---|---|
| CapsLock | Ctrl on hold, Esc on tap (`&mt LCTRL ESCAPE`) |
| Shift, double-tapped | Caps Word (`TD_LSHFT_CAPS`) |
| Fn held | the Lily58's `lower_layer`: `hjkl` arrows, `1`-`5` -> `F1`-`F5`, `7 8 9 0 -` -> `[ ] { } =`, `\` -> `+`, `u`/`d` -> PgUp/PgDn, `n m , .` -> play-pause / mute / vol down / vol up |

### The BIOS step (manual, required)

The ThinkPad's real `Fn` key is consumed by the embedded controller and never
reaches the OS -- it isn't in the keyboard's reported keycode range, so no
remapper on any platform can see it held.

**Swap Fn and Ctrl in the BIOS** (Enter/F1 at boot -> Config -> Keyboard/Mouse
-> "Fn and Ctrl Key swap" -> Enabled). The key *labelled* Fn then emits
`KEY_LEFTCTRL`, which kanata picks up as the layer key -- so holding the key
marked Fn gets you the Fn layer. CapsLock covers Ctrl, so nothing is lost.

To skip the BIOS trip instead, change `lctl` to `ralt` in the two `deflayer`
blocks in `kanata/.config/kanata/kanata.kbd` and hold Right Alt. That costs you
AltGr, which the `us,intl` secondary layout uses for accented characters.

### Notes

- Group membership (`input`) only takes effect at the next login.
- `systemctl --user status kanata` to check it; `systemctl --user restart
  kanata` after editing the keymap.
- Tapping terms are the 200ms from the ZMK keymap. They live in the
  `defalias` block.

---

## 15. General Notes

- `install.sh` is safe to re-run
- System-level dotfiles (`sddm`) are stowed with `sudo stow -t /`
- `dbus`, `claude` and `herdr` are stowed with `--no-folding`, everything else
  plainly
- When an app has already written a config that stow wants to own, `install.sh`
  moves the original aside as `<name>.pre-stow` rather than failing
- All non-deterministic or GUI-based steps are documented here on purpose

### Leftovers worth removing

Superseded packages that may still be installed from earlier runs. Nothing
depends on them and `install.sh` no longer pulls them in:

```bash
sudo pacman -Rns mako dunst rofi rofi-calc anyrun cliphist pcmanfm tmux waybar
```

If something breaks after a system update, this file is the single source of
truth for restoring expected behavior.
