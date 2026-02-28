# commit

## Format
```
{type}({scope}): {subject}

{body}

{footer}
```

## Types
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change (no feat/fix)
- `test`: Adding tests
- `docs`: Documentation
- `chore`: Maintenance
- `perf`: Performance
- `style`: Formatting
- `ci`: CI/CD changes

## Rules
- Subject: imperative, lowercase, no period, ≤50 chars
- Scope: component/module affected
- Body: what & why, not how. Wrap 72 chars
- Footer: `Closes #123`, `BREAKING CHANGE:`
- One logical change per commit
- Run tests before commit

## Sequence
1. `git status` - verify changes
2. `git diff` - review changes
3. `git add -p` - stage intentionally
4. `git commit` - with message
5. Verify: `git log -1`

## Examples
```
feat(auth): add JWT refresh token support
fix(api): handle null response in user fetch
refactor(utils): extract date formatting to helper
```
