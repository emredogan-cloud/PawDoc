# 09 — RevenueCat project skeleton

Sets up the subscription backend's **identifiers only**. Products, entitlements, and the paywall are built in **Phase 1.4** — do **not** configure them now (roadmap: don't over-build this phase).

**Dashboard:** <https://app.revenuecat.com>

## 1. Create the project

Sign up → **Create new project** → name it `PawDoc`.

## 2. Add the two apps (identifiers)

Project → **Apps** → add both platforms. Use the canonical bundle identifier (also used by the Flutter app in Phase 1.1):

| Platform | Identifier | Field |
|----------|-----------|-------|
| Apple App Store | `app.pawdoc` | Bundle ID |
| Google Play | `app.pawdoc` | Package name |

> Apple app config in RevenueCat asks for an **App Store Connect shared secret / in-app purchase key** — that comes from the Apple Developer account (runbook 01). You can register the identifier now and finish the key linkage once Apple enrollment is approved.

## 3. Capture the keys

RevenueCat → **API keys**:
- **Public SDK keys** (one per platform) — these ship in the Flutter client in Phase 1.4 (public by design).
- A **secret API key** — server-side only.
- Set a **webhook authorization header secret** — used to verify `/revenuecat-webhook` in Phase 1.4 (Critical Review #21: never trust an unsigned webhook).

Store the server-side ones in Doppler:
```bash
doppler secrets set REVENUECAT_API_KEY="<secret api key>"          --project pawdoc --config prd
doppler secrets set REVENUECAT_WEBHOOK_SECRET="<webhook auth value>" --project pawdoc --config prd
# public SDK keys are recorded for the client build (see ENVIRONMENT_VARS.md)
```

## 4. Stop here

Per the roadmap, **do not** create products/offerings/entitlements yet. The DoD for this phase is only: *project exists with both app identifiers registered, ready to receive product config in Phase 1.4.*

## Verify

RevenueCat dashboard shows the project with **both** app identifiers under **Apps**. Note them in the SUB-PR report.
