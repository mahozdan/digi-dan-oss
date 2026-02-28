# Qwik Integrations

## Qwik React (Use React Components in Qwik)
```bash
npm run qwik add react
```

```typescript
/** @jsxImportSource react */
import { qwikify$ } from '@builder.io/qwik-react';
import { Slider } from '@mui/material';

// Convert React component to Qwik component
export const MuiSlider = qwikify$(Slider, {
  eagerness: 'hover', // When to hydrate: 'load' | 'visible' | 'hover' | 'idle'
});

// Use in Qwik component
import { MuiSlider } from './mui-slider';
export default component$(() => {
  return <MuiSlider min={0} max={100} />;
});
```

### Eagerness Options
| Value | When React Hydrates |
|---|---|
| `'load'` | Immediately on page load |
| `'visible'` | When element enters viewport |
| `'hover'` | When user hovers over element |
| `'idle'` | When browser is idle |

## Head Management (SEO)
```typescript
// src/routes/about/index.tsx
import { component$ } from '@builder.io/qwik';
import { type DocumentHead } from '@builder.io/qwik-city';

export default component$(() => <h1>About</h1>);

export const head: DocumentHead = {
  title: 'About Us',
  meta: [
    { name: 'description', content: 'About our company' },
    { property: 'og:title', content: 'About Us' },
  ],
  links: [
    { rel: 'canonical', href: 'https://example.com/about' },
  ],
};
```

### Dynamic Head (from routeLoader$)
```typescript
export const head: DocumentHead = ({ resolveValue }) => {
  const product = resolveValue(useProduct);
  return {
    title: product.name,
    meta: [{ name: 'description', content: product.description }],
  };
};
```

## Third-Party Libraries

### Browser-Only Libs (Chart.js, etc.)
```typescript
useVisibleTask$(async () => {
  const { Chart } = await import('chart.js'); // Dynamic import
  const chart = new Chart(canvasRef.value, config);
  chartRef.value = noSerialize(chart);
});
```

### Server-Only Libs (DB, Auth)
```typescript
// Safe in routeLoader$, routeAction$, server$, onRequest
export const useData = routeLoader$(async () => {
  const { PrismaClient } = await import('@prisma/client');
  const prisma = new PrismaClient();
  return prisma.user.findMany();
});
```

## Form Libraries
Qwik's built-in Form + routeAction$ + zod$ covers most cases.
For complex forms, consider [Modular Forms](https://modularforms.dev/qwik/):
```bash
npm install @modular-forms/qwik
```

## i18n
```bash
npm install qwik-speak
```
Provides `$translate()`, locale routing, and SSR-friendly translations.

## Auth Providers
Use `server$` or middleware to integrate:
- **Lucia Auth** — works well with Qwik middleware
- **Auth.js** — community adapter available
- **Custom JWT** — via cookie management in `onRequest`

## Key Rule
- Browser-only libs → `useVisibleTask$` + dynamic import + `noSerialize`
- Server-only libs → `routeLoader$` / `server$` / `onRequest`
- React components → `qwikify$` with appropriate eagerness
