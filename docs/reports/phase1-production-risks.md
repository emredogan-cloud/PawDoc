# Phase 1 — Production Risk Register

**Audit date:** 2026-05-16
**Threat model:** Health-adjacent consumer mobile + AI product.
- App Store reviewers will scrutinise on day 1.
- Malicious users will probe upload, auth, and quota systems.
- Real users on slow networks and old Android devices.
- Real subscription edge cases (payment failure, refund, family
  switching).
- Real AI hallucination + legal liability.

Each risk:
- **Severity:** Critical / High / Medium / Low
- **Likelihood:** Likely / Possible / Rare
- **Affected file(s)**
- **Impact** if it happens
- **Mitigation today**
- **Recommended action**

---

## 1. Safety / Legal Risks

### R-1. AI false-negative on a real emergency

- **Severity:** Critical
- **Likelihood:** Rare (low frequency, catastrophic if it happens)
- **Affected:** Entire AI pipeline
- **Impact:** Real pet harm → user lawsuit → press → company-ending event
- **Mitigation today:**
  - Hardcoded emergency keyword override pre-AI (Phase 1B)
  - Cross-verify on every Tier-3 EMERGENCY
  - Confidence floor 0.60 → graceful degradation
  - Disclaimer at API level on every response
  - Append-only `analyses` table as legal record
- **Recommended action:**
  1. Pre-public-launch: E&O insurance ($100K min) per roadmap §9.
  2. Establish a "if pet died" P0 nightmare-scenario response runbook
     (roadmap §13 mentions it; not yet written).
  3. Quarterly review of 50 random `analyses` rows for quality drift
     (roadmap §13 analytics cadence).

### R-2. Disclaimer can be hidden by UI bug

- **Severity:** High
- **Likelihood:** Rare
- **Affected:** `mobile/lib/features/analysis/analysis_result_screen.dart`
- **Impact:** Legal exposure if a user claims "the app said it was OK,
  not 'consult a vet'."
- **Mitigation today:** The disclaimer text is in the API response
  (`AnalysisResult.disclaimer_text`), not hardcoded in the UI. A UI
  bug that hides the disclaimer is recoverable via API tweak.
- **Recommended action:** Add a widget test that asserts the disclaimer
  text is visible on every triage variant. Currently the result-widget
  test verifies disclaimer presence but only via `textContaining`;
  tighten to assert it's not zero-pixel-height.

### R-3. EMERGENCY override fires on a non-emergency

- **Severity:** Medium
- **Likelihood:** Possible
- **Affected:** `ai-service/app/services/safety.py`
- **Impact:** User shows up at the emergency vet at 3am with a healthy
  pet because they mentioned "I'm worried she collapsed onto the
  couch." Costs them $400. Trust erosion.
- **Mitigation today:** Substring-match (case-insensitive) on a curated
  keyword list. Over-triage to EMERGENCY is documented as accepted
  trade-off (safer false-positive than false-negative).
- **Recommended action:** Phase 2: refine keywords with word-boundary
  regex; add common false-positive guards (e.g., "couch", "into bed"
  near "collapse"). Until then, document accepted.

### R-4. "Diagnosis" language in UI triggers App Store rejection

- **Severity:** Critical
- **Likelihood:** Likely (App Store treats health apps strictly)
- **Affected:** All UI text + App Store metadata
- **Impact:** App Store rejection, possibly multiple times. Roadmap
  §10 Phase 2 warns of 2-3 rejection cycles for health apps.
- **Mitigation today:** Result screen uses "triage", "may be
  consistent with", "consult a vet". No "diagnosis" string found in
  mobile codebase.
- **Recommended action:** Pre-submission scan: grep all user-visible
  strings for medical-claim language ("diagnosis", "cure",
  "treatment", "guaranteed"). Update App Store metadata + screenshots
  with the same discipline.

---

## 2. Security Risks

### R-5. Storage bucket MIME spoofing

- **Severity:** Medium
- **Likelihood:** Possible (motivated attacker)
- **Affected:** `supabase/migrations/20260516010100_storage_bucket.sql`
- **Impact:** A user uploads a file with `Content-Type: image/jpeg` but
  actual content is e.g. a polyglot file or a large nonsense payload.
  The AI service fetches it, the provider chokes, we return graceful
  degradation. Worst case: a malformed file that crashes our image
  pipeline. Bounded by bucket size cap (5 MB).
- **Mitigation today:** Bucket size cap; MIME allowlist (header-based,
  not magic-byte-based); per-user RLS scoping.
- **Recommended action:** Phase 2 — add an edge function `image-scan`
  that runs file-magic detection before exposing to AI. Until then,
  accepted.

### R-6. Quota bypass via direct DB write

- **Severity:** Low
- **Likelihood:** Rare (would require leaking the service role key)
- **Affected:** Architecture
- **Impact:** A user who somehow has the service role key writes
  `subscription_status = 'premium'` to their own row. Free analyses
  forever.
- **Mitigation today:** Service role key only on ai-service + edge
  functions; never in mobile binary. RLS denies user-facing UPDATE on
  billing columns (column-level GRANT in Phase 1A).
- **Recommended action:** Doppler integration to rotate the service
  role key periodically (Phase 2 operational).

### R-7. Prompt injection via `text_description`

- **Severity:** Medium
- **Likelihood:** Possible (researchers; jailbreak community)
- **Affected:** AI pipeline
- **Impact:** A motivated user crafts a `text_description` that ignores
  the system prompt and asks Claude/Gemini to produce off-schema
  output, dangerous medical advice, or jailbroken content. The schema
  validator catches schema violations (returns 502 via parser failure
  → graceful degradation). The user-visible output stays safe.
- **Mitigation today:** Pydantic schema validation; tool_use forced
  output for Claude; `responseSchema` for Gemini; system prompt anti-
  hallucination clause.
- **Recommended action:**
  1. Truncate `text_description` to 2000 chars (currently the AI
     service accepts up to provider limits).
  2. Phase 2: Tier-0 content classifier (e.g., a small open-source
     model) that filters obvious jailbreak attempts.

### R-8. JWT replay during a session window

- **Severity:** Low
- **Likelihood:** Rare (would require MITM)
- **Affected:** Auth flow
- **Impact:** A stolen JWT remains valid until expiry. Standard JWT risk.
- **Mitigation today:** Supabase Auth issues short-lived JWTs (1h
  default) + refresh tokens. Refresh-token rotation enabled (Phase 0
  config.toml).
- **Recommended action:** None — within standard practice.

### R-9. Webhook secret leak via misconfigured logs

- **Severity:** Medium
- **Likelihood:** Possible
- **Affected:** `supabase/functions/auth-webhook`, `revenuecat-webhook`
- **Impact:** Attacker who knows the webhook URL + secret can forge
  arbitrary auth events / subscription state changes.
- **Mitigation today:** Constant-time HMAC comparison in
  `_shared/auth.ts`; secrets via Supabase functions secrets store
  (Doppler-synced).
- **Recommended action:** Quarterly rotation; alert on any unauthorized
  webhook attempt (currently logged via `webhook_secret_mismatch`).
  Phase 2: forward unauthorised attempts to Sentry as a security event.

### R-10. CORS misconfiguration allowing arbitrary origin

- **Severity:** Low
- **Likelihood:** Rare (would require config change)
- **Affected:** `supabase/functions/_shared/cors.ts`
- **Impact:** A malicious site could call edge functions from a
  browser with the user's session.
- **Mitigation today:** Explicit allowlist (localhost + pawdoc.app
  subdomains). The pattern `/^app\.pawdoc\.app$/` is dead (missing
  protocol) but the wildcard pattern catches it.
- **Recommended action:** Fix the dead pattern (audit H-1). Add a CI
  test that asserts unknown origins return 403.

---

## 3. Reliability / Scalability Risks

### R-11. Free-tier quota burned by transient AI failure

- **Severity:** Critical
- **Likelihood:** Likely (provider 5xx happens; we retry once then
  graceful-degrade)
- **Affected:** `supabase/functions/analyze/index.ts:229-267`
- **Impact:** Free-tier user's quota decrements before AI call. If AI
  call fails (timeout / 5xx after retries / network), the quota is gone
  and the user got nothing. User retries → consumes another slot.
- **Mitigation today:** None — the design choice (atomic consume
  before AI call) was explicit for safety against double-counting,
  but it has this cost.
- **Recommended action:** Implement `refund_free_analysis(p_user_id)`
  RPC + edge function calls it on AI failure (see audit C-3).

### R-12. AI provider cost runaway

- **Severity:** High
- **Likelihood:** Possible (compromised user, runaway loop)
- **Affected:** `ai-service/app/services/orchestrator.py`
- **Impact:** A malicious or compromised account drives 1000s of calls.
- **Mitigation today:**
  - Free tier 3/month/user (server-side atomic)
  - Daily rate limit 10/user (Upstash, fails open)
  - Provider org-level budget caps (operational, set in Anthropic +
    Google AI dashboards per `docs/environment-setup.md`)
- **Recommended action:**
  1. Verify operational caps are set BEFORE first prod traffic.
  2. Add a daily total-call alert at the AI service layer
     (`total_calls_today > N` → page).

### R-13. Fly.io worker restart mid-call

- **Severity:** Medium
- **Likelihood:** Possible (rolling deploys, OOM, scaling event)
- **Affected:** AI service runtime
- **Impact:** Edge function consumed quota; AI service died mid-
  request; edge function times out at 30s; user sees error. Same
  failure mode as R-11.
- **Mitigation today:** `min_machines_running = 1` keeps a warm
  instance; rolling deploys; health probe.
- **Recommended action:** Combine with R-11 refund fix.

### R-14. Upstash outage during peak hours

- **Severity:** Low
- **Likelihood:** Rare
- **Affected:** Rate limiter
- **Impact:** Rate limiter fails open → no daily cap. Free-tier
  counter still enforced. Abuse bounded.
- **Mitigation today:** Documented fail-open with warn log.
- **Recommended action:** Sentry alert on
  `rate_limit_upstash_error` count > N/minute.

### R-15. AI service cold start on Fly.io

- **Severity:** Low
- **Likelihood:** Rare
- **Affected:** `ai-service/fly.toml`
- **Impact:** First request after deploy hits cold start (~3-5s extra
  latency).
- **Mitigation today:** `min_machines_running = 1` keeps one warm.
- **Recommended action:** Monitor cold-start frequency in Fly.io
  metrics; tune `min_machines_running` if traffic justifies > 1.

### R-16. Mobile app crash during upload

- **Severity:** Low
- **Likelihood:** Possible (low memory on old Android)
- **Affected:** `mobile/lib/shared/services/image_service.dart`
- **Impact:** `flutter_image_compress` allocating bytes can OOM on
  256MB Android. The compress loop retries with smaller dimensions,
  but the first pass at 2048px is the largest.
- **Mitigation today:** Iterative downscale on size cap.
- **Recommended action:** Phase 1.5 — use `compute()` to isolate the
  compression; on memory errors, retry with `minWidth: 1024`.

### R-17. Race during onboarding draft save

- **Severity:** Low
- **Likelihood:** Rare
- **Affected:** `mobile/lib/features/onboarding/onboarding_controller.dart`
- **Impact:** Two rapid updates within the 300ms debounce window — the
  second triggers a Timer cancel + restart. If the widget disposes
  between the two, no save. Draft lost.
- **Mitigation today:** Submit-on-tap saves explicitly before navigation.
- **Recommended action:** Acceptable.

### R-18. Race between RevenueCat webhook and analyze call

- **Severity:** Low
- **Likelihood:** Rare
- **Affected:** Flow timing
- **Impact:** User purchases at second N. Webhook fires at N+5. User
  taps analyze at N+1. The free-tier RPC sees `subscription_status =
  'free'` and consumes a quota slot. Webhook at N+5 sets `premium`.
  The slot the user just spent is now "wasted" (they're already
  unlimited).
- **Mitigation today:** Sub-linear cost; doesn't impact the user
  beyond a confusing "you had X analyses left" count.
- **Recommended action:** Acceptable.

---

## 4. App Store / Compliance Risks

### R-19. App Store rejection due to missing privacy manifest

- **Severity:** Critical
- **Likelihood:** Likely (automated check)
- **Affected:** `mobile/ios/Runner/PrivacyInfo.xcprivacy` (missing)
- **Impact:** Submission blocked.
- **Mitigation today:** None.
- **Recommended action:** P0 — author the manifest before first submit.

### R-20. App Store rejection: missing usage descriptions

- **Severity:** Critical
- **Likelihood:** Likely
- **Affected:** `mobile/ios/Runner/Info.plist`
- **Impact:** Submission blocked.
- **Mitigation today:** None.
- **Recommended action:** P0 — add `NSCameraUsageDescription` +
  `NSPhotoLibraryUsageDescription`.

### R-21. App Store rejection: missing ToS / Privacy links on paywall

- **Severity:** Critical
- **Likelihood:** Likely
- **Affected:** `mobile/lib/features/paywall/paywall_screen.dart`
- **Impact:** Submission blocked.
- **Mitigation today:** None.
- **Recommended action:** P0.

### R-22. Health-app rejection: medical-claim language

- **Severity:** High
- **Likelihood:** Possible
- **Affected:** UI text + App Store metadata + screenshots
- **Mitigation today:** Codebase uses "triage" and disclaimer copy.
- **Recommended action:** Pre-submission audit of all user-visible
  text + App Store assets.

### R-23. ATT prompt mismatch

- **Severity:** High
- **Likelihood:** Possible
- **Affected:** OneSignal SDK configuration
- **Impact:** App Store rejection or ATT prompt errors.
- **Mitigation today:** Need to verify OneSignal 5.2.7's tracking
  behaviour.
- **Recommended action:** Audit OneSignal's IDFA usage; either add
  `NSUserTrackingUsageDescription` and call `requestTrackingAuth` or
  document explicit non-use in `PrivacyInfo.xcprivacy`.

### R-24. Apple Sign-In disabled in prod build

- **Severity:** Critical
- **Likelihood:** Possible (operational mistake)
- **Affected:** `mobile/env/prod.json.example`
- **Impact:** Submission rejected on rule 4.8.
- **Mitigation today:** Documented in env example.
- **Recommended action:** Add a CI check that prod env file has
  `APPLE_SIGN_IN_ENABLED: true`.

---

## 5. Operational Risks

### R-25. Doppler integration not provisioned

- **Severity:** High
- **Likelihood:** Likely (operational gap)
- **Affected:** All secret management
- **Impact:** Secrets live in env files committed to people's local
  machines + GitHub Actions secrets — sprawl risk.
- **Mitigation today:** `.env.example` files clearly documented; CI
  uses GitHub Action secrets.
- **Recommended action:** Pre-launch — provision Doppler workspace +
  per-env configs; sync to GH Actions + Fly.io. The runbook is in
  `docs/environment-setup.md`.

### R-26. Sentry quota burn from a crash loop

- **Severity:** Medium
- **Likelihood:** Possible
- **Affected:** Sentry org budget
- **Impact:** A bug triggers a crash loop on N% of devices → Sentry
  quota exhausted → no more error reports.
- **Mitigation today:** `tracesSampleRate: 0.1`, `profilesSampleRate:
  0.0`. Crash sample rate is 1.0 (every crash captured).
- **Recommended action:** Phase 2 — set up alerts on Sentry quota
  usage > 70%.

### R-27. No rollback rehearsal

- **Severity:** Medium
- **Likelihood:** Possible (first time we need it)
- **Affected:** All deploys
- **Impact:** First production rollback takes longer than necessary
  because no one has practised it.
- **Mitigation today:** `docs/rollback-runbook.md` is comprehensive.
- **Recommended action:** Pre-launch — dry-run a `flyctl releases
  rollback` against the dev environment.

### R-28. No alerting on key metrics

- **Severity:** High
- **Likelihood:** Possible
- **Affected:** Production operations
- **Impact:** Outages go unnoticed for hours.
- **Mitigation today:** Better Uptime monitors documented for /health
  endpoints. No application-level alerts (Sentry crash rate, PostHog
  funnel break, etc).
- **Recommended action:** Pre-launch — wire Sentry crash-rate alert
  → Slack. Wire Better Uptime to SMS founder on /health failure.

### R-29. No disaster-recovery plan for Supabase

- **Severity:** Medium
- **Likelihood:** Rare (Supabase has backups)
- **Affected:** Database integrity
- **Impact:** Total user-data loss if Supabase fails AND backups
  unavailable.
- **Mitigation today:** Supabase automatic daily backups; PITR on
  Pro plan.
- **Recommended action:** Phase 2 — verify Supabase Pro is enabled
  for prod; document recovery time objective.

---

## 6. UX Reliability Risks

### R-30. User session expires during analyze flow

- **Severity:** Medium
- **Likelihood:** Likely (overnight sessions)
- **Affected:** Mobile auth + analyze
- **Impact:** Analyze submits → 401 → mobile shows error but doesn't
  redirect to /auth → user stuck.
- **Mitigation today:** `supabase_flutter` auto-refresh tokens.
  401 still possible after 1h+ idle.
- **Recommended action:** Audit H-12 fix — on 401, force sign-out +
  redirect to /auth.

### R-31. User backgrounds during upload → upload cancelled

- **Severity:** Low
- **Likelihood:** Likely
- **Affected:** Mobile analyze
- **Impact:** Upload fails silently; user comes back to capture
  screen.
- **Mitigation today:** None — accepted.
- **Recommended action:** Acceptable for Phase 1; consider iOS
  background upload tasks in Phase 2.

### R-32. User permission denied for camera/photos

- **Severity:** Low
- **Likelihood:** Possible
- **Affected:** Image picker flow
- **Impact:** App throws `ImagePickFailure` with copy "Permission
  denied. Allow camera/photos access in Settings." User has to know
  to go to Settings.
- **Mitigation today:** Error copy is clear.
- **Recommended action:** Phase 2 — add a "Open Settings" CTA via
  `app_settings` plugin.

### R-33. Slow network → upload + analyze takes > 60s

- **Severity:** Medium
- **Likelihood:** Likely (real users on 3G / 4G edges)
- **Affected:** Mobile analyze flow
- **Impact:** Mobile HTTP timeout (60s on mobile, 30s on edge fn).
  Quota consumed. User sees timeout error.
- **Mitigation today:** Image compressed <2 MB; edge function 30s
  timeout.
- **Recommended action:** Phase 1.5 — bump mobile timeout to 90s
  (still under user attention threshold); add upload progress
  indicator (currently a generic spinner).

### R-34. EMERGENCY result on a low-battery device

- **Severity:** Medium
- **Likelihood:** Possible
- **Affected:** Mobile UI
- **Impact:** User on 5% battery has an emergency; analyze takes 6s;
  battery dies mid-response.
- **Mitigation today:** Tier 1 keyword override returns
  instantaneously (0 ms). Tier 2 path is 1.5-3s typical.
- **Recommended action:** Document; not actionable.

---

## 7. Production Risk Summary

| Severity | Count | Top items |
|----------|-------|-----------|
| Critical | 5 | Quota refund, iOS manifest, iOS permissions, paywall links, Apple Sign-In env |
| High | 6 | AI cost runaway, false-negative emergency, prompt injection, App Store medical-claim, Doppler unprovisioned, alerting |
| Medium | 14 | MIME spoof, webhook secret rotation, Fly.io restart, app crash, Sentry quota, session expiry, slow network, R3-R34 various |
| Low | 9 | Several rare or acceptable risks |

**Pre-launch P0 hit list (operational + engineering combined):**

1. Implement `refund_free_analysis` RPC + edge fn integration (R-11)
2. Author `PrivacyInfo.xcprivacy` (R-19)
3. Add iOS `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` (R-20)
4. Add ToS + Privacy links to paywall + ensure URLs live (R-21)
5. Set `APPLE_SIGN_IN_ENABLED=true` in prod env + configure provider (R-24)
6. Integrate PostHog (Critical from audit C-4)
7. Verify provider budget caps in Anthropic + Google dashboards (R-12)
8. Pre-submission UI/metadata audit for medical-claim language (R-22)
9. Wire Sentry crash-rate alert → Slack (R-28)
10. Provision Doppler workspace + sync (R-25)

These are the non-negotiables before a public launch.

---

*End of production risks register.*
