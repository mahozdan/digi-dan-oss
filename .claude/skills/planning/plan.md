# plan

## Output Format
```markdown
## Objective
{one-line goal}

## Scope
- IN: {list}
- OUT: {list}

## Tasks
1. [ ] {task} → {file(s)}
2. [ ] ...

## Dependencies
- {external deps if any}

## Risks
- {potential issues}
```

## Rules
- Each task = single responsibility
- Include file paths
- Identify blockers upfront
- No implementation details—just what, not how
- Update plan file after each task completion
- Build around well defined testable mile stones 
- The testable goals should be clearly communicated including instruction on how to test them with all mocks and stabs required to perform the tests already ready.


## Plan Location
Save to: `.claude/plans/{feature-name}.md`
