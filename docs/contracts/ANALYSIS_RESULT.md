# AnalysisResult — Frozen Cross-Language Contract (v2)

**v2 (2026-07-17, evolution reframe).** The triage *verdict* is gone. The AI
returns an **action ladder with no terminal "do nothing" state** plus a
plain-language observation. The diagnostic surface — `differential`, condition
names, "LIKELY NORMAL" — was removed **by design**: PawDoc describes and
schedules; it never diagnoses and never reassures.

This contract is **frozen across three implementations**. Any field change
touches all three in the same commit:

| Binding | File |
|---|---|
| Python (authoritative) | `ai-service/app/models.py` (`AnalysisResult`) |
| TypeScript / Edge | `supabase/functions/analyze/index.ts` (+ `_shared/quota_gate.mjs`, `_shared/web_checker.mjs`) |
| Dart | `mobile/lib/src/models/analysis_result.dart` |

## Fields (JSON keys are exactly these snake_case names)

| Key | Type | Meaning |
|---|---|---|
| `action` | enum string | exactly one of `GET_HELP_NOW` \| `CALL_TODAY` \| `BOOK_VISIT` \| `WATCH_AND_RECHECK` |
| `confidence` | number 0.0–1.0 | model confidence. **INTERNAL ONLY** — used for tier routing and stored for monitoring; **never rendered to the user** |
| `observation` | string | plain-language description of what was observed/reported. **Never a condition or disease name** — "a swollen, firm belly", not "suspected bloat (GDV)" |
| `visible_symptoms` | string[] | what was seen/reported, itemized (may be empty) |
| `vets_look_for` | string[] | educational: what a veterinarian typically assesses for this *kind* of presentation — general knowledge, never findings about this animal |
| `watch_for` | string[] | concrete signs that mean the owner should act sooner than the chosen action |
| `recommended_actions` | string[] | ordered, safe, general steps (no medication names or doses) |
| `urgency_timeframe` | string | timing phrase, e.g. `immediately` \| `today` \| `within a few days` \| `re-check in 24h` |
| `recheck_hours` | integer \| null | hours until a re-check makes sense (1–336). Drives the client's re-check reminder CTA. **`WATCH_AND_RECHECK` always carries one** (server backstops 24) |
| `disclaimer_required` | boolean | when true the UI **must** show the disclaimer. Injected server-side on every path (`pipeline.py`); the client can never suppress it |

## The ladder

| Action | Meaning | Client surface |
|---|---|---|
| `GET_HELP_NOW` | signs that can threaten life or cause serious harm within hours | red screen: vet CTA + acknowledgment gate. **No monetization may ever appear here.** |
| `CALL_TODAY` | speak to a veterinary practice the same day | standard result, urgent styling |
| `BOOK_VISIT` | worth a routine appointment in the coming days | standard result |
| `WATCH_AND_RECHECK` | not enough signal to act on yet — watch for the listed signs, re-check in `recheck_hours` | standard result + re-check CTA. **The floor. There is no "likely normal".** |

## Invariants (enforced, not aspirational)

1. **No output path terminates without an action and a timeframe.** Every
   fallback (kill-switch, degrade, media-unreadable, moderation-reject,
   insufficient-information) lands on `WATCH_AND_RECHECK` with an explicit
   `recheck_hours` — never a dead end, never below the floor.
2. **The pre-AI keyword override** (157 EN/DE keywords, `safety.py` ≡
   `emergency_keywords.mjs` ≡ the client-side offline router) returns
   `GET_HELP_NOW` at `confidence=1.0` before any model call.
3. **`GET_HELP_NOW` is never paywalled, quota-blocked, or counted**
   (`quota_gate.mjs`, unit-tested) and is **cross-verified** by a second
   Tier-3 call (kept regardless of agreement; disagreement is logged).
4. `confidence < 0.60` → insufficient-information floor result — never
   fabricate. `confidence` is never shown to a user anywhere.
5. `disclaimer_required` is forced `true` server-side on every path.
6. **No field may ever carry a condition/disease name.** The observation
   describes; the veterinarian names.

## Canonical example

```json
{
  "action": "GET_HELP_NOW",
  "confidence": 0.92,
  "observation": "A visibly swollen, firm belly with restlessness and retching that brings nothing up.",
  "visible_symptoms": ["swollen, firm abdomen", "unproductive retching", "restlessness"],
  "vets_look_for": [
    "whether the stomach is distended or rotated",
    "circulation and gum color",
    "how quickly signs are progressing"
  ],
  "watch_for": ["collapse", "pale or blue gums", "worsening distress"],
  "recommended_actions": [
    "Contact an emergency veterinarian now.",
    "Do not give food or water on the way."
  ],
  "urgency_timeframe": "immediately",
  "recheck_hours": null,
  "disclaimer_required": true
}
```

## Storage mapping (`public.analyses`)

`action` → `analyses.action` (CHECK-constrained to the four ladder values) ·
`observation` → `analyses.observation` · `confidence` → `confidence_score`
(internal) · full payload → `full_response`. Migration:
`20260717130000_contract_v2_action_ladder.sql`.

## History

- **v1** (Phase 1.3 → 2026-07): `triage_level` EMERGENCY|MONITOR|NORMAL,
  `primary_concern`, `differential`. Retired because the verdict surface
  concentrated the product's entire false-negative and
  practice-of-veterinary-medicine exposure in its two lowest-value outputs
  (`NORMAL`, `differential`). See `PAWDOC_PRODUCT_EVOLUTION_MASTERPLAN.md`.
