# debug

## Sequence
1. **Reproduce**: Get consistent repro steps
2. **Isolate**: Narrow to smallest failing case
3. **Identify**: Find exact line/state causing issue
4. **Fix**: Minimal change to resolve
5. **Verify**: Repro steps now pass
6. **Prevent**: Add test for this case

## Techniques
| Symptom | Approach |
|---|---|
| Crash/exception | Read stack trace bottom-up |
| Wrong output | Binary search with logs |
| Race condition | Add delays, check async/await |
| Memory leak | Heap snapshot diff |
| Performance | Profile, find hotspot |
| Intermittent | Log state, check timing |

## Questions
- What changed recently?
- Works in other environments?
- Input-dependent?
- Time/load dependent?
- What do logs show?

## Log Format
```
[DEBUG] {location}: {variable}={value}
```

## Output
```markdown
## Bug
{description}

## Root Cause
{why it happens}

## Fix
{what was changed}

## Test Added
{test name/location}
```

## Rules
- Don't guess—verify with data
- One variable at a time
- Check assumptions
- Read error messages fully
- Clean up debug code before commit
