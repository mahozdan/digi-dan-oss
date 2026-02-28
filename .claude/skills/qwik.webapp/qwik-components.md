# Qwik Components

## Define a Component
```typescript
import { component$ } from '@builder.io/qwik';

export const Button = component$<{ label: string; disabled?: boolean }>((props) => {
  return <button disabled={props.disabled}>{props.label}</button>;
});
```

## Props
```typescript
interface CardProps {
  title: string;
  count?: number;          // Optional primitive
  onAction?: QRL<() => void>; // Callback prop (must be QRL)
}

export const Card = component$<CardProps>(({ title, count = 0 }) => {
  return <div>{title}: {count}</div>;
});
```

**Rule:** Pass `signal.value` not the signal itself when child only reads:
```tsx
// ✅ Good
<Child count={countSig.value} />
// ⛔ Avoid (unless child needs to write)
<Child count={countSig} />
```

## Slots (Content Projection)
```tsx
// Parent defines slots
export const Panel = component$(() => {
  return (
    <div>
      <header><Slot name="header" /></header>
      <main><Slot /></main> {/* Default slot */}
      <footer><Slot name="footer" /></footer>
    </div>
  );
});

// Usage
<Panel>
  <div q:slot="header">Title</div>
  <p>Body content (default slot)</p>
  <div q:slot="footer">Footer</div>
</Panel>
```

## DOM Refs
```tsx
const inputRef = useSignal<HTMLInputElement>();

return <input ref={inputRef} />;
// Access: inputRef.value?.focus()
```

## Lifecycle / Tasks
| Hook | Runs Where | Use For |
|---|---|---|
| `useTask$()` | Server + Client | Side effects on state change |
| `useVisibleTask$()` | Client only | DOM APIs, browser-only libs |
| `useComputed$()` | Server + Client | Derived/memoized values |
| `useResource$()` | Server + Client | Async derived values |

```typescript
useTask$(({ track, cleanup }) => {
  track(() => signal.value);        // Re-run when signal changes
  cleanup(() => clearInterval(id)); // Cleanup on destroy
});

useVisibleTask$(() => {
  // Runs only in browser, after element is visible
  const chart = new Chart(canvasRef.value);
});
```

## Inline Components (No Lazy Boundary)
```tsx
// No component$, no $, renders inline with parent
export const Badge = (props: { text: string }) => (
  <span class="badge">{props.text}</span>
);
```
Use for tiny, non-interactive elements that don't need their own lazy boundary.
