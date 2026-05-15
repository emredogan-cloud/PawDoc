# Deployment

How code reaches production for each service. All deploys are triggered from
GitHub Actions; nothing ships from a developer's laptop in prod.

---

## AI Service (Fly.io)

**Trigger:** push to `main` touching `ai-service/**`, or manual `workflow_dispatch`.

**Pipeline:** [`.github/workflows/ai-service-deploy.yml`](../.github/workflows/ai-service-deploy.yml)

```
push to main ─► ai-service-ci passes ─► ai-service-deploy
                                          │
                                          ├── checkout
                                          ├── set up flyctl
                                          ├── flyctl deploy --remote-only --app pawdoc-ai-<env>
                                          └── external /health check
```

**Strategy:** rolling. `min_machines_running = 1` ensures no cold starts.
A failing `/health` aborts the deploy (Fly's check waits for 200 before
routing traffic; the workflow doubles up with an external curl).

**Rollback:**

```bash
flyctl releases --app pawdoc-ai-prod
flyctl releases rollback <version> --app pawdoc-ai-prod
```

**Environments:**
- `pawdoc-ai-dev` (always-on, low resources, dev Supabase + R2)
- `pawdoc-ai-prod` (always-on, prod Supabase + R2)

Secrets injected by Doppler → Fly secrets.

---

## Supabase

**Migrations**

**Trigger:** push to `main` touching `supabase/migrations/**` (Phase 1+).

Migrations are forward-only. The workflow runs `supabase db push --linked` against the dev project on PR (preview) and the prod project on merge.

```
PR        ─► supabase-ci/migrations lint ─► supabase db push --dry-run on dev
merge     ─► supabase db push on dev
release tag ─► supabase db push on prod (manual approval required)
```

**Rollback:**
Migrations cannot be rolled back automatically. To recover from a bad migration:
1. Author a new "fix" migration (e.g., reversing the previous change).
2. Apply it through the normal pipeline.
3. NEVER edit a migration that has been applied to a remote.

**Edge Functions**

```bash
supabase functions deploy <name> --project-ref <prod-ref>
```

Trigger: push to `main` touching `supabase/functions/**` (Phase 1+).
Rollback: redeploy the previous source — versions are not snapshotted by Supabase.

---

## Mobile (TestFlight + Google Play)

**Trigger:** Git tag matching `v*`, e.g., `v0.1.0`.

**Pipeline:** [`.github/workflows/mobile-release.yml`](../.github/workflows/mobile-release.yml)

```
tag v0.1.0 ─► mobile-ci passes
              │
              ├── iOS job  ─► fastlane ios beta  ─► TestFlight
              └── Android  ─► fastlane android beta ─► Internal Testing
```

**Phase 0 status:** the workflow scaffold exists but jobs are gated by the
repo variable `MOBILE_RELEASE_ENABLED=true`. Phase 2 enables it once:
- Apple Developer enrollment is complete
- Fastlane Match (or App Store Connect API key) is configured
- Google Play Console service account is configured
- Doppler has all required signing secrets

**Strategy:** phased rollouts in both stores. Halt rollout from store console
if Sentry crash-free sessions drop more than 0.5% relative to the prior version.

**Rollback:**
- iOS: revert to the previous TestFlight build; submit hotfix.
- Android: pause rollout in Play Console; revert to previous build.

App binaries are inherently slow to roll back to users — keep prod deploys
boring.

---

## Cloudflare R2

Not deployed via code. Buckets, CORS, and lifecycle rules are configured in
the Cloudflare Dashboard or via Terraform (Phase 3+ if needed). Change log is
the dashboard's audit log.

---

## Secrets in Each Pipeline

| Workflow | Secrets Needed |
|----------|----------------|
| mobile-ci | none |
| ai-service-ci | none |
| supabase-ci | none |
| secret-scan | `GITHUB_TOKEN` (auto) |
| ai-service-deploy | `FLY_API_TOKEN` |
| mobile-release | `APP_STORE_CONNECT_KEY_*` (Phase 2), `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (Phase 2), Match repo deploy key |

All are GitHub Actions secrets, populated by Doppler's GitHub integration.

---

## Deployment SLOs

| Metric | Target |
|--------|--------|
| AI service deploy duration | < 5 min |
| AI service downtime per deploy | 0 (rolling) |
| Time from PR merge → prod | < 10 min |
| Mobile time from tag → TestFlight | < 30 min |
| Mobile time from tag → public release | 1-7 days (App Store review) |
