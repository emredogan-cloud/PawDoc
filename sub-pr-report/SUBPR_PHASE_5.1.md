# SUB-PR Report — Phase 5.1: Exotic Species Expansion

**Status:** Complete and fully green (ruff/pytest, node, flutter analyze/test, shellcheck). Exotic species added end-to-end with **species-specific AI prompts** and **species-specific emergency overrides** — mirrored across the Python safety core *and* its JS twin.
**Branch:** `phase-5.1-exotic-species` (from `origin/main` = `c188cd5`, contains 0.1→4.3)
**Date:** 2026-05-28

---

## 1. Files created / modified

**Safety core + AI (ai-service):**
```
app/safety.py            (mod)  + SPECIES_EMERGENCY_KEYWORDS (rabbit/guinea_pig/bird/reptile)
                                + _norm_species(); check_emergency_override(text, species);
                                is_sensitive_pet() normalized (incl. guinea_pig)
app/pipeline.py          (mod)  passes request.pet.species into the override
app/prompts.py           (mod)  + SPECIES_GUIDANCE + species_guidance() injected into the user prompt
tests/test_emergency_override.py (mod)  species-keyword + species-specificity tests
tests/test_prompts.py     (new)  species-guidance tests
```
**Edge / paywall mirror (supabase):**
```
functions/_shared/emergency_keywords.mjs       (mod)  + SPECIES_EMERGENCY_KEYWORDS;
                                                containsEmergencyKeyword(text, species)
functions/_shared/emergency_keywords.test.mjs  (new)  global + species + parity tests
functions/analyze/index.ts                     (mod)  containsEmergencyKeyword(text, pet.species)
```
**Client (mobile):**
```
lib/src/pets/pet.dart            (mod)  kSpecies += guinea_pig; centralized speciesLabel() (🐶🐱🐰🐹🦜🦎🐾)
lib/src/onboarding/onboarding_flow.dart (mod)  uses speciesLabel (removed the duplicate)
lib/src/pets/pet_form_screen.dart        (mod)  uses speciesLabel (removed the duplicate)
test/pet_test.dart               (mod)  guinea_pig + speciesLabel coverage
```
**Scripts/report:** `scripts/verify-phase-5.1.sh`, `sub-pr-report/SUBPR_PHASE_5.1.md`.

**No schema/migration** (species is a free-text column), **no new secrets/env**.

## 2. Sample of the new exotic emergency keywords (`safety.py`)

Added as a **separate** `SPECIES_EMERGENCY_KEYWORDS` dict (the global 23-keyword list is unchanged). Samples:

- **rabbit** (GI stasis = true emergency): `"not eating"`, `"stopped eating"`, `"no droppings"`, `"not pooping"`, `"bloated"`, `"hard belly"`, `"head tilt"`, `"gi stasis"`, `"not moving"`
- **guinea_pig** (same GI physiology + respiratory): `"not eating"`, `"not pooping"`, `"not drinking"`, `"bloated"`, `"labored breathing"`, `"gi stasis"`
- **bird** (prey animals hide illness): `"fluffed up"`, `"puffed up"`, `"bottom of the cage"`, `"tail bobbing"`, `"open-mouth breathing"`, `"not eating"`, `"fell off perch"`
- **reptile** (conservative — brumation caveat): `"open mouth breathing"`, `"mouth rot"`, `"prolapse"`, `"unresponsive"`, `"gasping"`

The discriminating case: **`"not eating"` overrides to EMERGENCY for a rabbit/bird, but for a dog it remains only a monitor-level risk signal** (unit-tested both ways).

## 3. How the pipeline knows which keyword set to evaluate

The request carries `pet.species`. The pipeline calls
`check_emergency_override(request.text_description, request.pet.species)` **before any AI call**, and the function:
1. checks the **global** `EMERGENCY_KEYWORDS` (apply to every species), then
2. checks `SPECIES_EMERGENCY_KEYWORDS[_norm_species(species)]` — **only the pet's species set** (`_norm_species` maps `"guinea pig"`/`"Guinea_Pig"` → `guinea_pig`).
If anything matches, the **AI is bypassed** and the result is hard-set to **EMERGENCY** (`emergency_override_result`, confidence 1.0) — exactly the existing pre-AI override path, now species-aware (strict rule satisfied).

**The same species logic is mirrored in the Edge Function** (`containsEmergencyKeyword(text, pet.species)`), so an exotic emergency *also* bypasses the **free-tier paywall gate** — otherwise a rabbit "not eating" emergency for an over-quota free user could be paywalled, breaking "EMERGENCY is never paywalled." The `prompts.py` `species_guidance(species)` separately injects species-specific clinical context (red-flag thresholds) into the model prompt for the non-override path.

## 4. Cross-language sync (surfaced)

The emergency keyword sets now live in **two** places by necessity — Python (`safety.py`, the authoritative override) and JS (`_shared/emergency_keywords.mjs`, the paywall bypass). Both were extended identically and must be **kept in sync by hand** (documented in both files). Guards: a Python test asserts the species key set is exactly `{rabbit, guinea_pig, bird, reptile}`, the JS test asserts the same keys, and `verify-phase-5.1.sh` checks each species appears in **both** files.

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check .` | **clean** |
| `pytest -q` | **112 pass** (+56: species-keyword parametrize, species-specificity, prompts) |
| `node --test _shared/*.mjs` | **42 pass** (+6: emergency-keyword global/species/parity) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **75 pass** (+ guinea_pig / speciesLabel) |
| `./scripts/verify-phase-5.1.sh` | **exit 0** — incl. Python↔JS parity per species; 2 MANUAL |
| `shellcheck` (verifier) | **clean** |

## 6. Strict rules honored

- **English-only** keywords — no localization (deferred to Phase 5.4 / CR #11). Documented in `safety.py` + the verifier MANUAL note.
- **Safety override** — a species keyword bypasses the AI and jumps straight to EMERGENCY (pre-AI override, unchanged path; confidence 1.0).
- **Over-triage is the safe direction** — exotic sets err generous (rabbit/bird), reptile deliberately conservative (brumation can lower appetite normally).

## 7. MANUAL

- On device: create a rabbit / guinea pig / bird / reptile end-to-end; confirm a species emergency (e.g. rabbit "not eating") classifies as EMERGENCY and is never paywalled.
- Localization of the keyword lists lands with the Germany launch (Phase 5.4).

## 8. Git branch / commit / push

- Branch: `phase-5.1-exotic-species`
- Implementation commit (deliverables): `24b40204a697d0212fc0897b1efc55e18a9570ce`
- Push: pushed to `origin/phase-5.1-exotic-species`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-5.1-exotic-species

## 9. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Exotic species in the model + onboarding grid (guinea_pig + icons) | ✅ DONE | `pet.dart` kSpecies + `speciesLabel`; pet test |
| Species-specific AI prompt guidance | ✅ DONE | `prompts.py` SPECIES_GUIDANCE; test_prompts |
| Species-specific emergency keywords (safety.py) | ✅ DONE | SPECIES_EMERGENCY_KEYWORDS; pytest |
| Override evaluates global + species set by pet context | ✅ DONE | `check_emergency_override(text, species)`; pipeline wires species |
| Exotic emergencies never paywalled | ✅ DONE | JS mirror + Edge passes pet.species |
| Species keyword bypasses AI → EMERGENCY | ✅ DONE | pre-AI override path; tests |
| On-device exotic create + emergency | ⏳ MANUAL | §7 |

**Verified now:** exotic species are selectable, get species-specific prompts, and trip species-specific emergency overrides — proven in Python, the JS paywall mirror, and the client — with cross-language parity guarded. Stopping for approval.
