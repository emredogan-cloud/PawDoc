#!/usr/bin/env node
// Assembles LEGAL_CONTENT_APPENDIX.md (repo root) from the final content/*.md
// legal texts, in frontmatter `order`. The legal Markdown is the single source
// of truth; this just concatenates it with a header + table of contents.
//   node web-legal/lib/build-appendix.mjs

import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CONTENT = join(ROOT, "content");
const OUT = join(ROOT, "..", "LEGAL_CONTENT_APPENDIX.md");
const PORTAL = process.env.PORTAL_URL || "https://d1klm6zb1x23me.cloudfront.net";

const pages = readdirSync(CONTENT)
  .filter((f) => f.endsWith(".md"))
  .map((f) => {
    const raw = readFileSync(join(CONTENT, f), "utf8");
    const m = raw.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
    const meta = {};
    for (const line of m[1].split("\n")) {
      const mm = line.match(/^(\w+):\s*(.*)$/);
      if (mm) meta[mm[1]] = mm[2].replace(/^["']|["']$/g, "").trim();
    }
    return { ...meta, order: Number(meta.order || 999), body: m[2].trim() };
  })
  .sort((a, b) => a.order - b.order);

const toc = pages
  .map((p, i) => `${i + 1}. [${p.title}](#${i + 1}-${p.slug}) — \`/${p.slug}\``)
  .join("\n");

const sections = pages
  .map((p, i) => {
    return `<a id="${i + 1}-${p.slug}"></a>

## ${i + 1}. ${p.title}

**Live URL:** ${PORTAL}/${p.slug} · **Slug:** \`/${p.slug}\` · **Effective:** ${p.effective} · **Last updated:** ${p.updated}

${p.body}

---`;
  })
  .join("\n\n");

const doc = `# PawDoc — Legal Content Appendix

> **Supporting Appendix 1** to \`PAWDOC_LEGAL_PORTAL_REPORT.md\`. Contains the final text of all 15 legal pages, exactly as deployed to the public legal portal.

- **Portal (live, public HTTPS):** ${PORTAL}
- **Effective date:** 2026-06-15
- **Document set version:** v1.0
- **Source of truth:** \`web-legal/content/*.md\` (rendered to HTML by \`web-legal/build.mjs\`)

> ⚠️ **Attorney review required before public launch.** These drafts were prepared to be accurate, truthful, and founder-protective, and are grounded in cited research (Apple/Google store policies, GDPR, CCPA/CPRA, COPPA, AVMA/VCPR guidance, EU AI Act Art. 50, FTC AI guidance, and US/EU auto-renewal law). They are **not legal advice** and have **not** been reviewed by a licensed attorney. All \`[BRACKETED]\` values are placeholders the operator must complete (legal entity, address, EU/UK representatives, governing law, contact mailboxes). Nothing here claims PawDoc diagnoses animals or replaces a veterinarian.

## Contents

${toc}

---

${sections}

*End of Legal Content Appendix — ${pages.length} documents.*
`;

writeFileSync(OUT, doc);
console.log(`Wrote ${OUT} (${pages.length} documents, ${doc.length} bytes)`);
