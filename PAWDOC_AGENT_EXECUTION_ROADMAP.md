# PawDoc — Agent Execution Roadmap (Phase 2)
**2026-06-13**

## There is no required agent phase.
Per the Phase-1 audit, **no agent-executable findings remain** for Engineering,
Beta, or Public-Launch GO. Every remaining item is founder-controlled. So there
is no `AG-1 / AG-2 …` critical-path phase to run — the engineering is done and
green on `main`.

## Why (evidence)
- All 30 agent findings closed + merged; CI green on merged main; release `.aab`
  builds; safety path intact (PAWDOC_CLOSURE_STATE_REPORT.md).
- The only open items are founder-fill (legal/store/creds), founder-config
  (signing, SMTP, RC, FCM, dev DB/PITR, domain), and on-device validation —
  none are code (PAWDOC_AGENT_CLOSURE_AUDIT.md).

## Optional / contingent agent backlog (only if the founder asks)
These are **not blockers** for beta. They become agent-actionable only on an
explicit founder request or decision.

| ID | Trigger | Scope | Effort |
|----|---------|-------|--------|
| AG-OPT-1 | Founder decides to support Turkish (E4) | Add TR emergency keywords to the override list (safety-critical) + locale wiring + tests | ~2–3h |
| AG-OPT-2 | Founder hits a config-surfaced bug during F-phases | Diagnose + fix whatever the live config reveals (e.g., a real-device crash, an RC webhook edge case) | varies |
| AG-OPT-3 | Founder wants store assets generated from the app | Produce screenshots/captions from the built app for B6 submission | ~2h (needs a device/emulator) |
| AG-OPT-4 | Post-beta roadmap Phases 7–8 (2nd engineer) | Deferred product scope — out of closure mission | — |

## How to re-engage the agent (copy-paste master prompt)
Use this only if a founder phase surfaces real code work:

```
PAWDOC AGENT RE-ENGAGEMENT

Context: PawDoc is at ENGINEERING GO; main is green. A founder-phase task
surfaced a code issue. Do NOT re-open closed findings unless regression is proven.

Task: <describe the bug/decision — e.g. "RevenueCat sandbox purchase returns a
422 from revenuecat-webhook" or "founder approved Turkish emergency keywords">.

Rules: one branch (fix/<name>); verify → fix → validate (flutter analyze/test,
ruff/pytest, node --test, test-rls.sh as relevant) → commit (Co-Authored-By) →
push → open PR. main is protected (squash, 1 review). Preserve the safety path
(emergency override, server disclaimers, no paywalled emergencies). Never weaken
safety to ship. Produce evidence; never claim closure without it.
```

## Bottom line
The agent's work on PawDoc is **complete**. The roadmap from here is the
**founder roadmap** (PAWDOC_FOUNDER_ROADMAP.md).
