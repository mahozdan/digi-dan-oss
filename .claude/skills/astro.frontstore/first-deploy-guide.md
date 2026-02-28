# Deploy Guide — Astro Front Store

**Last Updated:** 2026-02-19

This guide covers two scenarios:
- **Part A — First-Time Setup:** Creating all accounts and deploying from scratch
- **Part B — Ongoing Deployments:** Day-to-day workflow when everything is already configured

> **Interactive wizard available:** Run the Playwright wizard instead of following this guide manually:
> ```bash
> npm run deploy:setup   # one-time: install Chromium
> npm run deploy         # run the wizard
> ```

---

# Part A — First-Time Setup

Follow steps A1–A9 in order. Each step assumes the previous one is complete.

## Prerequisites

- [ ] Node.js 20+ installed
- [ ] Git installed and configured
- [ ] A domain purchased (e.g. `your-domain.com`) at any registrar

## Accounts to Create

| Service | URL | Plan |
|---------|-----|------|
| GitHub | [github.com](https://github.com) | Free |
| Cloudflare | [cloudflare.com](https://cloudflare.com) | Free |
| Resend | [resend.com](https://resend.com) | Free |
| Calendly | [calendly.com](https://calendly.com) | Free |

---

### A1 — Push Code to GitHub

1. Create a new repo at [github.com/new](https://github.com/new)
   - Name: `your-project-front-store` (or your preferred name)
   - Visibility: **Private**
   - Do NOT initialize with README/.gitignore
2. Push the project:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin <YOUR_GITHUB_URL>
   git push -u origin main
   ```

---

### A2 — Add Domain to Cloudflare

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **Add a site** → enter your domain (e.g. `your-domain.com`) → select **Free** plan
3. Cloudflare scans for existing DNS records. **Do NOT add a placeholder A record** (e.g. `192.0.2.1`) — it will block custom domain setup later in step A8. Leave DNS empty for now; Cloudflare auto-creates the correct record when you add the custom domain to the Worker.
4. Cloudflare gives you two nameservers. Go to your **domain registrar** and update the nameservers to Cloudflare's values.
   - Propagation takes minutes to 24 hours

5. **DNSSEC:** Verify it's off at your registrar

---

### A3 — Set Up Resend

#### A3.1 — Create API Key

1. Go to [resend.com/api-keys](https://resend.com/api-keys)
2. **Create API Key** → Name: `your-project-prod` → Permission: **Full access**
3. Copy the key (starts with `re_`) — shown once only. Save it securely.

#### A3.2 — Verify Sending Domain

1. Go to [resend.com/domains](https://resend.com/domains) → **Add Domain** → `your-domain.com`
2. Resend shows DNS records to add (MX, TXT for SPF/DKIM)
3. Add each record in **Cloudflare DNS → Records**:
   - For **MX** records: Resend shows `10 feedback-smtp...` — in Cloudflare, put the number in **Priority** and the hostname in **Mail server** (they're separate fields)
   - For **TXT/CNAME** records: copy Name and Value directly
4. Back in Resend, click **Verify**. Usually instant with Cloudflare DNS.

#### A3.3 — Create Waitlist Audience

1. Go to [resend.com/audiences](https://resend.com/audiences) → **Create Audience** → Name: `Waitlist`
2. Copy the **Audience ID** (UUID format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
3. Add this as `resendWaitlistId` in `src/config.ts`, commit and push

> **Note:** Resend Audiences are deprecated in favor of Segments. The API still works. Monitor for migration requirements.

---

### A4 — Create Cloudflare Workers Project

Cloudflare merged Pages into Workers (2025). New projects use the Workers flow.

1. Go to **Workers & Pages → Create application**
   - Direct link: `https://dash.cloudflare.com/?to=/:account/pages/new/provider/github`
2. Click **Import a repository** / **Connect to Git**
3. If your repo is under a GitHub **organization**, ensure the Cloudflare GitHub App has access:
   - Go to `https://github.com/organizations/YOUR_ORG/settings/installations`
   - Find Cloudflare Pages → Configure → grant access to your repo
4. Select your repo, then configure:

   | Setting | Value |
   |---------|-------|
   | Project name | `your-project-front-store` |
   | Production branch | `main` |
   | Build command | `npm run build` |
   | Deploy command | `npx wrangler deploy` (default) |
   | Path | `/` |

5. Add environment variables (see A5 below) **before** clicking Deploy
6. Click **Deploy**

---

### A5 — Set Worker Secrets

Add this in the Cloudflare dashboard at:
**Workers & Pages → your Worker → Settings → Variables and Secrets**

| Variable | Value | Type |
|----------|-------|------|
| `RESEND_API_KEY` | Your `re_...` key | **Secret** (encrypted) |

> **Note:** `CONTACT_EMAIL` and `RESEND_WAITLIST_ID` are hardcoded in `src/config.ts` — they are not secrets and do not belong in the dashboard. Only `RESEND_API_KEY` is a true secret. See the `env-and-config` skill for rationale.

---

### A6 — Set Up Cloudflare Email Routing

This forwards incoming emails (e.g. `hello@your-domain.com`) to your personal inbox.

1. **Cloudflare → your domain → Email → Email Routing**
2. Add a route: `hello@your-domain.com` → your Gmail/inbox
3. Cloudflare auto-adds the required MX/TXT records
4. Verify the destination email (Cloudflare sends a confirmation link)

---

### A7 — Set Up Cloudflare Web Analytics

1. **Cloudflare → Web Analytics → Add a site** → `your-domain.com`
2. Copy the beacon token from the snippet: `data-cf-beacon='{"token": "XXXXX"}'`
3. Open `src/layouts/BaseLayout.astro` → replace `REPLACE_WITH_CF_TOKEN` with your token
4. Commit and push

---

### A8 — Connect Custom Domain

Once nameservers have propagated (Cloudflare shows domain as "Active"):

1. **If an A record exists for your domain** (e.g. `192.0.2.1` placeholder), **delete it first** in DNS → Records. Cloudflare refuses to add a custom domain while a conflicting DNS record exists.
2. **Workers & Pages → your Worker → Settings → Domains & Routes → + Add**
3. Add `your-domain.com` — Cloudflare auto-creates the correct DNS record
4. Add `www.your-domain.com` — Cloudflare sets up a redirect to the apex

---

### A9 — Final Verification Checklist

**Pages:**
- [ ] `/` — Homepage loads correctly
- [ ] `/waitlist` — Form validates fields, submission works (check Resend Audiences)
- [ ] `/contact` — Form validates fields, submission delivers to CONTACT_EMAIL
- [ ] All main pages load without errors
- [ ] `/404` — custom 404 page (try `/does-not-exist`)

**Infrastructure:**
- [ ] `https://your-domain.com/sitemap.xml` — valid XML
- [ ] HTTPS works with padlock
- [ ] `www.` redirects to apex
- [ ] Cloudflare Web Analytics recording hits

**API:**
- [ ] Waitlist form → 200 response → contact added to Resend Audience → confirmation email sent
- [ ] Contact form → 200 response → notification email to team → auto-reply to sender
- [ ] Duplicate waitlist signup → 409 "Already registered"

---

# Part B — Ongoing Deployments

Once the first-time setup is complete, the day-to-day workflow is:

## Deploying Changes

```
git push origin main
```

That's it. Cloudflare auto-builds and deploys on every push to `main`.

- **Build:** `npm install` → `npm run build` (Astro static site → `dist/`)
- **Deploy:** `npx wrangler deploy` (uploads static assets + worker to Cloudflare edge)
- Build takes ~30–60 seconds

## Viewing Deployments

**Workers & Pages → your project → Builds** — shows build logs, status, and history.

## Changing Worker Secrets

1. **Workers & Pages → your Worker → Settings → Variables and Secrets**
2. Edit the variable → Save
3. Runtime secrets (`RESEND_API_KEY`, etc.) take effect immediately — no redeploy needed

## Changing Site Config (Mode, URLs, etc.)

Build-time config is hardcoded in `src/config.ts` — not in env vars.

1. Edit `src/config.ts`
2. Commit and push to trigger a rebuild

## Switching to Live Mode

When the app is ready and live:

1. Change `siteMode` from `'waitlist'` to `'live'` in `src/config.ts`
2. Commit and push
3. All CTAs site-wide switch from "Join Waitlist" to the live app link

## Rollback

In the Workers & Pages dashboard, go to **Builds** → find the previous successful build → **Rollback** to redeploy that version instantly.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Build fails: `npm ci` sync error | `package-lock.json` out of sync | Run `npm install` locally, commit and push the updated lock file |
| Build fails: Node version | Wrong Node version on Cloudflare | Ensure `.node-version` file contains `20` |
| Forms return 500 | `RESEND_API_KEY` missing or wrong | Check Variables and Secrets in Cloudflare |
| Forms return 502 | Resend API error (bad key, restricted permissions, invalid audience ID) | Check Worker logs; ensure API key has **Full access** |
| Forms return 400 "Missing fields" | Client validation bypassed | Check Worker logs in Cloudflare dashboard |
| "Book a Demo" links to `#` | `calendlyUrl` not set in `src/config.ts` | Edit `src/config.ts`, commit, push |
| Site shows wrong mode | `siteMode` not updated in `src/config.ts` | Edit `src/config.ts`, commit, push |
| Domain shows 522 error | Custom domain not added to Worker, or conflicting A record in DNS | Delete any A record for the domain, then add custom domain via Worker → Settings → Domains & Routes |
| Domain shows Cloudflare error | DNS not propagated | Wait; verify nameservers point to Cloudflare |
| CORS error on `cloudflareinsights.com` | Cloudflare Web Analytics internal issue | Ignore — does not affect site functionality |
| Email from forms go to spam | Domain not verified in Resend | Complete Resend domain verification (A3.2) |

---

## Architecture Reference

```
Developer → git push → GitHub → webhook → Cloudflare Builds
                                                │
                                    npm install + astro build + wrangler deploy
                                                │
                                    Cloudflare Workers (Edge)
                                        ├── Static Assets (dist/)
                                        └── Worker API (src/worker.ts)
                                                ├── POST /api/waitlist → Resend
                                                └── POST /api/contact  → Resend
```

**Key files:**
- `wrangler.toml` — Workers config (static assets directory, entry point)
- `src/worker.ts` — API routes (waitlist + contact handlers)
- `astro.config.ts` — Astro build config (site URL, i18n, integrations)
- `.node-version` — Ensures Cloudflare uses Node 20
