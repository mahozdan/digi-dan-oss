# Common Email Address Types for Product Domains

A reference guide for standard email addresses expected on product and SaaS domains.

## Essential — Set Up From Day One

| Address | Purpose |
|---------|---------|
| `hello@` or `info@` | General contact and catch-all for early-stage products. The default public-facing address for your domain. |
| `support@` | Customer support inquiries. Set up once you have users. |
| `noreply@` | Transactional emails such as password resets, receipts, notifications, and verification emails. Not monitored for replies. |

## Required by Email Standards and Infrastructure

| Address | Purpose |
|---------|---------|
| `postmaster@` | Required by RFC 5321. Receives delivery failure reports and bounce notifications. Some email providers auto-create this. |
| `abuse@` | Expected by ISPs and spam reporting systems. Receives spam and abuse complaints. Not having this can cause your domain to be flagged by some providers. |

## Growth Stage — Add When Needed

| Address | Purpose |
|---------|---------|
| `billing@` | Separates payment and subscription issues from general support. Set up once you have paying customers. |
| `security@` | Receives vulnerability reports and security disclosures. Increasingly expected for SaaS products. Pair with a `/.well-known/security.txt` file pointing to this address. |
| `team@` or `founders@` | Internal alias for distributing emails to the founding or core team. |

## Situational — Only When the Need Arises

| Address | Purpose |
|---------|---------|
| `sales@` | Inbound sales inquiries. Only useful when you have a sales funnel or lead capture flow. |
| `press@` or `media@` | Press and media inquiries. Only relevant when actively seeking or receiving media coverage. |
| `legal@` | Legal correspondence, DMCA takedowns, and compliance matters. |
| `jobs@` or `careers@` | Job applications and recruitment inquiries. Only when actively hiring. |
| `feedback@` | Dedicated channel for product feedback. Often redundant with `support@` at early stages. |
| `privacy@` | GDPR and privacy-related requests. Some privacy regulations expect a dedicated contact. Can alias to `legal@`. |
| `admin@` | Administrative and internal system notifications. Sometimes required by third-party service registrations. |

## Setup Strategy

For early-stage multi-product setups, the most cost-effective approach is:

1. **Enable a catch-all** on each domain via Cloudflare Email Routing (free, 200 rules per domain, unlimited volume).
2. **Forward everything** to a single Gmail or primary inbox.
3. **Configure Gmail "Send mail as"** to reply from each product domain.
4. **Add explicit routing rules** only when specific addresses need to go to different destinations (e.g., `billing@` to a finance team member).

This gives you full coverage across all standard addresses with zero per-address cost.
