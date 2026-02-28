# Session Start

**At the start of every session**, run `npm run good:morning` to sync branches, check for shuru updates, and run a health check.

# Claude Code Skills Router

## Skill Loading
Load skill from `.claude/skills/{skill}.md` before executing task.

## Skill Map

| Task Pattern | Skill |
|---|---|
| learning / reading / searching the code base | `querying-@trace` |
| plan, design, architect, structure | `plan` |
| test, spec, coverage, unittest | `test` |
| end of task, DoD | `dod` |
| commit, save changes | `commit` |
| branch, checkout, merge | `branch` |
| pr, pull request, review request | `pr` |
| add @trace, update @trace | `using-@trace` |
| review, audit code | `review` |
| dependency, package, library, install | `deps` |
| refactor, clean, improve code | `refactor` |
| debug, fix, troubleshoot, error | `debug` |
| security, vulnerability, auth | `security` |
| performance, optimize, speed | `perf` |
| document, readme, jsdoc | `docs` |
| api, endpoint, route, rest | `api` |
| error handling, exceptions, catch | `error` |
| deploy, ci, cd, pipeline | `deploy` |
| database, schema, migration, query | `db` |
| config, env, settings | `config` |

## Multi-Skill Tasks
Complex tasks may require multiple skills. Load in sequence:
- Feature: `plan` → `api`/`db` → `test` → `dod` → `commit`
- Bugfix: `debug` → `test` → `dod` → `commit`
- Release: `review` → `docs` → `deploy`

## Defaults
- Unknown task: Ask for clarification
- Always: Follow project conventions in codebase
- Commits: Auto-load `commit` after code changes unless told otherwise

### Quality Checks After Each Extraction

```bash
npm run build              # Must pass
npm run check:longfiles    # Target file < 300 lines
npm run test:unit          # All tests pass
```
