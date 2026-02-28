# Qwik Fundamentals

## Core Concept: Resumability
- Qwik does NOT hydrate — it **resumes** from server-rendered HTML
- JS loads on-demand per interaction, not upfront
- The `$` suffix marks lazy-load boundaries (code splitting points)

## The `$` Suffix
Every function ending with `$` creates a lazy-load boundary:
```typescript
component$()    // Component definition
onClick$()      // Event handler
useTask$()      // Side effect / lifecycle
useVisibleTask$() // Client-only side effect
server$()       // Server-only function
$()             // Create a QRL (lazy reference)
```

**Rule:** Closures captured by `$` functions must be serializable.

## Serialization Rules
Qwik serializes state to HTML. These are serializable:
- Primitives (string, number, boolean, null, undefined)
- Arrays, plain objects, Date, URL, Map, Set, RegExp
- Signals, stores, QRLs
- DOM references (via `ref`)

**NOT serializable** (use `noSerialize()`):
- Class instances, closures, DOM nodes directly
- Streams, WebSocket, third-party lib objects

```typescript
import { noSerialize } from '@builder.io/qwik';
const chart = noSerialize(new Chart()); // Won't be serialized
```

## Component Basics
```typescript
import { component$ } from '@builder.io/qwik';

export const MyComponent = component$(() => {
  return <div>Hello</div>;
});
```

## Event Handlers
```tsx
<button onClick$={() => console.log('clicked')}>Click</button>
<input onInput$={(_, el) => console.log(el.value)} />
<form onSubmit$={(ev) => ev.preventDefault()} />
// Prevent default shorthand:
<a href="/" preventdefault:click onClick$={() => {}}>Link</a>
```

## Key Imports
```typescript
import {
  component$, useSignal, useStore, useTask$,
  useVisibleTask$, useComputed$, useResource$,
  $, noSerialize, Slot, useId, useStyles$,
} from '@builder.io/qwik';
```
