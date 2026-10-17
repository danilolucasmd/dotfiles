#!/usr/bin/env bash
# A file has finished arriving from a KDE Connect device: say so.
#
# KDE Connect does not, on its own. A received file is reported as a KJob to
# Plasma's job tracker (org.kde.JobViewServer), which is what draws the
# progress-then-"finished" notification on a Plasma desktop; nothing here
# serves that interface, so on Hyprland a file lands in ~/Downloads in silence.
# Text is the one share it does announce, through an ordinary notification, and
# NotificationsState handles that one directly.
#
# NotificationsState watches the share plugin's `shareReceived` D-Bus signal and
# calls this once per finished file, with the device id from the signal's
# object path and the file:// URL it carried. The notification goes out over
# D-Bus like any other, so it comes back into the shell as an ordinary popup and
# lands in the history panel. Three hints make it more than that:
#
#   desktop-entry: the daemon's own, so this reads as KDE Connect's
#                  notification and not as something a script sent.
#   category: transfer.complete, the spec's name for exactly this.
#   x-kde-urls: the file, where KNotification itself puts the files a
#               notification is about. A plain string rather than the string
#               array KNotification sends, because notify-send cannot build
#               one; NotificationsState reads it either way.
#
# Clicking it opens the file (NotificationsState.shareTarget, open-shared.sh).

set -euo pipefail

device=${1:-}
url=${2:?file url}

name=$(busctl --user --json=short get-property org.kde.kdeconnect \
  "/modules/kdeconnect/devices/$device" org.kde.kdeconnect.device name 2>/dev/null |
  jq -r '.data // empty' || true)

file=${url##*/}
file=$(printf '%b' "${file//%/\\x}")
# The body is read as markup (the server advertises it), and a filename is
# free to contain an ampersand.
file=${file//&/&amp;}
file=${file//</&lt;}
file=${file//>/&gt;}

notify-send \
  --app-name="KDE Connect" \
  --hint=string:desktop-entry:org.kde.kdeconnect.daemon \
  --hint=string:category:transfer.complete \
  --hint="string:x-kde-urls:$url" \
  "File from ${name:-your device}" \
  "$file"
