# 03 — Domain & Cloudflare DNS  ✅ DONE (verify only)

**Status:** `pawdoc.app` is already registered and delegated to Cloudflare. No action needed — this runbook is for confirmation and future reference.

## Confirm it yourself

```bash
dig NS pawdoc.app +short
# expected:
#   mark.ns.cloudflare.com.
#   ivy.ns.cloudflare.com.
```

If you see the `*.ns.cloudflare.com` nameservers, the domain is registered and its DNS is managed by Cloudflare — the Phase 0.1 deliverable is met.

```bash
dig A pawdoc.app +short
# expected: empty for now
```
An empty apex `A` record is **correct** at this stage — there is no website to point to yet.

## DNS records added in later phases (not now)

| Record | Purpose | Added in |
|--------|---------|----------|
| Apex `A`/`CNAME` → landing page | `pawdoc.app` marketing site | 4.3 (or earlier if a holding page is wanted) |
| `MX` + SPF/DKIM/DMARC | `support@pawdoc.app` email | 2.2 |
| `terms` / `privacy` routes | ToS & Privacy pages | 2.2 |
| `blog`, `check` | SEO blog, web symptom checker | 3.4 / 4.3 / 5.2 |

Manage all of these in the Cloudflare dashboard → **Websites → pawdoc.app → DNS**.

## Account hygiene

- Enable 2FA on the Cloudflare account.
- Confirm domain **auto-renew** is ON at the registrar so the brand can't lapse.
