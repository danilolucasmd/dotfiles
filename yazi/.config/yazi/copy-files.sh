#!/usr/bin/env bash
# Put files on the system clipboard as a text/uri-list, the way a file manager
# copies them, so Ctrl+V in a browser (WhatsApp, Gmail) attaches the files
# themselves. Bound to y in keymap.toml, alongside yazi's own yank.
python3 -c '
import sys, pathlib
sys.stdout.write("".join(pathlib.Path(p).resolve().as_uri() + "\r\n" for p in sys.argv[1:]))
' "$@" | wl-copy --type text/uri-list
