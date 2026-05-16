# Rollback Runbook

Last-resort procedures for getting PawDoc back to a known-good state.
**Read before pulling triggers.** Most production issues are better
served by a forward-fix; rollback is for catastrophic regressions only.

Decision rule: if the change introduced data corruption or a
user-visible safety regression (false-negative EMERGENCY, mass auth
breakage, paywall ineffective), prefer rollback. For latency tails or
UI quirks, fix forward.

---

## 1. AI Service (Fly.io)

The fastest rollback path. Releases are immutable; each deploy is a
new container image.

```bash
# List recent releases
flyctl releases list --app pawdoc-ai-prod

# Roll back to the version that was healthy
flyctl releases rollback <prior-version> --app pawdoc-ai-prod

# Watch traffic shift; new instances replace old
flyctl status --app pawdoc-ai-prod
```

**Verify after:** `curl https://pawdoc-ai-prod.fly.dev/health` returns
200 with the expected `version` field.

**When NOT to rollback:** if the prior version had a known security or
safety regression. In that case fix forward — bump version, deploy.

---

## 2. Supabase Edge Functions

There is no native rollback. We redeploy from a prior commit.

```bash
# Stash any local work
git stash

# Check out the last known-good commit
git checkout <prior-sha>

# Redeploy the affected function(s)
supabase functions deploy analyze --project-ref <prod-ref>
supabase functions deploy revenuecat-webhook --project-ref <prod-ref>
supabase functions deploy auth-webhook --project-ref <prod-ref>

# Return to main and your stashed work
git checkout main
git stash pop
```

**Verify after:** trigger a test event through the affected function
and watch the Supabase function logs in the dashboard.

**Note:** edge functions deploy in seconds — there's no "rolling
deploy." A brief window of mixed-version processing is possible if a
client made an in-flight request right at the deploy boundary.

---

## 3. Supabase Migrations

**Forward-only.** Never run destructive rollbacks against production
data. To revert a problematic migration:

1. Author a follow-up migration that reverses the change (e.g., a
   migration named `..._revert_<slug>.sql`).
2. Apply it through the normal CI deploy pipeline.
3. Never edit a previously-applied migration file. The CI lint will
   catch it; production has no path to apply the edit anyway.

**Special case — bad CHECK constraint that's blocking writes:**
- Author a migration that drops the constraint:
  `ALTER TABLE x DROP CONSTRAINT x_foo_check;`
- Decide later whether to re-add the constraint with corrected logic.

**Special case — accidentally-permissive RLS policy:**
- Treat as a P0 security incident.
- Author a migration that drops the offensive policy and adds the
  correct one in the same transaction.
- Notify the user base if data may have leaked (legal counsel
  involvement).

---

## 4. Mobile (TestFlight / Play Internal)

Mobile rollbacks are slow because users have to re-download.

**iOS TestFlight:**
- App Store Connect → TestFlight → invalidate the failing build.
- Users on the failing build see "no build available" until they
  install the prior version.
- For production App Store releases: same flow, plus halt-rollout in
  the App Store Connect dashboard.

**Android Play Console:**
- Play Console → Production → Halt rollout (or roll back to a prior
  build if you've kept it as the production track).
- Already-installed users keep the failing version until they reinstall
  or update to the next forward-fix release.

**Forward-fix discipline for mobile:**
- Increment the build number.
- Submit a new build with the fix.
- Phased rollout: start at 5%, watch Sentry crash-free sessions, ramp
  up to 100% over 24-48 hours.

---

## 5. RevenueCat

There is no rollback of webhook side effects (the webhook has already
written to `public.users.subscription_status`).

**If the webhook misbehaved:**
- Replay events from the RevenueCat Dashboard → Events → Resend.
- Each event is idempotent (`UPSERT` against `id`), so replays are
  safe.
- Use the dashboard's filter to scope to the affected window.

**If you need to manually fix a user's entitlement:**
- Service-role SQL:
  ```sql
  UPDATE public.users
     SET subscription_status = 'premium', subscription_tier = 'pawdoc_premium_annual'
   WHERE id = '<user_id>';
  ```
- This is appropriate for support escalations only. Always pair with a
  RevenueCat side note explaining why.

---

## 6. OneSignal

OneSignal has no rollback semantics. If a campaign sent in error:
- Stop the campaign in the dashboard.
- Consider an apology campaign acknowledging the mistake (better than
  silent radio).
- Audit the trigger source (segment query, manual trigger, automated
  rule) and fix it before re-enabling.

---

## 7. Sentry

Sentry is read-only ops infrastructure. There is nothing to "roll
back." If Sentry was reporting in error:
- Resolve the noisy issues in the Sentry UI.
- Adjust `sampleRates` if quota is at risk.

---

## 8. Decision Tree

```
Is the issue a data correctness or safety regression?
├── YES → Rollback ai-service (fastest); investigate
│         Forward-fix supabase functions if affected
│         Mobile: halt rollout + forward-fix
└── NO (latency, UI nit, log noise)
    └── Forward-fix only. Roll forward.
```

## 9. Post-Incident

After every rollback OR forward-fix incident:

1. Within 24 hours, draft a one-page post-mortem:
   - What happened, when, who saw it
   - Root cause
   - Mitigation steps taken
   - Lesson learned
   - Action items (with owners + deadlines)
2. Add a regression test for the failure mode.
3. Update this runbook if the procedure was unclear.

---

*Last reviewed: 2026-05-16 (Phase 1D).*
