# PawDoc — Launch Readiness Matrix (Phase 5)
**2026-06-13**

## Readiness matrix
| Gate | Status | Blocking items | Owner | Time remaining | Confidence |
|------|--------|----------------|-------|----------------|------------|
| **Engineering GO** | ✅ **ACHIEVED** | none — 30 findings closed, CI green on main, release `.aab` builds, safety intact | Agent (done) | 0 | **High** — independently verified this mission |
| **Beta GO (50 users)** | 🟡 **NOT YET** | FA-1 signing · FA-2 store accounts · FA-3 listing+creds · FA-4 SMTP · FA-5 auth dash · FA-6 RevenueCat · FA-7 FCM · FA-8 dev DB/PITR · FA-9 monitoring · FA-10 domain · FA-11 TR decision · FA-12 on-device E2E · FA-15 runbook fills | **Founder** | ~2–3 founder-days work; **~1–2 wks calendar** (Apple enrolment lead) | **High** — all standard console/device work, no unknowns |
| **Public Launch GO** | 🔴 **NOT YET** | FA-13 privacy/terms finalization · FA-14 attorney review + **E&O insurance** · store review | **Founder + Attorney** | **~4–8 wks calendar** | **Medium** — external legal/insurance + store-review dependencies |

## Estimates
- **Days to Beta GO:** ~**2–3 working days** of founder effort; calendar **~1–2
  weeks** (the binding constraint is Apple Developer enrolment, esp. org D-U-N-S).
- **Days to Public Launch GO:** **~4–8 weeks** from today — dominated by the
  attorney finalization + E&O binding (2–4+ wks) plus store review (2–7 days),
  which can run in parallel with beta.
- **Cash (first year):** ~**$130 one-time** (Apple $99 + Play $25 + domain ~$12)
  + ~**$50–75/mo** recurring (Supabase Pro $25 + SMTP $0–20 + Sentry/monitoring
  $0–26 + Fly ~$5–20) + **$1.5k–5k** legal (privacy/terms/waiver) + **$0.5k–2k/yr**
  E&O. **First-year total ≈ $2.5k–8k**, dominated by legal/E&O.

## Biggest remaining risks
1. **Legal/E&O timeline** — the true critical path; start it Day 0 or launch slips.
2. **Keystore loss** — lose the upload key and you can never update the app. Back it up off-machine.
3. **On-device emergency-path regression** — the #1 business risk (false negative); must be walked on a real device (FA-12), the one thing CI/agent can't cover.
4. **Store review rejection** — health/medical apps get extra scrutiny; the listing is positioned as *triage/information, not veterinary advice* + demo creds + disclaimers must be airtight.
5. **RevenueCat product-ID mismatch** — RC offering IDs must match the store product IDs or purchases fail silently (paywall stays "coming soon").

## Top 5 highest-leverage actions (do these first)
1. **Today:** start Apple enrolment **and** engage the attorney + request E&O quote (longest leads — they gate everything downstream).
2. **Before any real user:** harden the backend — separate dev project + **PITR** (FA-8); a bad migration without backups is unrecoverable.
3. **On-device emergency walk** (FA-12) — submit "my dog is choking…", confirm EMERGENCY + disclaimer + **no paywall**. Safety gate.
4. **RevenueCat products + sandbox purchase** (FA-6) — flips the paywall from "coming soon" to revenue.
5. **Run `verify-no-placeholders.sh --strict` to 0** (FA-3) — fills legal entity, store URLs, App Review creds; it's the machine-checkable launch gate.
