#!/bin/bash

# Lid and idle power policy, all in one place.
#
# logind is told to ignore the lid entirely (install.sh writes the drop-in), so
# nothing here races with a second decision made behind Hyprland's back:
#
#   * External monitor connected -> closing the lid does nothing at all. The
#                                   desktop lives on the other screen and the
#                                   machine is still in use, plugged in or not.
#   * No external monitor        -> closing the lid locks. On battery it then
#                                   suspends; on the adapter it stays awake, so
#                                   a build or a download finishes with the lid
#                                   shut.
#
# `idle` is that same battery-only suspend, called by hypridle once the screen
# has been locked and blanked for a while.

on_ac() {
  # "Connected to the power adapter" is the mains supply reporting online --
  # AC on this ThinkPad, but the name is not fixed, so ask by type. The USB-C
  # entries are deliberately not counted: they describe the port, and this
  # laptop's PD brick already shows up as mains.
  local supply
  for supply in /sys/class/power_supply/*; do
    [[ $(cat "$supply/type" 2>/dev/null) == Mains ]] || continue
    [[ $(cat "$supply/online" 2>/dev/null) == 1 ]] && return 0
  done
  return 1
}

external_monitor() {
  # `hyprctl monitors` lists only enabled outputs, which is the question being
  # asked: a monitor Hyprland is not drawing on is not one you are using. The
  # -j form is no help here -- its nested workspace objects carry "name" keys
  # too -- so the plain listing gets parsed instead.
  hyprctl monitors | awk '/^Monitor /{print $2}' | grep -qvE '^(eDP|LVDS|DSI)-'
}

case "$1" in
close)
  external_monitor && exit 0

  if on_ac; then
    # Backgrounded: hyprlock runs until it is unlocked, and this script must
    # not stay alive that long.
    hyprlock &
    hyprctl dispatch dpms off
  else
    # No explicit lock. hypridle holds a delay inhibitor and runs its
    # before_sleep_cmd to completion before the system goes down, so letting it
    # do the locking is the one ordering that cannot suspend an unlocked
    # screen.
    systemctl suspend
  fi
  ;;
open)
  # The panel was blanked either here or by hypridle; only one of them tracks
  # that, so turn it back on unconditionally.
  hyprctl dispatch dpms on
  ;;
idle)
  on_ac || systemctl suspend
  ;;
*)
  echo "usage: ${0##*/} {close|open|idle}" >&2
  exit 1
  ;;
esac
