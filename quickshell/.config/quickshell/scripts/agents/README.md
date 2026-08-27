# Agent providers

One script per coding agent. `agent-usage.sh` and `agent-tokens.sh` run every
executable in this directory and merge what comes back, so an agent is added by
dropping a file here — there is no registry to edit, in the scripts or in QML,
and the panel grows a tab for it on the next tick.

A provider answers two verbs and prints one line of JSON per verb.

## `limits`

Cheap. Polled on a timer all day, so it must not touch the network on every
call.

```json
{
  "id": "claude-code",
  "name": "Claude Code",
  "icon": "󰚩",
  "avatar": "claude.svg",
  "plan": "PRO",
  "available": true,
  "source": "statusLine feed",
  "ageSeconds": 43,
  "stale": false,
  "limits": [
    { "label": "Session", "span": "5h", "pct": 67, "pace": 29, "resetsIn": "3h 31m" }
  ]
}
```

`id` must match the filename without `.sh` — that is the key `agent-tokens.sh`
files the history under. `icon` is a Nerd Font glyph and is what the bar module
draws beside the percentage. `avatar` is optional and names a file in
`../../assets/` — the vendor's own mark, which the panel header draws in place
of the glyph. A filename rather than a path, so a provider does not have to know
where the shell keeps its assets; leave it out and the header falls back to
`icon`, which is the right answer for an agent with no logo worth 24 pixels.

`pace` is how much of the window has already elapsed, as a percentage, which is
what the panel marks on the meter: past it is spending faster than the window
refills. A window with no reset time to anchor against reports `-1` and gets no
mark. `resetsIn` is preformatted here rather than in QML because the panel
redraws on a binding, not on a tick, and a countdown computed at paint time
would freeze at whatever it said when the reading landed.

Two kinds of silence, and they mean different things:

- **No output at all** — this agent is not installed on this machine. No tab.
- **`available: false`** — installed, but nothing has been read yet. The panel
  keeps the tab and explains itself. `limits`, `source`, `ageSeconds` and
  `stale` may be omitted in this case.

## `tokens`

Expensive. Only run while the panel is open, so a transcript parse or a
directory walk is fine here.

```json
{
  "byDay": [ { "label": "Mon", "tokens": 4339533 } ],
  "byModel": [ { "label": "Opus 5", "tokens": 423386972 } ],
  "total": 423386972
}
```

`byDay` is seven entries, oldest first, the last labelled `Today`; the panel
draws them in the order given and bolds the last. `byModel` is sorted
descending. Both cover the same seven days, so the two sections add up.

Printing nothing is allowed and means the agent cannot report this — the panel
drops both sections and keeps the limits.
