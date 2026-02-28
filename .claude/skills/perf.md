# perf

## Measure First
```bash
# Node.js
node --prof app.js
# Browser
Lighthouse / DevTools Performance tab
# General
time {command}
```

## Checklist
- [ ] N+1 queries → batch/join
- [ ] Unbounded lists → pagination
- [ ] Missing indexes → add index
- [ ] Sync in hot path → async/defer
- [ ] Large payloads → compress/paginate
- [ ] No caching → cache stable data
- [ ] Memory leaks → profile heap

## Complexity Targets
| Operation | Target |
|---|---|
| API response | <200ms p95 |
| DB query | <50ms |
| Page load | <3s |
| Function | O(n) or better |

## Quick Wins
- Lazy load non-critical
- Compress responses (gzip/brotli)
- Use CDN for static assets
- Connection pooling
- Index frequently queried columns
- Debounce/throttle UI events

## Frontend
- Bundle splitting
- Image optimization (WebP, lazy)
- Minimize DOM operations
- Virtual scrolling for lists
- Memoize expensive computations

## Backend
- Query only needed fields
- Paginate all list endpoints
- Cache at appropriate layer
- Async for I/O operations
- Pool database connections

## Rules
- Profile before optimizing
- Optimize bottlenecks only
- Measure improvement
- Document tradeoffs
- Don't premature optimize
