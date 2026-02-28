# logging

## Levels
| Level | Use |
|---|---|
| error | Failures requiring attention |
| warn | Unexpected but handled |
| info | Business events, milestones |
| debug | Diagnostic details |

## Format
```json
{
  "level": "info",
  "timestamp": "ISO8601",
  "message": "User created",
  "context": {
    "requestId": "uuid",
    "userId": "123",
    "action": "createUser"
  }
}
```

## What to Log
- ✅ Request received (info)
- ✅ Request completed + duration (info)
- ✅ Errors with stack (error)
- ✅ Auth events (info)
- ✅ Business actions (info)
- ✅ External API calls (debug)

## What NOT to Log
- ❌ Passwords, tokens, secrets
- ❌ PII (unless required + masked)
- ❌ Full request/response bodies
- ❌ High-frequency debug in prod

## Pattern
```javascript
logger.info('User action', {
  requestId,
  userId,
  action: 'purchase',
  itemId: item.id,
  // NOT: creditCard, password
});
```

## Rules
- Structured logs (JSON)
- Include requestId for tracing
- Log at entry/exit points
- No string concatenation in log calls
- Set level via env var
- Async logging in prod

## Checklist
- [ ] Consistent format across services
- [ ] Request correlation IDs
- [ ] Appropriate levels used
- [ ] No sensitive data
- [ ] Centralized aggregation
- [ ] Alerting on errors
