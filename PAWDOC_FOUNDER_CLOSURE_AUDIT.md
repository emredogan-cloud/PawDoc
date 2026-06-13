# PawDoc — Founder Closure Audit (Phase 3)
**2026-06-13** · every remaining item is founder-controlled. IDs map to the
blueprint's F-series / finding inventory (evidence column).

Legend: **Crit-path** = blocks beta or launch. Cost = first-year estimate (USD).

| # | Item | Gate | Why it matters / risk if skipped | Time | Cost | Accounts/services | Deps | Evidence |
|---|------|------|----------------------------------|------|------|-------------------|------|----------|
| FA-1 | **Android signing keystore** (B1/F-6) | Beta | Release is debug-signed; Play **rejects** debug-signed AABs and a debug key can't be rotated → can't ship/update. | 1h | $0 | Play Console, local keytool | — | blueprint B1 |
| FA-2 | **Apple Developer + Google Play accounts** (F-7/8) | Beta | No store presence without them; Apple enrollment can take days (D-U-N-S for orgs). | 1–3h + wait | $99/yr + $25 once | Apple Developer, Google Play Console | — | runbooks 01/02 |
| FA-3 | **Store metadata + asset pack** (B6) + **`--strict` fills** | Beta | Listing needs icon/screenshots/copy + **App Review demo creds** (`[REVIEWER_DEMO_*]`), or review is rejected. | 3–5h | $0 | both consoles | FA-2, FA-1 | `verify-no-placeholders.sh --strict` |
| FA-4 | **SMTP + Supabase redirect URLs** (E1/F-13) | Beta | Password-reset emails don't send → week-1 lockouts unrecoverable. | 1h | $0–20/mo | Resend/Postmark/SES + Supabase | — | E1 doc-comment |
| FA-5 | **Supabase auth dashboard** (E3/F-14) | Beta | Raise server min-password to 8; allow-list `pawdoc://login-callback`. Weak server policy undercuts the client gate. | 20m | $0 | Supabase | — | E3 report |
| FA-6 | **RevenueCat products/offerings** (E5/F-15) | Beta | Paywall shows "coming soon" until configured → **no revenue**; verify webhook secret + sandbox purchase. | 2h | $0 (free <$2.5k/mo) | RevenueCat, App Store Connect, Play | FA-2 | paywall_screen.dart |
| FA-7 | **FCM key for OneSignal** (E6/F-16) | Beta | Push/reminders don't deliver (Android). Non-safety, but a retention feature. | 45m | $0 | Firebase, OneSignal | — | onesignal_service.dart |
| FA-8 | **Dev Supabase project + PITR + prod hardening** (D1/F-5) | Beta | One prod DB, no backups → a bad migration or wrong-env write = **data loss**, no recovery. PITR needs Pro. | 2h | $25/mo (Pro) | Supabase | — | blueprint D1 |
| FA-9 | **Monitoring + spend caps + live Sentry DSN** (D2/F-11) | Beta | Outages invisible; a runaway AI loop could rack cost. Wire Better Stack + provider spend caps + Sentry env. | 2h | $0–26/mo | Better Stack, Sentry, Fly, provider consoles | — | blueprint D2 |
| FA-10 | **Domain `pawdoc.app` + DNS + support email** (F-4) | Beta | Privacy/terms URLs, deep-link App Links, support@ all depend on it; the app links to `pawdoc.app`. | 1–2h | $12/yr | Registrar, Cloudflare | — | runbook 03 |
| FA-11 | **Turkish emergency-keyword decision** (E4) | Beta (scope) | If TR users are in scope, the safety override needs TR keywords — a **false-negative safety gap** otherwise. Decision: add (agent AG-OPT-1) or scope-out TR for beta. | 15m decide | $0 | — | — | blueprint E4 |
| FA-12 | **On-device E2E + live photo smoke** (F-17) | Beta | The only validation the headless agent can't do: real device, camera, live backend, emergency path. **Safety-critical confidence.** | 2–3h | $0 | Android/iOS device | FA-1, FA-4, FA-6, FA-8 | CI device-validation note |
| FA-13 | **Privacy Policy + Terms finalization** (C1–C3) | **Launch** | Templates have `[LEGAL ENTITY]/[ADDRESS]/[DATE]` + a counsel-drafted liability waiver. Health-adjacent + GDPR/CCPA → **legal exposure** if shipped as-is. | attorney-led | $1.5k–5k | Attorney | legal entity formed | `--strict` gate |
| FA-14 | **Attorney review + E&O insurance** (C4–C7/F-1..3) | **Launch** | Pet-health triage carries liability; E&O (professional liability) + a reviewed disclaimer chain protect the business. **The public-launch critical path** (weeks). | 2–4+ wks | $0.5k–2k/yr (E&O) + legal above | Attorney, insurer | legal entity | blueprint C1–C7 |
| FA-15 | **Runbook `<FILL>` operational data** (D4) | Beta | On-call contact, status page, dashboard links, support channel — so incident response is executable, not theoretical. | 30m | $0 | — | FA-9, FA-10 | runbook 22 §9 |

## Notes
- **Already done by the founder's pipeline:** branch protection is active (F-12),
  and **the AI service auto-deployed to Fly** on merge (deploy workflow green +
  `/health` smoke passed) — so F-17's *service* half is live; only the *on-device
  client* smoke (FA-12) remains.
- **Security reminder:** a GitHub PAT was pasted into chat this session and must
  be **revoked/rotated** (it was not used or stored by the agent).
- **No agent dependency** blocks any of the above — all are console/legal/device.

→ Ordered, click-by-click execution in PAWDOC_FOUNDER_ROADMAP.md.
