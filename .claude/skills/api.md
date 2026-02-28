# api

## REST Conventions
| Action | Method | Path | Response |
|---|---|---|---|
| List | GET | /resources | 200 + array |
| Get | GET | /resources/:id | 200 + object |
| Create | POST | /resources | 201 + object |
| Update | PUT | /resources/:id | 200 + object |
| Partial | PATCH | /resources/:id | 200 + object |
| Delete | DELETE | /resources/:id | 204 |

## Response Format
```json
{
  "data": {},
  "meta": { "page": 1, "total": 100 }
}
```

## Error Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human readable",
    "details": [{ "field": "email", "issue": "invalid" }]
  }
}
```

## Status Codes
- 200: Success
- 201: Created
- 204: No content
- 400: Bad request
- 401: Unauthorized
- 403: Forbidden
- 404: Not found
- 409: Conflict
- 422: Validation failed
- 500: Server error

## Checklist
- [ ] Validate all input
- [ ] Pagination for lists (limit/offset or cursor)
- [ ] Rate limiting
- [ ] Versioning strategy (/v1/)
- [ ] Auth on protected routes
- [ ] CORS configured
- [ ] Request IDs for tracing

## Naming
- Plural nouns: `/users`, not `/user`
- Kebab-case: `/user-profiles`
- No verbs: `/users`, not `/getUsers`
- Nested for relations: `/users/:id/posts`
