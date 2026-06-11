# PHASE M4 REPORT — Refinement, evaluation & hardening

**Date:** 2026-06-11 · **Branch:** `motion-m4` (stacked on `motion-m3`, PR #38) · **Source of truth:** `PAWDOC_MOTION_ROADMAP.md` §3 M4 + matrix #20/#22/#23 + §5 gates.

## 1 · Scope delivered

| Item | Delivery |
|------|----------|
| **#20 error nap loop (A9)** | `error_nap_loop_v1.json` (33KB, 6s): error-pet breath + two muted sparkles. Wired into `AppErrorView` — which also serves `BootErrorApp` — replacing the bare error icon; message/retry logic untouched; PNG under reduce-motion; icon fallback if art missing. |
| **#23 pulse→verdict resolve** (safety-review gated) | The runner gains a `resolving` phase: **non-emergency** verdicts get one 450ms beat where the rings settle outward in the verdict hue (MONITOR amber / NORMAL green) before the reveal. **EMERGENCY keeps the instant cut — test-pinned at zero resolve delay.** Reduce-motion goes straight to the result. The code-drawn pulse is byte-for-byte preserved (hard guardrail). |
| **#22 pulse-pet evaluation** | Shipped as a true A/B mechanism, not a taste call: PostHog flag `pulse_pet_variant`, **control = OFF (pulse-only, default experience unchanged)**. The variant renders a small **sleepy** Paw Pal beneath the pulse ("being cared for" — deliberately not playful). The roadmap requires this decided "by data, not taste" — the data can only exist post-launch, so M4 delivers the instrumented arm and the decision stays with the experiment. |
| **Reduce-motion audit** | Sweep test: loading view (with resolve + pulse-pet params set) is fully static under RM (zero Lottie/Rive/Animate); error view zero-Lottie with retry intact; combined with M1's per-slot fallback tests, M2's avatar contract, M3's celebration contract → every motion surface has an asserted static path. |
| **Golden tests** | Implemented as the structural reduce-motion suite above (per the M1-documented deviation: pixel goldens would couple CI to rasterizer versions; the verified-PNG-fallback intent is fully held; pixel-level frame audits were done headlessly and archived under `runtime/motion_validation/`). |
| **Perf pass** | Static budgets all green (Lottie 33–78KB ≤250KB; rig 15KB ≤300KB; ≤1 ambient loop per screen; pause-offscreen universal). Frame-profile + battery soak are device-bound (see §3). |
| **Loading min-display decision** | **Explicitly left as the owner call the roadmap says it is** — not implemented; flagged in the final audit as an open owner decision (must remain emergency-exempt if ever adopted). |

## 2 · The H-phase safety ritual (mandatory for result-path work)

| Check | Result |
|-------|--------|
| `./scripts/verify-disclaimers.sh` | **PASS 6/6** |
| `paywall_policy_test` | **PASS 7/7** (incl. "NEVER shows during/after an EMERGENCY") |
| Pipeline-untouched diff | **`git diff main...motion-m4 -- ai-service/ supabase/ docs/contracts/` → EMPTY** across the entire M0–M4 train |
| EMERGENCY instant cut | test-pinned (`m4_hardening_test.dart`) |
| AI pulse preserved | the pulse code path for the loading phase is unchanged; resolve is an additive one-shot branch |
| Delete exempt | guard test unchanged & green |

## 3 · Validation gates

| Gate | Result |
|------|--------|
| `flutter analyze` | **PASS** — no issues |
| `flutter test` (full) | **PASS** — 185 passed, 1 documented skip |
| `flutter build apk --debug` | **PASS** |
| GitHub CI | runs on the PR |
| Device validation | **PASS** — 2026-06-11 live pass; see PAWDOC_MOTION_IMPLEMENTATION_FINAL_AUDIT.md §Device Results |

## 4 · Rollback
Per-item commits. #23 reverts to the instant transition; #22 is dormant unless the flag is enabled (rollback = leave it off); A9 reverts to the error icon.
