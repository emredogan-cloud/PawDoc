# PawDoc Web — landing page + SEO blog

Static **Next.js (App Router)** site. `output: 'export'` emits plain HTML/JS into
`out/`, so it hosts for **free on Cloudflare Pages with no Node server** (Phase 4.3
strict rule).

## Local

```bash
npm install
npm run build      # -> ./out (fully static)
npx serve out      # optional local preview
```

## Deploy to Cloudflare Pages

- **Root directory:** `web`
- **Build command:** `npm run build`
- **Build output directory:** `out`
- **Framework preset:** Next.js (Static HTML Export) — or "None"
- **Node version:** 20+ (set `NODE_VERSION=20` if Pages defaults lower)
- **Environment variables:** none required

Point the `pawdoc.app` domain at the Pages project (runbook 03 DNS).

## Blog (MDX)

Articles are MDX pages at `app/blog/<slug>/page.mdx`, each with
`export const metadata` for SEO (`title`, `description`, `alternates.canonical`,
`openGraph`). `metadataBase` in `app/layout.tsx` resolves canonical paths to
absolute `https://pawdoc.app/...` URLs.

**To add an article:** create `app/blog/<slug>/page.mdx` + add a row to the list
in `app/blog/page.tsx`. Only **one** article ships here (Phase 4.3); the rest is a
founder/content task.

## Assets

Replace the placeholder screenshot boxes + store-badge hrefs in `app/page.tsx`
with real assets dropped into `public/` (and the real App Store / Play URLs).
