#!/usr/bin/env node
// PawDoc Legal Portal — static site generator.
// Reads content/*.md (frontmatter + markdown) and emits a premium static site
// to dist/: an index landing page + one clean-URL page per policy, a shared
// header/footer/TOC, robots.txt and sitemap.xml. Zero runtime dependencies.
//
//   node build.mjs                 # build into ./dist
//   SITE_BASE_URL=https://… node build.mjs

import { readFileSync, writeFileSync, readdirSync, mkdirSync, rmSync, cpSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { renderMarkdown, slugify } from "./lib/markdown.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = __dirname;
const DIST = join(ROOT, "dist");

// ---- Site configuration ----------------------------------------------------
const SITE = {
  name: "PawDoc",
  tagline: "Legal & Trust Center",
  // Canonical base; override at build time once the final domain is live.
  baseUrl: (process.env.SITE_BASE_URL || "https://pawdoc.app").replace(/\/$/, ""),
  contactEmail: "support@pawdoc.app",
  privacyEmail: "privacy@pawdoc.app",
  version: "v1.0",
  effective: process.env.LEGAL_EFFECTIVE_DATE || "2026-06-15",
  buildDate: process.env.LEGAL_BUILD_DATE || new Date().toISOString().slice(0, 10),
};

// Category order + presentation on the index page.
const CATEGORIES = [
  { id: "essentials", label: "Essentials", blurb: "Start here." },
  { id: "safety", label: "Safety & AI", blurb: "How PawDoc helps — and its limits." },
  { id: "billing", label: "Billing", blurb: "Subscriptions." },
  { id: "data", label: "Your Data & Rights", blurb: "Privacy controls and regional rights." },
];

// ---- Icons (Lucide-style, 24px stroke) ------------------------------------
const S = (p) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`;
const ICONS = {
  paw: S('<circle cx="6.5" cy="10" r="1.8"/><circle cx="11" cy="7" r="1.8"/><circle cx="16" cy="7.6" r="1.8"/><circle cx="19" cy="11.5" r="1.6"/><path d="M8.5 14.5c1.8-2.4 5.2-2.4 7 0 .9 1.2 2.4 2.1 2.2 3.8-.2 1.6-1.9 2-3.3 1.5-1.6-.6-2.8-.6-4.4 0-1.4.5-3.1.1-3.3-1.5-.2-1.7 1.3-2.6 1.8-3.8Z"/>'),
  shield: S('<path d="M12 3 5 6v5c0 4.3 2.9 7.7 7 9 4.1-1.3 7-4.7 7-9V6l-7-3Z"/><path d="m9 12 2 2 4-4"/>'),
  doc: S('<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h6"/>'),
  stethoscope: S('<path d="M5 3v5a4 4 0 0 0 8 0V3"/><path d="M5 3H4M13 3h1"/><path d="M9 16a5 5 0 0 0 9 3"/><circle cx="19.5" cy="14.5" r="2"/>'),
  alert: S('<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>'),
  cpu: S('<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 9h6v6H9z"/><path d="M9 2v2M15 2v2M9 20v2M15 20v2M2 9h2M2 15h2M20 9h2M20 15h2"/>'),
  card: S('<rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20M6 15h4"/>'),
  gift: S('<path d="M20 12v8H4v-8"/><path d="M2 7h20v5H2zM12 22V7"/><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7ZM12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7Z"/>'),
  trash: S('<path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/>'),
  cookie: S('<path d="M12 3a9 9 0 1 0 9 9 3 3 0 0 1-3-3 3 3 0 0 1-3-3 3 3 0 0 1-3-3Z"/><path d="M8.5 10h.01M13 14h.01M9 16h.01M16 11h.01"/>'),
  clock: S('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  child: S('<circle cx="12" cy="5" r="2.2"/><path d="M12 8v7M9 22l3-4 3 4M8 12h8"/>'),
  globe: S('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 3.5 6 3.5 9s-1 6.5-3.5 9c-2.5-2.5-3.5-6-3.5-9s1-6.5 3.5-9Z"/>'),
  flag: S('<path d="M5 21V4M5 4h11l-1.5 4L16 12H5"/>'),
  scale: S('<path d="M12 3v18M7 21h10M5 7h14l-3 6a3 3 0 0 1-6 0L5 7Z"/><path d="m5 7-2 5a2.5 2.5 0 0 0 5 0M19 7l2 5a2.5 2.5 0 0 1-5 0"/>'),
  ban: S('<circle cx="12" cy="12" r="9"/><path d="m5.6 5.6 12.8 12.8"/>'),
  mail: S('<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m3 7 9 6 9-6"/>'),
  leaf: S('<path d="M11 20A7 7 0 0 1 4 13c0-5 4-9 16-9 0 9-5 13-9 13Z"/><path d="M4 20c3-5 6-7 10-9"/>'),
  arrow: S('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  back: S('<path d="M19 12H5M11 6l-6 6 6 6"/>'),
};

// ---- Frontmatter parser ----------------------------------------------------
function parsePage(file) {
  const raw = readFileSync(file, "utf8");
  const m = raw.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) throw new Error(`Missing frontmatter in ${file}`);
  const meta = {};
  for (const line of m[1].split("\n")) {
    const mm = line.match(/^(\w+):\s*(.*)$/);
    if (mm) meta[mm[1]] = mm[2].replace(/^["']|["']$/g, "").trim();
  }
  meta.order = Number(meta.order || 999);
  return { meta, body: m[2] };
}

// ---- HTML helpers ----------------------------------------------------------
const head = (page) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${page.title} · ${SITE.name}</title>
<meta name="description" content="${page.description || page.summary || ""}"/>
<link rel="canonical" href="${SITE.baseUrl}${page.path}"/>
${page.noindex ? '<meta name="robots" content="noindex"/>' : ""}
<meta property="og:title" content="${page.title} · ${SITE.name}"/>
<meta property="og:description" content="${page.summary || ""}"/>
<meta property="og:type" content="website"/>
<meta property="og:url" content="${SITE.baseUrl}${page.path}"/>
<meta name="theme-color" content="#0e7c6b" media="(prefers-color-scheme: light)"/>
<meta name="theme-color" content="#0c1714" media="(prefers-color-scheme: dark)"/>
<link rel="icon" href="/assets/favicon.svg" type="image/svg+xml"/>
<link rel="stylesheet" href="/styles/portal.css"/>
<script>
  // Apply saved theme before paint to avoid a flash.
  try {
    var t = localStorage.getItem("pawdoc-theme");
    if (t) document.documentElement.setAttribute("data-theme", t);
  } catch (e) {}
</script>
</head>`;

const header = () => `<a class="skip-link" href="#main">Skip to content</a>
<header class="site-header">
  <div class="site-header__inner">
    <a class="brand" href="/" aria-label="${SITE.name} home">
      <span class="brand__mark">${ICONS.paw}</span>
      <span class="brand__word">${SITE.name}<small>${SITE.tagline}</small></span>
    </a>
    <span class="header-spacer"></span>
    <nav class="header-nav" aria-label="Primary">
      <a href="/">All policies</a>
      <a href="/contact/">Contact</a>
    </nav>
    <button class="theme-toggle" type="button" aria-label="Toggle dark mode" data-theme-toggle>
      <span class="icon-moon">${S('<path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8Z"/>')}</span>
      <span class="icon-sun">${S('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4 12H2M22 12h-2M5 5l1.5 1.5M17.5 17.5 19 19M19 5l-1.5 1.5M6.5 17.5 5 19"/>')}</span>
    </button>
  </div>
</header>`;

function footer(pages) {
  const cols = CATEGORIES.map((c) => {
    const items = pages
      .filter((p) => p.category === c.id)
      .map((p) => `<li><a href="${p.path}">${p.navTitle || p.title}</a></li>`)
      .join("");
    return `<div class="footer-col"><h4>${c.label}</h4><ul>${items}</ul></div>`;
  }).join("");
  return `<footer class="site-footer">
  <div class="container">
    <div class="footer-grid">
      <div class="footer-brand">
        <a class="brand" href="/"><span class="brand__mark">${ICONS.paw}</span><span class="brand__word">${SITE.name}<small>${SITE.tagline}</small></span></a>
        <p>AI-assisted pet-health triage. PawDoc gives general guidance and urgency triage — it does not diagnose, and it is not a substitute for a licensed veterinarian.</p>
      </div>
      ${cols}
    </div>
    <div class="footer-disclaimer">
      <p><strong>Not veterinary advice.</strong> PawDoc provides general educational information and urgency guidance generated with the help of AI. It does not diagnose, prescribe, or treat, and using it does not create a veterinarian-client-patient relationship. In an emergency, contact a veterinarian or an animal poison control center immediately. These documents are provided for transparency and are pending final review by a licensed attorney.</p>
    </div>
    <div class="footer-bottom">
      <span>© ${SITE.effective.slice(0, 4)} ${SITE.name}. All rights reserved.</span>
      <span>Document set ${SITE.version} · Effective ${SITE.effective}</span>
    </div>
  </div>
</footer>
<script>
(function () {
  var root = document.documentElement;
  var btn = document.querySelector("[data-theme-toggle]");
  if (btn) btn.addEventListener("click", function () {
    var cur = root.getAttribute("data-theme");
    if (!cur) cur = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    var next = cur === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try { localStorage.setItem("pawdoc-theme", next); } catch (e) {}
  });
  // TOC scroll-spy
  var links = [].slice.call(document.querySelectorAll(".toc a"));
  if (links.length && "IntersectionObserver" in window) {
    var map = {};
    links.forEach(function (a) { map[a.getAttribute("href").slice(1)] = a; });
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          links.forEach(function (l) { l.classList.remove("is-active"); });
          if (map[e.target.id]) map[e.target.id].classList.add("is-active");
        }
      });
    }, { rootMargin: "-15% 0px -75% 0px" });
    document.querySelectorAll(".prose h2[id]").forEach(function (h) { obs.observe(h); });
  }
})();
</script>`;
}

// ---- Page renderers --------------------------------------------------------
function policyPage(page, pages, prev, next) {
  const { html, headings } = renderMarkdown(page.body);
  const toc = headings.filter((h) => h.level === 2);
  const tocHtml = toc.length
    ? `<aside class="toc" aria-label="On this page"><div class="toc__label">On this page</div><ul>${toc
        .map((h) => `<li><a href="#${h.id}">${h.text}</a></li>`)
        .join("")}</ul></aside>`
    : "";
  const cat = CATEGORIES.find((c) => c.id === page.category);
  const navFoot = [
    prev ? `<a class="back-all" href="${prev.path}">${ICONS.back}<span>${prev.navTitle || prev.title}</span></a>` : "<span></span>",
    next ? `<a class="back-all" href="${next.path}"><span>${next.navTitle || next.title}</span>${ICONS.arrow}</a>` : "<span></span>",
  ].join("");

  return `${head(page)}
<body>
${header()}
<section class="hero fade-up">
  <div class="hero__icon">${ICONS[page.icon] || ICONS.doc}</div>
  <div class="hero__eyebrow">${ICONS.leaf}${cat ? cat.label : "Legal"}</div>
  <h1>${page.title}</h1>
  ${page.summary ? `<p class="hero__sub">${page.summary}</p>` : ""}
  <div class="hero__meta">
    <span><b>Effective</b> ${page.effective || SITE.effective}</span><span class="dot"></span>
    <span><b>Last updated</b> ${page.updated || SITE.effective}</span><span class="dot"></span>
    <span><b>Version</b> ${SITE.version}</span>
  </div>
</section>
<main id="main" class="page ${toc.length ? "has-toc" : ""}">
  <article class="doc fade-up-2">
    <div class="notice"><span>${ICONS.scale}</span><div><strong>Attorney review pending.</strong> This document was prepared to be accurate and protective, but it has <strong>not yet been reviewed by a licensed attorney</strong> and is not legal advice. It will be finalized before public launch. Questions: <a href="mailto:${SITE.contactEmail}">${SITE.contactEmail}</a>.</div></div>
    <div class="prose">
${html}
    </div>
    <div class="doc-foot">${navFoot}</div>
    <p style="max-width:var(--measure);margin-top:24px"><a class="back-all" href="/">${ICONS.back}<span>Back to all policies</span></a></p>
  </article>
  ${tocHtml}
</main>
${footer(pages)}
</body>
</html>`;
}

function indexPage(pages) {
  const page = {
    title: "Legal & Trust Center",
    summary:
      "Transparency about how PawDoc works, how we protect your information, and the rules that keep pets safe.",
    description:
      "PawDoc's Legal & Trust Center — privacy, terms, veterinary and emergency disclaimers, AI transparency, subscriptions, and your data rights.",
    path: "/",
  };
  const cats = CATEGORIES.map((c) => {
    const cards = pages
      .filter((p) => p.category === c.id)
      .map(
        (p) => `<a class="policy-card" href="${p.path}">
        <span class="policy-card__icon">${ICONS[p.icon] || ICONS.doc}</span>
        <h3>${p.title}</h3>
        <p>${p.summary || ""}</p>
        <span class="policy-card__more">Read ${ICONS.arrow}</span>
      </a>`
      )
      .join("");
    return `<section class="cat fade-up-2"><div class="cat__head"><h2>${c.label}</h2><span>${c.blurb}</span></div><div class="card-grid">${cards}</div></section>`;
  }).join("");

  return `${head(page)}
<body>
${header()}
<section class="hero fade-up">
  <div class="hero__eyebrow">${ICONS.leaf}PawDoc</div>
  <h1>Legal &amp; Trust Center</h1>
  <p class="hero__sub">${page.summary}</p>
  <div class="hero__meta"><span><b>Document set</b> ${SITE.version}</span><span class="dot"></span><span><b>Effective</b> ${SITE.effective}</span></div>
</section>
<main id="main" class="container" style="padding-bottom:80px">
  <div class="index-intro fade-up-2">
    <div class="notice"><span>${ICONS.stethoscope}</span><div><strong>PawDoc is not a veterinarian and does not diagnose.</strong> It offers general educational information and urgency guidance — an action from "get help now" through "watch and re-check," never a statement that your pet is normal — generated with the help of AI, and always directs you to a licensed veterinarian. In an emergency, contact an emergency vet or animal poison control immediately.</div></div>
  </div>
  ${cats}
</main>
${footer(pages)}
</body>
</html>`;
}

function notFoundPage(pages) {
  const page = { title: "Page not found", summary: "", description: "Page not found", path: "/404", noindex: true };
  return `${head(page)}
<body>
${header()}
<main id="main" class="container" style="padding:80px 24px;text-align:center">
  <div class="hero__icon" style="margin:0 auto 20px">${ICONS.paw}</div>
  <h1 style="font-family:var(--font-serif);font-size:2rem">This page wandered off</h1>
  <p style="color:var(--text-muted);margin-top:12px">We couldn't find that document. Browse the full list instead.</p>
  <p style="margin-top:24px"><a class="back-all" href="/" style="justify-content:center">${ICONS.back}<span>Back to all policies</span></a></p>
</main>
${footer(pages)}
</body>
</html>`;
}

// ---- Build -----------------------------------------------------------------
function build() {
  rmSync(DIST, { recursive: true, force: true });
  mkdirSync(DIST, { recursive: true });

  const dir = join(ROOT, "content");
  const pages = readdirSync(dir)
    .filter((f) => f.endsWith(".md"))
    .map((f) => {
      const { meta, body } = parsePage(join(dir, f));
      return { ...meta, body, path: `/${meta.slug}/` };
    })
    .sort((a, b) => a.order - b.order);

  // policy pages with prev/next within the sorted list
  pages.forEach((p, i) => {
    const out = policyPage(p, pages, pages[i - 1], pages[i + 1]);
    const d = join(DIST, p.slug);
    mkdirSync(d, { recursive: true });
    writeFileSync(join(d, "index.html"), out);
  });

  writeFileSync(join(DIST, "index.html"), indexPage(pages));
  writeFileSync(join(DIST, "404.html"), notFoundPage(pages));

  // assets + styles
  cpSync(join(ROOT, "styles"), join(DIST, "styles"), { recursive: true });
  cpSync(join(ROOT, "assets"), join(DIST, "assets"), { recursive: true });

  // robots + sitemap
  writeFileSync(
    join(DIST, "robots.txt"),
    `User-agent: *\nAllow: /\nSitemap: ${SITE.baseUrl}/sitemap.xml\n`
  );
  const urls = ["/", ...pages.map((p) => p.path)]
    .map(
      (u) =>
        `  <url><loc>${SITE.baseUrl}${u}</loc><lastmod>${SITE.buildDate}</lastmod></url>`
    )
    .join("\n");
  writeFileSync(
    join(DIST, "sitemap.xml"),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`
  );

  console.log(`Built ${pages.length} policy pages + index → ${DIST}`);
  console.log(`Base URL: ${SITE.baseUrl}`);
  pages.forEach((p) => console.log(`  ${p.path.padEnd(22)} ${p.title}`));
}

build();
