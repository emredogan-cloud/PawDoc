# 05 — GitHub branch protection + secret scanning

The repo already exists: <https://github.com/emredogan-cloud/PawDoc>. This step makes `main` un-pushable-to without a reviewed PR, and turns on GitHub's secret scanning so a leaked key is caught before it lands.

**Why:** the roadmap's DoD requires "a test PR cannot merge to `main` without a review," and Phase 0.4's exit gate requires **zero secrets in git history**.

## Option A — script (fast)

1. Create a **fine-grained personal access token**: <https://github.com/settings/tokens?type=beta>
   - Repository access: **only** `emredogan-cloud/PawDoc`.
   - Permissions: **Administration → Read and write** (also covers branch protection + security settings).
2. Run:
   ```bash
   export GH_TOKEN=github_pat_xxxxx
   ./scripts/github-branch-protection.sh
   ```
   This requires PRs + review on `main`, blocks force-push/deletion, requires linear history + conversation resolution, and enables secret scanning + push protection.
3. **Delete or expire the token afterward** — it's only needed once.

### Solo-founder note on required reviews
With one developer there's no second person to approve a PR. The script defaults to `REVIEW_COUNT=1` (matches the roadmap literally). If self-approval blocks you, re-run with:
```bash
REVIEW_COUNT=0 ./scripts/github-branch-protection.sh
```
This still **requires a PR** (no direct pushes to `main`) and keeps CI as the real gate once Phase 0.4 adds status checks — just without a human approval you can't give yourself.

## Option B — web UI

**Branch protection:** repo → **Settings → Branches → Add branch ruleset** (or *Add rule*) for `main`:
- ✅ Require a pull request before merging (set required approvals)
- ✅ Require linear history
- ✅ Require conversation resolution before merging
- ✅ Block force pushes and deletions

**Secret scanning:** repo → **Settings → Code security and analysis**:
- ✅ Secret scanning → Enable
- ✅ Push protection → Enable

> Secret scanning + push protection are **free for public repos**. Private repos need GitHub Advanced Security; if it's unavailable, rely on the repo's `.gitignore` + local scanning (`gitleaks`) and the `verify-phase-0.1.sh` basic scan.

## Optional — install `gh` CLI

Not required (the script uses `curl`), but handy later:
```bash
# Debian/Ubuntu
sudo apt install gh && gh auth login
```

## Verify

```bash
GH_TOKEN=github_pat_xxxxx ./scripts/verify-phase-0.1.sh
```
The branch-protection check passes when `required_pull_request_reviews` is present on `main`.
