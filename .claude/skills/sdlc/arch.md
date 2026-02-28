# arch

## Decision Record (ADR)
```markdown
# ADR-{NNN}: {Title}

## Status
{Proposed | Accepted | Deprecated | Superseded by ADR-XXX}

## Context
{Why is this decision needed?}

## Decision
{What was decided?}

## Consequences
- ✅ {Positive}
- ⚠️ {Trade-off}
- ❌ {Negative}
```
Save to: `docs/adr/ADR-{NNN}-{slug}.md`

## Layer Structure
```
src/
├── api/          # HTTP handlers
├── services/     # Business logic
├── repositories/ # Data access
├── models/       # Domain entities
├── utils/        # Shared helpers
└── config/       # Configuration
```

## Dependency Direction
```
API → Service → Repository → Database
         ↓
       Models
```

## Principles
- Dependencies point inward
- Business logic in services, not handlers
- One responsibility per module
- Interfaces at boundaries
- No circular dependencies

## Patterns by Problem
| Problem | Pattern |
|---|---|
| Create objects | Factory |
| One instance | Singleton (sparingly) |
| Decouple components | Event/Observer |
| External service | Adapter |
| Complex construction | Builder |
| Cross-cutting | Middleware |

## Checklist
- [ ] Clear module boundaries
- [ ] Dependencies explicit
- [ ] Testable in isolation
- [ ] Documented decisions (ADR)
- [ ] No god classes/modules
- [ ] Failure modes considered
