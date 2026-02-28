# refactor

## Prerequisites
- [ ] Tests exist and pass
- [ ] Clear goal defined
- [ ] No feature changes included

## Patterns
| Smell | Refactor |
|---|---|
| Long function | Extract method |
| Long param list | Introduce param object |
| Duplicate code | Extract shared function |
| Deep nesting | Early return / guard clauses |
| Feature envy | Move method to data |
| God class | Split by responsibility |
| Primitive obsession | Value objects |
| Switch on type | Polymorphism |

## Sequence
1. Identify smell
2. Write/verify tests
3. Small change
4. Run tests
5. Commit
6. Repeat

## Rules
- One refactor type per commit
- No behavior changes
- Keep functions pure when possible
- Reduce cyclomatic complexity
- Max 3 levels of nesting
- Max 10 params (prefer ≤3)
- DRY: extract if used 3+ times

## Naming
- Functions: `verbNoun()` - `getUserById`, `calculateTotal`
- Booleans: `is/has/can` prefix
- Collections: plural nouns
- Avoid abbreviations

## Anti-patterns
- ❌ Refactor + feature in same commit
- ❌ Refactor without tests
- ❌ Big bang rewrites

## Refactoring Strategy for Files Over 300 Lines

### Check if there are long files 
run `npm run check:longfiles` and follow on output

### Core Pattern: Extract, Compose, Export

For any file exceeding 300 lines, create a feature directory with:

```
src/components/{feature}/
├── types.ts              # TypeScript interfaces (no JSX)
├── use{Feature}.ts       # Custom hook for state management
├── {Section}Component.tsx # UI components
├── ...                   # More components as needed
└── index.ts              # Barrel exports (re-export all)
```

### Extraction Steps

1. **Types First** - Extract all interfaces to `types.ts`
2. **Hook Second** - Extract state/logic to `use{Feature}.ts`
3. **Components Third** - Extract UI sections to separate `.tsx` files
4. **Barrel Last** - Create `index.ts` to re-export everything
5. **Rewrite Original** - Import from barrel, compose components

### Barrel Exports Pattern

Always create an `index.ts` that re-exports:

```typescript
export * from "./types";
export { useFeature } from "./useFeature";
export { Component1 } from "./Component1";
export { Component2 } from "./Component2";
```

**Benefits:**

- Single import statement: `from "@/components/feature"`
- Easy refactoring - change internals without breaking imports
- Clean public API

### When to Reuse vs Extract

- **Reuse** existing components when they fit the use case
- **Extract** new components for repeated UI patterns
- **Share** hooks across related features
- Example: DayTabs component was created once, then reused in 2 other pages