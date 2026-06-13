# Runbook 22 — Incident Response & Outage Procedures (GAP-D4)

Operational playbook for when something breaks in production. Goal: anyone on
call can execute an incident **without tribal knowledge**. Pairs with runbook
12 (observability/alerts), 08 (Fly), 06 (Supabase), 09 (RevenueCat), 19
(beta/launch).

> **Safety overrides everything.** PawDoc is pet-health triage; a **false
> negative is the #1 business risk**. During ANY incident the non-negotiables
> hold: the hardcoded **emergency keyword override runs before any AI**, the
> server **injects the disclaimer on every result**, **emergencies are never
> paywalled**, and when the AI can't answer confidently the app says
> **"insufficient information → contact a vet"** — it NEVER fabricates a
> "normal". If an incident response would weaken any of these, **stop and take
> the feature offline instead.**

---

## 0. Quick reference

| Symptom | Likely cause | Section |
|---------|--------------|---------|
| `/analyze` errors / very slow; results all "insufficient information" | AI service / providers | §2 |
| Login fails, data won't load, every API 401/5xx | Supabase (DB/Auth/Edge) | §3 |
| Purchases fail / "premium" not unlocking / double credits | RevenueCat | §4 |
| Push notifications not arriving | OneSignal | §5 |
| "Upload failed" on capture | Cloudflare R2 / upload Edge fn | §6 |
| A bad build/migration shipped | — | §7 rollback |
| A beta tester reports a problem | — | §8 |

**First 15 minutes (any SEV):** 1) confirm it's real (reproduce + check the
dashboard), 2) assess **safety impact first** (is the emergency path intact?),
3) set severity (§1), 4) post status in the incident channel, 5) mitigate (often
disable/rollback before root-causing), 6) only then diagnose.

**Founder-fill (provision before beta — see §9):** on-call contact(s), incident
channel, status page URL, dashboard links. Marked `<FILL>` below.

---

## 1. Incident framework

**Severity**
- **SEV1** — safety path broken OR full outage (no one can get triage). Example:
  emergency results not surfacing, disclaimer missing, analyze hard-down. Drop
  everything; mitigate within minutes.
- **SEV2** — major feature down, safety intact (e.g. purchases failing, uploads
  failing, push down). Mitigate same day.
- **SEV3** — degraded/cosmetic (slow, one screen glitchy). Next business day.

**Roles** (solo founder may hold all): *Incident Lead* (decides, communicates),
*Operator* (executes fixes). For SEV1 a second person verifies the safety path
after mitigation.

**Comms cadence:** SEV1 — update the channel every 30 min until resolved; SEV2 —
at mitigation + resolution. Always post: what's impacted, what's NOT (esp. "the
emergency path is unaffected"), ETA, next update time.

**The loop:** detect → assess safety → mitigate → diagnose → fix → validate
locally (the repo's gates: `flutter analyze/test`, `pytest`/`ruff`,
`node --test`, `test-rls.sh`) → deploy → verify → write a short post-incident
note (cause, fix, prevention).

---

## 2. AI service outage  (Fly `pawdoc-ai` + Gemini/Claude)

**Detection:** `release.yml`/deploy smoke or alerts on `https://pawdoc-ai.fly.dev/health`;
Sentry spike from `ai-service`; users report errors or all-"insufficient
information" results.

**Impact & what stays safe:** The pipeline is ordered for safety — the hardcoded
**emergency keyword override runs first**, so blatant emergencies are flagged
**even with both AI providers down**. Tier 2 (Gemini) → Tier 3 (Claude) failover
is automatic; only if **both** tiers fail does it **degrade to the safe fallback
(CR #5)** — a conservative, disclaimered "couldn't fully analyze, contact a vet
if unsure" — never a fabricated normal. So the danger in an AI outage is *lost
functionality*, not unsafe output.

**Mitigate:**
1. `flyctl status -a pawdoc-ai` and `flyctl logs -a pawdoc-ai`. If the app is
   unhealthy/crashed: `flyctl apps restart pawdoc-ai`.
2. If a recent deploy caused it → **rollback** (§7 AI service).
3. If a provider (Gemini/Claude) is the culprit (timeouts/5xx/quota): confirm the
   other tier carries load; if both are degraded, the safe fallback is already
   protecting users — post a status note and wait out the provider, or flip the
   kill-switch (CR #19) to force the safe fallback intentionally.
4. Check Doppler hasn't rotated/expired a provider key (a 401 from a provider
   looks like an outage).

**Recover/verify:** `/health` returns 200; submit a known **EMERGENCY** text
("my dog is choking and can't breathe") and a benign text — confirm EMERGENCY
surfaces with the seek-care directive and a normal-ish case returns sensibly,
both with the disclaimer.

---

## 3. Supabase outage  (Postgres / Auth / Edge Functions / RLS)

**Detection:** Supabase status page `<FILL>`; auth + all data calls fail; Edge
functions (`analyze`, `generate-upload-url`, webhooks) 5xx.

**Impact:** Broad — sign-in, pets, history, analyze (the Edge `analyze` wraps the
AI service), uploads (presign), webhooks. This is typically **SEV1** (no triage
possible). RLS is unaffected by an outage (it fails closed — no data leaks).

**Mitigate:**
1. Check the Supabase status/dashboard for the project `<FILL>`. If it's a
   Supabase-side platform incident: nothing to fix in-app — post status, monitor.
2. If it followed a **migration** deploy → roll the migration back (§7 DB) and
   re-run `./scripts/test-rls.sh` locally to confirm RLS still isolates.
3. If a single Edge function is failing: check its logs; redeploy the last-good
   version (`supabase functions deploy <name> --project-ref <ref>`).
4. Auth issues only: confirm the JWT/anon keys in Doppler are current; check the
   `auth` webhook isn't erroring (runbook 13).

**Recover/verify:** sign in on a test account, load pets/history, run one analyze
end-to-end, and run `test-rls.sh` if any migration/policy changed.

---

## 4. RevenueCat outage  (subscriptions / entitlements / webhook)

**Detection:** RevenueCat status `<FILL>`; purchases fail; "premium" not
unlocking; `revenuecat-webhook` 5xx in Edge logs.

**Impact & what stays safe:** Monetization only. **Emergencies are never
paywalled** (enforced server-side in the analyze Edge fn AND client
`paywall_policy`), so an RC outage **cannot block a triage result**. Worst case:
a paying user temporarily doesn't see premium, or a credit isn't applied.

**Mitigate:**
1. RC platform incident → post status; entitlements generally keep working from
   RC's cache. Do **not** hand-grant premium in the DB under pressure (audit
   risk); wait for RC.
2. Webhook failing: check `revenuecat-webhook` logs. The handler is **idempotent**
   (E5 — `processed_rc_events` pk ledger) and **releases its claim on a transient
   failure**, so RC's retries reconcile automatically once healthy — do NOT
   replay events manually (you'd risk nothing, but let the retry/idempotency do
   it).
3. If the shared webhook secret rotated, update `REVENUECAT_WEBHOOK_SECRET` in
   Doppler + the RC dashboard so signature checks pass.

**Recover/verify:** a sandbox purchase reflects the right entitlement; a replayed
webhook event is a no-op (idempotent).

---

## 5. OneSignal outage  (push notifications)

**Detection:** OneSignal status `<FILL>`; reminders/pushes not delivered.

**Impact:** **Non-critical** — push is a convenience (reminders). No safety or
core-flow impact; the app works fully without it.

**Mitigate:** Usually nothing to do but wait out an OneSignal platform incident —
post a brief status note. If sends fail after a config change, verify
`ONESIGNAL_APP_ID`/REST key in Doppler. Identity hygiene is already handled
(E6: external IDs are cleared on sign-out), so there's no cross-account leak risk
during recovery.

**Recover/verify:** send a test notification to a test device.

---

## 6. Cloudflare R2 / upload outage

**Detection:** "Upload failed" on capture; `generate-upload-url` Edge fn errors;
R2/Cloudflare status `<FILL>`.

**Impact:** Photo/video capture can't upload. **Text triage still works** (no
upload needed), and the client now (E8c) **fails gracefully** — bounded retries,
per-call timeouts (no infinite spinner), and a clear message — so users aren't
stuck. SEV2.

**Mitigate:**
1. R2/Cloudflare platform incident → post status; text triage remains available.
2. If `generate-upload-url` errors: check its logs + that the R2 credentials in
   Doppler are valid (they live server-side only — never in the client).
3. Bucket/CORS misconfig after a change → re-verify per runbook 07.

**Recover/verify:** capture + upload a photo end-to-end; confirm EXIF is stripped
and orientation is correct (E8b).

---

## 7. Emergency rollback

**Mobile app (already shipped):** you cannot instantly recall an installed build.
1. **Halt the rollout** in the Play Console (pause the staged rollout) / App Store
   (remove from sale or halt phased release) — stops the blast radius.
2. Ship an expedited fix: branch → fix → local gates green → bump build number →
   `fastlane <platform> beta` (verify on TestFlight/internal) → `release`
   (runbook 11 / B4). Request expedited App Review if SEV1.
3. If the bug is server-side, prefer fixing the backend (below) — it reaches all
   users immediately without a store cycle.

**AI service (Fly):** `flyctl releases -a pawdoc-ai` → `flyctl releases rollback
<version> -a pawdoc-ai`. Re-run the `/health` smoke.

**Edge Functions:** redeploy the previous good revision:
`supabase functions deploy <name> --project-ref <ref>` from a checkout of the
last-good commit.

**Database migration:** Postgres migrations are forward-only here. To revert,
write a NEW compensating migration (don't edit a shipped one), test it with
`./scripts/test-rls.sh`, and apply. For destructive changes, restore from PITR
(`<FILL>` — founder must enable PITR first) — coordinate, this can lose data.

After any rollback: verify the **safety path** (emergency text → EMERGENCY +
disclaimer) before declaring resolved.

---

## 8. Beta escalation path

**Channel:** beta testers report via `<FILL: support email / TestFlight feedback /
form>`; triage daily during the 50-user beta.

**Flow:**
1. **Intake** — capture: device/OS, app version, steps, screenshot, and (if a
   triage result looked wrong) the input + what was expected. *Never* ask testers
   to send another animal's medical data beyond what they submitted.
2. **Triage severity (§1).** Any report of a **missed/incorrect emergency or a
   missing disclaimer is an automatic SEV1** — reproduce immediately.
3. **Reproduce** with the reported version; check Sentry/PostHog for the session.
4. **Fix** on a branch → local gates → release via fastlane.
5. **Close the loop** — tell the tester what shipped; thank them.

**Acknowledge SLA (beta):** SEV1 < 2h, SEV2 < 1 business day, SEV3 best-effort.

---

## 9. Founder-controlled prerequisites

Provision before beta so this runbook is executable (replace every `<FILL>`):
- On-call contact(s) + an **incident channel** (Slack/Discord/email thread).
- A public/internal **status page** (even a pinned doc).
- **Dashboard links**: Fly, Supabase, RevenueCat, OneSignal, Cloudflare, Sentry,
  PostHog, Play Console, App Store Connect.
- **Supabase PITR** enabled (for §7 DB restore) — see runbook 06.
- Alert routing wired (runbook 12) so detection isn't "a user told me".
