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

**It asks for your password once, at the very start, and never again.** sudo's
credential cache expires after five minutes of *not being used*, which on a
twenty-minute install means it lapses in the middle of every long AUR build. So
after that one authentication the script writes a NOPASSWD rule for your user
to `/etc/sudoers.d/99-dotfiles-install`, and removes it again on the way out —
the trap covers `EXIT`, `INT`, `TERM` and `HUP`, and is armed before either rule
is written rather than after, so there is no window where a Ctrl-C leaves one
behind. The file is checked with `visudo -c` before it is installed, because an
invalid file in `/etc/sudoers.d` makes sudo refuse to run at all.

**The one case no trap covers is `SIGKILL`, a power cut, or a reboot mid-run** —
both rules survive that, and the machine then has passwordless sudo until
something removes them. A re-run clears them before writing its own and prints a
warning saying it found them; failing that, `sudo rm -f
/etc/sudoers.d/99-dotfiles-install /etc/polkit-1/rules.d/49-dotfiles-install.rules`
by hand. If an install dies badly, that is the thing to check.

That means that for the length of the install, anything running as you can
become root without a password. It is a real widening, and it is deliberate:
the script already has root, on a machine that has just been installed and has
nothing on it yet. Keeping sudo's timestamp warm with a background `sudo -n`
loop was the previous attempt and is not reliable — one refresh that does not
land ends the loop silently, and the prompts come back with nothing on screen
to explain them.

**sudo is not the only thing that asks.** Several tools here don't run a binary
as root at all — they ask a system daemon to do something over D-Bus, and that
goes through **polkit**, which has its own rules and knows nothing about sudo's
timestamp or the NOPASSWD rule. On a TTY a polkit prompt names itself:

```
==== AUTHENTICATING FOR net.reactivated.Fprint.device.verify ===
Authentication is required to ...
```

That action id after `====` is the only reliable way to tell the two apart. So
the script writes the matching polkit rule,
`/etc/polkit-1/rules.d/49-dotfiles-install.rules`, allowing this user's actions
for the length of the run, and the same trap removes it. It is the safer half
of the pair: a rule that returns nothing falls through to the next file, so it
can only ever add permission, and a broken rules file is logged and skipped
rather than bricking authorization the way a broken sudoers file does. It is
written after the Wayland package batch rather than at the top, because
`/etc/polkit-1/rules.d` is created by the `polkit` package and a hand-made copy
of that directory is one polkitd declines to read.

**`makepkg --noconfirm` is narrower than it reads.** The man page scopes it to
confirmation "when resolving dependencies" — the install that `-i` performs
afterwards is a separate `pacman -U` that makepkg drives itself, and that is
where a `[Y/n]` and a password prompt appeared in the middle of the Limine
builds, inside what looks from the script like one command that already has
`--noconfirm` on it. So the two hand-rolled builds — `yay` and the vendored-
Gradle Limine pair — now build with `makepkg -s` and install with an explicit
`sudo pacman -U --noconfirm --needed`, against the exact paths
`makepkg --packagelist` reports rather than a `*.pkg.tar.zst` glob that would
also match leftovers from an earlier build.

**`mkinitcpio` is not `mkinitcpio` on this machine.** `limine-mkinitcpio-hook`
installs `/usr/local/bin/mkinitcpio`, a wrapper that runs the real one and then
asks `Would you like to run 'limine-mkinitcpio' now? [Y/n]` for any `-P`. It is
a bare `read` with no test for whether anything is there to answer, and
`/usr/local/bin` comes first in sudo's `secure_path`, so the install stopped
dead on it. The script calls `/usr/bin/mkinitcpio -P` by absolute path. Nothing
is lost: the wrapper's `limine-mkinitcpio` would run before
`/etc/limine-entry-tool.conf` is written, building entries from a command line
the script has not composed yet, and the `limine-update` a few lines later does
the same work in the right order.

Nothing else in the script prompts either: `chsh` goes through sudo rather than
asking PAM for the password a second time, and `yay` is called with
`--answerdiff=None --answerclean=None` because `--noconfirm` does not cover
those two questions.

`install.sh` is safe to re-run, and **it never stops to ask you anything.**
Steps that can fail on their own — an AUR package that stopped building, a
package that has not landed in the repos yet, a clone that timed out — are
skipped, recorded, and printed as a list at the end. This used to be a `[Y/n]`
prompt per casualty; the answer was always yes, and the question was always
asked at the moment nobody was watching the screen. Re-running retries every
skipped step, which is usually all a broken AUR build needs.

What replaced the prompt is a guard in front of anything that *depends* on a
step: the AUR loop checks for `yay`, the herdr integration checks for `herdr`,
the Rust toolchain checks that `rustup` landed. A missing package skips its
dependants once, with a reason in the list, rather than failing again once per
dependant. The handful of steps that genuinely cannot be survived — the first
`pacman -Syu`, `stow`, Hyprland missing at the end — are still fatal.

Package installs are batched into one `pacman` transaction, and a batch is
all-or-nothing — so a failed batch is retried one package at a time, and what
lands in the list is the single package that is actually broken rather than the
whole batch.

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

Nine jobs still want a script in `quickshell/.config/quickshell/scripts/`,
because no service exposes them: weather, package updates, screen-recording
state, coding-agent usage, network counters, system counters,
backlight-to-monitor discovery, the battery facts UPower does not carry, and
matching a notification against the window list to find the app that sent it.
`updates.sh` shells out to `checkupdates`, which is why `pacman-contrib` is in
the package list.

The centre group is the weather and the clock, with three more things anchored
to its edges rather than laid out in it: the night light glyph on the left, the
keep-awake mug and then the recording dot on the right. The glyph and the dot
come and go mid-session, and anchoring is what keeps the clock from sliding
sideways when they do; the mug is always there, and is what the dot anchors to.

The right cluster is split in two. Media, keyboard layout, volume, network,
bluetooth, battery, display, performance, agent usage, updates and
notifications are always on screen; only the tray folds away behind a chevron that
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
drops `/org/bluez/hci0` and publishes it again, and the `PropertiesChanged` that
follows a few milliseconds later arrives before Quickshell has finished
subscribing to the new object — so it is delivered to nobody, and the bar and
the panel go on reporting a Bluetooth that is off while music plays through it.
`bluetooth-powered.sh` asks BlueZ directly, and the state writes the answer back
into the adapter when the two disagree. It runs when the adapter is replaced —
a burst of checks, since the dongle needs a few seconds to finish coming up —
and once more each time the panel is opened.

The script reads two properties, not one, and the second is what makes the
repair land. That missed signal carried `Powered` and `PowerState` together, so
both go stale together: Quickshell is left believing the adapter is powered off
*and* still `off-enabling`, a full second after BlueZ has settled it to `on`.
An adapter that looks mid-transition is one the state deliberately will not
write to — the switch is left alone rather than bounced a second time on a
double click — so the first version of this repair asked BlueZ the right
question every two seconds and then declined to act on the answer, forever.
Reading `PowerState` too means the mid-transition test is BlueZ's own answer
rather than the stale copy, and the two properties are believed or discarded as
a pair. A reading is discarded whenever the adapter has moved since it was
asked for, so a burst still in flight cannot undo a switch the user has just
flipped; the repair's own write is the one move that does not count, since it
lands on exactly what the reading said.

Until this panel existed, clicking the module opened buds-tui in a terminal —
reasonable while the only Bluetooth device here was one pair of earbuds, which
connect themselves the moment they leave the case. It stopped being reasonable
the moment anything else needed connecting. `buds` is still installed and still
the only thing that knows per-bud battery and ANC mode; it is a terminal
command again rather than something the bar launches.

The battery module is the charge glyph and the percentage, and clicking it (or
`super+shift+B`) opens a panel that says what the percentage is a percentage
*of*. This machine has two packs that wear at different rates, so each gets its
own meter and, under it, six readings: charge in watt-hours, health, cycle
count, capacity against the design figure, cell voltage, and what that pack in
particular is drawing or taking. The pair explains itself that way — the SMP
pack has done 1738 cycles and holds 17.5 of its 24 Wh, the LGC 89 cycles and
13.2 of 23.9 — which is the difference between "the battery is old" and knowing
which one to replace.

UPower carries about half of that. Percentage, health, change rate and the time
estimates come from it; the cycle count, the watt-hour figures, the voltage and
the charge threshold exist only in `/sys/class/power_supply`, so
`battery-info.sh` reads them and prints a line of JSON per pack. It polls every
three seconds with the panel open and every minute with it closed, since the
cycle count and the threshold move on the order of days. Firmware that reports
charge in µAh rather than energy in µWh is converted against the pack's design
voltage, so the panel has one unit to print.

The panel's slider sets the charge threshold: the percentage the firmware stops
charging at, from 20% to 100%, defaulting to 80%. A lithium pack ages fastest
across the top of its charge, and a laptop that lives on the cable spends all
day there; giving up the last fifth costs an hour of runtime and is the single
thing on this panel that changes how fast the packs wear out. The chosen figure
is written to every pack that has the attribute, and saved to
`$XDG_STATE_HOME/quickshell/charge-limit.json` so a reboot that clears the EC
does not quietly stop applying it. Where the limit is under 100% the meter
above carries a mark at it, which is what explains a machine that reads 80% on
the cable and never moves.

`charge_control_end_threshold` is root-owned, so `install.sh` drops
`/etc/udev/rules.d/99-charge-threshold.rules` to hand `wheel` write access to
it at every plug and unplug. Without the rule the panel still shows the
threshold and can still set it — `charge-limit.sh` falls back to one `pkexec`
for the whole gesture — but every move of the slider is a password prompt, and
the saved figure is not re-applied at login, since a shell that opened a polkit
dialog at every boot would be worse than one that left the setting alone.

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
opens a panel headed by that agent's actual mark — `quickshell/.config/quickshell/assets/claude.svg`
is the one Anthropic ships in `@anthropic-ai/sdk`, copied rather than redrawn,
and an agent with no logo falls back to its bar glyph. Below it, three sections,
in the order the questions get asked. **Limits**
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

The weather module is a glyph and a temperature, and clicking it opens the
conditions in full: what it feels like, humidity, wind with the compass point
spelled out, and a row each for the next three days — weekday, sky, high and
low. Three days rather than the sixteen Open-Meteo will hand over, because the
question a bar module gets asked is whether this week needs a jacket, and a
scrolling list is one nobody reads past the top of.

The header is also where the location is set. By default the reading follows the
machine: `weather-place.sh` turns the IP into coordinates through `ipwho.is` and
those into a neighbourhood and city through OpenStreetMap's Nominatim, cached
for an hour, and a small pin beside the name says that is what happened. Both
services are keyless, as Open-Meteo is, so the whole module needs no account
anywhere. Clicking the name opens an address box over it; anything Nominatim
recognises works, and the resolved point is written to
`~/.local/state/quickshell/weather-location.json` so it survives a relogin. The
pin is then replaced by a clear button that hands the reading back to the
machine.

The location used to be hardcoded to Pinheiros, with a comment explaining that
geolocating by IP reports the Proton VPN exit node rather than São Paulo. That
is still true, and it is now the reason the address box exists rather than the
reason there is no auto-detection: an IP lookup can do nothing about a VPN, and
a laptop that is somewhere else this week can do nothing with a coordinate pair
compiled into a script. The forecast cache holds the finished reading rather
than the raw response, so a stale one keeps the place name it was actually taken
at instead of relabelling old numbers with a new address.

The night light is one of two things in the bar with no panel and no keybind:
it is a blue-light filter, warming the screen to 4000K, and it is turned on by
name from the launcher and off again by clicking the glyph that turning it on
puts beside the weather. Nothing sits idle waiting for it. `hyprsunset` ships a
systemd user unit that would run all session and be told to go neutral while the
filter is off, but the filter *is* the process — the warm ramp lives on the
`wlr-gamma-control` object hyprsunset holds, and the compositor gives every
output its own ramp back the instant that client disconnects. So quickshell runs
it only while the filter is on, and "is the night light on" has one answer
instead of two that can disagree: a hyprsunset that died, or never started,
takes the glyph with it rather than leaving it lit over an untinted screen. The
cost is that reloading the shell turns the filter off, which is a thing that
happens while editing quickshell rather than while using it.

The glyph is a setting sun rather than the moon the desktop convention would
use, because the weather module two places along already draws a moon for a
clear night.

Keep awake is the other one with no panel: the coffee mug between the clock and
the recording dot. It fills as well as changes colour — an outlined dim cup
while the machine is free to lock and suspend, a filled yellow one while it is
not — and the two glyphs are the same drawing at the same ink box, so nothing
beside it moves when the state flips. It is drawn a notch smaller than every
other icon on the bar, at 14px rather than 16: the cup stands on a thin saucer
line, which puts its ink weight above the middle of the box it is centred in,
and at 16 it read as sitting high against the digits next to it. The gap it
leaves to the date is pulled back to match the gap between the temperature and
the date on the other side of the clock. Clicking it toggles, and so does its
launcher entry, which is the way in it was asked for — it has no keybind
either.

What it holds while it is on is a single logind inhibitor lock,
`systemd-inhibit --what=idle` wrapped around a command that never finishes.
hypridle watches logind's `BlockInhibited` property and skips every listener it
has while an idle lock is held, so one lock is the whole policy: no `hyprlock`
at 300s, no `dpms off` at 330s, and no idle suspend at 600s either, since that
suspend is something hypridle asks `lid.sh` for rather than something logind
does on its own. Nothing in `hypridle.conf` knows the toggle exists.

The lock is `--what=idle` and not `idle:sleep` on purpose. Closing the lid with
no external monitor still suspends on battery: that is a laptop going into a
bag, not a machine going idle, and blocking it would leave the thing running
warm in there because of a toggle flipped hours earlier for a download. Keep
awake stops the machine deciding to sleep on its own; asking it to sleep still
works. The state lives in the process the same way the night light's does —
`systemd-inhibit` dying takes the mug's colour with it rather than leaving it
lit over a machine that is free to lock again — and reloading the shell drops
the lock for the same reason it turns the filter off.

The emoji picker is a panel with no bar module at all: `super+E` is the only
thing that opens it, and it has nothing to say while it is closed. It is laid
out the way every emoji keyboard is — "Frequently Used" first, then the eight
standard categories under their headings, in CLDR order. Typing filters on the
CLDR search keywords as well as the names, so
`lol` finds 😂 and `hi` finds 👋, neither of which says so in its name; the
arrows walk the grid and Return picks. Choosing one copies it, closes the panel
and pastes it into whatever had focus, which is section 15 below.

`super+E` used to open walker on elephant's `symbols` provider, and ordering is
why it stopped. That provider sorts by name, so an empty query opened on "1st
place medal", "abacus", "accordion" — the emoji nobody wants next to the ones
everybody does, with no shape to the list at all. elephant had no ordering knob
to turn, and walker's list was flat and could not have carried the headings even
if it had. The picker outlived both of them; what did not survive is the rest of
that provider, the arrows and the maths and the currency signs, which went when
walker did (section 15). They were never emoji and never belonged in this grid,
and nothing has asked for them back.

The dataset is generated rather than written: `scripts/gen-emoji-data.py` builds
`quickshell/.config/quickshell/data/emoji.json` from Unicode's `emoji-test.txt`
(the emoji themselves, already in CLDR order) and CLDR's `annotations/en.xml`
(the search keywords), and drops anything the emoji font fontconfig resolves has
no glyph for, so nothing in the grid can render as a blank box. Skin-tone
variants are left out for the same reason macOS hides them behind a long press:
they would triple the list and bury the base glyph. The JSON is checked in, so a
fresh machine needs no network for it; the script is checked in so it can be
rebuilt when Unicode ships a release or the font is swapped. The 1500-odd
entries are parsed on the first open of a session rather than at login, and the
"Frequently Used" tally lives in `~/.local/state/quickshell/emoji-usage.json`.

The wallpaper picker is the one panel here that is not a card. It covers the
screen, because a wallpaper cannot be judged in a 360px box: the selection is
drawn full size, exactly as it will look, with a strip of the whole collection
floating over the bottom of it. The arrows walk the strip, and so do `h` and `l`
— there is no search field here, so a bare letter is free to mean that — and it
scrolls past a fixed point in the middle rather than marching a highlight to the
edge; Return sets what is under it and Escape leaves with nothing changed, since
browsing only ever changes the preview. Each step crossfades, which is two image
layers rather than one: the next wallpaper is decoded into whichever layer is not
being shown and only comes forward once it is ready, so the one it replaces stays
on screen underneath for the whole fade. A single layer faded in on `Ready` has
nothing to draw for the length of a 2560px JPEG decode, and what shows through
the gap is the wallpaper you already have — the picker flashed it between every
pair of candidates until this was two layers. It opens on the wallpaper that is
already up, so the first frame is indistinguishable from the desktop it just
covered, and the name above the strip says `· current` against it — which is the
only way to tell, from a preview that fills the screen, whether Return would
change anything. The bar
stays up while picking: the wallpaper runs under the bar in real life too, so
covering it would preview a screen that never exists. Like the night light and
keep awake it has no keybind, and the launcher entry is the only way in.

The collection is `~/.config/wallpapers`, which is the `wallpapers` stow package
-- so what the picker offers is exactly what a fresh clone brings, and dropping
an image in the repo is the whole of adding one.

Making a choice stick is the part with a decision in it. hyprpaper and hyprlock
both read `$ACTIVE_WALLPAPER_PATH` out of their own config, and a wallpaper has
to outlive the session, which left rewriting an `env =` line in a checked-in
config from a picker (runtime state in the repo) or `source`-ing a generated
fragment (a `source =` of a file that does not exist yet on a fresh clone is a
config error). It does neither. The var points at one stable path,
`~/.local/state/hypr/wallpaper`, which is a symlink; choosing a wallpaper
retargets the link. Nothing in the repo changes, nothing has to be re-applied at
the next login -- hyprpaper simply follows the link again -- and `hyprctl
reload` cannot undo it, which a runtime `hyprctl keyword env` would not have
survived. `install.sh` creates the link on a fresh machine and leaves an
existing one alone, since that one points at whatever was last picked.

The link deliberately has no extension, so it can point at a `.jpg` or a `.png`
without being renamed. That is safe because both readers load images through
hyprgraphics, which sniffs the format with libmagic rather than trusting the
name, and both canonicalise the path first -- which is also why `hyprctl
hyprpaper listactive` answers with the real file and the picker can tell which
one of the collection is up. `scripts/wallpaper.sh` is the whole of the
plumbing: `list` for what the panel draws, `set` for the link and the one
`hyprctl hyprpaper wallpaper` that makes it visible without waiting for a login.
There is no preload and no unload, because hyprpaper 0.8 has dropped both
requests and loads on demand.

Every panel is also reachable by name from the launcher, for the ones whose
keybind you do not have in your fingers yet. `panels/` is a stow package of
desktop entries — one per panel, each a single
`Exec=qs ipc call <target> <function>`, which is exactly what the matching
`bindd` runs — symlinked into `~/.local/share/applications`, where
`DesktopEntries` finds them with nothing to restart. Searching `panel` or
`quickshell` lists the lot. `toggle` is the right verb even from a launcher: the
launcher holds a `HyprlandFocusGrab` of its own while it is up, which clears the
one an open panel was holding, so the panel is always already closed by the time
the entry runs. See `panels/README.md`.

Three of those entries open no panel at all: **Lock screen**, **Suspend** and
**Shut down**. The machine's power policy already lives elsewhere —
`super+Escape` locks, hypridle blanks and locks on its timers, and a closed lid
is `lid.sh`'s decision — so what was missing was only a way to reach the three
deliberate ones by typing their name. Lock and suspend do exactly what they say
the moment they are picked; suspend does not lock on its way down, because
hypridle's `before_sleep_cmd` is `hyprlock` and logind runs it before the
machine goes anywhere. Shut down is the one that asks: it opens a small card
with Cancel selected, and the selection starts on the harmless button on
purpose. A launcher row is one fuzzy match and one Return away from whatever
was typed, which is the right amount of friction for opening a window and the
wrong amount for taking the machine down with unsaved work on it — a card whose
default answer was "yes" would be a delay rather than a confirmation. Left,
Right or Tab moves between the buttons, Return presses the selected one, Escape
and a click outside both cancel.

All three route through quickshell (`qs ipc call power lock`, `… suspend`,
`… shutdown`) rather than the first two being plain `Exec` lines, so that what
the launcher does about power is one file. Nothing is lost by it: the launcher
asking is quickshell, so a shell that is not running has no row to pick either
way. There is no hibernate entry. Swap on this machine is zram — RAM pretending
to be a disk, which is no use to hibernate — and the kernel has no `resume=`,
so `systemctl hibernate` fails; the entry would list, and picking it would do
nothing but log an error.

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
- **Screenshots open in an editor.** A screenshot notification names the PNG
  `screenshot.sh` just wrote, and no window sent it — the script wrote a file and
  exited. Clicking it opens that image in **tensaku**, a GTK4 annotation editor
  (a fork of Satty): pointer, crop, brush, line, arrow, rectangle, ellipse,
  text, numbered markers, blur, highlighter and spotlight, each on a single
  left-hand key. It opens on the arrow tool, because a screenshot worth clicking
  back into is usually one with something to point at. **Enter** copies the
  edited image to the clipboard — over the raw one `screenshot.sh` already put
  there — and closes the window; `ctrl+s` saves a *new* file beside the original
  under the same `%Y-%m-%d-%H%M%S.png` name rather than overwriting it, and
  `esc` closes without copying. The colour palette is the bar's, the config is
  `tensaku/.config/tensaku/config.toml`, and the in-app preferences dialog
  (`ctrl+,`) writes back into that same stowed file, so a setting changed there
  lands in the repo. `hyprland.conf` floats and centres the window, which is
  what lets it open at the size of the image it was given.

  This is keyed on the app name (`-a "Screenshot"`), so a **screen recording is
  untouched**: its notification, and any other one naming a file that exists,
  still opens nautilus on the folder with that file selected. There is nothing
  to annotate in an mp4.

  The same editor is the second way into an image: **`ctrl+o` on an image in the
  clipboard history** (`super+V`, or `:` in the launcher) opens it in tensaku,
  which is the `edit` subcommand of `quickshell/scripts/clipboard.sh`. It works
  on the file that listing already decoded into `~/.cache/quickshell/clipboard`
  for the thumbnail, so nothing has to be written out again to open it. Return
  there stays paste — the entry back onto the clipboard and into the window you
  came from, per section 15 — because that is what the history is opened for,
  and `ctrl+o` is the exception rather than the other way round.
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

This is how the system recovers itself. `install.sh` sets up snapper, snap-pac
and Limine so that every meaningful change to `/` leaves a restore point, and so
that those restore points are bootable — pick one from the boot menu and you are
running last Tuesday's system, with last Tuesday's kernel.

Before anything else: **a snapshot is not a backup.** All of this lives on the
same filesystem on the same disk. It survives a bad `-Syu`, a botched `/etc`
edit and an `rm` in the wrong directory, and it survives none of a dead NVMe.
Off-machine backup is a separate concern and deliberately not this repo's.

The whole section is skipped if `/` is not btrfs, so the script still works on an
ext4 install — you just get none of this. `snapper create-config` runs only when
the config does not already exist, which is what makes re-running safe.

### What takes snapshots

Three things, and between them they cover everything worth returning to.

**Every package transaction.** `snap-pac` ships alpm hooks, so it does not matter
who calls pacman: `pkg`, which shells out to pacman or yay; yay itself, since
every AUR build ends in a `pacman -U`; or pacman by hand. All of them go through
libalpm and all of them leave a pre/post pair described with the command that
caused it. Nothing in this repo wraps `pkg` — a wrapper would only produce a
second, worse-described snapshot beside the one already being taken. The one
honest gap is that a bare `pacman -Sy` installs nothing and so snapshots nothing,
which is correct rather than missing.

**A timeline on `/home`,** hourly and daily. Not on `/`: snap-pac and `snapshot`
already cover it, and an hourly snapshot of a root filesystem that did not change
still costs a boot entry and a kernel copy.

**You, before doing something destructive.** That is the `snapshot` command
below, and `CLAUDE.md` makes it a standing rule.

The ordering matters and is worth not breaking. The **pre** snapshot is created
before the transaction, so it is paired with the *old* kernel; `zz-snap-pac-post`
sorts last among the alpm hooks, after mkinitcpio has regenerated, so the
**post** snapshot is paired with the *new* one. Rolling back to a pre snapshot
boots the kernel that was running before the update.

Kernel, graphics, systemd and bootloader transactions are additionally tagged
`important=yes` in `/etc/snap-pac.ini`, which gives them their own retention
budget so a run of routine installs cannot age out last week's kernel upgrade.

### The `snapshot` command

```
snapshot "about to rewrite /etc/foo"   take a named snapshot of /
snapshot                               list what exists, and what is bootable
snapshot info                          bootable snapshots and their kernels
snapshot diff 214                      what changed since snapshot 214
snapshot restore-file 214 ~/notes.md   copy one path back out of 214
snapshot restore                       roll the system back (interactive)
```

Creating and listing need no sudo — `install.sh` sets `ALLOW_USERS` and
`SYNC_ACL` in the snapper configs for exactly that reason, because a rule that
costs a password prompt is a rule that gets skipped. The description is
mandatory: it becomes the label in the boot menu.

A first argument that is not a subcommand is taken as a description, so the
common case needs no ceremony. `snapshot create "list"` is how you name a
snapshot after a subcommand, on the day that comes up. `--home` points `list`
and `diff` at the home config instead.

### Getting back

Reach for these in order — the first one is almost always enough.

**A single file.** `snapshot restore-file <id> <path>` copies it out of the
snapshot and saves whatever was there as `<path>.before-restore` first. No
rollback, no reboot, nothing else lost. Because `SYNC_ACL` syncs the ACL onto
`/home/.snapshots`, you can also just browse `/home/.snapshots/*/snapshot/` as
yourself and copy things by hand.

**The whole system, from a running system.** `snapshot diff <id>` first to see
what would be discarded, then `snapshot restore`. It saves the current state as
its own snapshot before doing anything, so the rollback itself is undoable.

**The whole system, when it will not boot.** Pick the snapshot from the
**Snapshots** submenu in Limine. It comes up read-only with an overlayfs
writable layer — that is what the `btrfs-overlayfs` hook is for — so you can log
in and look around without committing to anything. If it is the one you want,
run `snapshot restore` from inside it and reboot. This is the upstream flow and
the one to prefer: you see the system you are about to keep before you keep it.

`snapshot restore` refuses to run without a terminal, deliberately. Snapshot
creation is passwordless so that scripts and agents can leave restore points
freely; replacing the running system is not something that should inherit that.

### Why Limine

This repo used to install `grub-btrfs`, and on an archinstall layout it never
worked — archinstall's bootloader is systemd-boot, so `grub-btrfsd` regenerated
a `grub.cfg` that nothing read. `install.sh` now removes both it and the `grub`
it dragged in.

Installing GRUB properly would have fixed the smaller half. The larger half is
that archinstall mounts the ESP at `/boot`, so the kernel and initramfs sit on
FAT32, outside every btrfs snapshot; a rollback would pair an old root subvolume
with today's kernel and an old `/usr/lib/modules` that no longer matches it.
`limine-snapper-sync` copies each snapshot's boot files onto the ESP as the
snapshot is made, deduplicated by hash. Omarchy does the same thing, which is
where the idea came from.

### The one number to keep an eye on

The ESP is 1 GiB on an archinstall layout and holds every snapshot's kernel, so
it — not disk space — is what limits how far back the boot menu goes. Past
`LIMIT_USAGE_PERCENT` (75, in `/etc/limine-snapper-sync.conf`) new snapshots
silently stop getting boot entries: snapper keeps working and nothing in its
output changes. `snapshot` checks after every create and says so, and
`limine-snapper-remove <id>..<id>` frees entries up.

To make 1 GiB workable, `install.sh` drops `kms` from `HOOKS` **on NVIDIA
machines only**, where the hook pulls ~107 MiB of nouveau GSP firmware into the
early CPIO for a driver that is never loaded. That takes a kernel generation
from ~157 MiB to ~43 MiB. The cost is that the console runs on the EFI
framebuffer until `nvidia_drm` loads, which is normal for the proprietary
driver. On amdgpu or Intel the hook stays.

Full write-up, including the arithmetic: `snapshots/README.md`.

### Two things that get in the way of installing this

Both are upstream problems rather than anything this repo does, and `install.sh`
works around both.

**The AUR is unreachable over IPv6 from here.** `aur.archlinux.org` publishes
both A and AAAA records, glibc prefers the IPv6 one, and every `git clone`
against it dies with `Recv failure: Connection reset by peer` — which takes the
whole AUR half of the install with it, not just Limine. Other things fail the
same way for the same reason; the AUR is only where it is loudest.

**So IPv6 is switched off on this machine, deliberately, for the whole system.**
Two earlier attempts each looked like a whole fix and were half of one:
`sysctl -w net.ipv6.conf.all.disable_ipv6=1` in front of each AUR step, which
`-w` undoes at the next boot; and an `/etc/gai.conf` precedence rule with IPv6
left up, which fixes everything that asks the resolver which family to prefer
and nothing that opens an IPv6 socket without asking. `install.sh` now does all
three, because each one is put back by the others:

- `/etc/sysctl.d/40-disable-ipv6.conf` sets `all` and `default`, applied on the
  spot to every interface that already exists — writing `all.disable_ipv6` does
  not retract an address an interface is already holding.
- `/etc/NetworkManager/conf.d/10-disable-ipv6.conf` sets `ipv6.method=disabled`
  as the default for every connection, because NetworkManager is what
  configures the interfaces after the reboot and would hand out a fresh address
  whatever sysctl says.
- `/etc/gai.conf` still prefers IPv4, for anything reached before or outside
  those two.

Loopback is the deliberate exception: `all.disable_ipv6` covers `lo` too, and
taking `::1` away breaks local daemons that bind it for no benefit here, so the
sysctl file re-enables `lo` on its last line. Order matters there — sysctl
applies a file top to bottom, so the specific key has to come after the `all`
key it overrides.

To put IPv6 back on a machine where it works, delete those three files and
reboot.

**Arch's gradle cannot build them.** Gradle 9 moved its public API into
`lib/api/` inside the distribution, and `gradle 9.7.0-1` ships no `lib/api`
directory at all, so both packages fail to configure with `Cannot find module
'gradle-public-api-legacy'`. `install.sh` downloads the official Gradle
distribution to `~/.local/share/gradle-<version>` (checksum-verified) and
rewrites the hardcoded `/usr/bin/gradle` in each PKGBUILD to point at it.
Nothing pacman owns is touched. Two details make that work and are easy to lose:
`GRADLE_HOME` has to be set explicitly, because `/etc/profile.d/gradle.sh` points
it at the broken tree and the official launcher honours it; and `--no-daemon` is
required, because a Gradle daemon already started from Arch's distribution gets
reused and fails identically.

If either package fails to build, snapshots still work and are still taken —
they are simply not bootable until it succeeds.

### What still compiles, and why the install takes as long as it does

Most of a fresh install is downloads. The exceptions, in order of how much of
the wall clock they own:

- **`limine-mkinitcpio-hook` and `limine-snapper-sync`** — the two above. Gradle
  builds a GraalVM native image for each, after downloading a JDK to do it with.
  This is the single longest thing the script does, and it is why the vendored
  Gradle apparatus exists at all.
- **`rtl8188gu-dkms-git`** — a kernel module, so DKMS compiles it against the
  running kernel and will do so again on every kernel upgrade. Unavoidable by
  construction; there is nothing to prebuild.
- **`tensaku`** (Rust) and **`wifitui`** (Go) — no `-bin` variant exists in the
  AUR for either.

Everything else that used to compile no longer does. `ghostty`, `btop`,
`bluetui` and `wiremix` all landed in `[extra]` and moved to the pacman list —
one Zig build and two Rust builds gone. `ghostty` is not optional there: its AUR
package was deleted when the repo package appeared. The rest of the AUR list is
already `-bin`, or a repackaged upstream binary (`1password`, `docker-desktop`,
`brave-bin`, `orca-slicer-bin`), and downloads rather than builds.

### Re-running install.sh on a machine set up before this

Everything here is safe to re-run, and idempotent. What you get depends on what
that machine already boots.

**On a machine that boots systemd-boot** (archinstall's default, which is what
`archinstall.md` now specifies) `install.sh` does the full migration in place:
Limine is installed, the snapshot menu appears, and the systemd-boot EFI binary
and NVRAM entry are left behind as a fallback. This is exactly the path this
machine took.

**On a machine that genuinely boots GRUB** — which is what `archinstall.md`
specified before this change, so anything set up from these dotfiles earlier
will be one — `install.sh` deliberately stops short. It configures snapper,
snap-pac, the retention tuning and the `snapshot` command, and then leaves the
bootloader alone: replacing a working bootloader as a side effect of re-running
an installer is not something that should happen on a machine nobody is
watching, and that layout also mounts the ESP at `/boot/efi` with `/boot` inside
the root subvolume, which none of this was built against. You get everything
except the boot menu, and the script says so.

Switching such a machine over is a deliberate act:

```bash
sudo pacman -Rns grub grub-btrfs
DOTFILES_FORCE_LIMINE=1 ./install.sh
```

Do that one from a terminal you can watch, with a live USB within reach.

`grub-btrfs` is only removed on machines that are *not* booting GRUB, where it
was never doing anything. Where GRUB is real, it stays and keeps working.

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
- **`rust` and `rustup` conflict, and `--noconfirm` answers that question with
  no.** Arch's `rust` package owns the same paths as rustup's shims, so on a
  machine that has it `pacman -S rustup` asks whether to remove `rust` and then
  aborts on the default answer — which showed up as `pacman: rustup` and `rust
  stable toolchain` both landing in the skipped list. `install.sh` removes
  `rust` first, so both steps become no-ops instead.
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

## 15. The Launcher

`super+SPACE` opens the launcher, `super+V` opens it already switched to the
clipboard history, and `super+shift+/` opens the keybind sheet. All three are
quickshell panels — `qs ipc call launcher toggle`, `... launcher clipboard`,
`... keybinds toggle` — and none of them is a bar module, because none of them
has anything to say while it is closed.

They replaced **walker**, and with walker went **elephant**, the provider daemon
it talked to: six AUR packages and a socket protocol whose entire job was to put
a list of `.desktop` files on a screen. Everything that stack actually did is
native to what was already running. `DesktopEntries` is a Quickshell singleton
that indexes the same files walker's `desktopapplications` provider did.
`Hyprland.toplevels` is a live window list the shell was already holding. The
clipboard is `cliphist`, which is in the official repos where elephant's
provider was an AUR build. And the calculator is `qalc`, which elephant was
shelling out to anyway.

That last one was not a lateral move. elephant's `calc` provider answered
`100 usd to brl` with `14.34121571 in·€²`; `qalc -t` answers
`BRL 514.7134299`. The currency conversion that had been quietly broken was
never qalc's fault, and dropping the layer in between fixed it.

### One window, six modes

The prefixes are walker's, character for character, deliberately — they are in
the fingers and there was nothing to gain by retraining them:

| Prefix | Mode | What it lists |
| --- | --- | --- |
| *(none)* | Apps | `.desktop` entries, most-used first |
| `:` | Clipboard | Everything copied, newest first |
| `=` | Calculator | `qalc`, including unit and currency conversion |
| `$` | Windows | Every open window, by title or class |
| `>` | Run | A shell command, with `$PATH` completion |
| `@` | Web | A search, or a URL to open |

Apps mode also answers the other two things walker had in its default provider
set. A query that is unambiguously a sum gets a result row above the app list,
and a query that matched no app at all falls through to a web search. The guard
on the first of those is strict on purpose: `qalc` reads everything as units and
will answer `firefox` with `0 B` and `hello world` with `6.5E−26 B²·h²·L³`, so
nothing short of a digit-operator-digit, a `<number> <unit> to <unit>`, or a
named function gets to be arithmetic. The `=` prefix skips the guard, which is
the way to ask when it guesses wrong.

Return activates, `shift+Return` activates and leaves the panel up, and the line
along the bottom names whatever else the current mode can do — an unlabelled
`ctrl+shift+D` that wipes a clipboard is a trap. The arrows wrap, unlike the
bar's panels: a launcher list is walked from the bottom as often as from the
top, and walker wrapped.

Ranking is a fuzzy match plus a launch history. The match is three tiers in the
order someone typing expects them — what starts with the query, what contains it
at a word boundary, then what merely spells it out in order, which is what makes
`gimp` find "GNU Image Manipulation Program". On top of that sits a frecency
score capped at 240, so the thing you always open wins a one-letter query
without a month of habit being able to outvote an exact match. `ctrl+P` pins an
app above all of it. Both live in
`~/.local/state/quickshell/launcher-usage.json`.

### The clipboard

`cliphist` is a store, not a daemon: it is fed by two `wl-paste --watch`
processes, one for text and one for images, because `wl-paste` watches a single
MIME type at a time and an image on the clipboard is not offered as text.
Starting them is `scripts/clipboard.sh watch` in `hyprland.conf`, which clears
its own stale watchers first so that running it again is how `ctrl+P` resumes a
paused history — cliphist has no pause of its own, so pausing is stopping the
things that feed it.

Clipboard mode is the one mode with a second column. The card widens and a
preview pane opens to the right of the list, because a listing line is not
enough to tell two entries apart that begin the same way — and it never can be,
since cliphist folds every entry onto one line to list it and a row is 46px
besides. The pane shows an image at pane size, or the text as it was actually
copied, newlines and indentation intact. That last part costs a `decode`, so it
is fetched for the row the cursor is on rather than for the hundred it walked
past, debounced by 90ms so that holding Down does not fork per row and capped at
4KB because the pane is for recognising an entry, not reading it.

Everything the panel does to an entry is a subcommand of that same script,
because an entry is addressed by a cliphist id and `cliphist delete` will not
take one: it wants the whole listing line back on stdin. `list` also decodes any
image it has not seen into `~/.cache/quickshell/clipboard/<id>.<ext>` — the
bytes only come back through `decode`, and the panel cannot draw a thumbnail
without a file to point an `Image` at. Ids are never reused, so a cached file
can only ever be the entry it was named for. `ctrl+O` opens an image in tensaku,
which is the same annotation editor a screenshot notification opens (section 6),
and it works because that decode already happened.

### The keybind sheet

`super+shift+/` lists every bind on the system, built from `hyprctl binds -j` at
open time — so it is the live bind table and never a second copy of
`hyprland.conf` that could drift. Adding a `bindd` is all it takes to appear
there. Selecting a row runs it, so the sheet doubles as a command palette; a
mouse bind has nothing to dispatch and is listed dimmed and read-only.

`scripts/keybinds.py` still does the parsing — the modmask, the evdev keycodes a
`code:59` bind comes back as, the XF86 media keysyms — but it now prints JSON and
stops. It used to draw the sheet itself, by padding a key column to a fixed
width and piping the lot into `walker --dmenu --index`, which was the best that
could be done with a flat list of strings. The panel draws each modifier as a
keycap of its own, which is why `keys` is a list now rather than a `SUPER + T`
string. Dispatching is the panel's job for a reason: it holds a focus grab, and
a good third of what it can run is `exec` on something that wants the keyboard —
its own bind included.

### Pasting what you pick

`super+V` and `super+E` both exist to put something into the window you were
just in, so Return on an entry copies it **and** pastes it. That was true under
walker too, and the script that does it is the one piece of that era that
survived unchanged in substance:
`scripts/.config/scripts/copy-and-paste.sh`. It copies, then presses `ctrl+v`
with `wtype` over the virtual-keyboard protocol. `ctrl+v` and not
`ctrl+shift+v`, because ghostty is bound to paste on `ctrl+v` here, so one chord
covers the terminal and every GUI app and the script never has to ask what it is
pasting into.

The clipboard hands it the entry on stdin — text as text, an image as the raw
bytes of the cached PNG, so nothing in the script has to know which it is
holding. The emoji picker calls the same script with the emoji as an argument
and `--layer quickshell:emoji`, and runs it rather than a version of its own
because the wait below is the subtle part and there is no reason for two copies
of it to drift.

The paste cannot fire immediately, and the delay is not a guessed `sleep`. The
panel still holds the keyboard at the moment the command runs, so a `ctrl+v`
sent too early is typed into its own search field and lost when it closes. The
script polls `hyprctl layers` until that layer surface is gone — the one honest
signal that focus is on its way back — waits another 80ms for the compositor to
actually hand it over, and gives up after about 1.2s so a panel left open drops
the paste rather than firing it at a random moment. That wait is also why the
launcher and the emoji picker each take a layer namespace of their own,
`quickshell:launcher` and `quickshell:emoji`, instead of the `quickshell:panel`
the bar's cards share: a panel left open elsewhere must not be able to hold the
wait open.

The copy is kept as well as the paste. The thing that was chosen does belong on
the clipboard, and pasting it somewhere is not a reason for the next `ctrl+v` to
produce something else.

---

## 16. `copy` from a pipe

`copy` is the shell end of all this: a zsh function in `.zshrc` that puts stdin,
or its arguments, on the clipboard through `wl-copy --trim-newline`. It was an
alias until it grew a set of regex flags, and those exist for one command in
particular:

```bash
history | fzf | copy --hist
```

`history` prints an index in front of every line, and that index is not noise —
it is half of what fzf matches against when you are hunting for a command you
half remember. It has to survive the picker and die on the way out, which is
what `--strip` is: a PCRE deleted from what is being copied, everywhere it
matches, line by line. `--hist` is that flag with the pattern already written:
`--strip '^\s*\d+\s+(?:[\d/.-]{8,10}\s+)?'`, the index and — if `HIST_STAMPS` is
ever uncommented in `.zshrc` — the date beside it.

`--only` is the inverse and keeps just what matched, so
`copy --only 'https?://\S+'` off a wall of log output, or
`--only 'v(\d+\.\d+\.\d+)'`, where a capture group wins over the whole match so
the pattern can anchor on the `v` without copying it. A line matching nothing is
dropped rather than copied blank, several matches on a line come back one per
line, and the flags refuse to be combined, because composing them would mean
picking an order and neither order is the obvious one.

The regex engine is perl, not `sed -E`: POSIX ERE has no `\d`, no `\s` and no
non-greedy, which is most of what makes a pattern typeable at a prompt without
stopping to think. perl is nothing this repo installs on purpose — it is git's
dependency, so it is already on any machine that got this far. With no flags
nothing is in the pipe but `cat`, so an image piped in still copies as bytes.

---

## 17. Fingerprint Unlock

The ThinkPad's reader unlocks **hyprlock and nothing else**. SDDM at boot, `sudo`
and a TTY login all still want the password, and that is deliberate rather than
an omission: the password is what stands between a stolen laptop and the session,
and it is worth typing once a day. The screen you unlock forty times a day is the
one that earns a shortcut.

Keeping it that narrow costs nothing, because hyprlock does not use PAM for this.
It speaks to fprintd over DBus directly (`net.reactivated.Fprint`), so the
`auth:fingerprint` block in `hyprlock.conf` is the whole configuration and
`/etc/pam.d/` is untouched. Adding `pam_fprintd.so` to `system-auth` would have
been the other way to do it, and it would have handed the reader to `sudo` and
SDDM as well.

### How `install.sh` picks a driver

Nothing about the sections above is specific to this laptop, and the install is
written the same way: it tries to work on whatever reader it meets, and where it
cannot, it says so by name instead of leaving a silent no-op.

`fprintd` goes on first, because it is the part that is always right — it owns
the DBus name hyprlock talks to, and libfprint behind it drives most readers on
the market. Then **the daemon itself is asked whether it found anything**:

```bash
fprintd-list "$USER"    # "found 1 devices" -> done
```

That is a better test than any table of USB IDs kept in this repo. It covers
sensors that never appear in `lsusb` (the SPI ones), and it keeps being right as
libfprint gains drivers between releases, which a hand-written list does not.

Only when the daemon comes up empty does anything machine-specific happen, and
then the reader has to be identified. The ID comes from `lsusb` matched against
**libfprint's own hwdb** (`/usr/lib/udev/hwdb.d/60-autosuspend-libfprint-2.hwdb`),
which names every device any of its drivers claims — four hundred-odd IDs,
regenerated on each upgrade, on disk already because fprintd pulled libfprint in.
It answers "is this thing a fingerprint reader" even for devices libfprint then
turns out not to drive, which is exactly the case worth naming. A product string
containing "finger" or "biometric" is the fallback for a sensor too new for it.

From there it is one `case` arm per family libfprint cannot drive. Today there is
one arm — the Validity 009x below. A reader matching no arm is reported by ID and
added to the skipped-steps summary that `install.sh` prints at the end, pointing
back here.

### Readers that need something other than libfprint

| Family | IDs | What it needs |
| --- | --- | --- |
| Validity 009x | `06cb:009a`, `138a:0090`, `138a:0097` | `open-fprintd` + `python-validity` (AUR). **Automated** — this is the T480's sensor. |
| Goodix | `27c6:*` | `libfprint-2-tod1` plus the per-model blob (`libfprint-2-tod1-goodix`, `…-goodix-550a`, and others). Manual: the right package depends on the product ID. |
| Egis | `1c7a:*` | A separate driver again, and several models have none at all. Manual. |
| Elan, Upek, AuthenTec, most others | — | Already in libfprint. `fprintd` alone is the whole answer. |

Teaching `install.sh` a new one is adding a `case` arm in the fingerprint
section and a row here. The reason the Goodix and Egis rows are not arms is that
guessing wrong installs a proprietary driver for the wrong sensor, and the
product ID is what decides — so that stays a decision a human makes once.

### Why the T480 needs it

`fprintd` alone fails here in the way that wastes an afternoon: it installs, it
starts, and then `fprintd-enroll` says

```
Impossible to enroll: GDBus.Error:net.reactivated.Fprint.Error.NoSuchDevice: No devices available
```

The sensor is `06cb:009a`, "Synaptics Metallica MIS Touch Fingerprint Reader",
one of the Validity 009x family. Confusingly libfprint *does* carry a `vfs7552`
driver whose device table claims that ID — it is in the hwdb, and the driver is
compiled into the Arch package — and it still does not drive this sensor. The
device is enumerated by nobody and fprintd has nothing to hand out.

What does drive it is uunicorn's pair: **python-validity** as the driver and
**open-fprintd** as a drop-in replacement for the fprintd daemon, both from the
AUR. This is an either/or rather than an addition — `fprintd-clients-git`
conflicts with `fprintd` and installing it removes the repo package, which is
also why `install.sh` checks for it before putting `fprintd` back on a re-run.
Everything above the DBus name is unchanged, which is the whole point of
open-fprintd: hyprlock, `fprintd-enroll` and the indicator script all still talk
to `net.reactivated.Fprint` and none of them know the difference.

Two units are enabled that are worth knowing about. `python3-validity.service`
is enabled even though the udev rule already starts it, because a machine that
booted with the sensor attached never gets an add event. And the AUR package's
`python3-validity-suspend-hotfix.service` restarts both the driver and the
daemon after resume: this laptop suspends itself on battery, and the sensor
comes back dead without it — open-fprintd's own `resume.py` only re-opens
devices, which is not enough. `open-fprintd.service` is `Type=dbus` and
deliberately not enabled; the first fingerprint call activates it.

### Enrolling

Manual, and it has to be — it writes per-user biometric templates and needs the
finger in the room:

```bash
fprintd-enroll                 # right index by default; swipe until it says done
fprintd-enroll -f left-index-finger
fprintd-list "$USER"           # what is enrolled
fprintd-delete "$USER"         # start over
fprintd-verify                 # test outside the lock screen
```

Enrolment asks polkit for a password once. If it reports no device on a machine
where the units are running, `sudo journalctl -u python3-validity -b` is where
the driver says why — a sensor previously paired by Windows Hello has to be
reset with `validity-sensors-tools-git` before it will pair with anything else.

### The indicator

`hypr/.config/hypr/scripts/fingerprint-icon.sh` prints a fingerprint glyph, or
prints nothing, and a hyprlock label draws whatever it printed just outside the
right edge of the password field. Nothing is the case worth having: hyprlock's
fingerprint auth fails *silently* — it logs that fprintd was unreachable and goes
on being a password prompt — so on a machine with no reader, without `fprintd`,
or with no finger enrolled yet, the lock screen has to look exactly like the
password-only one it did before. The script therefore asks `fprintd-list`, which
fails when there is no daemon or no device and prints no numbered lines when
nothing is enrolled — the same question on every machine, whichever driver is
underneath.

It runs once per lock (`cmd[update:0]`), which is as often as the answer can
change.

The label is the one thing on the lock screen not set in `$font`, and it has to
be. hyprlock sizes a label's texture to pango's *logical* extents — the glyph's
advance width — and JetBrainsMono Nerd Font draws `nf-md-fingerprint` as a 28px
picture in a 21px cell, so seven pixels of it landed outside the texture and the
icon appeared with its right edge sliced off. `Symbols Nerd Font Mono` keeps the
glyph inside its advance, which is what a symbols-only face is for. Any other
Nerd Font glyph borrowed for a label here is worth checking the same way.

Both the label's position and the input field's size are percentages of the
monitor — field `20%` wide and centred, glyph centred at `12%` — so the glyph
stays a fixed gap off the field's edge on the laptop panel and on an external
screen alike. A pixel offset would have been right on exactly one width.

### Two things that surprise

**Three misses and it stops.** After three non-matching scans hyprlock disables
fingerprint auth for the rest of that lock and the field says so; the password
still works. The `retry_delay = 250` is why a badly placed finger usually costs
one attempt rather than one of those three.

**A fingerprint does not wake the screen.** hypridle blanks the panel 30 seconds
after locking, and the reader is not an input device as far as Wayland is
concerned, so touching it on a dark screen unlocks the session without turning
the panel back on. Any key or the touchpad brings it back. Press a key first and
the ordinary case — wake, then touch — behaves the way it looks like it should.

---

## 18. General Notes

- `install.sh` is safe to re-run
- System-level dotfiles (`sddm`) are stowed with `sudo stow -t /`
- `dbus`, `nautilus`, `panels`, `kanata`, `claude`, `caveman` and `herdr` are
  stowed with `--no-folding`, everything else plainly
- `webapps/` and `snapshots/` are not stow packages at all -- the first is a
  generator, the second a set of curated `/etc` files `install.sh` copies
- When an app has already written a config that stow wants to own, `install.sh`
  moves the original aside as `<name>.pre-stow` rather than failing
- All non-deterministic or GUI-based steps are documented here on purpose

### Leftovers worth removing

Superseded packages that may still be installed from earlier runs. Nothing
depends on them and `install.sh` no longer pulls them in:

```bash
sudo pacman -Rns mako dunst rofi rofi-calc anyrun cliphist pcmanfm tmux waybar
```

`grub-btrfs` and `grub` belong on that list too, but `install.sh` removes them
itself -- see section 10 for why they were never doing anything.

If something breaks after a system update, this file is the single source of
truth for restoring expected behavior.
