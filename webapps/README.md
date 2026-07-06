# webapps

Declarative, toolbar-free Brave web apps.

Brave's built-in "Install app" creates launchers with `--app-id=<id>`, which open
the installed-PWA window. That window shows a thin toolbar at the top whenever the
site's web-app manifest requests it — and Brave has no setting to hide it. These
launchers use `--app=<URL>` instead, which gives a bare content-only window with
no toolbar.

## Add / change / remove an app

1. Edit [`apps.conf`](./apps.conf) — one line per app: `Name | URL | slug`.
2. Drop a `icons/<slug>.png` (any square PNG; 256–512px is ideal). Optional — a
   missing icon just falls back to a themed name.
3. Run the generator:

   ```sh
   ./generate.sh
   ```

It writes `~/.local/share/applications/webapp-<slug>.desktop` for every app and
removes launchers for apps you deleted from `apps.conf`. Log out/in or restart
your launcher (walker) if a new entry doesn't show up immediately.

You do **not** install these through Brave. Cookies/logins are shared with the
Brave `Default` profile, so you stay signed in.

## Options

- `BRAVE_PROFILE=Work ./generate.sh` — use a different Brave profile.
- `BRAVE_BIN=/opt/brave-bin/brave ./generate.sh` — pin a specific binary
  (otherwise `brave` / `brave-browser` on `$PATH` is autodetected).

## Fresh machine

Part of the dotfiles install (see `../install.sh`). Just run `./generate.sh`
once after Brave is installed.

## Notes

- Each window gets a stable `--class=webapp-<slug>` so Hyprland/Waybar group it
  under the right icon. If Hyprland still mis-groups a window, match on
  `class:^(webapp-<slug>)$` in a windowrule.
- To go back to Brave's PWA launchers, reinstall the app from Brave and delete
  the matching `webapp-<slug>.desktop`.
