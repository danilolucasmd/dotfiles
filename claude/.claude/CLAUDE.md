# Working preferences

These are standing instructions across all projects.

## "Global memory" means this file

When the user asks to add something to "the global memory", "global claude memory", "claude's global memory", or any variation of that phrasing, they mean this file: `~/.claude/CLAUDE.md` (a symlink into the dotfiles repo at `claude/.claude/CLAUDE.md`). Edit it directly; do not write to the file-based memory directory or to a project's `CLAUDE.md`.

If they mean the project's memory or something else, they will say so explicitly. If it is not clear which memory is meant, ask.

## Git: never operate unless explicitly asked

Never run ANY git operation on the user's behalf unless they explicitly ask for it in that request. This includes `git add`/staging, `git commit`, `git push`, `git restore`, `git checkout`, branch creation/switching, etc. Read-only inspection (`git status`, `git diff`, `git log`) is fine.

Do all the work — edits, lint, format, tests, verification, conflict resolution — and then STOP, leaving the working tree exactly as the tools left it for the user to review. Do NOT `git add` the files you changed.

Showing PR review comments, describing a fix, resolving merge conflicts, or an active PR does NOT constitute permission to run git. Wait for an explicit instruction like "commit this", "stage it", "push", or "/submit-pr".

Even "fixing" a mistaken git operation (e.g. unstaging what was wrongly staged) is itself an unrequested git operation — don't do it; tell the user and let them decide. If a merge/rebase left files unmerged, resolve the file contents but do NOT `git add` to clear the unmerged state unless asked — describe the state instead.

## "Comments" means Hunk review comments

When the user says they "added comments", "made comments", "left comments", or "commented" (and asks to fix/address them), they almost always mean inline review comments in a **Hunk diff session** — not code comments, PR comments, or anything else.

The user reviews diffs in Hunk (interactive terminal diff viewer) and leaves inline notes there. On such a request, use the Hunk CLI to find and read them (do NOT run `hunk diff`/`hunk show` — those are the user's TUI). Typical flow:
- `hunk session list --json` → find the live session id matching the repo/work you're on (there may be several sessions across repos; pick the one whose repo/title matches).
- `hunk session comment list <session-id> --type user --json` → read the user-authored notes (filePath + newRange line + body).
- Make the fixes, then optionally reply with `hunk session comment add <session-id> --file <path> --new-line <n> --summary "..." --author agent --focus` after `hunk session reload <session-id> -- diff`.

See the hunk-review skill (`hunk skill path`) for the full command reference. Never perform git operations while doing this — see "Git: never operate unless explicitly asked" above.

## Dashes: never use them as sentence punctuation

Do not use an em dash, en dash, or spaced hyphen to interrupt a sentence. It reads as obviously generated text, and the user strips it out of anything they share, so producing it only creates cleanup work.

Rewrite the sentence rather than swapping the dash for a comma. Use a colon when the second half explains the first, parentheses for a genuine aside, a semicolon for two linked clauses, or split it into two sentences. Choose whichever reads best.

This applies to everything generated, not just prose documents: PR descriptions, commit messages, Slack drafts, content destined for Google Docs, code comments, and the text inside diagram nodes and chart labels. It applies to replies in the conversation too.

These are different things and should be kept:
- Hyphenated compound words (`pre-fill`, `read-only`, `per-rail`, `delete-then-add`)
- Middots or bullets separating items in a label or metadata line
- Ranges, though prefer words: write `Aug 18 to 20` rather than `Aug 18-20`

After generating a document, grep for `—`, `–`, and ` - ` before handing it over. Missed instances hide in HTML attributes, headings, alt text, and generated code comments.

## PR descriptions: no hard wraps

When writing PR descriptions (or other markdown for the user to paste), do not hard-wrap paragraph text at a fixed column. Keep each paragraph on a single line and let it soft-wrap in the editor.

The user reflows/removes line breaks from generated markdown before using it, so pre-wrapped text is extra work to undo. Produce PR description bodies with one line per paragraph and per list item; do not insert manual newlines mid-paragraph even if lines get long.
