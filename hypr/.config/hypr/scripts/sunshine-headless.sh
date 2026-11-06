#!/bin/bash

# Keeps a Moonlight stream alive while the KVM is switched to the other machine.
#
# Sunshine captures one Wayland output, and the monitor here sits behind a
# physical KVM: switching away pulls HDMI-A-1's hotplug line, Hyprland destroys
# the output, and the stream freezes on its last frame while audio carries on.
# So for the length of a stream the desktop is moved onto a headless output
# that no cable can unplug, and every real connector mirrors it. A mirror is
# hidden from wl_output, which makes SUNSHINE the only monitor Sunshine can see
# and spares sunshine.conf an `output_name` index that would shift with
# hotplug order.
#
# Run by Sunshine's global_prep_cmd (install.sh writes it): `start` before
# capture begins, `stop` when the session ends. Only during a stream, because
# a mirror costs the physical monitor its own mode and VRR, which is not a
# trade worth making on an ordinary day at the desk.
#
# 1920x1080@60 is the most the Switch client asks for.

set -euo pipefail

OUTPUT=SUNSHINE

# Monitor changes land a few frames after hyprctl returns.
wait_for() {
  local i
  for i in {1..20}; do
    hyprctl monitors all -j | jq -e --arg m "$1" \
      ".[] | select(.name == \$m) | $2" >/dev/null && return 0
    sleep 0.1
  done
}

start() {
  hyprctl monitors all -j | grep -q "\"name\": \"$OUTPUT\"" ||
    hyprctl output create headless "$OUTPUT" >/dev/null
  hyprctl keyword monitor "$OUTPUT,1920x1080@60,0x0,1" >/dev/null

  # Every connector, connected or not: a rule by name waits for its output, so
  # the monitor coming back from the other machine mid-stream rejoins as a
  # mirror instead of pulling the workspaces back onto itself.
  local connector
  for connector in /sys/class/drm/card*-*; do
    [[ -e $connector/status ]] || continue
    hyprctl keyword monitor "${connector##*/card[0-9]-},preferred,auto,1,mirror,$OUTPUT" >/dev/null
  done
}

stop() {
  hyprctl monitors all -j | grep -q "\"name\": \"$OUTPUT\"" || return 0

  # With the KVM still on the other machine there is nowhere to hand the
  # workspaces to, so the headless output and the mirror rules stay: the
  # monitor comes back as a mirror and the next stream's stop finishes the job.
  local target
  target=$(hyprctl monitors all -j | jq -r --arg o "$OUTPUT" \
    '[.[] | select(.name != $o)][0].name // empty')
  [[ -n $target ]] || return 0

  # The mirror rules were runtime keywords, so a reload is what puts the
  # monitor rules in hyprland.conf back. It lands a few frames later, and a
  # workspace moved onto a monitor that is still a mirror goes nowhere.
  hyprctl reload >/dev/null
  wait_for "$target" '.mirrorOf == "none"'

  # Workspaces have to be walked off by hand first: removing an output that
  # still holds them leaves them on a monitor that no longer exists, windows
  # and all, unreachable from every keybind.
  local active ws
  active=$(hyprctl monitors -j | jq -r --arg o "$OUTPUT" \
    '.[] | select(.name == $o) | .activeWorkspace.id')
  for ws in $(hyprctl workspaces -j | jq -r --arg o "$OUTPUT" \
    '.[] | select(.monitor == $o) | .id'); do
    hyprctl dispatch moveworkspacetomonitor "$ws" "$target" >/dev/null
  done
  hyprctl output remove "$OUTPUT" >/dev/null
  [[ -n $active ]] && hyprctl dispatch workspace "$active" >/dev/null

  # Some of the time Hyprland 0.56 advertises no wl_output for the unmirrored
  # monitor at all, not even to a fresh client: hyprpaper starts with "Found 0
  # output(s)", leaves Hyprland's default wallpaper up and ignores every
  # `hyprctl hyprpaper wallpaper` from the picker. grim is the cheapest probe
  # for the global. Disabling and re-enabling the monitor recreates it, but
  # only once SUNSHINE is gone: tried before the workspaces were walked off,
  # it was measured not to help. Hyprland parks the workspaces on its FALLBACK
  # output for the moment the monitor is off and hands them back after.
  if ! grim -o "$target" - >/dev/null 2>&1; then
    hyprctl keyword monitor "$target,disable" >/dev/null
    wait_for "$target" '.disabled'
    hyprctl reload >/dev/null
    wait_for "$target" '(.disabled | not) and .mirrorOf == "none"'
    [[ -n $active ]] && hyprctl dispatch workspace "$active" >/dev/null
  fi

  # Even when the global is there, Hyprland never re-advertises it to the
  # clients that were already connected: the monitor lights up, but hyprpaper
  # leaves it on Hyprland's default wallpaper and quickshell sees no outputs,
  # so the bar is gone. A fresh client does see it, so the two layer-shell
  # clients are restarted. Through
  # Hyprland's exec rather than from here, because the display panel runs this
  # script as a child of quickshell, and the restart must outlive the qs it
  # kills.
  hyprctl dispatch exec 'pkill -x hyprpaper; pkill -x qs; while pgrep -x hyprpaper || pgrep -x qs; do sleep 0.1; done >/dev/null; hyprpaper & qs &' >/dev/null
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  *)
    echo "usage: ${0##*/} start|stop" >&2
    exit 2
    ;;
esac
