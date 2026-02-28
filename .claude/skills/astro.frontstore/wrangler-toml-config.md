# Wrangler TOML Configuration

Reference for all required `wrangler.toml` settings for this project.

## Required Fields

| Key                 | Value                              | Purpose                                      |
|---------------------|------------------------------------|----------------------------------------------|
| `name`              | `your-project-front-store`         | Worker name (also determines `*.workers.dev`) |
| `main`              | `src/worker.ts`                    | Worker entry point (API routes)              |
| `compatibility_date`| `YYYY-MM-DD`                       | Cloudflare runtime compat target             |

## Custom Domains (Dashboard Only — NOT in wrangler.toml)

Custom domains are configured **manually in the Cloudflare dashboard**, not in `wrangler.toml`. The `[[custom_domains]]` syntax is not a valid wrangler.toml field (Wrangler warns "Unexpected fields").

**Setup path:** Workers & Pages → your Worker → Settings → Domains & Routes → + Add

**Critical:** Do NOT create a placeholder A record (e.g. `192.0.2.1`) for the domain in Cloudflare DNS. If one exists, **delete it first** — Cloudflare refuses to add the custom domain while a conflicting DNS record exists. Cloudflare auto-creates the correct DNS record when you add the custom domain to the Worker.

- Add `your-domain.com` (apex)
- Add `www.your-domain.com` (redirects to apex)
- The domain's zone must already exist in the same Cloudflare account
- DNS for this domain is managed by Cloudflare (nameservers pointed to Cloudflare)

## Static Assets

```toml
[assets]
directory = "dist"
```

- Astro builds static output to `dist/`.
- Cloudflare serves files from this directory automatically before hitting the Worker fetch handler.
- The Worker's `fetch()` only handles API routes (`/api/*`); unmatched requests fall through to a 404.

## Runtime Secrets (not in wrangler.toml)

These are set via `npx wrangler secret put <NAME>` or in the Cloudflare dashboard under Worker → Settings → Variables & Secrets:

| Secret              | Purpose                                     |
|---------------------|---------------------------------------------|
| `RESEND_API_KEY`    | Resend transactional email API key (**Full access** required) |

Non-secret Worker config (`contactEmail`, `resendWaitlistId`) is hardcoded in `src/config.ts`.

**Never** put secrets in `wrangler.toml` — it is committed to git.

## Build-Time Config

Non-secret config (site mode, URLs, feature flags) is **not** set via env vars. It is hardcoded in `src/config.ts` and tracked in git. See the `env-and-config` skill for details.

## Full Working Example

```toml
name = "your-project-front-store"
main = "src/worker.ts"
compatibility_date = "2026-02-19"

[assets]
directory = "dist"
```

Note: custom domains are NOT in this file — they are set via the dashboard (see above).

## Deploy Command

```bash
npx wrangler deploy
```

This uploads the Worker + static assets. Custom domain routing is managed separately via the dashboard.
