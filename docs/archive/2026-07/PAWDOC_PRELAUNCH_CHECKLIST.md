# PawDoc — Pre-Launch Checklist ("Submit for Review")

**Date:** 2026-07-18 · Consolidates every remaining item from `PAWDOC_STORE_REVIEW_FINAL.md`, `PAWDOC_FINAL_PRODUCTION_REPORT.md`, and the environment audit. Engineering-addressable items were **already fixed** this cycle (see the store review §A); everything below is **founder / legal / vet / console** work.

Each item: **explanation · owner · effort · blocking status.**

---

## 🔴 CRITICAL — submission cannot pass without these

1. **Android upload keystore + Play App Signing** — the release build's signing config is wired to read `android/key.properties`, but the keystore itself must be generated and enrolled; Play auto-rejects debug-signed AABs. · **Owner:** Founder · **Effort:** 1–2h · **Blocking:** Google Play (hard).

2. **iOS distribution signing + Apple Developer account** — no `DEVELOPMENT_TEAM`/distribution cert; you cannot produce an App Store archive without them. · **Owner:** Founder (needs a Mac + Apple Developer membership) · **Effort:** 1–3h once the account exists · **Blocking:** Apple (hard).

3. **Finalize + re-deploy the legal portal** — the deployed Privacy/Terms still carry entity placeholders (`[LEGAL ENTITY]`, `[BUSINESS ADDRESS]`, `[EU/UK REPRESENTATIVE]`), an unspecified liability cap (`[12] months / [USD 50]`), and counsel brackets. A privacy policy without a named controller is incomplete → rejection. The **source** content fixes (incl. the "likely normal" purge) are done; the portal must be **rebuilt + re-deployed to AWS**. · **Owner:** Founder + Legal · **Effort:** 2–4h + counsel · **Blocking:** both stores.

4. **RevenueCat products + store IAP** — create the offering/entitlement + App Store Connect/Play subscription products, submit them **with** the binary, and confirm **real localized prices** render (the paywall shows "Premium is coming soon" and hardcoded `$39.99/$6.99` when offerings are absent — a reviewer must never see either). · **Owner:** Founder · **Effort:** 2–4h · **Blocking:** subscription review (Apple 3.1.2 / Play).

5. **App-review demo account** — the app auth-gates before use; reviewers need working credentials (fill the placeholders in the iOS metadata + Play "app access"). · **Owner:** Founder · **Effort:** 15 min · **Blocking:** Apple 2.1.

6. **Data Safety form / privacy nutrition label** — declare all collected data: email, pet profile, uploaded photos, **plus product analytics (PostHog, opt-in)** and **crash diagnostics (Sentry, PII-stripped)**. An omission is an inaccurate disclosure. · **Owner:** Founder · **Effort:** 1h · **Blocking:** Play (and Apple label accuracy).

7. **Domain + mailbox decision** — store review notes and all legal mailboxes use `pawdoc.app` (not live); the app links to the CloudFront portal. Either stand up `pawdoc.app` + `support@/privacy@/legal@` mailboxes, **or** use the CloudFront URLs consistently in the app, App Store Connect, and Play. The store Privacy-Policy URL must resolve and the mailboxes must receive mail. · **Owner:** Founder · **Effort:** 1–3h · **Blocking:** privacy-URL check (both stores).

8. **Production environment decision** — there is **no separate prod Supabase project**; dev and "prod" share one project, which currently holds ~5 test accounts. Decide: (a) create an isolated production project and run the (now-proven) migrate + deploy procedure against it, or (b) launch on the shared project after **purging test data**. · **Owner:** Founder · **Effort:** (a) 3–6h / (b) 30 min · **Blocking:** a clean production launch.

9. **Licensed-veterinarian review of safety content** — the 5 first-aid cards + breed insights. They are defensible (no meds/doses; always route to a vet) but a vet must bless the evolving-guidance items (heatstroke cooling, seizure ">2–3 min" threshold, bloat framing). · **Owner:** Founder + Vet · **Effort:** external · **Blocking:** safety/liability (self-imposed but essential for a health app).

10. **Attorney sign-off** — Terms/Privacy, the liability cap value, the 13+/16+ age bracket, GDPR framing. · **Owner:** Founder + Legal counsel · **Effort:** external · **Blocking:** legal exposure.

11. **iOS on-device pass** — iOS has **never been built or run on hardware**; also provision the Apple auth secrets (`SUPABASE_AUTH_EXTERNAL_APPLE_*`, currently enabled-but-missing in prod) or the app's Apple sign-in fails at runtime. · **Owner:** Founder (needs an iOS device + Mac) · **Effort:** 2–4h · **Blocking:** Apple confidence + SIWA runtime.

---

## 🟡 IMPORTANT — do before/right after launch (quality, risk, accuracy)

12. **E&O / professional liability insurance** — bind before public availability for a pet-health advice product. · Founder · external · Strongly recommended.

13. **Reconcile the age rating** — store rating **12+** vs eligibility **13+/16+**. The document contradiction is fixed; pick a consistent public number. · Founder/Legal · 30 min.

14. **Production env provisioning** (env audit) — add `ANON_IP_SALT`, `SENTRY_DSN`, `POSTHOG_*` if wanted; provision Apple auth secrets; and **delete the 6 legacy prod Doppler slots** (OneSignal/OpenAI/Places/Resend/invite). · Founder · 1h.

15. **Store assets** — new-UI screenshots (both platforms, required sizes), final descriptions, EN/DE listings, review notes. · Founder · 2–4h.

16. **Operational** — SMTP for auth email; production DB backups/PITR; a cost/billing alarm on the AI API keys; confirm Sentry is receiving events. · Founder · 1–2h.

17. **Purge test data** — if launching on the shared project, delete the ~5 QA accounts (incl. `rcqa.device@pawdoc-test.com` + pet "Rex"). · Founder · 15 min.

---

## 🟢 OPTIONAL — post-launch / nice-to-have

18. **Custom domain** `pawdoc.app`, then fold the legal portal into `web/` and retire the AWS/Terraform stack.
19. **Full German localization** (only ~13 strings localized today; the safety keyword spine is EN/DE) before marketing in DE.
20. **Deferred product Should-Haves** (see `PAWDOC_PRODUCT_EXPANSION_ROADMAP.md`): persisted vet questions (no migration), photo progression (the premium loop), pet photo, weekly local digest.

---

## Final Launch Readiness — scores (evidence-based, not optimistic)

| Dimension | Score | Basis |
|---|---|---|
| **Engineering** | **93%** | All suites green + CI; runs end-to-end on real hardware; a critical AI-degrade bug and the plist blocker fixed. Remaining: iOS never built on hardware. |
| **Infrastructure** | **70%** | Everything deployed and working — but on a **single shared dev/prod project** with test data; no environment isolation, no prod backups verified. |
| **Security/Privacy** | **88%** | Owner-only RLS proven in CI; deletion cascade proven; consent real; no client secrets; salted anon IPs available. Remaining: legacy prod secret cleanup, key rotation, single-project blast radius. |
| **AI** | **95%** | Ladder invariant tested 3 layers; golden set 0 FN; offline override; real analysis verified on-device (rich + safe-floor + degrade paths). Timeout bug fixed. |
| **UI/UX** | **88%** | Clean, consistent, accessible; every Critical/High UX defect fixed; validated on-device. Minor cosmetic deferrals cataloged. |
| **Legal** | **60%** | Content now matches the product (no "likely normal", honest free-tier); but attorney sign-off, entity identity, liability cap, and a portal re-deploy are open. |
| **Store Readiness** | **55%** | Design is compliant + metadata guarded + plist/signing-config fixed; but keystore, iOS signing, IAP, demo account, Data Safety, and privacy-URL are all open founder work. |
| **Operational** | **65%** | Cost telemetry, burst limits, runbooks, consent-safe Sentry; remaining: SMTP, PITR, billing alarms, support inbox, prod isolation. |
| **Business** | **55%** | Coherent one-plan model; but E&O, vet content sign-off, and the domain/entity are unstarted — the external critical path. |
| **Overall** | **~72%** | Engineering/AI are launch-grade and proven; the gap is founder-console + legal/vet/insurance + production isolation — none of it engineering-blocked. |

## Can PawDoc now be submitted?

**Google Play — NO today → YES WITH CONDITIONS.** No code blocker remains; the debug-signing engineering half is wired. It becomes submittable once the founder supplies the **upload keystore + Play App Signing** (item 1), configures **IAP/RevenueCat** (4), completes the **Data Safety form** (6), finalizes + re-deploys the **privacy policy** (3), and fixes the **privacy-URL/domain** (7). Estimated founder effort: ~1–2 days of console/legal work (plus counsel/vet turnaround). **Evidence:** the app builds a release AAB, runs a full authenticated E2E on real hardware, and the compliance design (health framing, emergency path, deletion, SIWA, subscription disclosure) is verified sound.

**Apple App Store — NO.** Beyond the shared blockers, iOS has **never been built or run on hardware**, distribution signing is unconfigured (item 2), and Apple sign-in is unprovisioned in prod (item 11). These need a Mac, an Apple Developer account, and an iOS device — none available in this environment. Apple is a genuine **NO** until that first iOS build + device pass happens. **Evidence:** `DEVELOPMENT_TEAM` absent; no prior iOS run in project history; `SUPABASE_AUTH_EXTERNAL_APPLE_*` missing in prod.

### The honest reality check
*"If I were personally responsible for approving PawDoc for public release today, would I approve it?"* — **No, not today** — but not because of the product's quality or safety. The engineering is done and proven; the AI, safety spine, and emergency path are genuinely strong. I would withhold approval only until three things are true: (1) the **legal portal is finalized and re-deployed** with a real entity and counsel-approved liability terms, (2) a **licensed vet has signed off** the first-aid content, and (3) the app has been **run once on a real iOS device** and the **production environment decision** is made (isolated prod or purged shared project). None of those is speculative or far away — they are concrete, mostly-external tasks. With them done, this is an approvable, and genuinely good, first release.
