# Working preferences

These are standing instructions across all projects.

## Always respond in English

Talk to the user in English, always, in every project. This holds even when the
codebase, its comments, its commit history, the issue tracker, or the user's own
message are in another language -- Portuguese included. Read and work in
whatever language the project uses, but write back in English.

Only the prose addressed to the user is covered. Code, comments, commit
messages, and other artifacts keep the language of the thing they belong to.

## Git: never operate unless explicitly asked

Never run ANY git operation on the user's behalf unless they explicitly ask for it in that request. This includes `git add`/staging, `git commit`, `git push`, `git restore`, `git checkout`, branch creation/switching, etc. Read-only inspection (`git status`, `git diff`, `git log`) is fine.

Do all the work — edits, lint, format, tests, verification, conflict resolution — and then STOP, leaving the working tree exactly as the tools left it for the user to review. Do NOT `git add` the files you changed.

Showing PR review comments, describing a fix, resolving merge conflicts, or an active PR does NOT constitute permission to run git. Wait for an explicit instruction like "commit this", "stage it", "push", or "/submit-pr".

Even "fixing" a mistaken git operation (e.g. unstaging what was wrongly staged) is itself an unrequested git operation — don't do it; tell the user and let them decide. If a merge/rebase left files unmerged, resolve the file contents but do NOT `git add` to clear the unmerged state unless asked — describe the state instead.

## Git: commits always in the user's name

When the user authorizes a commit, it must be entirely in their name — author, committer, and attribution. Never append `Co-Authored-By: Claude ...` or `Claude-Session: ...` trailers to a commit message, and never set an author/committer other than the user. This overrides the default Claude Code instructions that ask for those trailers.

The user saw a pushed commit render on GitHub as "danilolucasmd and claude committed" and does not want Claude appearing as a co-author on their repositories at all. Authorizing a commit is permission to commit *as them*, not to add attribution.

Applies to every repo and every commit, including amends and rebases. Permission to commit still has to be asked for separately each time — see "Git: never operate unless explicitly asked" above.

## "Comments" means Hunk review comments

When the user says they "added comments", "made comments", "left comments", or "commented" (and asks to fix/address them), they almost always mean inline review comments in a **Hunk diff session** — not code comments, PR comments, or anything else.

The user reviews diffs in Hunk (interactive terminal diff viewer) and leaves inline notes there. On such a request, use the Hunk CLI to find and read them (do NOT run `hunk diff`/`hunk show` — those are the user's TUI). Typical flow:
- `hunk session list --json` → find the live session id matching the repo/work you're on (there may be several sessions across repos; pick the one whose repo/title matches).
- `hunk session comment list <session-id> --type user --json` → read the user-authored notes (filePath + newRange line + body).
- Make the fixes, then optionally reply with `hunk session comment add <session-id> --file <path> --new-line <n> --summary "..." --author agent --focus` after `hunk session reload <session-id> -- diff`.

See the hunk-review skill (`hunk skill path`) for the full command reference. Never perform git operations while doing this — see "Git: never operate unless explicitly asked" above.

## PR descriptions: no hard wraps

When writing PR descriptions (or other markdown for the user to paste), do not hard-wrap paragraph text at a fixed column. Keep each paragraph on a single line and let it soft-wrap in the editor.

The user reflows/removes line breaks from generated markdown before using it, so pre-wrapped text is extra work to undo. Produce PR description bodies with one line per paragraph and per list item; do not insert manual newlines mid-paragraph even if lines get long.

## "Global memory" means this file

When the user asks to add, save, or remember something in "claude's global memory", "global claude memory", "your global memory", or any variation of that phrasing, they mean **`~/.claude/CLAUDE.md`** — this file. Write it here, not to the auto-memory directory (`~/.claude/projects/*/memory/`) and not to a project's `CLAUDE.md`.

The user will say explicitly when something belongs in a project's memory instead. If a request is genuinely ambiguous about which memory is meant, ask rather than guessing.
