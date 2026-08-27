#!/bin/bash
# Quickshell module: what each coding agent has actually spent, by day and by
# model. The same collector shape as agent-usage.sh, over the same agents/
# directory, but keyed by agent id rather than a list -- the panel already knows
# which agent it is drawing and wants that one's history, not all of them.
#
# Split from agent-usage.sh because the two run at completely different
# cadences. Limits are polled on a timer all day; this parses transcripts, costs
# over a second on a cold cache, and is worth nothing while the panel is shut --
# so AgentUsageState only starts its timer when the panel opens.

dir="$(dirname "$(readlink -f "$0")")/agents"

for provider in "$dir"/*.sh; do
  [ -x "$provider" ] || continue
  id=$(basename "$provider" .sh)
  "$provider" tokens 2>/dev/null | jq -c --arg id "$id" '{($id): .}'
done | jq -sc 'add // {} | {agents: .}'
