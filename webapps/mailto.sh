#!/usr/bin/env bash
#
# The mailto: handler: mailto.sh <mailto-link>. Opens Gmail's compose window,
# filled in from the link, in the Mail web app (a new window there if it is
# already open). generate.sh writes the desktop entry that registers this, and
# install.sh makes it the default for x-scheme-handler/mailto.
#
# The compose address is the one Gmail registers itself as a protocol handler
# with in a full browser: the whole link, encoded, as `url`, and Gmail parses
# the recipients, subject and body out of it.
set -euo pipefail

link=${1:-mailto:}
encoded=$(jq -rn --arg s "$link" '$s | @uri')
exec "$(dirname "$(realpath "$0")")/qutebrowser-app.sh" mail \
	"https://mail.google.com/mail/?extsrc=mailto&url=$encoded"
