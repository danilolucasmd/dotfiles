#!/usr/bin/env bash
# Jump to the window that sent a notification, on whatever workspace it lives.
#
#   focus-sender.sh <desktop-entry> <app-name> <summary> <body> <has-default-action>
#
# Called from NotificationsState.activate(). Exit status is the answer to "did
# I find the right window?":
#
#   0  focused something; the caller does nothing further
#   1  found nothing worth focusing; the caller invokes the notification's own
#      default action instead, and lets the app raise itself
#
# That split exists because the app's default action is not always the better
# answer. Brave sets desktop-entry=brave-browser on every notification and its
# default action raises the *browser* window — but the notification for a
# WhatsApp message belongs to the web-app window, which Brave will never raise.
# The origin is the first line of the body ("web.whatsapp.com"), and the
# generated launchers give those windows classes built from the same host
# (brave-web.whatsapp.com__-Default), so matching on that beats both.
#
# Five passes, in order of how much the match can be trusted:
#
#   herdr  The body opens with the name of a herdr workspace. herdr multiplexes
#          every project into one terminal window, so nothing about that window
#          says which project a notification came from — and its title names
#          only the workspace currently on screen. Ask herdr instead: switch it
#          to the workspace that notified, and match the terminal on the label
#          it was showing before the switch.
#   host   The body names an origin and a window's class carries it. This is a
#          web app: nothing else can be that window.
#   class  desktop_entry, then its reverse-DNS leaf (org.telegram.desktop ->
#          telegram), then app_name, matched against window classes with
#          punctuation and case stripped so "KDE Connect" can meet
#          "kdeconnect". desktop_entry names the app's .desktop file, which
#          usually matches the class; app_name is a human label, so it ranks
#          below.
#   path   No window is the app, because the app was a script that wrote a file
#          and exited -- screenshot.sh's "Image saved in /home/.../shot.png".
#          What the notification is really pointing at is the file, so open it:
#          a screenshot in the tensaku annotation editor, anything else as the
#          folder around it with the file selected. Ranked under class so an app
#          that has a window still gets its window, and over title so a
#          screenshot does not go looking for a terminal that happens to say
#          "Pictures".
#   title  Nothing identified the app, and herdr did not claim it either — a
#          bare `notify-send` typed at a prompt, or a tool that shells out to
#          one without naming itself. All that is left is the text: score
#          windows by the words their titles share with the notification.
#
# A host that matches nothing is deliberately *not* fallen back on: the site is
# not open as a web app, so the app's own action (which will open the tab) is
# the better answer. That is the exit 1 case, unless there is no default action
# to fall back to, when a plain class match is better than nothing.
#
# This began as mako's on-button-left hook; the makoctl half is gone, since
# quickshell passes the fields directly rather than looking the notification
# back up by id. Focusing crosses workspaces on its own: `focuswindow` switches
# to the window's workspace on the way.

entry="$1"
app="$2"
summary="$3"
body="$4"
has_default="${5:-0}"

# herdr's toasts come through a bare `notify-send` with no desktop entry (see
# NotificationsState.displayName), and open with the workspace they are about:
# "sopezinho · 4 · 1 agent". Ask herdr whether that names a workspace it is
# actually running — which is both how this is told apart from any other
# anonymous notify-send, and how the workspace gets switched below.
#
# The label herdr is showing *now* is what the terminal's title carries
# ("danilo-pc: dotfiles"), and it is the only handle on that window: one ghostty
# holds every project, so the class says nothing about which one notified and
# the notification's own text only ever matches the project already on screen.
# Read it before switching, or the title is one we no longer know.
herdr_target=""
herdr_showing=""
if [ -z "$entry" ] && [ "$app" = "notify-send" ] && command -v herdr >/dev/null 2>&1; then
  want=$(printf '%s' "${body%%·*}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$want" ]; then
    read -r herdr_target herdr_showing < <(herdr workspace list 2>/dev/null | jq -r \
      --arg want "$want" '
      (.result.workspaces // [])
      | ((map(select(.label == $want)) | .[0].workspace_id) // "-") as $t
      | ((map(select(.focused)) | .[0].label) // "-") as $l
      | [$t, $l] | @tsv' 2>/dev/null)
    [ "$herdr_target" = "-" ] && herdr_target=""
    [ "$herdr_showing" = "-" ] && herdr_showing=""
    # A first field that names no workspace is not herdr talking. Leave it to
    # the passes below rather than guessing at a terminal.
    [ -z "$herdr_target" ] && herdr_showing=""
  fi
fi

# Brave and friends put the origin on the first line of the body. Only a bare
# hostname counts — anything with a space in it is prose.
host=$(printf '%s' "$body" | head -n1 | grep -oE '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}$' || true)

# The first absolute path in the text that is a file we can actually open.
# Existing is the whole test: it is what stops prose about a path that has since
# been moved -- or a lone "/" between two words -- from sending the file manager
# somewhere useless, and it costs nothing when there is no path at all. Markup
# is stripped first (screenshot.sh italicises the path) and a path with a space in it
# is not found, which is the price of finding one in a sentence.
path=""
while read -r cand; do
  cand="${cand#file://}"
  [ "${cand#\~/}" != "$cand" ] && cand="$HOME/${cand#\~/}"
  # A path at the end of a sentence keeps the full stop.
  [ -e "$cand" ] || cand="${cand%[.,;:)]}"
  if [ -e "$cand" ]; then
    path="$cand"
    break
  fi
done < <(printf '%s %s' "$body" "$summary" | sed 's/<[^>]*>/ /g' | tr ' \t\n' '\n\n\n' | grep -E '^(file://|~?/.)' || true)

read -r byherdr byhost byclass bytitle < <(hyprctl clients -j 2>/dev/null | jq -r \
  --arg entry "$entry" --arg app "$app" --arg host "$host" --arg text "$summary $body" \
  --arg showing "$herdr_showing" '
  def norm: (. // "") | ascii_downcase | gsub("[^a-z0-9]"; "");
  def leaf: (. // "") | sub("\\.desktop$"; "") | split(".") | last // "";
  # Words worth matching a title on. Short ones ("the", "1", "of") match
  # everything and mean nothing.
  def words: (. // "") | ascii_downcase | gsub("[^a-z0-9]+"; " ") | split(" ") | map(select(length >= 4));

  ($entry | norm) as $e
  | ($entry | leaf | norm) as $eleaf
  | ($app | norm) as $a
  | ($host | norm) as $h
  | ($text | words) as $tokens
  | [ .[]
      | { addr: .address,
          # focusHistoryID: 0 is the focused window, so lower means more
          # recently used -- the best tie-breaker when an app has several
          # windows open.
          hist: (.focusHistoryID // 9999),
          cls: (.class | norm),
          icls: (.initialClass | norm),
          raw: (.title // "" | ascii_downcase),
          title: (.title | words) } ]
  | map(. + {
      cscore: (
        if    $e     != "" and (.cls == $e     or .icls == $e)     then 5
        elif  $eleaf != "" and (.cls == $eleaf or .icls == $eleaf) then 4
        elif  $a     != "" and (.cls == $a     or .icls == $a)     then 3
        elif  $e     != "" and (.cls | startswith($e))             then 2
        elif  $a     != "" and (.cls | contains($a))               then 1
        else 0 end),
      # Longer shared words say more than more of them: "dotfiles" identifies a
      # window, "with" does not.
      tscore: ([ .title[] | select(. as $t | $tokens | index($t)) ] | map(length) | add // 0)
    })
  | (map(select($showing != "" and (.raw | contains($showing | ascii_downcase)))) | sort_by(.hist) | .[0].addr) as $byherdr
  | (map(select($h != "" and (.cls | contains($h)))) | sort_by(.hist) | .[0].addr) as $byhost
  | (map(select(.cscore > 0)) | sort_by(-.cscore, .hist) | .[0].addr) as $byclass
  | (map(select(.tscore > 0)) | sort_by(-.tscore, .hist) | .[0].addr) as $bytitle
  | [ ($byherdr // "-"), ($byhost // "-"), ($byclass // "-"), ($bytitle // "-") ]
  | @tsv')

[ "$byherdr" = "-" ] && byherdr=""
[ "$byhost" = "-" ] && byhost=""
[ "$byclass" = "-" ] && byclass=""
[ "$bytitle" = "-" ] && bytitle=""

# herdr first: it is the one pass that identified the sender outright rather
# than inferring it from a window. Switching the workspace is worth doing even
# if the terminal cannot be found afterwards -- the notification has been dealt
# with either way -- so it happens before the window match is tested.
if [ -n "$herdr_target" ]; then
  herdr workspace focus "$herdr_target" >/dev/null 2>&1
  if [ -n "$byherdr" ]; then
    hyprctl dispatch focuswindow "address:$byherdr" >/dev/null
    exit 0
  fi
fi

addr=""
if [ -n "$byhost" ]; then
  addr="$byhost"
elif [ -n "$byclass" ]; then
  # A host that matched nothing is deliberately not fallen back on here; see
  # above.
  [ -z "$host" ] && addr="$byclass"
elif [ -n "$path" ]; then
  # A screenshot is the one file worth more than the folder around it.
  # screenshot.sh sends `-a "Screenshot"` and names the PNG it just wrote, and
  # what that notification is really offering is the chance to draw on the
  # image -- an arrow at the thing being pointed out, and Enter to put the
  # edited version back on the clipboard over the raw one screenshot.sh already
  # copied there. tensaku is that editor; see tensaku/.config/tensaku/config.toml.
  #
  # Keyed on the app name rather than on the file being a .png, so
  # screen-record.sh's "Recording saved" -- and any other tool that happens to
  # name an image -- still gets the file manager below.
  if [ "$app" = "Screenshot" ] && [ -f "$path" ]; then
    setsid -f tensaku --filename "$path" >/dev/null 2>&1
    exit 0
  fi

  # Nothing identified the app, but it named a file. Nautilus is what this
  # system opens a directory with; -s opens the folder *around* a file with it
  # selected, which is not what a path that is already a folder wants. Detached,
  # because opening a folder is not something to wait on.
  if [ -d "$path" ]; then
    setsid -f nautilus "$path" >/dev/null 2>&1
  else
    setsid -f nautilus -s "$path" >/dev/null 2>&1
  fi
  exit 0
else
  # A title match only gets a say when nothing identified the app at all.
  addr="$bytitle"
fi

# Nothing to fall back to, so a browser window is better than no window.
[ -z "$addr" ] && [ "$has_default" != "1" ] && addr="$byclass"
[ -z "$addr" ] && exit 1

hyprctl dispatch focuswindow "address:$addr" >/dev/null
exit 0
