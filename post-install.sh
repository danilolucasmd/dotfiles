#!/usr/bin/env bash

set -e

echo "==> Fixing GTK cedilla input..."

GTK2="/usr/lib/gtk-2.0/2.10.0/immodules.cache"
GTK3="/usr/lib/gtk-3.0/3.0.0/immodules.cache"

for file in "$GTK2" "$GTK3"; do
  if [ -f "$file" ]; then
    echo "Updating $file"
    sudo sed -i \
      's/"az:ca:co:fr:gv:oc:pt:sq:tr:wa"/"az:ca:co:fr:gv:oc:pt:sq:tr:wa:en"/' \
      "$file"
  else
    echo "Skipping $file (not found)"
  fi
done

echo "==> Updating Compose key mappings..."

COMPOSE="/usr/share/X11/locale/en_US.UTF-8/Compose"

if [ -f "$COMPOSE" ]; then
  echo "Backing up Compose file..."
  sudo cp "$COMPOSE" "${COMPOSE}.bak"

  echo "Applying cedilla fix..."
  sudo sed -i 's/ć/ç/g' "$COMPOSE"
  sudo sed -i 's/Ć/Ç/g' "$COMPOSE"
else
  echo "Compose file not found at $COMPOSE"
fi

echo "==> Done! Reboot your system to apply changes."
