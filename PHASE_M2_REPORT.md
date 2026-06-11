# PHASE M2 REPORT — "Paw Pals" living avatar system (flagship)

**Date:** 2026-06-11 · **Branch:** `motion-m2` (stacked on `motion-m1`, PR #36) · **Source of truth:** `PAWDOC_MOTION_ROADMAP.md` §3 M2 + §4 A10 + matrix #9–#13 · audit §§4–6.

## 1 · Scope delivered

**The rig — `assets/motion/paw_pals_v1.riv` (15KB; budget ≤300KB):** 7 species artboards (`dog cat rabbit guinea_pig bird reptile other`) @256×256 in the icon-set palette (deep-teal outline / teal / mint / cream / coral), each with the shared **state machine `pal`**: inputs `tap`(trigger) `happy`(trigger) `sleepy`(bool) `attentive`(trigger); states idle (breath + blink) / tilt (tap, 400ms) / happyBeat (≤700ms, per-species part beat) / attentive (500ms, eyes-widen + lift) / sleep (5s breath, eyes closed, floating "z"). Zero bones (≤30 budget); transform animations only.

**Authoring route:** no Rive editor exists in this environment, so the rig is authored programmatically by `scripts/motion/build_paw_pals_riv.py` against the **rive-0.13.20 runtime parser as format ground truth** (RIVE v7 binary, importer-stack object stream). The script ships in-repo (reproducible, reviewable) with a `--preview` PIL renderer used for face-proportion audits (previews archived under `runtime/motion_validation/m2/`).

**The widget — `core/living_pet_avatar.dart`:** `LivingPetAvatar(species, size, {sleepy, mountBeat, beatKey, seed})` — flag-gated (PostHog `paw_pals_enabled`, control ON = kill-switch rollback), reduce-motion → static species PNG, rig failure → original paw-disc (cannot break a screen), offscreen pause, seeded blink phase, tap-tilt decorative + semantics-excluded.

**Surfaces (#9–#13):** home hero (beat key = last-check timestamp → attentive→relieved on return, riding the F-2 invalidation) · onboarding activation (arrival + ONE happy beat) · pets list rows (per-pet seeds) · pet-form live preview · result screen (NORMAL = one happy beat; **MONITOR = attentive only** per the ear-perk rule; **EMERGENCY = zero rig**, guard-tested) · species chips (#12 via the sanctioned "C scale-only" icon beat, ≤400ms).

**Found & fixed en route:** species key `other` pointed at a non-existent `species_other.png` — the Other chip has been silently rendering the emoji fallback; now maps to `species_other_paw.png` (completes F-5's intent).

## 2 · Validation gates

| Gate | Result |
|------|--------|
| `flutter analyze` | **PASS** — no issues |
| `flutter test` (full) | **PASS** — 168 passed, 1 skipped-by-design (see §3) |
| `paywall_policy_test` | **PASS** — 7/7 |
| `./scripts/verify-disclaimers.sh` | **PASS** — 6/6 |
| `flutter build apk --debug` | **PASS** |
| GitHub CI | runs on the PR |
| Device validation | **PASS** — 2026-06-11 live pass; see PAWDOC_MOTION_IMPLEMENTATION_FINAL_AUDIT.md §Device Results |

## 3 · The rig's layered verification (important)
`flutter_tester` cannot instantiate Rive artboards on this host (rive_common's native layout lib is a platform binary; no C++ toolchain available to build it). Verification is therefore layered:
1. **Always (CI):** a pure-Dart structural walk in `paw_pals_riv_test.dart` — independent re-parse of the binary: budget, 7 artboards, `pal` + 4 inputs per artboard, all 5 animations with roadmap timings, loop flags, ≥6 states / ≥9 transitions / ≥5 conditions each, blink-cycle distinctness in the 4–7s band.
2. **When the native lib exists:** the same test file runs a real `RiveFile.import` + state-machine drive (tap → tilt → sleepy on/off); it self-skips here with an explicit reason.
3. **Device (mandatory):** live rig render + input reactions are **item #1 of the M2 device checklist**; additionally the widget's degrade path guarantees a rig problem can only ever produce the old paw-disc, never a broken screen (tested).

## 4 · Acceptance vs roadmap (self-audit)

| Requirement | Status |
|---|---|
| One .riv, 7 artboards, shared `pal` machine, 4 inputs | **COMPLETE** |
| Budget ≤300KB / ≤30 bones | **COMPLETE** (15KB / 0 bones) |
| Blink randomized 4–7s, no sync-blinking lists | **COMPLETE** — distinct per-species cycles (4.7–6.1s) + per-pet seeded phase offset (deterministic, documented deviation from "blend-based" randomization) |
| Tap-tilt ≤400ms, optional | **COMPLETE** (decorative, a11y-excluded) |
| MONITOR ear-perk only / EMERGENCY zero rig | **COMPLETE** + permanent guard test (incl. ResultScreen-with-species route) |
| Reduce-motion → static species PNG | **COMPLETE** (tested; M0's regenerated icons are the stills) |
| Fallback paw-disc, flag-gated rollout | **COMPLETE** (`paw_pals_enabled` kill-switch) |
| Home hero attentive→relieved on post-check return (#11) | **COMPLETE** (beatKey = checkedAt; never fires on first data load — no fabricated celebrations) |
| 60fps Redmi profile + battery soak ≤2%/10min | **PENDING DEVICE** |
| "1 active rig per screen" | hero/activation/form/result: one rig. Pets list: one per **visible** row (the roadmap's own no-sync-blink acceptance presupposes list rigs), offscreen rows pause; device profiling will confirm or the list falls back via the flag. **Interpretation documented.** |

## 5 · Documented deviations
1. **Programmatic .riv** instead of editor-authored (environment constraint; format derived from the runtime parser; structural gates + device run verify).
2. **rive pinned to 0.13.20** — the last pure-Dart-renderer line, matching the roadmap's "no platform channels" rationale; 0.14+ pulls build-time native binaries (CI/offline risk). Future migration is a deliberate owner decision.
3. **Blink randomization** is deterministic (distinct cycles + seeded phase) rather than a state-machine blend; achieves the same observable property (no synchronized lists) and is CI-assertable.
4. **happyBeat per species** = shared bounce + one species part beat (ear/crest/toe). "Tail wag" isn't drawable on head-only artboards — the part beat carries the species character.
5. `sleepy` is wired end-to-end but no surface sets it yet (no quiet-hours product surface exists); the input is part of the rig contract for future use.

## 6 · Rollback
Flip `paw_pals_enabled` off in PostHog (no release needed) → every surface reverts to the paw-disc. Per-surface revert = the integration commit; the rig asset + widget are inert when unused.
