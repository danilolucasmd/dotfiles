-- Hyprland 0.57 dropped hyprlang: this file is the whole config now, and
-- hyprland.conf is no longer read at all. When 0.57 found no hyprland.lua it
-- wrote a stock one here instead, which is how the session came up with none
-- of the binds, the bar, or the autostart below.

local home = os.getenv("HOME")

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XMODIFIERS", "@im=fcitx")
-- The wallpaper, for both hyprpaper and hyprlock, which each read this var out
-- of their own config. It points at a symlink rather than at an image so that
-- the quickshell picker (`qs ipc call wallpaper toggle`) can change the
-- wallpaper by retargeting the link, with nothing in this repo to rewrite and
-- nothing to re-apply at the next login: hyprpaper simply follows the link
-- again. install.sh is what creates the link on a fresh machine, pointing it at
-- one of the images in the `wallpapers` stow package; see
-- quickshell/.config/quickshell/scripts/wallpaper.sh for why it has no
-- extension and why that is safe.
hl.env("ACTIVE_WALLPAPER_PATH", home .. "/.local/state/hypr/wallpaper")

-- Steam under Wayland on NVIDIA. These used to sit in a `steam` stow package at
-- ~/.config/steam/env.conf, which nothing ever read: Steam does not look
-- there, so they had never taken effect. The session is the only place that can
-- actually put them in the client's environment.
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1")

-- Icon theme for the quickshell bar's system tray. Qt has no icon theme of its
-- own here, so symbolic tray icons (fcitx5's keyboard) would render black on
-- the dark bar or not at all; breeze-dark ships light variants built for it.
hl.env("QS_ICON_THEME", "breeze-dark")

-- 1Password's SSH agent. ~/.ssh/config already points OpenSSH at the socket
-- with IdentityAgent, so `ssh` and `git` were fine without this, but anything
-- that looks for the agent the normal way (ssh-add, and any client that is not
-- OpenSSH reading its config) found nothing, which is why the agent looked
-- broken. Setting it here covers the whole session, GUI apps included.
hl.env("SSH_AUTH_SOCK", home .. "/.1password/agent.sock")

-- For Qt apps.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

------------------
---- MONITORS ----
------------------

-- One screen at a time (the laptop panel on its own, or the external with the
-- lid shut), so nothing here arranges two of them. Everything is left to
-- Hyprland; no daemon re-applies anything on hotplug.
--
-- The external is held at 120Hz instead of its top 144: resuming from suspend
-- at 144 comes back to a dead link, at 120 it comes back every time. The list
-- has no exact 120 and Hyprland takes the nearest, which is 119.98.
--
-- It is named by description because connectors are not stable. This block
-- used to say HDMI-A-1, which is how the monitor quietly sat at 60Hz after it
-- came up as HDMI-A-2.
--
-- `highrr` on the other two rather than `preferred`: the mode a display
-- advertises is not the best one it has, and this monitor advertises 60Hz while
-- doing 144. It is the highest rate in the whole mode list, not the highest at
-- the best resolution, so a display that can do 720p faster than 1080p would
-- come up at 720p. The panel cannot, and the display panel (super+D) can put
-- an unknown monitor back for the session if one ever does.
hl.monitor({ output = "eDP-1", mode = "highrr", position = "0x0", scale = 1.25 })
hl.monitor({ output = "desc:ASUSTek COMPUTER INC VG279QR", mode = "1920x1080@120", position = "auto", scale = 1 })
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "ghostty"
local fileManager = "nautilus"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("fcitx5 -d")
    -- Authentication agent for polkit prompts (mounting disks in Nautilus, the
    -- Proton VPN helper). Without one running, anything that asks for
    -- privileges gets no dialog and simply fails.
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("qs")
    -- The two wl-paste watchers that fill the clipboard history, started by the
    -- script that also pauses and lists them. It replaced elephant, which walker
    -- needed and nothing else did; cliphist is the same store with none of that
    -- attached. Re-runnable (it clears its own stale watchers first), which is
    -- what makes ctrl+P in the launcher able to resume capture by running it again.
    hl.exec_cmd(home .. "/.config/quickshell/scripts/clipboard.sh watch")
end)

-- Theme, re-applied on every config load as `exec =` used to.
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"') -- GTK4
hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"') -- GTK3

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,

        border_size = 0,

        col = {
            active_border = "rgb(dddddd)",
        },

        resize_on_border = false,
        allow_tearing = false,

        layout = "dwindle",

        -- Prevents windows focus to cycle through windows after focusing an edge window
        no_focus_fallback = true,
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        -- pseudotile option removed in Hyprland 0.55.x; pseudotiling is a
        -- per-window toggle via the `pseudo` dispatcher instead.
        preserve_split = true,
        -- Always create new split to the right
        force_split = 2,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,

        -- Honour xdg-activation requests, so an app that asks to be raised actually
        -- gets focus. Clicking a browser notification works through this: the
        -- browser focuses the window holding the tab that fired it, and without
        -- this Hyprland drops the request. See quickshell's focus-sender.sh.
        focus_on_activate = true,
    },

    input = {
        kb_layout = "us,us",
        kb_variant = ",intl",
        kb_model = "pc105",
        -- No grp:alt_space_toggle: alt+space is a Hyprland bind now (see the
        -- keyboard layout bind), so that quickshell hears the switch and can offer
        -- the same layout list as a panel. xkb switched the group inside
        -- libxkbcommon, where nothing could hang anything off it.
        kb_options = "",
        kb_rules = "",

        repeat_delay = 300,
        repeat_rate = 50,

        follow_mouse = 1,

        sensitivity = 0,

        accel_profile = "flat",

        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.2,
        },
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = false, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = false, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Every bind carries a description: the keybind sheet (super+?) lists the live
-- table from `hyprctl binds -j`, and a bind without one shows only its raw
-- dispatcher there.
local mainMod = "SUPER"

-- The sheet doubles as a command palette, but `hyprctl binds -j` now reports a
-- dispatcher as an opaque `HL.Dispatcher(exec_cmd)` that cannot be sent back.
-- So every bind's action is kept here under its description, a global because
-- `hyprctl dispatch` runs in this same Lua state, and keybinds.py hands the
-- panel `KEYBIND_ACTIONS["<description>"]` to dispatch. Binds that share a
-- description (the two play keys) share an action too.
KEYBIND_ACTIONS = {}

local function bind(keys, desc, dispatcher, opts)
    opts = opts or {}
    opts.description = desc
    if not opts.mouse then
        KEYBIND_ACTIONS[desc] = dispatcher
    end
    return hl.bind(keys, dispatcher, opts)
end

local function sh(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function qs(call)
    return sh("qs ipc call " .. call)
end

-- General
bind(mainMod .. " + T", "Open terminal", sh(terminal))
bind(mainMod .. " + W", "Close window", hl.dsp.window.close())

-- Launcher. One quickshell panel for all of it, where this used to be walker
-- talking to elephant: apps with no prefix, and `:` clipboard, `=` calculator,
-- `$` windows, `>` run, `@` web search (walker's own prefixes, kept because
-- they are in the fingers). super+V is the same panel opened on `:`.
bind(mainMod .. " + SPACE", "App launcher", qs("launcher toggle"))
bind(mainMod .. " + V", "Clipboard history", qs("launcher clipboard"))
-- Emoji picker. Its own panel rather than a launcher mode: it is a grid under
-- CLDR headings, not a list you search; see quickshell/EmojiState.qml.
bind(mainMod .. " + E", "Emoji picker", qs("emoji toggle"))
-- Coding-agent usage panel. Quickshell owns the panel, so the bind only has to
-- ask it to toggle; `qs ipc` finds the running instance on its own.
bind(mainMod .. " + A", "Agent usage panel", qs("agentUsage toggle"))
-- Past notifications, in the same arrangement. Quickshell is the
-- notification daemon itself now, so nothing else is involved.
bind(mainMod .. " + N", "Notification history", qs("notifications toggle"))
-- Reminders, on the notification key on purpose: a reminder is a notification
-- sent to your own future self, and it arrives as exactly that (quickshell is
-- the daemon, so it lands in the history above with everything else). Shift
-- writes one (a message, then how many minutes), ctrl lists what is pending with
-- the countdown on each. R would have been the obvious letter and is the screen
-- recorder; the keybind sheet is a discovery surface, and one letter meaning two
-- things there is worse than a letter that means neither.
bind(mainMod .. " + SHIFT + N", "New reminder", qs("reminder toggle"))
bind(mainMod .. " + CTRL + N", "Reminders panel", qs("reminder list"))
bind(mainMod .. " + C", "Calendar panel", qs("calendar toggle"))
-- The adapter switch, what is paired, and what is in range. B for bluetooth,
-- which is reached far more often than the battery panel it took the key from.
bind(mainMod .. " + B", "Bluetooth panel", qs("bluetooth toggle"))
-- Brightness, refresh rate, scale and rotation, per monitor. Runtime only:
-- whatever the panel sets, a reload puts the monitor rules above back.
bind(mainMod .. " + D", "Display panel", qs("display toggle"))
-- Both links, what the active one is doing, and the Wi-Fi networks in range.
-- W on its own closes the window, so the panel takes shift with it.
bind(mainMod .. " + SHIFT + W", "Network panel", qs("network toggle"))
-- Charge per pack, health, and the power profile. B on its own is the Bluetooth
-- panel, so battery takes shift with it.
bind(mainMod .. " + SHIFT + B", "Battery panel", qs("battery toggle"))
-- Processor, graphics, memory and disk: usage, temperature and transfer rates.
-- P on its own is the colour picker, so the panel takes shift with it.
bind(mainMod .. " + SHIFT + P", "Performance panel", qs("performance toggle"))
-- The reading in the bar, plus what it feels like and the humidity. W is the
-- window close and shift with it is the network panel; T for temperature went
-- to text recognition in the screenshot binds below, so weather sits on shift
-- with the calendar instead: the two panels that answer "what is today like".
bind(mainMod .. " + SHIFT + C", "Weather panel", qs("weather toggle"))
-- Everything currently playing or paused, one row per player, with a transport
-- on each.
bind(mainMod .. " + M", "Now playing panel", qs("media toggle"))
-- The collapsed half of the bar's right cluster, same as clicking the chevron.
bind(mainMod .. " + X", "Toggle bar extras", qs("extras toggle"))
-- The audio device panel, which lists outputs and inputs together: O opens it
-- on the outputs, I on the inputs.
bind(mainMod .. " + O", "Audio output picker", qs("audio outputs"))
bind(mainMod .. " + I", "Audio input picker", qs("audio inputs"))
-- Keyboard layout, on alt+space as it always was: each press switches straight
-- away and puts up no window at all. Holding alt used to raise the picker as a
-- HUD, which was a window in the way of a flip you do without looking; the
-- picker is on the bar module and in the launcher instead. The layout is
-- global: a per-app memory (kb-layout-per-app.py) restored each window's layout
-- on focus, and was removed for switching under you more than it helped.
bind("ALT + space", "Cycle keyboard layout", qs("keyboard cycle"))

-- Apps
bind(mainMod .. " + Backslash", "1Password quick access", sh("1password --quick-access"))

-- Move focus with mainMod + hjkl, swap with shift
local directions = { H = "left", J = "down", K = "up", L = "right" }
for key, dir in pairs(directions) do
    bind(mainMod .. " + " .. key, "Focus window " .. dir, hl.dsp.focus({ direction = dir }))
    bind(mainMod .. " + SHIFT + " .. key, "Swap window " .. dir, hl.dsp.window.swap({ direction = dir }))
end

-- Switch workspaces with mainMod + [0-9], move the window there with shift
for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, "Switch to workspace " .. i, hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key, "Move window to workspace " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Resize active window. code:59 and code:60 are the < and > keys.
bind(mainMod .. " + code:59", "Shrink window width", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
bind(mainMod .. " + code:60", "Grow window width", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
bind(mainMod .. " + SHIFT + code:59", "Shrink window height", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
bind(mainMod .. " + SHIFT + code:60", "Grow window height", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", "Move window with mouse", hl.dsp.window.drag(), { mouse = true })
bind(mainMod .. " + mouse:273", "Resize window with mouse", hl.dsp.window.resize(), { mouse = true })

bind(mainMod .. " + slash", "Toggle split direction", hl.dsp.layout("togglesplit"))

-- Every keybind on the system, searchable. The list is built from `hyprctl
-- binds -j` at open time, so it is the live bind table rather than a copy of
-- this file. super+? is super+shift+slash on this keyboard.
bind(mainMod .. " + SHIFT + slash", "Show all keybinds", qs("keybinds toggle"))

-- Toggle floating. Moved off super+O, which now opens the audio output picker.
bind(mainMod .. " + SHIFT + CTRL + F", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))

bind(mainMod .. " + F", "Maximize window", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind(mainMod .. " + SHIFT + F", "Fullscreen window", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

bind("ALT + Tab", "Cycle windows", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

bind(mainMod .. " + Escape", "Lock screen", sh("hyprlock"))

-- Lid switch. logind is configured to ignore the lid (install.sh writes the
-- drop-in), so the whole policy (lock, blank, suspend, or nothing at all) is
-- decided by the script, which needs to know about the external monitor and
-- the power adapter to answer. Locked so a lid closed on an already-locked
-- screen still suspends.
local lid = home .. "/.config/hypr/scripts/lid.sh"
bind("switch:on:Lid Switch", "Lid closed", sh(lid .. " close"), { locked = true })
bind("switch:off:Lid Switch", "Lid opened", sh(lid .. " open"), { locked = true })

-- Screenshots. The plain binds select: drag an area, or hover a window until it
-- lifts out of the dimmed screen and click to take that window alone.
-- screenshot.sh feeds slurp the window list to make the second half of that
-- work. SHIFT is the no-selection version, the focused monitor whole.
local scripts = home .. "/.config/scripts"
bind(mainMod .. " + S", "Screenshot region or window", sh(scripts .. "/screenshot.sh"))
bind(mainMod .. " + CTRL + S", "Screenshot region or window to clipboard", sh(scripts .. "/screenshot.sh --clipboard-only"))
bind(mainMod .. " + SHIFT + S", "Screenshot fullscreen", sh(scripts .. "/screenshot.sh --full"))
bind(mainMod .. " + SHIFT + CTRL + S", "Screenshot fullscreen to clipboard", sh(scripts .. "/screenshot.sh --full --clipboard-only"))

-- Text recognition. Drag an area and its text comes back on the clipboard
-- instead of an image: reading a code out of a screen share, or lifting an
-- error message out of a window that will not let it be selected. A plain
-- drag, without the click-a-window half of the screenshot binds; ocr.sh says
-- why. T for text rather than a fourth modifier on S: it is reached often
-- enough to deserve a key of its own, and the weather panel moved off shift+T
-- to make room.
bind(mainMod .. " + SHIFT + T", "Copy text from screen region", sh(scripts .. "/ocr.sh"))

-- Screen record. Same selection as the screenshot binds, and either bind
-- pressed again stops the recording that is running.
bind(mainMod .. " + R", "Screen record region or window", sh(scripts .. "/screen-record.sh"))
bind(mainMod .. " + SHIFT + R", "Screen record fullscreen", sh(scripts .. "/screen-record.sh --full"))

bind(mainMod .. " + P", "Color picker", sh("hyprpicker --autocopy --format=hex --lowercase-hex"))

-- Audio controls. Two orthogonal modifiers on the volume keys, and Hyprland
-- matches the modmask exactly, so every combination needs its own bind: CTRL
-- SHIFT is not covered by the CTRL and SHIFT binds firing together, and leaving
-- it out would make the fine step silently fall through to nothing. CTRL is the
-- fine step (1% instead of 5%), SHIFT is the audible confirmation; the four-way
-- spread below is the product of those two, not four unrelated binds.
local ding = " && paplay " .. home .. "/.config/sounds/volume-change.oga"
local function volume(mods, label, step)
    local up = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ " .. step .. "%+"
    local down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. step .. "%-"
    bind(mods .. "XF86AudioRaiseVolume", "Volume up" .. label, sh(up), { locked = true, repeating = true })
    bind(mods .. "SHIFT + XF86AudioRaiseVolume", "Volume up" .. label .. " with sound", sh(up .. ding), { locked = true, repeating = true })
    bind(mods .. "XF86AudioLowerVolume", "Volume down" .. label, sh(down), { locked = true, repeating = true })
    bind(mods .. "SHIFT + XF86AudioLowerVolume", "Volume down" .. label .. " with sound", sh(down .. ding), { locked = true, repeating = true })
end
volume("", "", 5)
volume("CTRL + ", " (fine)", 1)

-- AudioMute button toggles the mic (keyboard knob click)
bind("XF86AudioMute", "Toggle microphone mute", sh(home .. "/.config/sounds/scripts/toggle-mic.sh"))

bind("XF86MonBrightnessUp", "Brightness up", sh("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", "Brightness down", sh("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

bind("XF86AudioNext", "Next track", sh("playerctl next"), { locked = true })
bind("XF86AudioPause", "Play/pause", sh("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", "Play/pause", sh("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", "Previous track", sh("playerctl previous"), { locked = true })
-- Shift on the play key opens the now-playing panel instead of toggling. The
-- plain binds above still fire on their own: Hyprland matches the modmask
-- exactly, so holding shift is not also a bare play/pause. Both keys are
-- covered because keyboards disagree about which one the play key sends.
-- Deliberately not locked: the transport keys are worth having on the lock
-- screen, a panel is not.
bind("SHIFT + XF86AudioPlay", "Now playing panel", qs("media toggle"))
bind("SHIFT + XF86AudioPause", "Now playing panel", qs("media toggle"))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- The screenshot annotation editor, opened by clicking a screenshot notification
-- (quickshell/.config/quickshell/scripts/focus-sender.sh). It asks GTK for a
-- window the size of the image it was handed, which only means anything if it
-- floats: tiled, a 463x171 region grab is stretched across half a monitor and
-- every annotation drawn on it lands on a blur. Centred because it is a card
-- over the work it was taken from, not a window to arrange.
hl.window_rule({
    name = "tensaku-float",
    match = { class = "^(dev\\.tensaku\\.Tensaku)$" },
    float = true,
    center = true,
})
