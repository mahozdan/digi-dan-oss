# docs

## Types
| Doc | Location | Audience |
|---|---|---|
| README | `./README.md` | New devs |
| API | `./docs/api.md` or inline | Consumers |
| Architecture | `./docs/architecture.md` | Team |
| Inline | In code | Maintainers |

## README Structure
```markdown
# {Project}
{one-line description}

## Quick Start
{3-5 steps to run}

## Usage
{basic examples}

## Config
{env vars / options}

## Contributing
{link or brief guide}
```

## Function Docs
```javascript
/**
 * {What it does—one line}
 * @param {Type} name - {description}
 * @returns {Type} {description}
 * @throws {Error} {when}
 * @example
 * functionName(arg) // => result
 */
```

## Rules
- Document why, not what (code shows what)
- Update docs with code changes
- Examples over explanations
- Keep current or delete
- No commented-out code as docs

## API Documentation
```markdown
## {METHOD} {/path}
{description}

**Request**
- Headers: {list}
- Body: {schema}

**Response**
- 200: {schema}
- 4xx: {error format}
```

## When to Document
- Public API: Always
- Complex logic: Always
- Workarounds: Always with context
- Obvious code: Never
