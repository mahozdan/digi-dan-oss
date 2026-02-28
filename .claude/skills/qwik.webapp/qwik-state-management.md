# Qwik State Management

## useSignal — Single Value
```typescript
const count = useSignal(0);       // Reactive primitive
count.value++;                    // Trigger re-render
return <p>{count.value}</p>;
```

## useStore — Object/Nested State
```typescript
const state = useStore({
  user: { name: 'Qwik', age: 1 },
  items: ['a', 'b'],
});
state.user.name = 'Updated';     // Deep reactivity by default
state.items.push('c');            // Arrays tracked too
```

### Shallow Store (Performance)
```typescript
const store = useStore({ nested: { val: 1 } }, { deep: false });
// Only top-level property changes trigger re-render
```

## useComputed$ — Sync Derived
```typescript
const name = useSignal('qwik');
const upper = useComputed$(() => name.value.toUpperCase());
// upper.value auto-updates when name changes
```

## useResource$ — Async Derived
```typescript
const userId = useSignal(1);
const user = useResource$(async ({ track, cleanup }) => {
  const id = track(() => userId.value);
  const ctrl = new AbortController();
  cleanup(() => ctrl.abort());
  const res = await fetch(`/api/users/${id}`, { signal: ctrl.signal });
  return res.json();
});

return (
  <Resource
    value={user}
    onPending={() => <p>Loading...</p>}
    onRejected={(err) => <p>Error: {err.message}</p>}
    onResolved={(data) => <p>{data.name}</p>}
  />
);
```

## Context (Cross-Component State)
```typescript
// 1. Create context ID (shared file)
import { createContextId } from '@builder.io/qwik';
export const ThemeCtx = createContextId<Signal<string>>('theme');

// 2. Provide in parent
import { useContextProvider } from '@builder.io/qwik';
const theme = useSignal('light');
useContextProvider(ThemeCtx, theme);

// 3. Consume in any child
import { useContext } from '@builder.io/qwik';
const theme = useContext(ThemeCtx);
return <div class={theme.value}>...</div>;
```

## noSerialize — Non-Serializable Values
```typescript
import { noSerialize, type NoSerialize } from '@builder.io/qwik';

const chartRef = useSignal<NoSerialize<Chart>>();
useVisibleTask$(() => {
  chartRef.value = noSerialize(new Chart(canvas));
});
```

## Rules
- Keep state in signals/stores, not plain variables
- Don't destructure stores: `let { count } = store` breaks reactivity
- Pass `signal.value` to children that only read
- Pass the full `signal` to children that also write
- Use `noSerialize()` for class instances and browser-only objects
