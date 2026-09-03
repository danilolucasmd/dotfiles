# Working preferences

These are standing instructions across all projects.

## "Global memory" means this file

When the user asks to add something to "the global memory", "global claude memory", "claude's global memory", or any variation of that phrasing, they mean this file: `~/.claude/CLAUDE.md` (a symlink into the dotfiles repo at `claude/.claude/CLAUDE.md`). Edit it directly; do not write to the file-based memory directory or to a project's `CLAUDE.md`.

If they mean the project's memory or something else, they will say so explicitly. If it is not clear which memory is meant, ask. Ask even when an existing related entry in one store makes that store look like the obvious target: inferring silently skips the check, and a guess that happens to land right is still a guess.

Instructions about how to handle memory itself belong here, in this file, not in a project's memory store.

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

## PR descriptions: title and body in two separate code blocks

Always emit a PR description as two fenced code blocks, never one combined block: first a block containing only the title line, then a separate block containing the Markdown body. The user copies the title and the body into different fields.

Title format is `[TICKET-123] Title of the PR`, with the ticket ID taken from the branch name (branch `ddias/vend-2414-...` gives `[VEND-2414]`). No Conventional Commit type or scope prefix, even when a repository guide asks for one.

Use exactly this body template:

````md
<!-- Keep prose under 250 words; most pull requests need much less. -->

## Context

<!-- Why is this change needed? Keep only context that affects the review decision. -->

## What Changed

<!--
Use 1-4 reviewer-level bullets. Cover behavior, contracts, and tradeoffs;
do not list files.
-->

<!--
Add `## Call Stack / Flow` only for a non-obvious path across several components.
Show the entrypoint, decisions, and side effect in a 5-10 line text tree.
-->

## Validation

<!--
What behavior did you observe beyond CI? If none, say why.
Add concise media for visible UI changes.
-->

<!-- Optional footer, no heading: `Fix ENG-1234` and related links. -->
````

Rules for filling it in:

- Keep the HTML comments in the emitted body as ongoing guidance, unless the user asks for them stripped.
- Keep prose under 250 words total. The user wants brevity over exhaustive explanation.
- Under "What Changed", use 1 to 4 reviewer-level bullets covering behavior, contracts, and tradeoffs. Never list files.
- Add `## Call Stack / Flow` only when a runtime path crosses several components in a non-obvious way, as a short text tree going from entrypoint to decisions to side effect.
- Under "Validation", say what was observed beyond CI, or why nothing further was needed. Add concise media for visible UI changes.
- Do not invent sections beyond this template unless asked.

Hard-wrap rules for the body are in the section above.

## Comments: only for what the code cannot say

Keep comments short, and do not write one at all when the name already says it. A well-named variable, function, or type needs no restatement; `/** Vendor ID */` above `vendorId` is noise.

Comment only what the code cannot express: why a non-obvious choice was made, a constraint imposed from elsewhere in the system, or a decision that looks wrong until explained. One or two lines usually covers it. Reserve multi-paragraph doc blocks for genuinely subtle contracts, never for narrating an implementation a reader can see.

If a comment feels necessary because the name is unclear, rename instead.
