# PawDoc — Founder Roadmap (Phase 4)
**2026-06-13** · the complete, ordered, no-ambiguity path from today → Beta → Public Launch.
Engineering is done; this is entirely founder/console/legal work.

> **Start the long-lead items (F-0) TODAY** — Apple enrollment, legal entity, and
> attorney/E&O run for days–weeks in parallel with everything else.

---

## Phase F-0 — Kick off long-lead items (Day 0, parallel)
**Goal:** start every clock that takes days/weeks so they don't dominate the tail.
1. **Domain** — register/confirm `pawdoc.app` at your registrar; point DNS to
   Cloudflare (runbook 03). Create `support@pawdoc.app`.
2. **Apple Developer Program** — enrol at developer.apple.com ($99/yr). Org
   accounts need a **D-U-N-S number** (can take days). Individual is faster.
3. **Google Play Console** — register ($25 one-time) at play.google.com/console.
4. **Legal entity** — if not formed, start it (LLC or local equivalent); the
   privacy/terms need a real legal name + address.
5. **Engage an attorney** — brief: a pet-health **triage/information** app
   (explicitly *not* veterinary advice), GDPR + CCPA + health-adjacent disclaimers;
   ask them to finalize `docs/legal/privacy-policy.md` + `terms-of-service.md` and
   the liability waiver. **Also request an E&O / professional-liability quote.**
- **Outputs:** domain live, both store accounts, entity in progress, attorney engaged.
- **Common mistake:** leaving Apple enrolment to last — it's the slowest gate.
- **Recovery if blocked:** Apple org delay → enrol as Individual for beta, convert later.

## Phase F-1 — Backend hardening (½ day)
**Goal:** stop the data-loss risk + make outages visible before real users arrive.
1. **Supabase**: create a **separate dev project**; upgrade prod to **Pro** and
   enable **PITR** (Dashboard → Database → Backups). Set the dev/prod URLs+keys in
   Doppler (don't reuse prod for dev).
2. **Supabase Auth** (Dashboard → Authentication): set **min password length = 8**;
   add `pawdoc://login-callback` to **Redirect URLs**.
3. **Monitoring**: create a **Sentry** project → put the DSN in Doppler (mobile +
   ai-service); add **Better Stack** uptime monitor on `https://pawdoc-ai.fly.dev/health`;
   set **spend caps** on Anthropic + Google AI consoles.
- **Verify:** dev project answers; PITR shows enabled; `/health` monitor green;
  a test Sentry event appears.
- **Common mistake:** enabling PITR but never testing a restore — do one drill.

## Phase F-2 — SMTP, billing, push (½ day)
**Goal:** turn on the founder-gated product features.
1. **SMTP** (E1): create Resend/Postmark/SES; add SMTP creds in Supabase Auth →
   Email; send a test reset to yourself → confirm the recovery deep link opens the app.
2. **RevenueCat** (E5): create the app + **products/offerings** (the PDF add-on +
   Premium); set `REVENUECAT_WEBHOOK_SECRET` (Doppler + RC dashboard); run a
   **sandbox purchase** → confirm entitlement unlocks + the webhook is idempotent.
3. **FCM/OneSignal** (E6): create a Firebase project; put the **FCM server key**
   in OneSignal; send a test push to a device.
- **Verify:** reset email arrives; sandbox purchase flips to Premium (no "coming
  soon"); test push received.
- **Common mistake:** RC product IDs not matching the store product IDs → purchases fail.

## Phase F-3 — Release mechanics (½ day)
**Goal:** produce a store-signed build + a complete listing.
1. **Keystore** (B1): `keytool -genkey -v -keystore pawdoc-upload.jks -keyalg RSA
   -keysize 2048 -validity 10000 -alias upload`. Store it + the password in Doppler
   (NEVER in git); wire `android/key.properties` + the release `signingConfig`.
2. **iOS signing**: `cd mobile/ios && fastlane match appstore` once (creates the
   private certs repo); set the match + ASC secrets as GitHub repo secrets (runbook 11).
3. **Store metadata** (B6 + `--strict`): fill the `[LEGAL ENTITY]/[ADDRESS]/[DATE]`
   in `docs/legal/*`, the App Review **demo creds**, and the real store URLs in
   `web/app/page.tsx`. Produce icon (done) + screenshots + descriptions per
   `docs/store_metadata/*`. **Run `./scripts/verify-no-placeholders.sh --strict`
   until it exits 0.**
- **Verify:** `flutter build appbundle` is store-signed; `--strict` gate passes;
  listing complete in both consoles.
- **Common mistake:** losing the keystore → you can never update the app. Back it up.
- **Recovery if blocked:** Play "App Signing" can manage the key if you opt in.

## Phase F-4 — On-device validation (½ day) — **safety-critical**
**Goal:** the one validation the agent cannot do.
1. Install the signed build on a real Android (+ iOS via TestFlight). Walk:
   **Auth → Onboarding → Analyze (text + photo) → Emergency path → History →
   Family → Referral → Account → Delete account.**
2. **Explicitly verify the emergency path:** submit "my dog is choking and can't
   breathe" → EMERGENCY + seek-care directive, **no paywall**, disclaimer shown.
3. Confirm uploaded photos are upright (EXIF/orientation) + contain no GPS.
4. Capture screenshots + logcat into `runtime/final_release_validation/`.
5. Replace runbook 22 `<FILL>`s (on-call, status page, dashboards, support channel).
6. **Decide E4** (Turkish): scope-out for beta, or request agent AG-OPT-1.
- **Verify:** zero crashes; emergency + disclaimer + no-paywall confirmed.
- **Common mistake:** skipping the emergency walk — it's the #1 business risk.

## Phase F-5 — Beta (50 users)
**Goal:** ship to TestFlight + Play internal track.
1. `cd mobile/ios && bundle exec fastlane ios beta` (TestFlight).
2. `cd mobile/android && bundle exec fastlane android beta` (Play internal).
3. Invite ≤50 testers; triage reports per runbook 22 §8 (missed emergency =
   auto-SEV1).
- **→ BETA GO achieved.**

## Phase F-6 — Public launch gate (attorney critical path)
**Goal:** clear the legal/insurance path, then submit for public review.
1. Attorney finalizes privacy/terms + waiver; publish at `pawdoc.app/privacy|terms`.
2. Bind **E&O insurance**.
3. `fastlane ios release` / `android release` (staged 10% rollout).
- **→ PUBLIC LAUNCH GO** once review approves + legal/E&O are live.

---
### Money + time at a glance
- **To Beta:** ~2–3 focused founder-days of work + ~$130 one-time + ~$50–75/mo
  (Supabase Pro, SMTP, Sentry/monitoring). Apple enrolment lead time is the gate.
- **To Public Launch:** + **2–4+ weeks** (attorney/E&O) + store review (days).
