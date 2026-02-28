# Debugging Qwik Apps

## Common Errors & Fixes

### Serialization Error
```
Error: Can not serialize a HTML Node
Error: Only primitive and object literals can be serialized
```
**Cause:** A `$` function closure captures a non-serializable value.
**Fix:** Wrap with `noSerialize()` or move the value inside `useVisibleTask$`.

### QRL Resolution Error
```
Error: Q-ERROR: Failed to resolve QRL
```
**Cause:** Code splitting failed to find the lazy-loaded chunk.
**Fix:** Ensure `$` functions only capture serializable values. Check Vite build output for missing chunks.

### "Cannot use X during SSR"
**Cause:** Accessing `window`, `document`, `localStorage` during SSR.
**Fix:** Move browser-only code into `useVisibleTask$()`:
```typescript
useVisibleTask$(() => {
  const saved = localStorage.getItem('key'); // Safe here
});
```

### Store Reactivity Not Working
**Cause:** Destructured store properties lose reactivity.
```typescript
// ⛔ Broken — count is a plain number now
const { count } = useStore({ count: 0 });

// ✅ Works
const state = useStore({ count: 0 });
return <p>{state.count}</p>;
```

### routeLoader$ Not Available
**Cause:** routeLoader$ can only be exported from `routes/` files (pages/layouts).
**Fix:** Define the loader in the route file, not in a component file.

## Debug Tools

### Vite Dev Server
```bash
npm run dev          # HMR + source maps
# Debug in browser DevTools — Qwik source maps work
```

### Qwik Insight (Browser Extension)
- Chrome/Edge extension: "Qwik DevTools"
- Shows component tree, signal subscriptions, serialized state

### SSR Debug
```typescript
// vite.config.ts — enable SSR debug logging
export default defineConfig({
  plugins: [
    qwikCity(),
    qwikVite({
      debug: true, // Verbose SSR output
    }),
  ],
});
```

### Log Serialization State
```typescript
useTask$(() => {
  console.log('[DEBUG] state:', JSON.stringify(store));
});
```

## SSR vs Client Debugging
| Issue Location | Debug Approach |
|---|---|
| Server (SSR) | Check terminal/server logs, add `console.log` in routeLoader$/onRequest |
| Client | Browser DevTools, `useVisibleTask$` logs |
| Both | `useTask$` logs (runs on both) |

## Sequence
1. Check browser console AND terminal for errors
2. Identify if error is SSR or client-side
3. Check serialization boundaries ($ functions)
4. Verify all browser APIs are inside `useVisibleTask$`
5. Check that routeLoader$/routeAction$ are in route files
6. Verify store access patterns (no destructuring)
