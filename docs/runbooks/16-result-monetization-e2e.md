# 16 — Phase 1.4: result flow, paywall & end-to-end QA

Closes the loop: input (1.2) → `/analyze` (1.3) → loading → result; paywall; webhook.

## 0. Backend wiring

```bash
# RevenueCat webhook (verifies a shared secret — CR #21):
supabase functions deploy revenuecat-webhook --project-ref <ref>
supabase secrets set REVENUECAT_WEBHOOK_SECRET="<choose-a-secret>" --project-ref <ref>
# In RevenueCat → Integrations → Webhooks: URL = .../functions/v1/revenuecat-webhook,
# Authorization header = the SAME secret.
# analyze already deployed (1.3); ensure R2_* + AI_SERVICE_URL secrets are set.
```
In RevenueCat, create the **annual** + **monthly** products and an entitlement, and put them in the **current** offering (the paywall reads `offerings.current.annual/monthly`).

Build the app with the RevenueCat public key:
```bash
flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=… \
  --dart-define=POSTHOG_API_KEY=… --dart-define=REVENUECAT_PUBLIC_SDK_KEY=<ios-or-android-public-key>
```

## 1. How to mock the AI response for local end-to-end testing

Two ways, no real API keys needed:

- **Widget/integration (CI-friendly):** override the Riverpod provider with a fake —
  see `mobile/test/analysis_integration_test.dart`:
  ```dart
  ProviderScope(overrides: [
    analysisServiceProvider.overrideWithValue(FakeAnalysisService(mk(TriageLevel.emergency))),
  ], child: ...AnalysisRunnerScreen(...));
  ```
  The fake returns a canned `AnalysisResult`, so the loading→result flow runs offline.
  Swap the `TriageLevel` to exercise NORMAL / MONITOR / EMERGENCY screens.

- **Full stack:** run the AI service with the kill-switch on (`AI_KILL_SWITCH=1`) to get
  the safe degraded path, or point `AI_SERVICE_URL` at a local FastAPI started with a fake
  provider injected (see `ai-service/tests/test_pipeline.py` `FakeProvider`).

## 2. EMERGENCY-never-paywalled — verify it

1. Use up the 3 free analyses (non-emergency text).
2. Submit text containing an emergency keyword (e.g. **"my dog had a seizure"**).
   - Expect: it **still analyzes** (HTTP 200, not 402) and is **not** counted against the quota.
   - Expect: the **EMERGENCY screen** shows; the **paywall never appears** on this flow.
3. Confirm the standard paywall appears only **after a non-emergency analysis**, **not** during
   onboarding, and **at most once per day**.

## 3. Result screens

- NORMAL → green badge, "what we noticed / what to do", **Share** button, disclaimer.
- MONITOR → amber badge, escalation triggers, disclaimer (no Share).
- EMERGENCY → warm red, **Find an emergency vet** (opens maps), and you **cannot leave**
  until you tick the acknowledgment and tap Continue.

## 4. Webhook

A sandbox purchase fires the RevenueCat webhook → `users.subscription_status` becomes
`premium`/`trial`; the home counter shows "Premium — unlimited checks".
