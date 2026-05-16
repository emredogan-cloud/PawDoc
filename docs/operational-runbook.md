# Operational Runbook

This runbook covers the **operational** half of PawDoc reliability —
the controls that live in third-party dashboards, not in code. These
must be configured by a human with billing access before the prod
environment is considered "shippable" for the Phase 1 closed beta.

**Owner:** Founder (the only person with billing access to each
provider).
**Cadence:** Verify on the first business day of every month + on the
day of every Phase release.

---

## 1. AI Provider Budget Caps

Goal: ensure a runaway loop, compromised key, or unexpected traffic
spike cannot run up a five-figure bill before we notice.

Each provider exposes two layers of control:

1. **Soft cap** — alerts you when usage crosses a monthly threshold.
2. **Hard cap** — the provider *stops accepting requests* when the
   monthly bill reaches the limit.

We set both on every AI provider that bills per-token.

### 1.1 Anthropic (Tier 3 — Claude Sonnet)

1. Sign in at https://console.anthropic.com.
2. **Settings → Plans & Billing → Spend Limits.**
3. Configure:

| Phase | Soft limit (email alert) | Hard limit (requests start rejecting) |
|---|---|---|
| Phase 1 closed beta | **$50/month** | **$200/month** |
| Phase 2 public launch | **$200/month** | **$1000/month** |
| Phase 3+ | revisit quarterly | revisit quarterly |

4. **Settings → Notifications** — confirm the founder email + Slack
   webhook (if configured) are subscribed to "Spend alert".
5. Confirm by triggering a test alert via Anthropic's "Test" button on
   the alert row.

### 1.2 Google AI Studio (Tier 2 — Gemini Flash)

1. Sign in at https://aistudio.google.com.
2. **API Keys → (your key) → Configure quotas.**
3. Configure:

| Phase | Soft limit | Hard limit |
|---|---|---|
| Phase 1 closed beta | **$50/month** | **$150/month** |
| Phase 2 public launch | **$150/month** | **$500/month** |

4. Google AI's hard cap is set via the **Cloud Billing → Budgets**
   surface for the linked project. Confirm the *project* (not just the
   API key) has a budget with the **"Cap spending at limit"** action
   enabled. Without that, the budget is alert-only.

### 1.3 OpenAI (Phase 3 only — semantic-cache embeddings)

Not active in Phase 1. When Phase 3 lands, repeat the same pattern at
https://platform.openai.com → **Settings → Limits**:

| Phase | Soft limit | Hard limit |
|---|---|---|
| Phase 3 launch | **$30/month** | **$100/month** |

OpenAI's "Usage limits" page exposes both. Hard limit returns a 429
to the client; the AI service treats this as a Tier-3 failure and
returns the cached graceful-degradation response.

### 1.4 Anomaly threshold (manual, no provider feature)

Even with caps in place, sudden 10× spikes are worth investigating
the same day. The rule of thumb:

> If the **daily** spend on Anthropic or Google AI exceeds **10×** the
> rolling 7-day average, freeze all non-essential traffic and start a
> root-cause investigation.

The PostHog dashboard tracks `analysis_completed` count; cross-check
with provider usage to detect a billing event that didn't come from a
real analysis (compromised key, scraping bot, etc.).

---

## 2. Monthly Verification Checklist

Run on the first business day of every month:

- [ ] Anthropic spend limit unchanged from §1.1
- [ ] Google AI / Cloud Billing budget unchanged from §1.2
- [ ] Email + Slack alert subscriptions still active
- [ ] Last month's actual spend logged in the founder's spreadsheet
- [ ] If actual spend > 80% of soft limit twice in a row, the cap
      gets revisited at the next planning checkpoint

---

## 3. Incident Response — Provider Hard-Cap Triggered

If Anthropic or Google AI returns a hard 429 / "spending limit
reached" error:

1. **Confirm** by visiting the provider dashboard. The cap row will
   show "tripped".
2. **Decide** in this order:
   - Is this expected month-end traffic? → Bump the cap by 25%, log
     in the spreadsheet, move on.
   - Is this a real anomaly? → Continue.
3. **Triage**:
   - Check PostHog `analysis_requested` count for the day vs.
     yesterday — is the spike on the client side or server side?
   - Check Supabase `analyses` table count for the day — confirms
     real users vs. background process.
   - Check the AI service logs in Fly.io for repeat `request_id`
     values (would indicate a client retry loop).
4. **Mitigate**:
   - Client retry loop → ship a mobile hotfix that respects the
     server's 402/429.
   - Compromised key → rotate the key in Doppler + Fly.io (`flyctl
     secrets set`) and clear it from the old provider dashboard.
   - Legitimate spike → temporarily raise the cap, then bring the
     monthly review forward.

The AI service is designed to **degrade gracefully** when both Tier 2
and Tier 3 fail — it returns a "limited assessment" response with the
emergency disclaimer. So users are not blocked; only the quality of
the result degrades. Treat the cap as a financial guardrail, not as a
fatal incident.

---

## 4. Token-Usage Telemetry (Optional Engineering Lever)

Phase 1B's `analyze_completed` log line **does not yet** include per-
analysis token counts. Sprint A2 deliberately left this as Phase 2
work (tracked in `docs/reports/phase1-technical-debt.md`).

Once added, summing `prompt_tokens + completion_tokens` over a day
gives a real-time cost forecast that runs ahead of the provider
dashboard's billing roll-up (which lags ~24h). The PostHog event
recipe for that arrives with Phase 2.

---

## 5. Pre-Launch Operational Gate

Before flipping the App Store / Play Console "Submit for review"
buttons, every box below must be ticked:

- [ ] Anthropic spend cap configured (§1.1)
- [ ] Google AI / Cloud Billing budget configured (§1.2)
- [ ] Alert recipients confirmed (founder email + at least one
      secondary channel)
- [ ] Better Uptime monitors live for both AI service + Supabase
- [ ] Sentry alerts wired to the same recipients
- [ ] RevenueCat webhook deliverability verified (test purchase in
      sandbox)
- [ ] Apple Sign-In configured per
      [`environment-setup.md` §14](environment-setup.md)
- [ ] Orphan-upload cleanup scheduled per §6
- [ ] First month's projected spend < 50% of the hard cap

If any box is empty, **do not submit**.

---

## 6. Orphan Upload Cleanup (Sprint B1)

The `/analyze` flow uploads a pet image to `pet-uploads/<user>/…`
**before** it consumes the user's free-tier slot. When the AI call
or persist fails afterward, Sprint A2's `refund_free_analysis` RPC
refunds the slot — but the image stays in the bucket. Without
cleanup the bucket grows monotonically.

The Sprint B1 migration adds:
```
public.cleanup_orphan_pet_uploads(p_older_than interval) → int
```
which deletes every `storage.objects` row in the `pet-uploads`
bucket older than `p_older_than` (default 7 days) that no
`analyses` row references. Service-role only. Returns the deletion
count.

### 6.1 Manual run (anytime)

From the Supabase SQL editor logged in as service-role:
```sql
SELECT cleanup_orphan_pet_uploads();           -- 7-day default
SELECT cleanup_orphan_pet_uploads(interval '14 days');  -- looser cap
```
Or via the CLI:
```bash
supabase db remote-commit --project-ref <prod-ref> \
  --command "SELECT cleanup_orphan_pet_uploads();"
```
Log the count in the founder's spreadsheet alongside the monthly
spend review (§2). Steady-state is single-digits per day; double-
digit spikes mean the analyze pipeline is dropping more requests
than usual — check Sentry for `analyses_insert_failed` and
`ai_service_call_*` warnings.

### 6.2 Scheduled run (production)

Supabase Cloud ships `pg_cron`. Enable + schedule once:
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'pawdoc-orphan-cleanup',
  '0 4 * * *',
  $$SELECT cleanup_orphan_pet_uploads();$$
);
```
4:00 UTC daily; tweak if your peak traffic shifts. Verify with:
```sql
SELECT * FROM cron.job WHERE jobname = 'pawdoc-orphan-cleanup';
SELECT * FROM cron.job_run_details
 WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'pawdoc-orphan-cleanup')
 ORDER BY start_time DESC LIMIT 7;
```

Local development deliberately omits `pg_cron` — the function is
still callable directly for testing (`supabase test db --local`
exercises it).

### 6.3 What this does NOT do

- It does **not** delete the underlying S3 / R2 blobs that
  `storage.objects` rows point to. Supabase's storage worker
  reconciles those eventually; if the bucket size doesn't shrink
  within ~24h after a large cleanup, file a Supabase support
  ticket. The cost impact of a stale blob is small compared to a
  proliferating bucket of metadata rows.
- It does **not** cover the `pet-photos` bucket (Phase 2). Re-run
  the function with `bucket_id = 'pet-photos'` when that bucket
  exists.
