# @trace Reference: Writing Code

## Annotations

| Annotation | Use |
|------------|-----|
| `@trace implements X` | Code fulfills requirement |
| `@trace tests X` | Test verifies requirement |
| `@trace depends-on X` | Code requires component X |
| `@trace extends X` | Code builds on X |
| `@trace fixes X` | Code fixes bug X |
| `@trace-defer X reason="Y"` | Postponed, explain why |
| `@trace-partial X coverage="N%"` | Incomplete implementation |
| `@trace-blocked X by="Y"` | Blocked by external factor |

## Placement

```typescript
// Function
/** @trace implements AC-001 */
function doThing() {}

// Class
/** @trace implements COMPONENT-001 */
class Service {
  /** @trace implements AC-002 */
  method() {}
}

// Test
/** @trace tests AC-001 */
describe('Feature', () => {
  /** @trace tests AC-001.1 */
  it('does thing', () => {});
});

// React
/** @trace implements UI-001 */
export function Component() {}

// API
/** @trace implements API-001 */
app.post('/endpoint', handler);
```

## Patterns

### Feature implementation
```typescript
/**
 * @trace implements STORY-123
 * @trace implements AC-123.1
 */
```

### With dependencies
```typescript
/**
 * @trace implements AC-001
 * @trace depends-on AUTH-SERVICE
 */
```

### Partial/deferred
```typescript
/**
 * @trace implements AC-001
 * @trace-defer AC-002 reason="Phase 2"
 */
```

### Bug fix
```typescript
/**
 * @trace fixes BUG-789
 * @trace implements AC-001
 */
```

### Test coverage
```typescript
/**
 * @trace tests STORY-123
 * @trace tests AC-123.1
 */
```

## Prompting Claude Code

New feature:
```
Implement [STORY-ID]. Add @trace implements for each AC.
Add @trace tests on test files. Use @trace-defer for incomplete items.
```

Bug fix:
```
Fix [BUG-ID]. Add @trace fixes on the fix, @trace tests on regression test.
```

Add tests:
```
Add tests for [COMPONENT]. Add @trace tests [AC-ID] on each test.
```

## Pre-commit

Pass:
```
✓ AC-123.1 → function() → test.ts
✓ AC-123.2 → DEFERRED (reason: "Phase 2")
```

Fail:
```
✗ src/payments/processor.ts has no @trace (critical path)
  Add @trace implements [ID] or @trace-defer [ID] reason="..."
```

## Checklist

- [ ] New functions in critical paths have `@trace implements`
- [ ] New tests have `@trace tests`
- [ ] Deferred items have `@trace-defer` with reason
- [ ] Pre-commit hook passes
