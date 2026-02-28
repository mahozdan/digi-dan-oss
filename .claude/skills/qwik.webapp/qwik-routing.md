# Qwik Routing (QwikCity)

## File-Based Routing
```
src/routes/
├── index.tsx              → /
├── about/index.tsx        → /about
├── blog/
│   ├── index.tsx          → /blog
│   └── [slug]/index.tsx   → /blog/:slug
├── [...catchall]/index.tsx → /* (catch-all)
├── (auth)/                → Route group (no URL segment)
│   ├── login/index.tsx    → /login
│   └── signup/index.tsx   → /signup
└── layout.tsx             → Wraps all routes
```

## Route Parameters
```typescript
// src/routes/blog/[slug]/index.tsx
import { routeLoader$ } from '@builder.io/qwik-city';

export const usePost = routeLoader$(async ({ params }) => {
  return getPost(params.slug); // params.slug from URL
});
```

## Layouts
```typescript
// src/routes/layout.tsx — wraps ALL routes
import { component$, Slot } from '@builder.io/qwik';

export default component$(() => {
  return (
    <main>
      <nav>...</nav>
      <Slot /> {/* Child route renders here */}
    </main>
  );
});
```

### Nested Layouts
```
src/routes/
├── layout.tsx            # Root layout
├── dashboard/
│   ├── layout.tsx        # Dashboard layout (nested inside root)
│   └── index.tsx         # /dashboard
```

### Named Layouts
```
src/routes/
├── layout.tsx            # Default layout
├── layout-minimal.tsx    # Named layout "minimal"
├── (auth)/
│   ├── layout-minimal.tsx  # Auth pages use minimal layout
```

## Navigation
```tsx
import { Link, useNavigate } from '@builder.io/qwik-city';

// Declarative
<Link href="/about">About</Link>

// Programmatic
const nav = useNavigate();
nav('/dashboard');
```

## Route Groups
Directories in `(parentheses)` group routes without adding URL segments:
```
src/routes/(marketing)/pricing/index.tsx → /pricing
src/routes/(app)/dashboard/index.tsx     → /dashboard
```

## 404 Page
Create `src/routes/[...catchall]/index.tsx` as catch-all for unmatched routes.
