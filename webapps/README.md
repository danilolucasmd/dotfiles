# webapps

Declarative web apps, each a bare qutebrowser window of its own: no tab bar, no
status bar, its own icon and window class.

## Add / change / remove an app

1. Edit [`apps.conf`](./apps.conf): one line per app, `Name | URL | slug`.
2. Drop an `icons/<slug>.png` (any square PNG; 256 to 512px is ideal). Optional:
   a missing icon falls back to a themed name.
3. Run the generator:

   ```sh
   ./generate.sh
   ```

It writes `~/.local/share/applications/webapp-<slug>.desktop` for every app and
removes launchers for apps you deleted from `apps.conf`. The launcher picks up a
new entry without a restart.

## How an app runs

Every launcher runs [`qutebrowser-app.sh`](./qutebrowser-app.sh), which holds
all of it:

- **A qutebrowser instance per app.** One instance gives all its windows the
  same app id, and an app needs its own: its icon in the bar, its windows kept
  apart from the browser's, notifications routed back to it. The window class
  is `webapp-<host>` (`webapp-web.whatsapp.com`), which is how quickshell's
  `focus-sender.sh` sends a clicked notification to the right window.
- **A profile per app**, in `~/.local/share/qutebrowser-apps/<slug>`. Logins are
  not shared with the main qutebrowser, so each app is signed into once.
- **The main `config.py`** for keys and theme, with forced dark mode off (the
  apps' own dark themes still apply), the tab bar off,
  the status bar shown only outside normal mode (insert, hints, the command
  line), and notifications allowed. A link the app opens in a
  new tab becomes a new window, since there is no tab bar to show it in.
- **WhatsApp starts in passthrough mode**, so every key goes to the page
  (typing anywhere, its own shortcuts), and has no status bar at all.
  Shift+Escape returns to normal mode.
- **User scripts for the apps** live in [`greasemonkey/`](./greasemonkey),
  linked into every profile at launch. `notifications.user.js` asks for the
  notification permission on each load: qutebrowser grants it without a prompt
  but never remembers the grant, so without it apps like WhatsApp show their
  enable-notifications banner on every open.
- **Launching an open app raises it** instead of opening a second window.
- **Widevine** (DRM video, which Spotify needs) is borrowed from Brave's
  profile, since QtWebEngine ships none. Without Brave installed and run once,
  Spotify will not play.

## Fresh machine

Part of the dotfiles install (see `../install.sh`), which runs `./generate.sh`.
