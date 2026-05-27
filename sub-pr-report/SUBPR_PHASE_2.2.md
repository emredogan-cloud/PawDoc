# SUB-PR Report — Phase 2.2: Legal, Compliance & Trust Gate

**Status:** Legal templates + launch gate drafted; disclaimer-source verification green. **This is a hard gate — the founder/legal actions below block public launch.**
**Branch:** `phase-2.2-legal-trust` (from `origin/main` = 0.1–1.4; independent of the 2.1 PR)
**Date:** 2026-05-27

---

## 1. Git `main` branch state (Part 1)

Verified by **content**, not just PR status:

- `origin/main` HEAD = `60f50a4`; it **already contains all of Phase 1.1, 1.2, 1.3, 1.4** (auth/RLS schema, capture/upload, AI pipeline, result/monetization all present).
- The **"Phase 1.1" PR shows _Open_** only because 1.1's commits reached `main` **via the stacked 1.3 squash (#5)** (1.3 was branched on top of 1.1), not through its own PR. **Action: close that PR _without merging_** (its content is already on `main`; merging would conflict/duplicate).
- **Phase 2.1 is NOT yet on `main`** — squash-merge the `phase-2.1-production-polish` PR to land CR #8/#9, OneSignal, etc.
- I have **no `gh` CLI / token**, so I could not merge via API — the two GitHub-UI actions above are yours.
- **2.2 is independent of 2.1** (it adds only docs + scripts, touching no code files 2.1 touches), so I branched it from the current clean `main`. The 2.1 and 2.2 PRs merge in **any order without conflict**.

**Net:** `main` is healthy and linear for 0.1–1.4. It becomes fully current once you (a) close the stale 1.1 PR and (b) squash-merge the 2.1 PR.

## 2. Legal templates, scripts & runbooks created

```
docs/legal/terms-of-service.md     ToS template — "information/guidance, NOT veterinary diagnosis",
                                   subscriptions, AS-IS/no-warranty, liability, in-app deletion,
                                   GDPR/EU statutory-rights note, prominent ATTORNEY-REVIEW banner
docs/legal/privacy-policy.md       Privacy template — data collected, GDPR legal bases, subprocessor
                                   table, EU data residency, CR #9 retention DECISION flag, user rights
                                   (in-app erasure), security, ATTORNEY-REVIEW banner
docs/runbooks/18-legal-and-launch-gate.md   the hard gate: E&O insurance, attorney review, CR #24
                                   practice-law review, CR #9 retention decision, support@pawdoc.app,
                                   App Store review notes (avoid "diagnosis"), affirmative ToS acceptance
scripts/verify-disclaimers.sh      asserts the disclaimer is API-injected (backend-forced flag,
                                   payload-driven, UI-gated) — NOT a removable hardcoded UI string
scripts/verify-phase-2.2.sh        phase verifier (templates + clauses + runbook + disclaimer check)
sub-pr-report/SUBPR_PHASE_2.2.md
```

No app code and no new secrets were changed this phase (so the 2.2 PR is conflict-free with 2.1).

## 3. ⛔ Launch blocker (explicit)

**PawDoc CANNOT be released publicly until the human founder:**

1. **Purchases / binds E&O insurance (≥ $100K coverage)** — effective before launch; certificate on file.
2. **Has a licensed attorney review and finalize** `terms-of-service.md` and `privacy-policy.md` (filling every `[BRACKET]`) and complete the **veterinary practice-law review (CR #24)** for each launch jurisdiction.

Until both are done, the ToS/Privacy here are **unreviewed templates** and must not be relied upon. Also pending (founder): `support@pawdoc.app`, the CR #9 retention-policy decision, and publishing `/terms` + `/privacy`. The launch gate (Phase 2.3) stays **CLOSED** until these are complete.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `./scripts/verify-disclaimers.sh` | exit 0 — disclaimer is API-injected (6 checks) |
| `./scripts/verify-phase-2.2.sh` | exit 0 — 17 checks green (templates + clauses + runbook + disclaimer) |
| `shellcheck scripts/*.sh` (via Docker) | clean (exit 0) |

## 5. Security / compliance checks

- **Disclaimer is API-injected** (backend forces `disclaimer_required`; UI gates on the payload flag) — proven by `verify-disclaimers.sh`. Not removable by a UI-only change.
- Templates carry the **"not a veterinary diagnosis"** framing prominently (App Store + liability posture) and **explicit attorney-review** banners.
- Privacy template documents EU data residency, the subprocessor list, and in-app erasure (ties to the CR #9 cascade shipped in 2.1).

## 6. Known issues / scope notes

- ToS/Privacy are **templates, not legal advice** — must be attorney-finalized before publication.
- `/terms` and `/privacy` web hosting arrives with the Next.js site in **Phase 4.3**; a simple static page suffices until then (runbook 18).
- CR #9 retention wording is left as an explicit **DECISION REQUIRED** in the Privacy Policy, to be reconciled with the code (currently full erasure on deletion).

## 7. Risks

- Legal/regulatory exposure if launched before attorney review / E&O — mitigated by making these explicit hard blockers (runbook 18, §3 above).
- App Store rejection risk if "diagnosis" language leaks into metadata — mitigated by the review-notes guidance.

## 8. Git branch

`phase-2.2-legal-trust`

## 9. Commit hash

Implementation commit: `74134aab5ce446ece21bdb2f3f41e50c62b7aefc`.

## 10. Push confirmation

Pushed to `origin/phase-2.2-legal-trust`. Open PR: https://github.com/emredogan-cloud/PawDoc/pull/new/phase-2.2-legal-trust

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| ToS + Privacy templates (GDPR, US/EU, not-diagnosis, attorney banner) | ✅ DONE | `docs/legal/*.md`; verifier checks clauses |
| Disclaimer API-level verification | ✅ DONE | `verify-disclaimers.sh` green |
| Launch/legal runbook (E&O, support email, CR #24, CR #9, store notes) | ✅ DONE | `docs/runbooks/18-...md`; verifier |
| E&O insurance bound | ⛔ MANUAL | founder — hard blocker |
| Attorney review of ToS/Privacy + CR #24 | ⛔ MANUAL | founder/legal — hard blocker |
| `support@pawdoc.app` + pages live + affirmative acceptance | ⏳ MANUAL | runbook 18 |

**Verified now:** the legal framework is drafted and the disclaimer is provably API-injected. **The gate to public launch (Phase 2.3) stays closed** until E&O is bound and the documents are attorney-reviewed. Next per roadmap: **Phase 2.3 (Beta, Store Submission & Public Launch)** — itself hard-gated by this phase.
