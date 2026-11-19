#!/usr/bin/env bash

set -e

# The Compose half of the cedilla fix lives in ~/.XCompose (the xcompose stow
# package) now. This is only GTK's immodules.cache, which gtk3 regenerates on
# upgrade, so it has to run again after one.
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

echo "==> Done! Restart the affected GTK apps to apply changes."
