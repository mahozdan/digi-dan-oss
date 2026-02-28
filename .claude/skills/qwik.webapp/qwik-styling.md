# Qwik Styling

## Global CSS
```typescript
// src/root.tsx
import './global.css';
```

## Scoped Styles (useStylesScoped$)
```typescript
import { component$, useStylesScoped$ } from '@builder.io/qwik';

export const Card = component$(() => {
  useStylesScoped$(`
    .card { border: 1px solid #ccc; padding: 16px; }
    .card h2 { color: blue; }
  `);
  return <div class="card"><h2>Title</h2></div>;
});
```
Qwik adds a unique attribute to scope styles to the component.

## Component Styles (useStyles$)
```typescript
import { component$, useStyles$ } from '@builder.io/qwik';
import styles from './card.css?inline';

export const Card = component$(() => {
  useStyles$(styles);
  return <div class="card">Content</div>;
});
```

## CSS Modules
```typescript
import styles from './card.module.css';

export const Card = component$(() => {
  return <div class={styles.card}>Content</div>;
});
```

## Tailwind CSS
```bash
npm run qwik add tailwind
```
This adds:
- `tailwind.config.js`
- `postcss.config.js`
- Tailwind directives to `global.css`

Usage:
```tsx
<button class="bg-blue-500 text-white px-4 py-2 rounded">Click</button>
```

## Dynamic Classes
```tsx
// Conditional classes
<div class={`card ${isActive ? 'active' : ''}`} />

// Object syntax (via class:list)
<div class={['base', { active: isActive, disabled: isDisabled }]} />
```

## Inline Styles
```tsx
<div style={{ color: 'red', fontSize: '16px' }} />
// Or string:
<div style="color: red; font-size: 16px" />
```

## Preference Order
1. Tailwind / utility classes — fastest iteration
2. CSS Modules — scoped, no runtime cost
3. `useStylesScoped$` — scoped, lazy-loaded with component
4. Global CSS — layout/reset only
