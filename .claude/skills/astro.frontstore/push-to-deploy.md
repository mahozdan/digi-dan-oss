# Push to Deploy

When the user says "push", execute the full release flow:

## Steps

1. **Commit pending changes**
   - Stage all modified/new files relevant to the work done
   - Commit with a descriptive message (use `--no-verify` to skip the interactive pre-commit hook)

2. **Bump version**
   - Read current `version` from `package.json`
   - Patch-bump it (e.g. `0.1.5` → `0.1.6`)
   - Write the updated `package.json`
   - Stage and commit: `chore: bump version to v0.1.6` (use `--no-verify`)

3. **Push**
   - `git push origin main`
   - The pre-push hook compares `package.json` version against `.last-pushed-version` — the bump in step 2 ensures it passes

## Notes

- The interactive `npm run bump` script and pre-commit hook require TTY input, which doesn't work in non-interactive Bash. Always bump manually by editing `package.json`.
- If there are no pending changes (only a version bump needed), skip step 1.
- Always use `--no-verify` on commits to bypass the interactive pre-commit hook.
