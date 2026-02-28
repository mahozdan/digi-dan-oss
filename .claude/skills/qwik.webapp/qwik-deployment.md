# Qwik Deployment

## Add an Adapter
```bash
npm run qwik add    # Interactive — pick from list
# Or directly:
npm run qwik add cloudflare-pages
npm run qwik add netlify-edge
npm run qwik add vercel-edge
npm run qwik add node-server
npm run qwik add static
```

## Available Adapters
| Adapter | Package | SSR | Edge |
|---|---|---|---|
| Node.js | `@builder.io/qwik-city/adapters/node-server` | Yes | No |
| Cloudflare Pages | `@builder.io/qwik-city/adapters/cloudflare-pages` | Yes | Yes |
| Vercel Edge | `@builder.io/qwik-city/adapters/vercel-edge` | Yes | Yes |
| Netlify Edge | `@builder.io/qwik-city/adapters/netlify-edge` | Yes | Yes |
| Static (SSG) | `@builder.io/qwik-city/adapters/static` | No | No |
| Deno | `@builder.io/qwik-city/adapters/deno-server` | Yes | No |

## Build & Deploy
```bash
npm run build        # Builds client + server
npm run preview      # Local preview of production build
```

Build output goes to:
- `dist/` — client assets
- `server/` — server entry (adapter-specific)

## SSG (Static Site Generation)
```typescript
// src/routes/blog/[slug]/index.tsx
export const onStaticGenerate = () => ({
  params: [
    { slug: 'post-1' },
    { slug: 'post-2' },
  ],
});
```

## Environment Variables
```typescript
// Access in server-side code (routeLoader$, routeAction$, server$, onRequest)
export const useData = routeLoader$(async ({ env }) => {
  const apiKey = env.get('API_KEY'); // Platform env vars
});
```

**Note:** `env.get()` reads from the platform's env system (not `process.env` for edge runtimes).

## Docker (Node Adapter)
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY dist/ ./dist/
COPY server/ ./server/
EXPOSE 3000
CMD ["node", "server/entry.node-server.js"]
```

## Pre-Deploy Checklist
- [ ] Adapter installed and configured
- [ ] `npm run build` succeeds
- [ ] Environment variables set on platform
- [ ] Preview tested locally: `npm run preview`
- [ ] SSG routes have `onStaticGenerate` if needed
- [ ] Check bundle size: `dist/` should be small (Qwik lazy loads)

## Platform-Specific Notes
- **Cloudflare:** Use `platform.env` for KV/D1 bindings
- **Vercel:** Edge functions have 25s timeout, serverless have 60s
- **Static:** All routes must be pre-renderable, no dynamic server code
