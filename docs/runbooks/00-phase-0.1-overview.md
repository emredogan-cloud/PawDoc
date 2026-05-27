# Phase 0.1 — Setup Overview (start here)

**Goal:** stand up every long-lead account, register the domain, and centralize secrets in Doppler so no later phase is blocked waiting on enrollment or hunting for a key.

These runbooks cover the steps a person must do by hand (paying, identity verification, logins) — an AI agent cannot create accounts or spend money for you. Everything that *can* be automated is in `scripts/`.

## Do them in this order

| # | Task | Time | Cost | Runbook | Why first |
|---|------|------|------|---------|-----------|
| 1 | **Apple Developer enrollment** | 30 min + 24–48h review | $99/yr | [01](01-apple-developer-enrollment.md) | Longest approval delay — gates TestFlight. Start Day 1. |
| 2 | Google Play Developer account | 30 min + ID verify | $25 once | [02](02-google-play-developer-account.md) | Identity verification can take days. |
| 3 | Domain + Cloudflare DNS | — | done | [03](03-domain-and-cloudflare-dns.md) | ✅ Already done (verified). Just confirm. |
| 4 | Doppler secrets backbone | 15 min | free tier | [04](04-doppler-secrets-backbone.md) | Single source of truth every service reads. |
| 5 | GitHub branch protection + secret scanning | 10 min | free | [05](05-github-repo-branch-protection.md) | Protects `main` before the first real push. |

## After the manual steps — run the scripts

```bash
# 4) once you've run `doppler login`:
./scripts/doppler-bootstrap.sh        # creates project + dev/prod + secret slots

# 5) once you have a GitHub admin token (GH_TOKEN):
./scripts/github-branch-protection.sh # protects main + enables secret scanning

# verify the whole checklist:
./scripts/verify-phase-0.1.sh
```

## Definition of Done (from the roadmap)

- [ ] `dig pawdoc.app` resolves through Cloudflare — **✅ verified**
- [ ] Doppler `dev` + `prod` configs exist with all expected keys (placeholders OK)
- [ ] A test PR cannot merge to `main` without a review
- [ ] Apple enrollment confirmation received, or in-progress with a case number logged

> Apple may still be "in review" — that is acceptable for DoD **as long as it was initiated Day 1**.

## Golden rule

**Never paste a real secret into a file you commit.** Real values go only into Doppler. The repo's `.gitignore` blocks the usual offenders, and GitHub push protection (step 5) is the backstop.
