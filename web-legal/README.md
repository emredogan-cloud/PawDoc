# PawDoc Legal Portal (`web-legal/`)

A dependency-free static site for PawDoc's legal & trust pages (Privacy, Terms,
Veterinary/Emergency disclaimers, AI Transparency, Subscriptions, Referrals,
Account Deletion, Cookies, Data Retention, Children, GDPR, CCPA, Acceptable Use,
Contact). Markdown source → custom Node SSG → premium teal/cream HTML/CSS.
Deployed to AWS S3 + CloudFront (see `../infra/legal-portal/`).

## Layout

```
content/        15 legal pages as Markdown + frontmatter (single source of truth)
lib/markdown.mjs  minimal Markdown→HTML renderer (no deps)
build.mjs       SSG: renders content/ + templates → dist/
styles/portal.css  design system (light/dark, responsive, a11y, print)
assets/         favicon
dist/           build output (gitignored)
```

## Build

```bash
node build.mjs                              # → dist/
SITE_BASE_URL=https://legal.example node build.mjs   # set canonical/sitemap base
```

No `npm install` needed — pure Node (>=18), zero runtime dependencies.

## Editing content

Each page is one `content/*.md` file with frontmatter:

```yaml
---
title: Privacy Policy
slug: privacy            # → /privacy/
order: 1                 # sort order
category: essentials     # essentials | safety | billing | data
icon: shield             # key in build.mjs ICONS
effective: 2026-06-15
updated: 2026-06-15
summary: One-line summary shown in hero + index card.
---
## Markdown body…
```

Supported Markdown: `##`/`###` headings (auto-anchored + TOC), paragraphs,
`-`/`1.` lists (one nesting level), `**bold**`, `*italic*`, `` `code` ``,
`[links](url)`, pipe tables, `---` rules, blockquotes, and admonitions
`> [!NOTE] / [!WARNING] / [!EMERGENCY]`.

## Deploy

See `../infra/legal-portal/README.md` (`terraform apply`, or `./deploy.sh`).
