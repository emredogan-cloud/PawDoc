# APPENDIX B — PawDoc Founder Action Plan

**Scope:** Only work that must be performed by the founder through external accounts, consoles, and legal/business channels — an AI coding agent cannot execute any of this. Code-side blockers an agent *can* fix (e.g., the RLS-01 FK migration, the iOS entitlements/URL-scheme files, the UX-01 light-mode fix, Data Safety mapping copy) are referenced here only where a founder step depends on them.

**Audit basis:** branch `feat/legal-portal-integration` (main + legal portal, PR #78 unmerged), 2026-07-06. Safety-critical app — a false negative is the #1 risk; nothing below may weaken the emergency/disclaimer path.

**Legend:** each step lists **[Service/Account]** and **↳ Depends on**. Do the sections roughly in order; Section 1 (Legal) and Section 3 (Signing) are the two long-lead critical paths — start both on day one.

---

## 0. Prerequisites & Accounts

Foundational accounts and the brand domain. Almost everything downstream depends on the domain (LEG-02, PLAY-04, APPL-02, REC-03, REC-04, UX-04, PRD-01) and on the two store developer accounts.

- [ ] **Register the brand domain `pawdoc.app`** (or the final chosen domain) and confirm control. The app currently ships links to this domain but it is dead. **[Domain registrar]** ↳ blocks LEG-02, PLAY-04, APPL-02, REC-03, REC-04.
- [ ] **Form / confirm the legal operating entity** (LLC or equivalent) that will be named as data controller and app publisher. **[State/registrar + registered agent]** ↳ blocks LEG-01, store publisher identity, RevenueCat/bank payout setup.
- [ ] **Enroll in the Apple Developer Program** (paid, org enrollment under the entity; D-U-N-S may be required for a company account). **[Apple Developer]** ↳ blocks all of Section 3 (Apple), APPL-01, APPL-02, APPL-03, REC-02.
- [ ] **Create the Google Play Console developer account** (org identity, D-U-N-S verification now required by Play). **[Google Play Console]** ↳ blocks Section 3 (Google), PLAY-01/02/04, SEC-01, INF-01, REC-01.
- [ ] **Confirm ownership of / access to the production accounts already in use:** Supabase project, Fly.io org, Cloudflare R2, AWS (CloudFront/S3 legal portal), Doppler, RevenueCat, OneSignal, PostHog, Sentry, Google Gemini + Anthropic API. **[each vendor console]** ↳ blocks Sections 2 and 4.
- [ ] **Set up a business email + billing/payment method** for each paid vendor above under the entity. **[email provider + entity bank/card]** ↳ blocks payouts and paid-tier provisioning.

---

## 1. Legal & Compliance (critical path — start day one, longest lead time)

Two CRITICAL and one HIGH launch blocker live here (LEG-01, LEG-02) plus store-both erasure blocker RLS-01. Attorney review and E&O insurance are the true critical path (weeks, not days).

- [ ] **Engage a licensed attorney** (privacy/consumer + product-liability aware) to review and sign off on the 15-page legal portal, Terms, Privacy, and the AI/vet disclaimer language. Real attorney sign-off is still outstanding and several "counsel-to-confirm" brackets are live. **[External counsel]** ↳ LEG-01, LEG-04; gates public launch.
- [ ] **Obtain E&O / professional-liability + general liability insurance** appropriate for an AI health-triage product. This is a long-lead procurement item — begin immediately. **[Insurance broker/carrier]** ↳ gates public launch (risk transfer for the #1 false-negative risk).
- [ ] **Fill the data-controller identity** (legal entity name, address, contact) into every published privacy/terms/deletion page — currently unfilled placeholders. **[Legal entity details + portal content update, then Section 4 redeploy]** ↳ **LEG-01 (CRITICAL, blocks both stores).**
- [ ] **Appoint and name an EU representative and DPO** (if serving EU users) and fill the placeholders; resolve the conflicting DPO contact in `docs/legal/`. **[EU rep service / DPO]** ↳ LEG-01, LEG-04.
- [ ] **Provision a deliverable DSAR / deletion / support mailbox** on the registered domain (add MX records; e.g., `privacy@` / `support@`). The sole contact today is non-deliverable (no MX). **[Domain DNS + email provider]** ↳ **LEG-02 (HIGH, Play blocker), PLAY-04.**
- [ ] **Decide the canonical legal-portal URL** (custom domain over the CloudFront hostname) and confirm attorney/counsel that the store privacy-policy link is stable, not ephemeral. **[Domain DNS + AWS ACM cert — see Section 4]** ↳ REC-04, APPL-02.
- [ ] **Confirm account-deletion works end-to-end for erasure compliance** before publishing the deletion URL — depends on the RLS-01 referral-FK `ON DELETE` migration being merged and applied to production (Section 4). Verify a referrer/referee account deletes without a 500. **[Founder verification on prod DB]** ↳ **RLS-01 (CRITICAL, both stores), GDPR/Apple 5.1.1(v).**
- [ ] **Confirm the affirmative Terms/Privacy acceptance and age-gate decision** with counsel (currently passive footer links, 18+ asserted but never attested). Founder decides scope; code change is agent-executable. **[Counsel decision]** ↳ LEG-03, LEG-05.

---

## 2. Secrets & Production Config

Populate Doppler production config and stand up each third-party service in production. Several "silently no-op unless configured" findings (PostHog, OneSignal, RevenueCat) are resolved purely by founder configuration.

- [ ] **Create/verify the Doppler `prod` config** and populate all production secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, service role, R2 keys, Gemini + Anthropic keys, RevenueCat, OneSignal, PostHog, Sentry, the AI-service bearer token, and the RevenueCat webhook secret. **[Doppler]** ↳ blocks Sections 4, 5, 6.
- [ ] **Set `ONESIGNAL_APP_ID` in every build/config path.** This is the *only* mitigation for the unfixed OneSignal crash-on-exit (QA-03) — a build without it will crash. **[OneSignal + Doppler]** ↳ **QA-03 (Play store risk).**
- [ ] **Configure PostHog production project + key.** Without it, all activation/conversion analytics and every A/B experiment silently serve control. **[PostHog]** ↳ PRD-03.
- [ ] **Stand up RevenueCat production:** create the entitlement, products, and **live Offerings**, wire App Store Connect + Play products, and configure the webhook (constant-time secret) to the analyze Edge Function. If offerings aren't live at review the app dead-ends on "coming soon." **[RevenueCat + both stores]** ↳ **APPL-03**, SUB-01/02/03, PRD-05.
- [ ] **Configure Sentry production DSN + release tagging.** **[Sentry]** ↳ production error visibility for beta.
- [ ] **Set production API quotas/keys for Gemini and Anthropic**, and confirm billing caps. Note: out-of-quota visual `/analyze` runs the full paid pipeline with no rate limit (BE-01) — set vendor-side spend alerts as an interim guard until the code rate-limit lands. **[Google AI + Anthropic consoles]** ↳ BE-01 cost-abuse mitigation.
- [ ] **Configure a custom domain + ACM certificate for the CloudFront legal portal** to replace the ephemeral hostname and raise the TLS floor above TLSv1.0. **[AWS ACM + CloudFront + domain DNS]** ↳ REC-04, INF-06.

---

## 3. Signing & Store Enrollment

The debug-keystore signing issue is the single most-cited launch blocker (SEC-01, INF-01, PLAY-01, REC-01). Generating and safeguarding the upload key is a founder action; the CI/gradle wiring is agent-executable but needs the founder's key material and secrets.

### Android / Google Play
- [ ] **Generate a production upload keystore** and store it + passwords in a secrets manager (never in git). The release build is still signed with the well-known debug keystore, which Play rejects. **[keytool + Doppler/secure vault]** ↳ **SEC-01 / INF-01 / PLAY-01 / REC-01 (CRITICAL, Play upload blocker).**
- [ ] **Enroll in Play App Signing** and upload the signing config to CI as secrets so release AABs are signed with the upload key. **[Google Play Console]** ↳ same blockers as above.
- [ ] **Complete the Play Data Safety form** to match the SDKs actually bundled (location, purchase history, device analytics, third-party AI sharing). Current mapping is materially incomplete. **[Play Console]** ↳ **PLAY-02 (HIGH, Play blocker).**
- [ ] **Set the Play data-deletion URL** to the provisioned deletion mailbox/page on the live domain (not the dead one). **[Play Console + domain]** ↳ PLAY-04.
- [ ] **Reconcile the FINE→COARSE location declaration** in the store listing after the manifest fix. **[Play Console]** ↳ PLAY-03.

### iOS / App Store
- [ ] **Create the App ID, provisioning profiles, and enable capabilities** for Sign in with Apple and Push Notifications; ensure the entitlements file is present in the signed build. Today there is no iOS entitlements file, so SIWA + Push fail. (Entitlements file itself is agent-editable; the App ID capabilities + profiles are founder-only.) **[Apple Developer portal]** ↳ **APPL-01 (HIGH, Apple blocker), REC-02.**
- [ ] **Register the `pawdoc://` URL scheme** (Info.plist — agent-editable) and confirm Universal Links / associated-domains entitlement for the live domain. iOS deep links (incl. password reset) are silently broken. **[Apple Developer + domain AASA file]** ↳ REC-02, REC-03.
- [ ] **Set `ITSAppUsesNonExemptEncryption`** in Info.plist to unblock automated TestFlight/submission processing. **[Info.plist — agent-editable, founder decides export-compliance answer]** ↳ APPL-04.
- [ ] **Create a real reviewer demo account** (not a placeholder) against the auth-gated app, with a working login and, ideally, sandbox IAP visible. **[App Store Connect + Supabase test user]** ↳ **APPL-03 (Apple blocker).**
- [ ] **Fix App Store Connect metadata and review notes** to point Support/Privacy at the live portal URL, not the dead pawdoc.app domain. **[App Store Connect]** ↳ **APPL-02 (HIGH, Apple blocker).**

---

## 4. Production Deployment

Apply migrations and deploy services once the fixes above are merged. Some infra hardening (remote TF state, CI gating) is founder-owned even though scriptable.

- [ ] **Apply all database migrations to production Supabase**, including the merged RLS-01 referral-FK `ON DELETE` fix, then run the RLS/cascade harness against prod. **[Supabase]** ↳ **RLS-01**, Section 1 deletion verification.
- [ ] **Deploy all ~13 Edge Functions to production** (`supabase functions deploy`) and confirm the removed/dead `auth-webhook` is not redeployed (BE-03). **[Supabase]** ↳ backend go-live.
- [ ] **Deploy the AI service to Fly** and raise it off a single 512 MB machine — set a scaling ceiling, health checks, and alerting. **[Fly.io]** ↳ INF-05.
- [ ] **Pin the AI-service auto-deploy GitHub Action** off `@master` to a fixed SHA on the `FLY_API_TOKEN` path. **[GitHub Actions + Fly token]** ↳ INF-02.
- [ ] **Move Terraform state to a remote backend with locking** (e.g., S3 + DynamoDB) before further portal changes. **[AWS]** ↳ INF-03.
- [ ] **`terraform apply` the legal portal** with the custom domain + ACM cert; confirm all 16 legal URLs return 200 on the branded domain and CDN invalidation ran. **[AWS + domain]** ↳ REC-04, INF-06, LEG-01 content redeploy.
- [ ] **Gate the RLS test suite and the no-placeholders check in CI** (both currently ungated/green-when-should-be-red) so the deletion blocker can't regress. **[GitHub Actions]** ↳ RLS-02, INF-04, INF-07.
- [ ] **Provision Android App Links + iOS Universal Links** (host the `assetlinks.json` / `apple-app-site-association` on the live domain) so referral/invite/share links resolve. **[Domain hosting + both stores]** ↳ REC-03, PRD-01.

---

## 5. On-Device Validation

No launch-critical flow has ever been exercised on a fully-configured, release-signed build. This is a mandatory founder device-pass (QA-01) — an agent cannot drive a physical device or complete a real purchase.

- [ ] **Build a release-signed, prod-config app** (real upload key, Doppler prod secrets) on both a physical Android device and a physical iPhone. **[both devices + Section 3 keys + Section 2 secrets]** ↳ QA-01.
- [ ] **Run a real premium PURCHASE end-to-end** (sandbox/live) and verify entitlement recognition; also test **Restore Purchases** (currently a silent no-op). **[RevenueCat + store sandbox]** ↳ QA-01, SUB-01/02.
- [ ] **Run the delete-account cascade on-device**, including an account that is in a referral relationship, and confirm no 500. **[prod build + prod DB]** ↳ QA-01, RLS-01.
- [ ] **Exercise photo AND video capture → real AI result**, confirming image pixels reach the models and a real triage renders. **[prod build + AI service]** ↳ QA-01, AI-01.
- [ ] **Verify the emergency safety path on-device:** text + visual emergency both bypass the paywall at 0 remaining quota, disclaimer shows, and quota is NOT decremented on override. **[prod build]** ↳ QA-05, safety gate.
- [ ] **Test family invite end-to-end** (invite → accept) on two devices. **[prod build]** ↳ QA-01.
- [ ] **Verify the AI-down / offline degrade path** shows safe messaging (degrades to MONITOR, never NORMAL). **[prod build, AI service disabled]** ↳ QA-04, QA-06.
- [ ] **Confirm light-mode legibility fix** shipped (UX-01) renders correctly on a phone set to LIGHT mode. **[prod build]** ↳ UX-01 (blocker; code fix agent-executable, founder verifies).

---

## 6. Beta Rollout

Ship to the 50-user beta via internal/closed tracks once Section 5 passes.

- [ ] **Upload the signed AAB to a Play internal/closed testing track** and add the 50 beta testers. **[Play Console]** ↳ Sections 3–5.
- [ ] **Upload the signed iOS build to TestFlight** (internal, then external if desired) and invite testers. **[App Store Connect / TestFlight]** ↳ Sections 3–5.
- [ ] **Confirm production monitoring is live during beta:** Sentry errors, Fly health/alerting, PostHog activation funnel, and vendor spend alerts on Gemini/Anthropic (BE-01 interim guard). **[Sentry/Fly/PostHog/AI consoles]** ↳ INF-05, BE-01.
- [ ] **Verify the referral/share funnel resolves** for beta testers (App Links live, messaging matches the actual grant mechanic). **[live domain + stores]** ↳ REC-03, PRD-01, PRD-04.
- [ ] **Collect and triage beta feedback**, especially any emergency-path or false-negative report — treat as P0. **[founder]** ↳ safety.

---

## 7. Public Launch Checklist

Final gate to production release on both stores. All CRITICAL/HIGH launch blockers must be closed and verified.

- [ ] **Attorney sign-off received** and all "counsel-to-confirm" brackets resolved. ↳ LEG-01, LEG-04.
- [ ] **E&O / liability insurance bound and active.** ↳ risk transfer.
- [ ] **All launch blockers verified closed:** UX-01, SEC-01/INF-01/PLAY-01/REC-01 (signing), RLS-01, LEG-01, LEG-02, APPL-01, APPL-02, APPL-03, PLAY-02, QA-01, REC-02, REC-03. **[founder confirms each]**
- [ ] **Legal portal on the branded, stable domain**; every store privacy/support/deletion link points there and returns 200. ↳ REC-04, LEG-02, PLAY-04, APPL-02.
- [ ] **Play Data Safety form submitted and accurate**; FINE-location declaration reconciled. ↳ PLAY-02, PLAY-03.
- [ ] **Submit iOS build for App Store review** with a working reviewer account, correct metadata, entitlements, and encryption declaration. **[App Store Connect]** ↳ APPL-01/02/03/04.
- [ ] **Promote the Play build to production** (closed → open/production) after review passes. **[Play Console]**
- [ ] **Confirm cost-abuse controls in place** before opening to public traffic — the BE-01 per-user/per-IP rate limit (agent-executable) merged and deployed, plus vendor spend caps. ↳ BE-01.
- [ ] **Confirm production scaling + alerting** on the AI service can handle public load. ↳ INF-05.
- [ ] **Enable outbound timeouts on Edge→Fly fetches** (agent-executable) deployed so a hung upstream can't tie up functions under public load. ↳ BE-02.
- [ ] **Final go/no-go review** with the founder: emergency-never-paywalled and disclaimer paths re-verified on the exact production build being shipped. ↳ #1 safety risk.

---

**Critical-path summary:** Legal (attorney + E&O + entity identity + EU rep/DPO) and Signing/Store enrollment are the two longest leads — start both in Section 0/1 immediately. Everything in Sections 4–7 is blocked until the domain is live (Section 0), secrets are populated (Section 2), and the signing keys exist (Section 3).
