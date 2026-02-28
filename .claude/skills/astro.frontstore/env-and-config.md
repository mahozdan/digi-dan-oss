# Environment Variables & Config — Astro + Cloudflare Workers

## Golden Rule

**Only secrets belong in `.env` / Cloudflare Worker secrets.** Everything else is hardcoded in `src/config.ts` and tracked in git.

## Why

Cloudflare Builds does not reliably pass plaintext environment variables to Astro's `import.meta.env` at build time. Rather than fighting env var injection across different CI environments, we hardcode all non-secret configuration as TypeScript constants. This guarantees the correct values are baked into the static HTML at build time, regardless of hosting provider.

## Where Config Lives

| What | Where | Accessed via |
|------|-------|-------------|
| Site mode, URLs, feature flags | `src/config.ts` (git-tracked) | `import { siteMode } from '../config'` |
| API keys, secrets | Cloudflare Worker secrets (dashboard or `wrangler secret put`) | `env.RESEND_API_KEY` in `worker.ts` |
| Local dev secrets | `.env` (git-ignored) | Only for local `wrangler dev` |

## src/config.ts

```ts
// Build-time (used by Astro pages)
export const siteMode: 'waitlist' | 'live' = 'waitlist';
export const appUrl = 'https://your-domain.com';
export const calendlyUrl = 'https://calendly.com/your-calendly-handle/30min';

// Runtime (used by worker.ts)
export const contactEmail = 'from.front.store@your-domain.com';
export const resendWaitlistId = 'YOUR_RESEND_AUDIENCE_ID';
```

To change a value, edit `config.ts`, commit, and push. No dashboard env vars to sync.

## src/env.d.ts

Minimal — only Astro's default types. No custom `ImportMetaEnv` needed since we don't read `import.meta.env` for our own vars.

```ts
/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />
```

## Worker Runtime Secrets

Typed in `worker.ts` via the `interface Env` block. Set in Cloudflare dashboard under Worker > Settings > Variables & Secrets:

- `RESEND_API_KEY` — Resend transactional email API key (**Full access** required, not just "Sending access" — Audiences API needs it)

Non-secret Worker config (`contactEmail`, `resendWaitlistId`) is imported from `config.ts`, not read from `env`.

## Anti-Patterns (Don't Do These)

- Don't use `import.meta.env` or `process.env` for non-secret config — it breaks on Cloudflare Builds.
- Don't put runtime Worker secrets in `ImportMetaEnv` — they're only available in the Worker `env` parameter, not at Astro build time.
- Don't duplicate config between `.env`, dashboard env vars, and code — single source of truth is `config.ts` for non-secrets, Cloudflare dashboard for secrets.
