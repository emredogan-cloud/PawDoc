# Appendix B — PawDoc Environment & Secrets Audit

**Date:** 2026-07-18 · **Branch:** `feat/release-candidate` · **Method:** every env-var reference grepped across Flutter (`--dart-define`), the Python AI service (`os.getenv`), Edge Functions (`Deno.env.get`), `supabase/config.toml` (`env(...)`), Terraform, the web checker, and CI — then **reconciled against the actually-configured Doppler `dev` and `prd` configs** (read live, names only). Fly secrets and Supabase Function secrets aren't readable from this environment (not authenticated) and are marked *founder-verify*.

> **Headline:** the **dev** Doppler config is already evolution-clean (14 slots, no removed-vendor secrets). The **prd** config (32 slots) still carries **6 legacy secrets** for deleted features and is **missing** analytics/observability (PostHog, Sentry), the salted-IP pepper (`ANON_IP_SALT`), and **Apple sign-in provisioning** — even though Apple sign-in is `enabled = true`. One code/secret **name drift** (`REVENUECAT_SECRET_API_KEY`) was found and fixed in this branch.

---

## Environment Readiness Score

| Area | State | Score |
|---|---|---|
| Core runtime (Supabase URL/anon/service-role/JWT/DB, R2 storage, Anthropic, Gemini) | Provisioned in **dev + prd** | ✅ 100% |
| AI-service trust boundary (`AI_SERVICE_TOKEN`, `AI_SERVICE_URL`) | In prd; Fly/Supabase-secret copies *founder-verify* | 🟡 85% |
| Purchases (RevenueCat SDK + webhook + server key) | Keys in prd (platform-split); **products/offerings = founder** | 🟡 70% |
| Observability (Sentry) + Analytics (PostHog) | **Missing in prd** (both client and server-side) | 🔴 30% |
| Apple Sign-in | Provider `enabled=true` but **secrets missing in prd** | 🔴 20% |
| Anonymous web checker (Turnstile + salted IP) | `ANON_IP_SALT` missing (optional); `TURNSTILE_SECRET_KEY` *founder-verify* | 🟡 60% |
| Release/CI signing secrets (Fly, App Store Connect, match) | GitHub Actions secrets — *founder-verify* | 🟡 50% |
| Legacy hygiene (removed-vendor slots still in prd) | **6 legacy slots present** — need deletion | 🔴 40% |
| **Overall production-env readiness** | Core solid; gaps are analytics/observability/Apple/legacy | **~72%** |

The gaps are all **founder-held values or console actions** — no code change is blocked. The one code defect found (RevenueCat key name) is fixed in this branch.

---

## A. Client — Flutter (`--dart-define`, compiled in, public/RLS-guarded)

| Name | Required | dev | prd | Where used | Prod status | Action |
|---|---|---|---|---|---|---|
| `SUPABASE_URL` | Yes | ✅ | ✅ | `supabase_providers.dart` | Present | **KEEP** |
| `SUPABASE_ANON_KEY` | Yes | ✅ | ✅ | client auth (RLS-guarded) | Present | **KEEP** |
| `SENTRY_DSN` | Recommended | ❌ | ❌ | `main.dart` crash reporting | **MISSING** | **CREATE** (publishable DSN; safe in client) |
| `POSTHOG_API_KEY` | Optional (analytics) | ❌ | ❌ | `analytics.dart` (gated by consent) | **MISSING** | **CREATE** if analytics wanted at launch; else KEEP unset (degrades cleanly) |
| `POSTHOG_HOST` | Optional | ❌ | ❌ | `analytics.dart` (build default `https://us.i.posthog.com`) | Missing (defaulted) | **KEEP** default |
| `REVENUECAT_PUBLIC_SDK_KEY` | Yes (purchases) | ❌ | split | RC SDK init | prd has `_IOS`/`_ANDROID`; **build must inject the platform key as this name** | **KEEP** (document the per-platform mapping) |
| `APP_VERSION` | Optional | n/a | n/a | version stamp | Build-time | KEEP |
| `LEGAL_BASE_URL` | Optional | n/a | n/a | `legal_urls.dart` (default = live CloudFront) | Defaulted | KEEP (set when custom domain lands) |

> Verified on-device: with `SENTRY_DSN`/`POSTHOG_API_KEY`/`REVENUECAT_PUBLIC_SDK_KEY` **absent**, the release build launches, renders, and degrades cleanly (no crash) — those integrations are simply inert. So they are launch-*quality* items, not launch-*blockers*, except RevenueCat (needed for the paid product to function).

## B. AI service — Python on Fly (`os.getenv`, server-only 🔒)

| Name | Required | Present | Where used | Action |
|---|---|---|---|---|
| `ANTHROPIC_API_KEY` 🔒 | Yes | dev ✅ / prd ✅ | Tier-3 Claude (`config.py:18`) | **KEEP** · rotate quarterly |
| `GOOGLE_AI_API_KEY` 🔒 | Yes | dev ✅ / prd ✅ | Tier-2 Gemini (`config.py:19`) | **KEEP** · rotate quarterly |
| `AI_SERVICE_TOKEN` 🔒 | Yes (prod fails **closed**) | prd ✅ | `main.require_service_auth` | **KEEP** · must equal the Edge copy |
| `SENTRY_DSN` 🔒 | Recommended | prd ❌ | `config.py:45` (no-op if unset) | **CREATE** as a Fly secret |
| `GEMINI_MODEL` / `CLAUDE_MODEL` | Optional | Fly env | model-ID overrides (`config.py:8-9`) | KEEP (pinned defaults) |
| `AI_KILL_SWITCH` | Optional | Fly env | static kill-switch (`config.py:25`) | KEEP |
| `AI_ENV` | Optional | Fly env | prod detection override (`config.py:37`) | KEEP |
| `FLY_APP_NAME` | Auto | Fly-set | prod detection | n/a (platform) |
| `UPSTASH_REDIS_REST_URL` / `_TOKEN` 🔒 | Optional | prd ✅ | dynamic kill-switch + result cache | KEEP |

## C. Edge Functions (`Deno.env.get`, `supabase secrets set` / Doppler prd 🔒)

| Name | Required | prd | Where used | Action |
|---|---|---|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Yes | ✅ | all functions | KEEP |
| `SUPABASE_SERVICE_ROLE_KEY` 🔒 | Yes | ✅ | admin writes / deletion (never user reads) | KEEP · rotate quarterly |
| `AI_SERVICE_URL` | Yes | *founder-verify* (Supabase secret, not Doppler) | `analyze` → Fly base URL | **VERIFY** set on the project |
| `AI_SERVICE_TOKEN` 🔒 | Yes | ✅ | bearer to the AI service | KEEP (same value both sides) |
| `REVENUECAT_WEBHOOK_SECRET` 🔒 | Yes (webhook) | ✅ | `revenuecat-webhook` auth | KEEP |
| `REVENUECAT_API_KEY` 🔒 | Optional | ✅ | `delete-account` RC subscriber purge | **KEEP** — *code aligned to this name in this branch (was `REVENUECAT_SECRET_API_KEY`, a drift that silently skipped the purge)* |
| `TURNSTILE_SECRET_KEY` 🔒 | Yes for `analyze-anonymous` (fails **closed** 503) | ❌ in Doppler | bot-gate on the web checker | **VERIFY/CREATE** (may live as a Supabase secret) |
| `ANON_IP_SALT` | Optional (recommended) | ❌ | `analyze-anonymous` IP hashing (`?? ""` fallback) | **CREATE** (`openssl rand -hex 32`) — unset means IPs are hashed **unsalted** |
| `POSTHOG_HOST` / `POSTHOG_PERSONAL_API_KEY` / `POSTHOG_PROJECT_ID` 🔒 | Optional | ❌ | server analytics + `delete-account` PostHog purge | **CREATE** if analytics wanted (else the GDPR PostHog purge no-ops, like RC did) |
| `UPSTASH_REDIS_REST_URL` / `_TOKEN` 🔒 | Optional | ✅ | web-checker rate limit | KEEP |

## D. Supabase Auth providers (`config.toml` `env(...)`, server 🔒)

| Name | Required | prd | State | Action |
|---|---|---|---|---|
| `SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID` / `_SECRET` 🔒 | **Yes** — `[auth.external.apple] enabled = true` | ❌ | **MISSING** — Apple sign-in is enabled but unprovisioned; will fail at runtime and blocks iOS review (SIWA is required when other social login is offered) | **CREATE** |
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` / `_SECRET` 🔒 | `[auth.external.google] enabled = true` | ✅ | Provisioned, **but no client UI currently offers Google** (app is email + Apple) | KEEP · or disable the provider until a Google button exists |
| `SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN` 🔒 | No — `[auth.sms] enable_signup = false` | — | **UNUSED** (SMS auth disabled) | **DELETE** the ref (or leave dormant; not needed) |
| `OPENAI_API_KEY` (`config.toml:95`) | No | — | **Local Supabase Studio AI only** (dev convenience), *not* a runtime processor; the AI-journal OpenAI processor was removed in the evolution | Harmless; treat `OPENAI_API_KEY` as **LEGACY** for prod |
| `SECRET_VALUE` (`config.toml:51`, commented) | No | — | Template placeholder | Ignore |

## E. Web checker (Cloudflare Pages, build-time public)
`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_TURNSTILE_SITE_KEY` — set in Cloudflare Pages env (public/build-time). **VERIFY** present if the web `/check` funnel is launched; otherwise n/a.

## F. Terraform — legal-portal infra (`infra/legal-portal/variables.tf`)
`acm_certificate_arn`, `aliases`, `bucket_name`, `dist_path`, `price_class`, `region` — infra variables (tfvars, founder). Note the masterplan intends to fold legal into `web/` and retire this stack once a custom domain exists (cataloged in the roadmap). **KEEP** until then.

## G. CI/CD & release signing (GitHub Actions secrets, build-time 🔒)
`FLY_API_TOKEN` (deploy), `APP_STORE_CONNECT_API_KEY_KEY_ID` / `_ISSUER_ID` / `_KEY`, `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION` (iOS signing), `GITHUB_TOKEN` (auto). All *founder-verify* in repo settings; required only for the release/deploy workflows. The Android release keystore + Play App Signing are **not yet created** (the long-standing debug-signing item). **CREATE/VERIFY**.

## H. Tooling
`DOPPLER_TOKEN` (CI/Fly read), `SUPABASE_ACCESS_TOKEN` (prd ✅, CLI/migrations), `GH_TOKEN` (one-time admin). KEEP.

---

## Missing-Variable Checklist (before public launch)

Blocking / high:
- [ ] **`SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID` + `_SECRET`** in prd — Apple sign-in is enabled but unprovisioned (iOS-review blocker).
- [ ] **`REVENUECAT_PUBLIC_SDK_KEY`** injected per-platform at build (prd holds `_IOS`/`_ANDROID`) — the paid product needs it.
- [ ] **`AI_SERVICE_URL`** + **`AI_SERVICE_TOKEN`** confirmed on the Supabase project (Edge→Fly trust) and equal to the Fly copy.
- [ ] **`TURNSTILE_SECRET_KEY`** on `analyze-anonymous` (it fails closed) **if** the web checker launches.

Recommended (quality/privacy, non-blocking — each degrades cleanly today):
- [ ] `ANON_IP_SALT` (prd) — real IP salting for the anonymous checker.
- [ ] `SENTRY_DSN` (client build + Fly) — crash/error visibility at launch.
- [ ] `POSTHOG_API_KEY` (client) + `POSTHOG_PERSONAL_API_KEY`/`_PROJECT_ID` (Edge) — analytics + the GDPR PostHog purge on account deletion.

## Legacy-Cleanup Checklist (delete from Doppler **prd** — code no longer references any)

- [ ] `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` — OneSignal removed (on-device notifications now).
- [ ] `OPENAI_API_KEY` — AI journal + OpenAI processor removed (the `config.toml` Studio ref is local-only, not this runtime slot).
- [ ] `PLACES_API_KEY` — vet finder is now an OS maps deep link.
- [ ] `RESEND_API_KEY`, `RESEND_FROM`, `INVITE_LINK_BASE_URL` — family invites removed.
- [ ] (dev config already clean — no action.)

## Rotation guidance
Rotate `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_AI_API_KEY`, `AI_SERVICE_TOKEN`, and `R2_SECRET_ACCESS_KEY` on a quarterly cadence and immediately if a contributor with Doppler access offboards. Publishable values (`SUPABASE_ANON_KEY`, `SENTRY_DSN`, PostHog project key, RC public SDK keys) are compiled into the client and rotate only on incident.
