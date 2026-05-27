# 10 — CI/CD (GitHub Actions)

Three workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | every PR + push to `main` | ai-service **ruff + pytest**, **ShellCheck** on `scripts/`, **gitleaks** secret scan, Flutter analyze+test (auto-skips until `mobile/` exists in 1.1) |
| `deploy.yml` | merge to `main` touching `ai-service/**` | `flyctl deploy` + post-deploy `/health` smoke check |
| `release.yml` | git tag `v*` | Fastlane `beta` → TestFlight (auto-skips until `mobile/ios` exists) |

## 1. Add repo secrets

GitHub → repo **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Needed by | Source |
|--------|-----------|--------|
| `FLY_API_TOKEN` | deploy.yml | `fly tokens create deploy` (runbook 08) |
| `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION` | release.yml | runbook 11 |
| `APP_STORE_CONNECT_API_KEY_KEY_ID`, `_ISSUER_ID`, `_KEY` | release.yml | runbook 11 |

> App **runtime** secrets (Supabase/Anthropic/etc.) are not needed by CI. When they are (Phase 1.3+), sync them from Doppler via the **Doppler → GitHub Actions** integration rather than pasting each one.

## 2. Make CI a required status check (closes the 0.1 gate)

After `ci.yml` has run once on a PR:
repo **Settings → Branches → branch protection for `main`** → **Require status checks to pass** → select **`AI service — ruff + pytest`**, **`ShellCheck (scripts)`**, **`Secret scan (gitleaks)`**, **`Flutter analyze + test`**.

Now no unverified code can reach `main`. (Re-run `./scripts/github-branch-protection.sh` first if branch protection isn't applied yet.)

## 3. Verify the DoD

- **CI < 5 min:** the jobs run in parallel and are lightweight; check the Actions run duration.
- **Deploy on merge:** merge a PR touching `ai-service/`, watch `deploy.yml` go green and the smoke check pass.
- **TestFlight < 24h:** push a `v*` tag once the iOS project + signing secrets exist (1.1 / runbook 11).
- **Zero secrets:** the `secret-scan` job must be green.

## Notes / surfaced proposals
- **#14 (staging/canary):** `deploy.yml` ships straight to the single prod machine. A staging app + smoke gate before prod is recommended (Critical Review #14) — surfaced for your decision, not auto-added.
- `ludeeus/action-shellcheck` and `superfly/flyctl-actions` are pinned to `@master` per their convention; pin to a SHA if you want full reproducibility.
