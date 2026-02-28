# Init New Qwik Project

## Create Project
```bash
npm create qwik@latest
# or with specific template:
npm create qwik@latest -- --template basic
```

## Templates Available
| Template | Description |
|---|---|
| `basic` | Minimal QwikCity app |
| `empty` | Bare Qwik (no QwikCity) |
| `playground` | Interactive playground |
| `library` | Component library |

## Project Structure (QwikCity)
```
src/
├── components/       # Reusable components
│   └── router-head/  # <head> management
├── routes/           # File-based routing
│   ├── index.tsx     # Home page (/)
│   ├── layout.tsx    # Root layout
│   └── service-worker.ts
├── entry.ssr.tsx     # SSR entry
├── root.tsx          # App root component
└── global.css        # Global styles
public/               # Static assets
vite.config.ts        # Vite + Qwik plugin
tsconfig.json
```

## Key Config Files
```typescript
// vite.config.ts
import { qwikVite } from '@builder.io/qwik/optimizer';
import { qwikCity } from '@builder.io/qwik-city/vite';

export default defineConfig(() => ({
  plugins: [qwikCity(), qwikVite()],
}));
```

## Post-Init Commands
```bash
npm install
npm run dev          # Dev server (default :5173)
npm run build        # Production build
npm run preview      # Preview production build
npm run qwik add     # Add integrations (adapters, tailwind, etc.)
```

## Add Integrations
```bash
npm run qwik add cloudflare-pages  # Deploy adapter
npm run qwik add tailwind          # Tailwind CSS
npm run qwik add playwright        # E2E testing
```

## Packages
| Package | Purpose |
|---|---|
| `@builder.io/qwik` | Core framework |
| `@builder.io/qwik-city` | Meta-framework (routing, loaders, actions) |
| `@builder.io/qwik-city/vite` | Vite plugin for QwikCity |
