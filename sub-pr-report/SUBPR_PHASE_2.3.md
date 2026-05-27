# SUB-PR Report — Phase 2.3: Beta, Store Submission & Public Launch

**Status:** Store metadata + beta/launch runbook + phase verifier complete and green. **Phase 2 (build) is complete; PUBLIC LAUNCH remains hard-gated by the founder's manual beta testing + legal/insurance verification.**
**Branch:** `phase-2.3-store-launch` (from `origin/main` = `f25893d`, which contains 0.1–1.4 + 2.1 + 2.2 + the Agent-SDK workspace #10)
**Date:** 2026-05-27

---

## 1. Git `main` branch state

Verified by **content**, not just PR status:

- `origin/main` HEAD = `f25893d chore: initialize Claude Agent SDK workspace (#10)`, on top of `3882edf Phase 2.2 legal trust (#9)` and `e93c935 Phase 2.1 production polish (#8)`. Linear history intact.
- Confirmed present on `main`: `CLAUDE.md`, `.claude/settings.json`, `memory/PAST_DECISIONS.md` — i.e. the workspace PR **did** squash-merge as #10 (an initial stale fetch showed `3882edf`; after `git fetch --prune` the real tip `f25893d` appeared).
- This branch was (re)created from the correct `f25893d` tip — **1 commit ahead, 0 behind** `origin/main`.
- 2.3 adds only **docs + one script + this report** — it touches **no app code and no shared contract**, so the PR is conflict-free.

**Net:** `main` is healthy and current (0.1 → 2.2 + workspace all landed).

## 2. Files created

```
docs/store_metadata/ios_app_store.md   iOS listing: title, subtitle, keyword field (80/100),
                                        promo text, full description, screenshot order (slots 1–5),
                                        and the App Store Review Notes ("AI-assisted information
                                        & triage tool, NOT a veterinary service")
docs/store_metadata/google_play.md      Play listing: title, short desc (72/80), full description,
                                        graphics checklist, Data-safety/compliance notes; no hidden
                                        keyword field, so "diagnosis" never used in copy
docs/runbooks/19-beta-and-launch.md     Founder runbook: Fastlane `beta` (TestFlight) + `play_internal`
                                        lanes, 50-user beta onboarding, the ≥4.0 rating gate + P0
                                        definition, pre-submission verification, the HARD launch gate,
                                        go-live + rollback
scripts/verify-phase-2.3.sh             Phase verifier — asserts files exist, keyword length ≤100,
                                        and (strict rule) NO "diagnosis/diagnose" inside any
                                        user-visible VISIBLE-COPY block
sub-pr-report/SUBPR_PHASE_2.3.md        this report
```

**No new env vars / secrets.** The lanes reuse the release secrets already documented in `ENVIRONMENT_VARS.md` (from Phase 0.4 / runbook 11): `MATCH_*`, `APP_STORE_CONNECT_API_KEY_*`, `GOOGLE_PLAY_JSON_KEY_FILE`, `FASTLANE_APPLE_ID`, `APPLE_DEVELOPER_TEAM_ID`.

## 3. ✅ Strict rule confirmed — "diagnosis" absent from all public-facing copy

The user's hard constraint: never use "diagnosis"/"diagnose" in visible store text; the Apple keyword field may include it for SEO.

- Every user-facing storefront string is wrapped in `<!-- VISIBLE-COPY:START/END -->` markers. **An independent extraction of those blocks in both files contains zero occurrences of "diagnosis"/"diagnose"** (and the verifier enforces this on every run).
- "diagnosis"/"diagnose" appears **only** in: the Apple **keyword field** (allowed — SEO, invisible), the **reviewer/compliance notes** (used to state the app does *NOT* diagnose — not user-facing), and the files' own **DO-NOT instruction** headers. None of these is visible store copy.
- Visible copy uses only the approved verbs: **triage / monitor / guidance / check / decide**. "treat"/"cure" are also avoided in visible copy.

| Field | Value | Limit | Length |
|---|---|---|---|
| iOS title | `PawDoc: AI Pet Health` | 30 | 21 ✓ |
| iOS subtitle | `Know When to Call the Vet` | 30 | 25 ✓ |
| iOS keywords | `symptom,checker,dog,cat,sick,emergency,vet,triage,diagnosis,rabbit,puppy,monitor` | 100 | 80 ✓ |
| Play short desc | `Know when to call the vet. AI triage for your pet's symptoms in seconds.` | 80 | 72 ✓ |

Screenshot order (slots 1–5) preserved exactly per roadmap: (1) "Know exactly what your pet needs." + result; (2) how it works (camera → AI → result); (3) "No more 2am anxiety spirals." + LIKELY NORMAL; (4) "Reviewed by veterinary experts"; (5) feature breadth (multi-pet, history, reminders). Apple allows up to 10 slots; these 5 are the canonical ordered set.

## 4. ⛔ Launch blocker (explicit, unchanged from 2.2)

**PawDoc CANNOT be released to the public until the human founder completes the Phase 2.2 manual items** in `docs/runbooks/18-legal-and-launch-gate.md` §1:

1. **Bind E&O (Errors & Omissions) insurance (≥ $100K)** — effective before launch; certificate on file.
2. **Licensed-attorney review & finalization** of `terms-of-service.md` + `privacy-policy.md`, plus the **veterinary practice-law review (CR #24)** per launch jurisdiction, and the **CR #9 retention-policy decision**.

Runbook 19 §7 makes this a checklist gate **before** the "Release to Public" button: store *submission* and *beta* may proceed now; *public availability* may not. The verifier echoes this as a MANUAL gate, and the launch step is blocked on it.

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `./scripts/verify-phase-2.3.sh` | **exit 0** — all verifiable checks green; 5 MANUAL items echoed |
| Independent VISIBLE-COPY extraction → grep `diagnos` (both files) | **clean** (0 matches) |
| Independent char counts (title/subtitle/keywords/short-desc) | all within budget (21/25/80/72) |
| `shellcheck scripts/verify-phase-2.3.sh` (via Docker) | **clean** (exit 0) |

> Headless env has no device/simulator, no App Store Connect, no Play Console — so the actual build upload, beta cohort, ratings, store review, and P95-on-4G measurement are **founder-side MANUAL** (documented in runbook 19), not faked here.

## 6. Security / compliance checks

- **Review notes pre-empt the health-app rejection**: framed as information/triage, disclaimers shown on every result, **emergencies never paywalled**, and **in-app account deletion (Apple 5.1.1(v) / CR #9)** explicitly noted — the rejection risk the roadmap flagged is addressed.
- **No "diagnose/treat/cure" claims** anywhere a user or reviewer would read as a medical claim.
- Play **Data-safety** guidance included (data collected, encryption in transit, deletion, EXIF/GPS stripped before upload).
- Strict no-"diagnosis"-in-visible-copy rule is **machine-enforced** (verifier), not just prose — it will fail CI if violated later.

## 7. Known issues / scope notes

- Reviewer **demo account** credentials in the iOS review notes are `[BRACKETED]` placeholders for the founder to fill before submission.
- `/terms` + `/privacy` hosting still arrives with the Next.js site in **Phase 4.3**; a static page suffices until then (runbook 18).
- TestFlight has no native star rating, so the **≥4.0 gate is measured via an in-beta survey** (≥30 of 50 responding) — documented in runbook 19 §4.
- Roadmap lists "10 screenshots"; this documents the canonical **5-slot ordered set** (the founder can add device/locale variants to fill remaining slots).

## 8. Risks

- **Apple review churn** (2–3 weeks, often 2–3 rejections) — mitigated by the review-notes framing and the "never add diagnosis language" instruction in runbook 19 §6.
- **Premature public release** before the legal gate — mitigated by the §7 checklist gate + verifier MANUAL items; this is the project's #1 risk surface and is treated as non-negotiable.

## 9. Git branch

`phase-2.3-store-launch`

## 10. Commit hash

Implementation commit: `<filled post-commit>`

## 11. Push confirmation

`<filled post-push>`

## 12. Phase 2 completion

With 2.1 (production polish), 2.2 (legal & trust gate), and 2.3 (beta/store prep) all implemented, **Phase 2's engineering scope is complete.** What remains for Phase 2 are **founder-side manual actions only**: the 50-user beta + ≥4.0 rating gate, the E&O insurance, and the attorney/practice-law legal verification. **Phase 2 is complete pending your manual beta testing and legal verification** — after which public launch may proceed.

## 13. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| iOS metadata (title, subtitle, keywords, description, screenshots) | ✅ DONE | `docs/store_metadata/ios_app_store.md`; verifier |
| App Store review notes (information-tool framing) | ✅ DONE | iOS file §"Review Notes"; verifier |
| Google Play metadata (short + full description) | ✅ DONE | `docs/store_metadata/google_play.md`; verifier |
| Beta + launch runbook (Fastlane lanes, 50-user beta, ≥4.0 gate, hard gate) | ✅ DONE | `docs/runbooks/19-beta-and-launch.md`; verifier |
| "diagnosis" absent from all visible copy | ✅ DONE | independent extraction + verifier (0 matches) |
| App Store approval without P0 rejection | ⛔ MANUAL | founder — store review |
| 50 beta users, avg rating > 4.0, zero P0 | ⛔ MANUAL | founder — runbook 19 §4 |
| Analysis P95 < 10s on 4G | ⛔ MANUAL | founder — device/network measurement |
| Public availability | ⛔ GATED | blocked on E&O + attorney review (runbook 18 §1) |

**Verified now:** store metadata + launch runbook + verifier are complete and green, and the no-"diagnosis" rule is machine-enforced. **Public launch stays gated** on the founder's beta cohort and the E&O/legal items. This is the last engineering sub-PR of Phase 2.
