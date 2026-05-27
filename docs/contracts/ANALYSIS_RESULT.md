# `AnalysisResult` — Frozen Contract (single source of truth)

The triage payload that crosses three languages: **AI service (Python/Pydantic)
→ Edge Function (TypeScript) → app (Dart)**. The field list is **frozen here in
Phase 1.1** (Critical Review #16) so the bindings cannot silently drift.

> **Change control:** any change to this contract must update all three bindings
> in the same PR and re-run the contract tests. Adding a field is backward-safe;
> renaming/removing/retyping is breaking.

## Fields

| JSON key | Type | Notes |
|----------|------|-------|
| `triage_level` | enum string | exactly one of `EMERGENCY`, `MONITOR`, `NORMAL` |
| `confidence` | number | model confidence, `0.0`–`1.0` |
| `primary_concern` | string | one-line summary of the main finding |
| `visible_symptoms` | string[] | what the model observed (may be empty) |
| `differential` | string[] | possible explanations, most→least likely (may be empty) |
| `recommended_actions` | string[] | ordered next steps |
| `urgency_timeframe` | string | e.g. `immediately`, `within 24 hours`, `routine` |
| `disclaimer_required` | boolean | when true the UI **must** show the disclaimer (injected server-side; never suppressible by the client) |

## Canonical example

```json
{
  "triage_level": "EMERGENCY",
  "confidence": 0.92,
  "primary_concern": "Suspected bloat (GDV)",
  "visible_symptoms": ["distended abdomen", "unproductive retching"],
  "differential": ["GDV", "ascites"],
  "recommended_actions": ["Go to an emergency vet now"],
  "urgency_timeframe": "immediately",
  "disclaimer_required": true
}
```

## Bindings

| Language | Location | Status |
|----------|----------|--------|
| Dart | `mobile/lib/src/models/analysis_result.dart` | ✅ Phase 1.1 (with round-trip tests) |
| TypeScript | Edge Function `/analyze` | ⏳ Phase 1.3 |
| Python (Pydantic) | AI service `/analyze` | ⏳ Phase 1.3 |

The Dart binding is the reference implementation; 1.3 mirrors it exactly and adds
contract tests across all three (CR #16).
