#!/usr/bin/env bash
# Waybar module: show when Bluetooth audio devices (earbuds/headphones) are connected.
#
# Event-driven: emits the current state on startup, then watches BlueZ's D-Bus
# Connected property changes and re-emits instantly. One JSON object per line,
# consumed by a custom/* module with "return-type": "json".

# Click handler: toggle connection for the first known audio device.
if [ "$1" = "toggle" ]; then
  while read -r _ mac _; do
    [ -z "$mac" ] && continue
    icon=$(bluetoothctl info "$mac" 2>/dev/null | sed -n 's/^\s*Icon: //p')
    case "$icon" in
      audio-*|*headphone*|*headset*|*earbud*) ;;
      *) continue ;;
    esac
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      bluetoothctl disconnect "$mac"
    else
      bluetoothctl connect "$mac"
    fi
    exit 0
  done < <(bluetoothctl devices 2>/dev/null)
  exit 0
fi

emit() {
  # Collect all currently-connected devices via bluetoothctl.
  local connected="" name
  while read -r _ mac _; do
    [ -z "$mac" ] && continue
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      name=$(bluetoothctl info "$mac" 2>/dev/null | sed -n 's/^\s*Name: //p')
      connected="${connected:+$connected, }${name:-$mac}"
    fi
  done < <(bluetoothctl devices 2>/dev/null)

  if [ -n "$connected" ]; then
    printf '{"text":"󰂰","class":"connected","tooltip":"Connected: %s"}\n' "$connected"
  else
    printf '{"text":"󰂱","class":"disconnected","tooltip":"No Bluetooth device connected"}\n'
  fi
}

emit

# Re-emit on every BlueZ property change (connect/disconnect events).
dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" 2>/dev/null |
while read -r line; do
  case "$line" in
    *Connected*) emit ;;
  esac
done
