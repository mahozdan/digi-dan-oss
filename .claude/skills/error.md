# error

## Error Hierarchy
```
BaseError
├── ValidationError (400)
├── AuthenticationError (401)
├── AuthorizationError (403)
├── NotFoundError (404)
├── ConflictError (409)
└── InternalError (500)
```

## Custom Error Class
```javascript
class AppError extends Error {
  constructor(code, message, statusCode, details = null) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}
```

## Rules
- Catch at boundaries (API, job, event handler)
- Log with context (requestId, userId, input)
- User message ≠ log message
- Never expose stack traces to client
- Always have fallback handler

## Pattern
```javascript
try {
  // risky operation
} catch (error) {
  if (error instanceof ExpectedError) {
    // handle specifically
  } else {
    // log and rethrow or wrap
    logger.error({ error, context });
    throw new InternalError();
  }
}
```

## Logging
```javascript
logger.error({
  code: error.code,
  message: error.message,
  stack: error.stack,
  context: { userId, requestId, input }
});
```

## Checklist
- [ ] All async has try/catch or .catch()
- [ ] Global error handler exists
- [ ] Errors have consistent format
- [ ] Sensitive data not in error messages
- [ ] Failed operations are retryable or final
- [ ] Error monitoring configured (Sentry, etc.)
