# pr

## Title Format
```
{type}({scope}): {description} [TICKET-123]
```

## Description Template
```markdown
## Summary
{What does this PR do? One paragraph max}

## Changes
- {Change 1}
- {Change 2}

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing done
- [ ] Edge cases covered

## Screenshots
{If UI changes}

## Notes
{Anything reviewer should know}
```

## Checklist Before Submit
- [ ] Self-reviewed diff
- [ ] Tests pass locally
- [ ] No console.log debris
- [ ] No unrelated changes
- [ ] Docs updated if needed
- [ ] Ticket linked
- [ ] Reasonable size (<400 lines)

## Size Guidelines
| Lines | Verdict |
|---|---|
| <100 | ✅ Ideal |
| 100-400 | ⚠️ Acceptable |
| >400 | ❌ Split PR |

## Commands
```bash
# Create PR
gh pr create --title "{title}" --body "{body}"

# List PRs
gh pr list

# Check status
gh pr checks

# Merge
gh pr merge --squash
```

## Rules
- One logical change per PR
- Draft PR for WIP/feedback
- Respond to all comments
- Squash commits on merge
- Delete branch after merge
