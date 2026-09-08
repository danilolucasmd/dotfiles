#!/usr/bin/env bash
# One reminder, come due: the sound, the notification, and the snooze the user
# picked handed back to the shell.
#
# This is a script rather than a few lines of QML because the whole thing is a
# blocking wait. `notify-send -A` implies --wait: it stays alive for as long as
# the notification is on screen and prints the chosen action's name when it goes
# away. A reminder popup is sticky (see the `reminder` category in
# NotificationsState.popupTimeout), so that can be hours -- and several of them
# can be waiting at once, which in QML would mean a Process object per live
# notification, created and destroyed by hand.
#
# Instead this is fired and forgotten by Quickshell.execDetached and comes back
# in through the front door: `qs ipc call reminder snooze`, the same IPC any
# keybind uses. Nothing has to be kept alive on the QML side, and a shell
# reloaded while a reminder is on screen still hears the snooze, because `qs
# ipc` finds whatever instance is running at the moment the button is pressed.
#
# The one thing that does not survive is a shell *reload* while a reminder is on
# screen: `keepOnReload: false` drops every live popup, and this notify-send goes
# on waiting for an action nobody can press any more. The reminder itself is not
# lost -- it is in the history panel like any other notification -- but the
# snooze buttons go with the popup, and the stray process sits there until it is
# killed. Not worth engineering around: the alternative is a timeout, and a
# reminder that expires on its own is the thing this feature exists to avoid.
#
# The notification goes out over D-Bus like any other, so quickshell -- which is
# the notification daemon -- receives its own reminder as an ordinary
# notification and it lands in the history panel with everything else. That is
# the whole reason this uses notify-send at all rather than some private path
# into the shell.

set -euo pipefail

message=${1:-}

# One chime, from sound-theme-freedesktop (install.sh pulls it in for this).
# Backgrounded because notify-send below blocks until the notification is dealt
# with, and the sound has to play now.
#
# complete.oga rather than the theme's alarm-clock-elapsed.oga, which is the
# obvious name and wrong: it is six seconds of a clock ringing over and over,
# and the popup it announces is already sticky -- the sound only has to say
# "look up", and everything after the first ring is the notification nagging
# about itself. bell.oga is the other single-shot candidate and is a 0.14s tick,
# quiet enough to miss.
sound=/usr/share/sounds/freedesktop/stereo/complete.oga
if [[ -r $sound ]]; then
  paplay "$sound" &
fi

# The action names are the minute counts themselves, so what comes back on
# stdout is already the argument for the snooze -- the labels are only what is
# drawn on the buttons. Kept short on purpose: the popup lays its buttons out in
# a single non-wrapping row 336px wide, and "15 minutes" five times over would
# run off the end of it.
#
# --hint=string:category:reminder is what makes the popup stay up until it is
# dealt with; NotificationsState reads the category and gives this one no
# timeout. Urgency is left at normal -- a reminder is not an emergency, and
# critical is the colour reserved for things that are.
#
# The summary is deliberately empty and the message goes in the body. The popup
# draws the app name -- "Reminder" -- as its first line already, so a summary of
# "Reminder" said it twice; and a summary is one elided line where a body wraps
# to four, which is the difference between reading "call the landlord about the
# boiler" and reading "call the landlord abo…". Both panels already handle a
# notification with nothing but a body: see `title` in NotificationsPanel.qml.
#
# `--` before the text: a message that starts with a dash is a message, not an
# option.
action=$(notify-send \
  --app-name=Reminder \
  --hint=string:category:reminder \
  --action=5=5m \
  --action=15=15m \
  --action=30=30m \
  --action=60=1h \
  --action=180=3h \
  -- "" "$message")

# Empty when the notification was dismissed or clicked away rather than
# snoozed, which is the normal case: the reminder has done its job and there is
# nothing left to schedule.
if [[ -n $action ]]; then
  qs ipc call reminder snooze "$message" "$action"
fi
