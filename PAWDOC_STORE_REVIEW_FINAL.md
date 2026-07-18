# PawDoc — Final Store Review (Apple + Google Play)

**Date:** 2026-07-18 · **Branch:** `feat/release-candidate` (PR #81). Reviewed as Apple App Review, Google Play Review, a privacy reviewer, a security reviewer, and (for wording) a veterinary-safety lens.

> **Verdicts today:** **Apple App Store — NO** (cannot yet archive/submit: iOS distribution signing missing; several founder-console items). **Google Play — NO today → YES WITH CONDITIONS once the founder supplies the upload keystore + IAP products** (the debug-signing blocker's engineering half is now wired; the rest is console work). **The product's *safety and compliance design* is sound** — the hard parts of a health-app review are already correctly built. What blocks is release-engineering + founder-console/legal items.

This cycle I **fixed every engineering- and content-addressable finding**. What remains is founder/legal/console. Both are itemized below; the actionable checklist is `PAWDOC_PRELAUNCH_CHECKLIST.md`.

---

## A. Fixed this cycle (engineering + content)

| ID | Was | Fix (this branch) |
|---|---|---|
| **B1** | **Malformed `Info.plist`** — a stray `<false/>` orphan after `NSCameraUsageDescription` made the `<dict>` invalid (`plutil -lint` fails; Apple processing can reject) | Removed the orphan line; plist is now well-formed |
| **B2 (eng half)** | Release build hard-coded to the **debug** signing key | Wired a real `release` `signingConfig` that reads `android/key.properties` (gitignored) and **auto-activates when the keystore is present**; falls back to debug only for local dev. Founder drops in the keystore → store builds are correctly signed |
| **C1 (CRITICAL)** | The phrase **"likely normal"** (and the stale "emergency / monitor / likely normal" tier model) — the one verdict the product is architected never to give — appeared in **6 user-facing legal surfaces**, deep-linked from inside the app (terms, vet-disclaimer, ai-transparency ×3, emergency, privacy, **and the global footer on every legal page**) | Replaced everywhere with the real ladder ("get help now → watch and re-check") + the explicit "never says your pet is normal/fine" line |
| **H1** | iOS screenshot-1 caption **"Know exactly what your pet needs"** — a certainty/diagnosis claim the app disclaims | Changed to the action-framed, certainty-free "Notice. Decide. Remember." (matches Play) |
| **M1** | Terms + Subscriptions said the free tier has "a **limited number of analyses**"; the app + store say **text checks are unlimited** (only photo logs metered) — a legal-accuracy contradiction | Aligned the legal text to "unlimited text symptom checks; photo logs limited" |
| **M2** | Sign-in subtitle "**vet-informed** triage" risked implying real-time veterinary involvement (the AI transparency page says it is *not* vet-reviewed in real time) | Softened to "careful triage" |
| **M10 (contradiction)** | `children.md` said both "**adults (18 and older)**" and "**13 or older**" in one document | Aligned to "13 and older (16+ for GDPR Art. 8)" to match the Terms |
| **L1** | Reminders "**Never miss what matters**" — absolute reliability over-promise (on-device notifications can fail) | "Stay on top of what matters" |
| **L11** | `privacy.md` disclosed "Sign in with Apple / **Google**"; the app offers only Email + Apple | Dropped "/ Google" |
| **L12** | Scaffold `TODO`s in `build.gradle.kts` | Removed |

**Note:** the legal-content fixes (C1, M1, M10, L11) edit the **source** in `web-legal/content/`. The live CloudFront portal must be **re-deployed** for them to go live — a founder AWS step (in the checklist). The site build was verified (`node build.mjs` succeeds).

---

## B. Verified SOUND (do not re-litigate)

The reviews independently confirmed the hard compliance pieces are correctly built:
- **Health/medical framing (Apple 1.4.1 / Play Health):** disclaimer is **server-forced** (`disclaimer_required=True`) and rendered as a tappable card; "not a diagnosis" is consistent across app, Terms, Privacy, and store copy; category is **Lifestyle**, not Medical. The AI system prompt explicitly forbids diagnosis, condition-naming, "likely X," medication/doses, and reassurance, and forces "an action and a timeframe. No exceptions." All pipeline fallbacks are non-reassuring and land on the re-check floor.
- **Emergency path:** offline, model-free, never paywalled (enforced client + server), no monetization/affiliates (grep-confirmed) — matches the CLAUDE.md red-path rule.
- **Account deletion (Apple 5.1.1(v) / Play):** in-app, typed-"DELETE" confirmation, real erasure (R2 media + RevenueCat + PostHog subject + auth delete with FK cascade).
- **Sign in with Apple (4.8):** only Email + Apple offered; SIWA entitlement set; button hidden on non-Apple platforms.
- **Subscription disclosure (3.1.2):** Restore works; auto-renew terms + Subscription-Terms/Terms/Privacy links + price/period present; manage-subscription deep-links the store — **when offerings load** (see H7).
- **Permissions minimal & justified:** iOS only `NSCameraUsageDescription`; Android camera/internet/notifications/boot, with storage/audio/location explicitly stripped; maps via OS deep-link (no GPS); camera `enableAudio:false` (no mic string).
- **First-launch crash safety:** boot error boundary + calm error + missing-config screen.

---

## C. Remaining rejection reasons — FOUNDER-gated

### Blockers (submission cannot pass without these)
- **B2 (keystore) — [FOUNDER]** Generate the upload keystore, enroll in **Play App Signing**, provide `android/key.properties` (from Doppler). The engineering config is ready and auto-activates.
- **B3 — [FOUNDER]** App-review **demo account**: the app auth-gates before use, so reviewers need working creds. Fill `[REVIEWER_DEMO_EMAIL]`/`[REVIEWER_DEMO_PASSWORD]` (`ios_app_store.md:123`) + Play "app access."
- **B4 — [FOUNDER/LEGAL]** The **published** privacy policy/terms still contain entity placeholders (`[LEGAL ENTITY]`, `[BUSINESS ADDRESS]`, `[EU REPRESENTATIVE]`, `[UK REPRESENTATIVE]`, `contact.md`, `deletion.md`). A privacy policy without a named data controller is incomplete → rejection. Fill and **re-deploy the portal**.

### High (likely rejection)
- **H5 — [FOUNDER]** **iOS distribution signing** is not configured (`DEVELOPMENT_TEAM` absent; identity is "iPhone Developer"). No App Store archive is possible without an Apple Distribution cert + provisioning profile (Apple Developer account).
- **H6 — [FOUNDER]** **Domain/mailbox mismatch:** the app links to the live CloudFront portal, but store review notes + all legal mailboxes use `pawdoc.app` (not live). Either enter the CloudFront URLs in App Store Connect / Play / review notes, or stand up `pawdoc.app` + its mailboxes. The store Privacy-Policy URL must match what the app links to and must receive mail.
- **H7 — [FOUNDER + verify]** **Subscriptions must be purchasable at review.** Metadata sells Premium, but the paywall renders "Premium is coming soon" when RevenueCat offerings aren't configured, and has hardcoded `$39.99/$6.99` fallbacks. Configure RevenueCat offerings + App Store Connect/Play IAP products, submit them **with** the binary, and confirm **real localized prices** render before purchase. (Apple 2.1/3.1.2.)

### Medium
- **M8 — [FOUNDER]** **Data Safety / privacy nutrition label** must declare **Analytics (PostHog, opt-in)** and **Crash logs/Diagnostics (Sentry, PII-stripped)** in addition to email/pet-profile/photos. ATT/IDFA not required (first-party analytics).
- **M9 — [FOUNDER/LEGAL]** Deployed legal pages show bracketed counsel notes + an unspecified **liability cap** (`[12] months / [USD 50]`) and governing law. Finalize and strip all `[…]` before re-deploy.
- **M10 (decision) — [FOUNDER/LEGAL]** Reconcile the **store age rating (12+)** with the eligibility (**13+/16+**). The internal document contradiction is fixed; the rating-vs-eligibility choice is yours.

### Report-only — licensed-vet sign-off (do NOT self-edit)
- **First-aid cards** are defensible (no meds/doses; every card routes to a vet), but a licensed vet should specifically confirm: **heatstroke cooling** ("room-temperature, not ice-cold" / "never ice baths" — 2024+ guidance on exertional heatstroke is evolving), the **seizure ">2–3 min"** threshold, and the **bloat** framing. Founder gate already noted in `first_aid.dart`.
- **Breed insights** name conditions only in "this breed is prone to… ask your vet" framing (consistent with the contract's general education allowance) — include in the same vet pass; no code change.

---

## D. The infrastructure caveat (from the production report)
There is **no separate production Supabase project** — dev and "prod" share one project, which currently holds test data. For a public launch this should be decided: either isolate a real prod project, or purge test data and launch on the shared one. This is not a store-review item per se, but it is a production-readiness gate (see `PAWDOC_FINAL_PRODUCTION_REPORT.md` and the checklist).

---

## E. Would it pass review today?
- **Apple: NO.** Even with B1 fixed, you cannot archive without iOS distribution signing (H5), and B3/B4/H6/H7 each independently cause rejection.
- **Google Play: NO today.** The engineering signing blocker is wired, but the founder must supply the keystore (B2) + enroll Play App Signing, configure IAP (H7), fix the privacy policy (B4), and complete the Data Safety form (M8). Once those are done, **Play is a plausible pass** — the product design itself is compliant.

The encouraging finding both reviews reached independently: **nothing blocking is about the product's safety or compliance design.** It is signing, IAP configuration, demo credentials, and entity/domain/legal finalization — ordinary pre-submission founder work.
