# Qwik Performance

## Built-In Performance (Resumability)
Qwik's architecture provides these by default:
- **Zero JS on load** — JS downloads only on user interaction
- **Fine-grained lazy loading** — each `$` boundary is a separate chunk
- **O(1) startup** — startup cost doesn't grow with app size
- **No hydration** — server HTML is immediately interactive

## Prefetching Strategies
Qwik prefetches JS modules in the background via service worker:
```typescript
// vite.config.ts
qwikCity({
  // Prefetch strategy (default is good for most apps)
  // Options: 'implementation' | 'event' | 'all'
})
```

The service worker (`src/routes/service-worker.ts`) handles module prefetching automatically.

## Optimization Tips

### Minimize useVisibleTask$
Each `useVisibleTask$` forces client-side JS execution on load:
```typescript
// ⛔ Avoid — runs eagerly on client
useVisibleTask$(() => {
  document.title = 'Hello'; // Use useDocumentHead instead
});

// ✅ Prefer — runs on server, no client JS
useTask$(() => {
  // Server-side logic
});
```

### Use `{ strategy: 'document-idle' }`
If `useVisibleTask$` is needed, defer it:
```typescript
useVisibleTask$(() => {
  initAnalytics();
}, { strategy: 'document-idle' }); // Runs after page is idle
```

### Lazy Load Heavy Components
```typescript
// Components with $ are already lazy — but you can also
// conditionally render to avoid loading at all
const showChart = useSignal(false);
return (
  <>
    <button onClick$={() => showChart.value = true}>Show Chart</button>
    {showChart.value && <HeavyChart />}
  </>
);
```

### Image Optimization
```tsx
// Use width/height to prevent layout shift
<img src="/photo.jpg" width={800} height={600} loading="lazy" />

// Or use a Qwik image component library
import { Image } from 'qwik-image';
```

### Bundle Analysis
```bash
npm run build
# Check dist/ folder sizes
# Qwik chunks should be small (< 5KB each typically)
```

## Anti-Patterns
| Anti-Pattern | Fix |
|---|---|
| `useVisibleTask$` for data fetching | Use `routeLoader$` |
| Large inline `$` closures | Extract to separate files |
| Importing large libs at top level | Dynamic import inside `$` functions |
| `useStore` with `deep: true` for huge objects | Use `deep: false` or split into signals |
| `useVisibleTask$` for computed values | Use `useComputed$` |

## Metrics to Watch
- **TTFB** — server response time (optimize routeLoaders)
- **LCP** — largest contentful paint (optimize critical path)
- **TBT** — total blocking time (minimize useVisibleTask$)
- **Bundle size per chunk** — should be tiny (< 10KB)
