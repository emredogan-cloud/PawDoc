# SUB-PR Report — Phase 4.3: Web Presence & Paid Acquisition

**Status:** Complete and verified by a **real static build** (`next build` → static export, green) plus shellcheck. Next.js landing page + MDX blog (one article) on a Cloudflare-Pages-ready static export, and the paid-acquisition runbook.
**Branch:** `phase-4.3-web-presence` (from `origin/main` = `b636711`, contains 0.1→4.2)
**Date:** 2026-05-28
**Scope note:** the roadmap lists **10** SEO articles, Search Console, and live campaigns; per your strict rules I shipped **exactly one** article (infra proof) and a **runbook** for the campaigns — the rest is founder/content/ops work. The remaining roadmap-3.4 items (widgets, Android parity, Airvet) are also still out of scope.

---

## 1. Files created / modified

**New `web/` project (static Next.js, App Router):**
```
web/package.json            next 15 + react 19 + @next/mdx; scripts: dev, build
web/next.config.mjs         output: 'export' + @next/mdx + images.unoptimized + trailingSlash
web/tsconfig.json           Next TS config
web/mdx-components.tsx       required by @next/mdx (App Router)
web/.gitignore              ignores node_modules/.next/out/next-env.d.ts
web/README.md               Cloudflare Pages deploy instructions
web/app/layout.tsx          root layout + metadataBase + default SEO/OpenGraph
web/app/globals.css         lightweight styling (no Tailwind dependency)
web/app/page.tsx            landing: value prop, App Store/Play badges, screenshots, testimonials
web/app/blog/page.tsx       blog index (lists the article)
web/app/blog/when-to-take-your-dog-to-the-vet-for-vomiting/page.mdx   the SEO article (+ metadata)
```
**Docs / scripts:**
```
docs/runbooks/20-paid-acquisition.md   Apple Search Ads (5 exact-match) + TikTok ($500) + PostHog CPI/LTV:CAC
scripts/verify-phase-4.3.sh            phase verifier (structural + a real next build)
sub-pr-report/SUBPR_PHASE_4.3.md       this report
```
**Not committed (gitignored):** `web/node_modules`, `web/.next`, `web/out`, `web/next-env.d.ts` (Next regenerates the latter on build). **No new secrets/env** — the static site needs none.

## 2. Cloudflare Pages configuration (no Node server)

`web/next.config.mjs` sets **`output: "export"`**, so `next build` emits a fully static site into **`out/`** (plain HTML/JS — no server, no SSR). Also `images: { unoptimized: true }` (the Image Optimization server can't run in a static export) and `trailingSlash: true` (stable directory URLs on Pages).

**Cloudflare Pages settings (in `web/README.md`):**
- Root directory: `web`
- Build command: `npm run build`
- Build output directory: `out`
- Node version: 20+
- Environment variables: none

This satisfies the strict rule — the landing page + blog host for free on Pages with **no Node server**.

## 3. The placeholder MDX article renders with proper SEO metadata (proven)

The article is an MDX **page** at `app/blog/when-to-take-your-dog-to-the-vet-for-vomiting/page.mdx` that `export const metadata = { title, description, alternates: { canonical }, openGraph }`. `metadataBase` (in `layout.tsx`) resolves the canonical path to an absolute URL.

**Proven by the real build** (`npm run build`, then inspecting `out/.../index.html`):
- `<title>When to Take Your Dog to the Vet for Vomiting · PawDoc</title>` (title template applied)
- `<meta name="description" content="How to tell normal tummy upset from a real emergency in dogs …">`
- `<link rel="canonical" href="https://pawdoc.app/blog/when-to-take-your-dog-to-the-vet-for-vomiting/"/>`
- The article body renders (heading + content), ending with the **"not a veterinary diagnosis"** safety framing + an emergency-first "call the vet now" section (on-brand with the app's safety posture).

`verify-phase-4.3.sh` re-runs `next build` (when deps are present) and asserts the exported article HTML contains the canonical link — so the SEO infra is checked, not just asserted.

## 4. Build / verification results

| Check | Result |
|------|--------|
| `npm install` (web) | 142 packages, OK |
| `npm run build` (`output: 'export'`) | **✓ Compiled + Exporting (2/2)** — 4 routes prerendered **static** (`/`, `/blog`, the article, `/_not-found`) |
| Exported article SEO | title + description + **canonical** present in `out/.../index.html` |
| `./scripts/verify-phase-4.3.sh` | **exit 0** — structural + real build + canonical assertion; 4 MANUAL |
| `shellcheck` (verifier) | **clean** |

(Mobile/AI/Edge untouched this phase — no Flutter/pytest/node changes needed.)

## 5. Paid-acquisition runbook (20)

`docs/runbooks/20-paid-acquisition.md` covers: the **price-discovery** mindset + the **LTV:CAC > 3** gate (CR #15); **Apple Search Ads** with **5 exact-match keywords** + daily/budget caps + Apple Ads Attribution; a **TikTok $500** hard-cap test; and **how to track CPI / cost-per-trial / CAC per channel in PostHog** (mapping `trial_started` / `subscription_converted`, channel as a person property, cost from the ad dashboards) to prove LTV:CAC — with a stop-loss/scale gate.

## 6. Surfaced / deferred

- **`/terms` + `/privacy` pages** (which runbook 18 said would land with this site) are **deferred** — they need the **attorney-final** content from the Phase 2.2 legal gate; shipping placeholder legal text would be worse than none. Footer notes where they'll live. Flag for when legal is finalized.
- Screenshots + store-badge URLs are **placeholders** (clearly marked) — drop real assets into `web/public/` and set the real store URLs.
- Exactly **one** article ships (strict rule); adding more = a new `app/blog/<slug>/page.mdx` + a row in the index.

## 7. Git branch / commit / push

- Branch: `phase-4.3-web-presence`
- Implementation commit (deliverables): `<filled post-commit>`
- Push: `<filled post-push>`

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Next.js landing page (value prop, badges, screenshots, social proof) | ✅ DONE | `app/page.tsx`; build green |
| Static export for Cloudflare Pages (no Node server) | ✅ DONE | `output: 'export'` → `out/`; README |
| MDX blog infrastructure | ✅ DONE | `@next/mdx` + `mdx-components.tsx`; build green |
| 1 SEO article with proper metadata | ✅ DONE | `page.mdx` + canonical in exported HTML |
| Paid-acquisition runbook (ASA + TikTok + CPI/LTV:CAC) | ✅ DONE | `docs/runbooks/20-paid-acquisition.md` |
| Deploy to Pages + Search Console + live campaigns | ⏳ MANUAL | founder (runbook 20) |
| 10 articles | ⏳ CONTENT | founder (infra proven) |

**Verified now:** the site builds to a static export, the landing page + blog index + MDX article all prerender, and the article carries title/description/**canonical** SEO metadata (confirmed in the built HTML). Stopping for approval — this completes Phase 4's engineering scope (4.1–4.3).
