# Migrating React to Qwik

## Strategy: Incremental via Qwik React
Don't rewrite everything at once. Use `qwikify$` to wrap existing React components, then migrate them one by one.

## Phase 1 — Scaffold Qwik Project
```bash
npm create qwik@latest
npm run qwik add react
```

## Phase 2 — Wrap React Components
```typescript
/** @jsxImportSource react */
import { qwikify$ } from '@builder.io/qwik-react';
import { MyReactComponent } from './legacy/MyReactComponent';

export const QMyComponent = qwikify$(MyReactComponent, {
  eagerness: 'visible',
});
```

Use wrapped components in Qwik pages while migrating the rest.

## Phase 3 — Convert Component by Component

### React → Qwik Mapping
| React | Qwik |
|---|---|
| `function Component()` | `component$(() => {})` |
| `useState(val)` | `useSignal(val)` or `useStore({})` |
| `useEffect(() => {}, [])` | `useTask$()` (server+client) or `useVisibleTask$()` (client-only) |
| `useEffect(() => {}, [dep])` | `useTask$(({ track }) => { track(() => dep.value); })` |
| `useMemo(() => val, [dep])` | `useComputed$(() => val)` |
| `useContext(Ctx)` | `useContext(CtxId)` (with `createContextId`) |
| `useRef()` | `useSignal<HTMLElement>()` + `ref={sig}` |
| `useCallback(fn)` | `$(() => fn)` (QRL) |
| `React.createContext()` | `createContextId<T>('name')` |
| `<Context.Provider value={}>` | `useContextProvider(CtxId, value)` |
| `{children}` | `<Slot />` |
| `onClick={fn}` | `onClick$={fn}` |
| `onChange={fn}` | `onInput$={(_, el) => ...}` |
| `className` | `class` |
| `dangerouslySetInnerHTML` | `dangerouslySetInnerHTML={html}` |
| `key={id}` | `key={id}` (same) |

### Event Handler Conversion
```tsx
// React
<button onClick={(e) => handleClick(e)}>

// Qwik
<button onClick$={(e) => handleClick(e)}>
```

### State Conversion
```tsx
// React
const [count, setCount] = useState(0);
setCount(count + 1);

// Qwik
const count = useSignal(0);
count.value++;
```

### Effect Conversion
```tsx
// React — runs on mount
useEffect(() => { fetchData(); }, []);

// Qwik — server+client (preferred for data)
useTask$(() => { /* use routeLoader$ instead if possible */ });

// Qwik — client only (browser APIs)
useVisibleTask$(() => { initChart(); });
```

### Context Conversion
```tsx
// React
const ThemeCtx = React.createContext('light');
<ThemeCtx.Provider value="dark"><App /></ThemeCtx.Provider>
const theme = useContext(ThemeCtx);

// Qwik
const ThemeCtx = createContextId<Signal<string>>('theme');
const theme = useSignal('dark');
useContextProvider(ThemeCtx, theme);
const theme = useContext(ThemeCtx); // in child
```

## Phase 4 — Migrate Data Fetching
| React Pattern | Qwik Replacement |
|---|---|
| `useEffect` + `fetch` on mount | `routeLoader$` (SSR, preferred) |
| `useSWR` / `react-query` | `routeLoader$` or `useResource$` |
| API routes (`/api/*`) | `server$` or `onGet`/`onPost` handlers |
| Form with `onSubmit` + fetch | `routeAction$` + `<Form>` |
| `getServerSideProps` (Next.js) | `routeLoader$` |
| `getStaticProps` (Next.js) | `routeLoader$` + `onStaticGenerate` |

## Phase 5 — Migrate Routing
| React Router / Next.js | QwikCity |
|---|---|
| `<Route path="/about">` | `src/routes/about/index.tsx` |
| `<Route path="/blog/:id">` | `src/routes/blog/[id]/index.tsx` |
| `<Layout>` wrapper | `src/routes/layout.tsx` |
| `<Outlet />` | `<Slot />` |
| `useRouter().push()` | `useNavigate()('/path')` |
| `<Link to="">` | `<Link href="">` |
| `useParams()` | `routeLoader$` params or `useLocation().params` |
| `useSearchParams()` | `useLocation().url.searchParams` |

## Phase 6 — Remove React
Once all components are converted:
```bash
npm uninstall react react-dom @builder.io/qwik-react
```
Remove `/** @jsxImportSource react */` from all files.

## Common Pitfalls
| Pitfall | Fix |
|---|---|
| `window`/`document` in component body | Move to `useVisibleTask$` |
| Passing callbacks as props | Use `QRL<() => void>` type, wrap with `$()` |
| Class component | Convert to function first, then to `component$` |
| CSS-in-JS (styled-components, emotion) | Replace with CSS modules or `useStylesScoped$` |
| Global state (Redux/Zustand) | Replace with Qwik context + stores |
| `useEffect` cleanup | Use `cleanup()` callback in `useTask$` / `useVisibleTask$` |
| Non-serializable props | Wrap with `noSerialize()` |

## Checklist
- [ ] Qwik project scaffolded with React integration
- [ ] React components wrapped with `qwikify$` and working
- [ ] Components converted one-by-one (leaf components first)
- [ ] State migrated from useState/Redux to signals/stores/context
- [ ] Effects migrated to useTask$/useVisibleTask$/routeLoader$
- [ ] Data fetching moved to routeLoader$/routeAction$
- [ ] Routing migrated to file-based QwikCity routes
- [ ] CSS-in-JS replaced with CSS modules/Tailwind/scoped styles
- [ ] React dependencies removed
- [ ] All tests passing
