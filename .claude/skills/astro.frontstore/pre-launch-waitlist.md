# Pre-Launch Waitlist — Astro + Cloudflare Workers + Resend

Pattern for adding a pre-launch waitlist to a front-store marketing site.

## Architecture

```
[Astro static page]  →  [React form island]  →  POST /api/waitlist  →  [Cloudflare Worker]  →  [Resend API]
     waitlist.astro       WaitlistForm.tsx          worker.ts              Audience + Email
```

- **Frontend:** Astro page with a React form component (`client:load`)
- **Backend:** Cloudflare Worker handles `/api/waitlist` POST requests
- **Storage:** Resend Audiences stores contacts (no separate DB needed)
- **Notifications:** Resend sends confirmation email to user + alert email to admin

## Site Mode Toggle

`src/config.ts` controls whether the site shows waitlist CTAs or live app links:

```ts
export const siteMode: 'waitlist' | 'live' = 'waitlist';
```

When `siteMode === 'waitlist'`:
- Nav CTA links to `/waitlist` (or `/en/waitlist`)
- Demo page shows "Join Waitlist" as secondary CTA
- All pages use `t.nav.cta_waitlist` label

When `siteMode === 'live'`:
- Nav CTA links to `appUrl` (the SaaS app)
- All pages use `t.nav.cta_live` label

## Key Files

| File | Purpose |
|------|---------|
| `src/pages/waitlist.astro` | Hebrew waitlist page |
| `src/pages/en/waitlist.astro` | English waitlist page |
| `src/components/forms/WaitlistForm.tsx` | React form island with client-side validation |
| `src/worker.ts` → `handleWaitlist()` | API handler: validates, stores contact, sends emails |
| `src/i18n/he.json` / `en.json` | Form labels, error messages, success copy |

## Worker API: POST /api/waitlist

**Request body:**
```json
{
  "name": "string (required)",
  "email": "string (required)",
  "company_name": "string (required)",
  "team_size": "string (required)",
  "referral": "string (optional)",
  "consent": "string (required)"
}
```

**Responses:**
- `200` — success
- `400` — missing fields or invalid email
- `409` — email already registered (Resend returns 409 for duplicate contacts)
- `502` — Resend API error (bad key, restricted permissions, invalid audience ID) — returns error detail
- `500` — server error

**What happens on success:**
1. Contact added to Resend Audience (`RESEND_WAITLIST_ID`)
2. Confirmation email sent to user
3. Alert email sent to admin (`CONTACT_EMAIL`)

## Worker Secrets Required

Set via Cloudflare dashboard (Worker > Settings > Variables & Secrets):

| Secret | Purpose |
|--------|---------|
| `RESEND_API_KEY` | Resend API key (**Full access** — Audiences API requires more than "Sending access") |

Non-secret config (`contactEmail`, `resendWaitlistId`) is hardcoded in `src/config.ts` and imported by `worker.ts`.

## Form Features

- Client-side validation with per-field error messages
- i18n: RTL Hebrew + LTR English
- Loading state on submit
- Duplicate detection (409 → friendly "already registered" message)
- Success state with social share buttons (WhatsApp + LinkedIn)
- Form resets on success

## Going Live (Switching Off Waitlist)

1. Change `siteMode` to `'live'` in `src/config.ts`
2. Optionally remove waitlist pages and form, or keep them as a redirect
3. Commit, bump, push
