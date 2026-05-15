# CI/CD

GitHub Actions workflows for PawDoc. One workflow per concern, each scoped by
path filters so unrelated changes don't trigger unrelated jobs.

---

## Workflow Inventory

| File | Trigger | Purpose | Required for merge to `main`? |
|------|---------|---------|------|
| [`mobile-ci.yml`](../.github/workflows/mobile-ci.yml) | PR/push to `mobile/**` | dart format, flutter analyze, flutter test | yes (when touched) |
| [`ai-service-ci.yml`](../.github/workflows/ai-service-ci.yml) | PR/push to `ai-service/**` | ruff fmt+lint, mypy, pytest, docker build | yes (when touched) |
| [`supabase-ci.yml`](../.github/workflows/supabase-ci.yml) | PR/push to `supabase/**` | deno fmt/lint/check, migration naming + RLS lint | yes (when touched) |
| [`secret-scan.yml`](../.github/workflows/secret-scan.yml) | Every PR/push | Gitleaks | yes |
| [`ai-service-deploy.yml`](../.github/workflows/ai-service-deploy.yml) | push to `main` on `ai-service/**`, manual | flyctl deploy | n/a (deploy) |
| [`mobile-release.yml`](../.github/workflows/mobile-release.yml) | tag `v*`, manual | TestFlight + Play Internal (scaffold) | n/a (release) |

## Job Concurrency

Each workflow uses `concurrency.group` keyed by branch so rapid pushes cancel
in-flight runs. Deploy workflows do NOT cancel in-flight runs (no
`cancel-in-progress: false`) — a half-deployed service is worse than a slow
deploy.

## Caching

| Cache | Workflow | Key |
|-------|----------|-----|
| Pub | mobile-ci | `pub-${{ runner.os }}-${{ hashFiles('mobile/pubspec.lock') }}` |
| uv | ai-service-ci | uv's built-in GitHub Actions cache via `astral-sh/setup-uv@v3` |
| Docker layers | ai-service-ci | `type=gha` BuildKit cache |

## Branch Protection

The following protections MUST be applied to `main` in GitHub repo settings
(documented in `environment-setup.md` too):

- Require PR review (1 approval).
- Require status checks to pass:
  - `mobile-ci/Format + Analyze + Test`
  - `ai-service-ci/Format + Lint + Type + Test`
  - `ai-service-ci/Docker image builds`
  - `secret-scan/Gitleaks`
- Require branches to be up to date before merging.
- Restrict force pushes.
- Restrict deletions.

Note: status checks marked "when touched" only become required when their
files change. GitHub automatically excludes them when path filters skip
them — this is the expected behavior.

## Conventions

- **YAML:** 2-space indent, no tabs (enforced by `.editorconfig`).
- **Job names:** human-readable; appear as required-status-check names. Renaming = repo settings update.
- **Step names:** verbose enough to be searchable in logs (e.g. "flutter analyze" not just "analyze").
- **Timeouts:** every job has `timeout-minutes`. Default 10-15min.
- **Permissions:** every workflow declares `permissions:` explicitly — no implicit write access.
- **Working directory:** set at workflow level via `defaults.run.working-directory` for service-scoped flows.

## Adding a New Workflow

1. Create `.github/workflows/<name>.yml`.
2. Path-filter triggers so it only fires when relevant.
3. Add `concurrency`, `permissions`, and a `timeout-minutes`.
4. Run `python3 -c 'import yaml; yaml.safe_load(open("...yml"))'` locally to syntax-check.
5. If it gates merges, add the job name to branch protection.

## Cost / Minutes Budget

Free tier: 2,000 GitHub Actions minutes/month for public repos. Private repo
allowance varies. macOS minutes (used by mobile-release iOS job) cost 10x
linux. To keep within budget:

- Path filters prevent mobile-ci from running when only ai-service changes (and vice versa).
- `concurrency.cancel-in-progress` cancels superseded runs.
- macOS-bound iOS release runs only on tags, not every push.
