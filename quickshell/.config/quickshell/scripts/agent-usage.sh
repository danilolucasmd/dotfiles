#!/bin/bash
# Quickshell module: coding-agent rate-limit usage, for every agent installed.
#
# This file is only the collector. Everything that knows what an agent is lives
# in agents/, one script per agent, and this runs each of them and concatenates
# what they say into `{"agents":[...]}` for AgentUsageState. Adding a second
# agent is therefore adding one file to agents/ and nothing else -- no case
# statement here to extend, no list to keep in step.
#
# An empty `agents` array means nothing is installed, and the bar module hides
# itself (same trick as recording.sh). An agent that is installed but has no
# reading yet still comes back, with available:false, because "Claude Code is
# here and silent" and "Claude Code is not here" are different answers and the
# panel says so differently.

dir="$(dirname "$(readlink -f "$0")")/agents"

for provider in "$dir"/*.sh; do
  [ -x "$provider" ] && "$provider" limits 2>/dev/null
done | jq -sc '{agents: .}'
