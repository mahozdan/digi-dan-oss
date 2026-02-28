# suggest-a-commit-message

Suggest a commit message for the currently staged changes.

## Checklist

1. **Run `git status -u`** — understand what is staged vs unstaged
2. **Run `git diff --cached --stat`** — get a summary of staged files and change volume
3. **Run `git diff --cached`** — read the full staged diff to understand every change
4. **Run `git log --oneline -5`** — read recent commit messages to match the repo's voice and style
5. **Draft the message** — apply the rules below

## Drafting Rules

- **Match the repo style.** Mirror the tone, casing, and structure of recent commits (e.g. if the repo uses `Added X, fixed Y` don't switch to conventional commits).
- **Lead with the biggest change.** If the diff touches multiple features, name the most significant one first.
- **List secondary changes after a comma.** Keep it one line when possible; overflow into a parenthetical for minor items.
- **Use action verbs that match the change type:**
  - new code → "Added"
  - enhancement → "Updated" / "Improved"
  - bug → "Fixed"
  - removal → "Removed"
  - reorder/restructure → "Moved" / "Reordered"
- **Be specific about what was fixed, not just that something was fixed.** e.g. "fixed --no-git default" not "fixed bug".
- **Keep it under ~120 chars** for the subject line. If it truly can't fit, use a body.

## Output

Return only the suggested message as a fenced code block so the user can copy it.
