# component

## Structure
```
ComponentName/
├── ComponentName.tsx      # Component
├── ComponentName.test.tsx # Tests
├── ComponentName.styles.ts # Styles (if needed)
├── index.ts               # Export
└── types.ts               # Types (if complex)
```

## Component Template
```tsx
interface Props {
  required: string;
  optional?: number;
  children?: React.ReactNode;
}

export function ComponentName({ required, optional = 0, children }: Props) {
  return (
    <div>
      {children}
    </div>
  );
}
```

## Rules
- One component per file
- Props interface always defined
- Default exports for pages, named for components
- Colocate styles and tests
- Extract hooks when logic >10 lines
- Max 150 lines per component

## Composition
```
Page
└── Layout
    ├── Header
    ├── Content
    │   ├── Feature
    │   │   ├── Container (logic)
    │   │   └── Presenter (UI)
    │   └── Shared components
    └── Footer
```

## State Management
| Scope | Solution |
|---|---|
| Local UI | useState |
| Form | useForm / controlled |
| Shared (siblings) | Lift state up |
| Global (app) | Context / store |
| Server | Query library |

## Checklist
- [ ] Props typed
- [ ] Loading state handled
- [ ] Error state handled
- [ ] Empty state handled
- [ ] Accessible (aria, keyboard)
- [ ] Responsive
- [ ] Tested

## Anti-patterns
- ❌ Props drilling >2 levels
- ❌ Business logic in components
- ❌ Inline styles
- ❌ Hardcoded strings (use constants)
- ❌ Direct DOM manipulation
