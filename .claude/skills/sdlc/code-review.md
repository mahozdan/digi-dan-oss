# review

## Review Order
1. Purpose: Does code solve stated problem?
2. Design: Right abstraction level?
3. Logic: Correct behavior? Edge cases?
4. Security: Input validation? Auth? Data exposure?
5. Performance: O(n)? Unnecessary ops?
6. Tests: Coverage? Right cases?
7. Style: Consistent? Readable?

## Comment Format
```
{severity}: {file}:{line} - {issue}
→ {suggestion}
```

Severity: `BLOCK` | `WARN` | `NIT` | `QUESTION`

## Checklist
- [ ] No hardcoded secrets/keys
- [ ] Error handling present
- [ ] No console.log/print debris
- [ ] Types/null checks where needed
- [ ] No dead code
- [ ] Functions ≤30 lines
- [ ] No duplicated logic
- [ ] Naming is clear

## Output
```markdown
## Summary
{one-line verdict}

## Blockers
- ...

## Warnings  
- ...

## Suggestions
- ...

## Approved: {YES/NO}
```

## Rules
- Critique code, not author
- Explain why, not just what
- Offer solutions, not just problems
- One pass for logic, one for style
