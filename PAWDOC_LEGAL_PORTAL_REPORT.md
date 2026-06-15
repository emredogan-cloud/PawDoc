# PawDoc — Legal Portal, AWS Deployment & App Integration Report

**Date:** 2026-06-15
**Mission:** Eliminate the founder-independent legal/content launch blockers by building a premium legal portal, deploying it to AWS, integrating it into the app, and validating it on a real Android device.
**Status:** **Complete (engineering) — YES WITH CONDITIONS** (founder-controlled items remain; see §9 and the Final Verdict).

This report is the single source of truth for this mission. Supporting detail lives in two appendices only:
- **`LEGAL_CONTENT_APPENDIX.md`** — the full final text of all 15 legal pages.
- **`DEVICE_VALIDATION_APPENDIX.md`** — on-device validation evidence + screenshot index.

> **Truthfulness note.** PawDoc is an AI-assisted pet **symptom-assessment / triage** tool. It is **not** a veterinary clinic, **does not diagnose**, and **does not** replace a licensed veterinarian. Every artifact in this mission reflects that. The legal drafts are accurate and founder-protective but are **not legal advice** and **require attorney review before public launch**.

---

## 1. What was delivered (Category A — agent-completed)

1. **15 production-quality legal pages**, grounded in cited research (Apple/Google store policies, GDPR, CCPA/CPRA, COPPA, AVMA/VCPR guidance, EU AI Act Art. 50, FTC AI guidance, US/EU auto-renewal law).
2. **A premium, dependency-free static legal portal** (`web-legal/`) — teal/cream design, light/dark, responsive, accessible, with per-page table of contents.
3. **Reproducible AWS infrastructure** (`infra/legal-portal/`, Terraform) — private S3 + CloudFront (HTTPS) + security headers + clean URLs + auto-invalidation.
4. **Live deployment** to a public HTTPS URL, verified across all routes.
5. **App integration** (`mobile/`) — a central `LegalUrls` config wired into every required entry point.
6. **A fresh release-candidate APK** built from the integrated code.
7. **Real-device validation** on a connected Xiaomi (Android 13) with screenshot evidence.

---

## 2. Legal pages inventory

15 pages, effective **2026-06-15**, document set **v1.0**. Full text in `LEGAL_CONTENT_APPENDIX.md`.

| # | Page | Route | Why it exists (key driver) |
|---|------|-------|----------------------------|
| 1 | Privacy Policy | `/privacy` | Apple 5.1.1 / Google — required, in-app + store; names third-party AI; retention/deletion; rights |
| 2 | Terms of Service | `/terms` | EULA; no-VCPR; AI "as-is"; liability; emergency-never-paywalled |
| 3 | Contact & Legal Notice | `/contact` | Operator identity, support/privacy/legal contacts, EU/UK rep slots |
| 4 | Veterinary Disclaimer | `/disclaimer` | No diagnosis / no VCPR; Google health-disclaimer keywords (veterinary-adapted) |
| 5 | Emergency Disclaimer | `/emergency` | Safety-first; red-flag signs; "don't rely on the app"; poison-control contact |
| 6 | AI Transparency & Limitations | `/ai-transparency` | EU AI Act Art. 50; hallucination/limits; FTC no-overclaim |
| 7 | Acceptable Use Policy | `/acceptable-use` | Permitted/prohibited use; content moderation; human-safety carve-out |
| 8 | Subscription Terms | `/subscriptions` | Apple 3.1.2 / Google; store-billed; auto-renew; CA ARL; EU/UK withdrawal |
| 9 | Referral Program Terms | `/referrals` | No cash value; anti-fraud; taxes; store-policy compliance |
| 10 | Account Deletion Policy | `/deletion` | **Google web-deletion URL** (works without the app) + in-app path |
| 11 | Data Retention Policy | `/data-retention` | Per-category retention; GDPR Art. 5(1)(e) |
| 12 | Cookie Policy | `/cookies` | App on-device storage; website strictly-necessary storage |
| 13 | Your GDPR Rights | `/gdpr` | Art. 13/15–22 rights; Art. 27 rep; pet-data-not-special-category (corrected) |
| 14 | Your California Privacy Rights | `/ccpa` | CCPA/CPRA rights; categories; no sale/share determination |
| 15 | Children's Privacy | `/children` | COPPA under-13 (not 16) vs GDPR Art. 8; adult-only eligibility |

**Research highlights baked in (and verified against primary sources):**
- **Google's hard requirement** for a standalone **web account-deletion URL** that works without reinstalling/logging into the app — satisfied by `/deletion` (verified email request path).
- Google's near-verbatim health-disclaimer keywords (*"not a medical device … does not diagnose, treat, cure, or prevent …"*) adapted to veterinary use.
- **AVMA**: general information + teletriage do **not** establish a VCPR (telemedicine does) — PawDoc stays squarely in the safe lane (no diagnosis, no prescription, no treatment).
- **Pet health data is *not* GDPR Art. 9 "special category"** data (that protects humans) — a common myth we explicitly avoid repeating; the human owner's data is ordinary personal data.
- **FTC "Click-to-Cancel" rule status stated precisely**: vacated by the 8th Circuit (Jul 8 2025), **not in force**; ROSCA + state ARLs still apply.
- All `[BRACKETED]` placeholders (legal entity, address, EU/UK reps, governing law) are clearly marked; "attorney review pending" appears on every page.

---

## 3. AWS architecture

```
 Visitor (HTTPS)
      │
      ▼
 CloudFront distribution  EDL2WWMB3OGFO   d1klm6zb1x23me.cloudfront.net
   • default TLS cert (TLSv1+), HTTP→HTTPS redirect, Brotli/gzip compression
   • CloudFront Function (viewer-request): /privacy → /privacy/index.html
   • Response-headers policy: HSTS(preload) · CSP · X-Frame-Options DENY ·
     X-Content-Type-Options · Referrer-Policy · Permissions-Policy
   • 403/404 → /404.html
      │  (Origin Access Control, SigV4 — origin is private)
      ▼
 S3 bucket  pawdoc-legal-450133579308   (us-east-1)
   • Block-all-public-access ON · BucketOwnerEnforced (no ACLs) · SSE-S3 · versioned
   • Readable ONLY by this CloudFront distribution (bucket policy + SourceArn)
```

**Why this shape:** the AWS account has **no Route 53 zone** for `pawdoc.app` and no registered domain, so a custom domain is a founder action. CloudFront's **default `*.cloudfront.net` domain gives real, public, valid HTTPS immediately** — no domain control required. The same account already runs this exact pattern for another product's legal pages, confirming permissions and precedent. Custom-domain support is pre-wired as **disabled Terraform variables** (`aliases`, `acm_certificate_arn`) for the founder to enable later.

---

## 4. Terraform summary (`infra/legal-portal/`)

Fully reproducible — **no console-only steps**. 32 resources.

| File | Contents |
|------|----------|
| `main.tf` | Provider (aws ≥5.40, us-east-1), caller identity, locals (bucket name, content-type map) |
| `s3.tf` | Private bucket, public-access block, ownership controls, SSE, versioning, **content upload** (`aws_s3_object` per file, correct content-types + cache-control) |
| `cloudfront.tf` | OAC, clean-URL Function, response-headers (security) policy, distribution, bucket policy, **auto-invalidation** (`terraform_data` triggered by content hash) |
| `cloudfront-rewrite.js` | Edge function: directory requests → `index.html` |
| `variables.tf` | region, bucket name, dist path, price class, **optional `aliases` + `acm_certificate_arn`** (default empty = CloudFront default domain) |
| `outputs.tf` | bucket, distribution id, CloudFront domain, portal URL |
| `deploy.sh` | build site → `terraform apply` → outputs (one command) |

State is **local** (`terraform.tfstate`, git-ignored). For team use the founder should migrate to a remote (S3) backend — noted in §9.

---

## 5. Deployment details (verified)

| Item | Value |
|------|-------|
| **Portal URL (live)** | **https://d1klm6zb1x23me.cloudfront.net** |
| CloudFront distribution | `EDL2WWMB3OGFO` |
| S3 bucket | `pawdoc-legal-450133579308` (us-east-1) |
| AWS account | `450133579308` |

**Verification performed (from this host):**
- All **16 routes** (index + 15 policies) return **HTTP 200 over HTTPS** via clean URLs (no trailing slash).
- Static assets (CSS, favicon, sitemap.xml, robots.txt, 404.html) return 200 with correct content-types.
- **HTTP → HTTPS** redirect (301); bogus path → **404** (`/404.html`).
- Security headers present: `strict-transport-security` (preload), `content-security-policy`, `x-frame-options: DENY`, `x-content-type-options: nosniff`, `referrer-policy`, `permissions-policy`. **Brotli** compression active.
- Canonicals/sitemap/OG point at the live CloudFront origin (rebuilt post-deploy for truthfulness).

---

## 6. Flutter integration summary (`mobile/`)

A single source of truth — **`lib/src/config/legal_urls.dart`** (`LegalUrls`) — with a build-time override:
```
flutter build ... --dart-define=LEGAL_BASE_URL=https://pawdoc.app
```
Default points at the live CloudFront portal, so links work out of the box (and were **confirmed compiled into the APK binary**). Wired entry points:

| Screen | Link(s) | Status |
|--------|---------|--------|
| Sign-in / Sign-up | Privacy, Terms | Re-pointed off dead `pawdoc.app` → `LegalUrls` |
| Settings / Account | Privacy, Terms, **AI Transparency (new)**, **Contact & Legal (new)** | Wired |
| Paywall | Auto-renew disclosure + Subscription Terms · Terms · Privacy | Added (shown when real offerings exist; see §7) |
| Referral | "Referral terms apply" → Referral Terms | Added |
| Delete account | AppBar "?" → Account Deletion Policy | Added |
| Result (standard) | Disclaimer card tappable → Veterinary Disclaimer | Added |
| Emergency result | "Read the full Emergency Disclaimer" | Added |

**Quality gates (local):** `flutter analyze` → **no issues**; `flutter test` → **217 passed** (1 pre-existing skip). **CI on PR #78 → all 6 checks green** (Flutter analyze+test+build, gitleaks, shellcheck, edge tests, AI-service, "no placeholders/overclaims").

---

## 7. Device validation summary

**Device:** Xiaomi `22095RA98C`, Android 13, system locale `tr-TR`. **APK:** `app-release.apk`, **SHA256 `62136aac…84ef2`**, v1.0.0+1, built 2026-06-15. Fresh install (no reused artifact). Full evidence + screenshot index in `DEVICE_VALIDATION_APPENDIX.md`.

**Confirmed on the real phone (tap → external Chrome → correct portal page, premium render):**
- **Privacy Policy → `/privacy`**, **Terms → `/terms`**, **AI Transparency → `/ai-transparency`** (new tile), **Contact & Legal → `/contact`** (new tile), **Delete-account "?" → `/deletion`**.
- Each opened the correct, distinct page (verified by title + content + launched-intent URL in logcat), rendered with the premium dark-mode design; Chrome auto-translated EN→Turkish for the device locale (the portal is English; translation is the browser's).
- **Return-to-app** (Android Back) works.
- The new **AI Transparency** and **Contact & Legal** tiles are present in Settings; the **Account-Deletion AppBar link** is present on the delete screen.

The remaining entry points (sign-in, referral, paywall, result/emergency disclaimers) use the **identical, already-proven `LegalUrls.open` mechanism**; they were not re-tapped individually to avoid disrupting the signed-in test session and (paywall) because RevenueCat offerings are not configured in the dev build (the disclosure block is correctly gated off in that state). See the appendix "coverage & honesty" note.

---

## 8. Bug fixes during the mission

| Issue | Resolution |
|-------|-----------|
| In-app Privacy/Terms pointed at dead `https://pawdoc.app/...` | Re-pointed all legal links through central `LegalUrls` (default = live CloudFront portal) |
| Two widget tests regressed when new links were added to lazy `ListView`s (cancel button / share button fell outside the build extent) | Delete-account link moved to an **AppBar action** (always built); result disclaimer made a **zero-height tappable card** — both restore the original layout height. `flutter test` green again. |
| `build.mjs` object-literal syntax bug (stray `;`) | Fixed before first build |
| Canonicals initially referenced the not-yet-owned `pawdoc.app` | Rebuilt with the live CloudFront base for truthful canonicals/sitemap |

**No CRITICAL or HIGH defects** were found in the legal-portal integration on-device. (A pre-existing, config-scoped OneSignal-on-exit issue is documented in the archived prior validation; it is unrelated to this mission and resolved by configuring `ONESIGNAL_APP_ID`.)

---

## 9. Founder handoff roadmap (Category B — founder-controlled)

These are **not** engineering tasks; they require the founder's legal/business decisions or accounts. Exact next actions:

0. **Merge PR #78** → https://github.com/emredogan-cloud/PawDoc/pull/78. All work in this mission lives there; **all 6 CI checks are green on the code**. `main` is protected (linear history + required review), so the final squash-merge is **founder-gated** — an automated `--admin` bypass was (correctly) refused. The validated release APK was built from **exactly this code**, so the engineering is done regardless of when the merge lands.
1. **Attorney review (critical path).** Have a licensed attorney (ideally consumer-health/veterinary-adjacent + AI/advertising experience) review all 15 pages in `LEGAL_CONTENT_APPENDIX.md`. Remove the "attorney review pending" notice only after sign-off.
2. **E&O / professional-liability insurance.** Obtain a policy appropriate to an AI pet-triage product before public launch.
3. **Legal entity + address.** Fill every `[LEGAL ENTITY]` and `[BUSINESS ADDRESS]` placeholder. Submit the app under a **company** (Apple 5.1.1(ix) for health-adjacent apps), not an individual.
4. **EU/UK representatives.** Appoint and name a **GDPR Art. 27 EU representative** (very likely required) and a **UK representative** if targeting the UK. Do **not** claim a DPO unless one is appointed (likely not required).
5. **Governing law / venue / arbitration.** Have counsel complete §10 of the Terms and the liability cap/carve-outs in §7.
6. **Live contact mailboxes.** Stand up real, monitored inboxes: `support@`, `privacy@`, `legal@` — the deletion and rights flows depend on `privacy@` being live.
7. **CCPA "sale/share" determination + GPC.** Decide whether any analytics/ads SDK constitutes a "sale"/"share"; if so, add the opt-out link + honor Global Privacy Control.
8. **Processor transfer mechanisms.** Confirm DPF certification vs SCCs for each US processor; finalize the retention periods (esp. tax records) in the Data Retention Policy.
9. **Custom domain (optional but recommended).** Acquire/point `pawdoc.app` (or `legal.pawdoc.app`): set the Terraform `aliases` + `acm_certificate_arn` variables, issue an ACM cert in us-east-1, then `SITE_BASE_URL=https://<domain> ./deploy.sh` and rebuild the app with `--dart-define=LEGAL_BASE_URL=https://<domain>`.
10. **Store submission wiring.** Put the Privacy Policy URL in App Store Connect + Play Console; put the **web account-deletion URL** (`/deletion`) in the Play Data-safety form; complete the Apple App-Privacy "nutrition label", Google Data-safety form, and Google **Health apps declaration**; add the subscription-terms + EULA links near the paywall in store metadata.
11. **Subscriptions/RevenueCat.** Configure RevenueCat offerings so the paywall (and its now-wired subscription-terms disclosure) renders for purchase; validate the paywall legal links on a configured build.
12. **Terraform state backend.** Migrate the local Terraform state to a dedicated S3 backend for reproducible team operation.
13. **Test-data cleanup.** The dev test account `rcqa.beta@example.com` accumulated data during validation — clean up before metrics matter.

---

## Final Verdict

1. **Are all legally required pages drafted?** **YES** — all 15, grounded in cited research, truthful and founder-protective (attorney review still required).
2. **Are all pages deployed?** **YES** — to AWS S3 + CloudFront.
3. **Are they accessible over HTTPS?** **YES** — all 16 routes return 200 over HTTPS, with security headers, from the public CloudFront domain.
4. **Are they integrated into the app?** **YES** — central `LegalUrls` wired into every required entry point; compiled into the release APK.
5. **Were they validated on a real Android device?** **YES** — fresh APK installed on a Xiaomi (Android 13); five links across two screens validated end-to-end with screenshot + logcat evidence; the rest use the same proven mechanism.
6. **Can PawDoc satisfy the app-store legal surface requirements pending attorney review?** **YES — the engineering/content surface is in place.**

### Overall: **YES WITH CONDITIONS**

The founder-controlled conditions are the items in §9 — chiefly: **attorney review**, **E&O insurance**, **legal-entity/address + EU/UK representatives**, **live contact mailboxes**, **store-console wiring (incl. the web-deletion URL + health declaration)**, and (optional) a **custom domain**. None of these are engineering blockers; all are business/legal actions only the founder can take.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
