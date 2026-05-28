# SUB-PR Report — Phase 6.2: Outcome Feedback Loop & Data Foundation

**Status:** Complete and fully green (ruff + 152 pytest, node, flutter analyze + 91 tests, accuracy_views pg test PASS, shellcheck).
**Branch:** `phase-6.2-outcome-feedback` (from `origin/main` = `1e9708e`, post-6.1 merge)
**Date:** 2026-05-28

This phase converts Phase 4.1's free-text feedback widget into a moat-grade pipeline: outcomes are server-enforced to the 5 canonical values, admin-only SQL views surface AI-accuracy proxies (FP / FN / TP / TN), and an admin-only export script projects joined rows into fine-tune-ready JSONL with a strict PII allowlist. The **false-negative proxy is the highest-value output** — those rows feed directly into Phase 6.1's golden-set safety eval.

---

## 1. Files created / modified

**DB:**
```
supabase/migrations/20260528020000_accuracy_views.sql   CHECK on analysis_feedback.outcome (5 values)
                                                         + view_accuracy_signals (per-row FP/FN/TP/TN)
                                                         + view_accuracy_summary (per-class counts)
                                                         + REVOKE from anon/authenticated, GRANT service_role
supabase/tests/accuracy_views.sql                        4 outcome combos + null-signal + CHECK reject + lockdown
scripts/test-accuracy-views.sh                           Docker pgvector harness
```
**AI service / export pipeline:**
```
ai-service/app/training_export.py                        pure shape: to_training_record, _classify_signal,
                                                         _age_years (at analysis time), assert_no_pii,
                                                         dumps_jsonl, allowlists + PII_BLOCKLIST
ai-service/tests/test_training_export.py                 13 cases: FP/FN/TP/TN labels, planted PII leak detection,
                                                         allowed-keys envelope, age-at-analysis-time
scripts/export-training-dataset.py                       admin CLI: PostgREST + service_role, JSONL writer,
                                                         FN-proxy callout in stderr
```
**Flutter (UI lock-step with the new DB CHECK):**
```
mobile/lib/src/feedback/followup_banner.dart   (mod)     + "Vet said it was nothing" chip + Keys on all 5 chips
mobile/test/feedback_test.dart                 (mod)     asserts FeedbackOutcome covers exactly the 5 canonical
                                                         values (so client/server can't drift silently)
```
**Docs / hygiene:**
```
.gitignore                                     (mod)     + *.jsonl  (belt-and-braces; CLI writes to /tmp by default)
ENVIRONMENT_VARS.md                            (mod)     Phase 6.2 note
scripts/verify-phase-6.2.sh                              phase verifier (incl. running the pg test)
sub-pr-report/SUBPR_PHASE_6.2.md                         this report
```

## 2. SQL view logic — how FP / FN are defined

The two views live in `20260528020000_accuracy_views.sql` and are admin-only (REVOKE from anon/authenticated, GRANT only to `service_role`).

**Per-row view (`view_accuracy_signals`)** joins `analyses` ⋈ `analysis_feedback` (where outcome is not null — rating-only / comment-only feedback isn't classifiable) and computes a `signal` column:

```sql
case
  when a.triage_level = 'EMERGENCY'
       and f.outcome in ('vet_said_nothing', 'resolved_on_own')   -- AI over-triaged
    then 'false_positive_proxy'
  when a.triage_level = 'NORMAL'
       and f.outcome = 'vet_confirmed'                             -- AI under-triaged (safety-critical)
    then 'false_negative_proxy'
  when a.triage_level = 'EMERGENCY' and f.outcome = 'vet_confirmed'
    then 'true_positive_proxy'
  when a.triage_level = 'NORMAL'
       and f.outcome in ('vet_said_nothing', 'resolved_on_own')
    then 'true_negative_proxy'
  else null                                                        -- MONITOR / still_monitoring / other
end as signal
```

**False Positives proxy:** the AI raised EMERGENCY and the user's eventual outcome was that the vet said it was nothing, or it resolved on its own — i.e. we cried wolf. **High enough rates would degrade user trust** (and over-paywall-bypass).

**False Negatives proxy:** the AI rated the symptom NORMAL but a vet eventually confirmed a real problem — **this is the safety-critical case, and the #1 business risk the project was scoped around.** The verifier and the export script explicitly call these out so the founder can paste the symptom text into `ai-service/tests/golden_set.json` as a new EMERGENCY case (with `expected_triage = "EMERGENCY"`, `expected_override` per the appropriate keyword); the Phase 6.1 safety eval then enforces the regression on every prompt edit.

**MONITOR triage rows + `still_monitoring` / `other` outcomes are intentionally `signal = NULL`** — they're not a clean binary signal, so they sit in the view but don't pollute the FP/FN/TP/TN counts. The aggregate `view_accuracy_summary` lists them under the `unclassified` bucket so the founder still sees how many are there.

**Tested on real Postgres (Docker):** `supabase/tests/accuracy_views.sql` seeds one of each outcome combo + a MONITOR row, asserts exact counts (`FP=1, FN=1, TP=1, TN=1, unclassified=1`), and asserts the lockdown (`anon`/`authenticated` cannot SELECT either view; `service_role` keeps SELECT). The CHECK constraint also gets a negative test — a `'this_is_not_a_real_outcome'` INSERT must raise `check_violation`.

**Outcome categorization enforcement** is now a closed loop:
- Server CHECK constraint: `analysis_feedback_outcome_check` allows only `{resolved_on_own, vet_confirmed, vet_said_nothing, still_monitoring, other}` (and NULL for the rating/comment path).
- Client enum `FeedbackOutcome` carries the same 5 strings; `feedback_test.dart` asserts the set equality between exposed constants and the canonical set — drift on either side fails CI on the side that drifts first.
- The followup banner now surfaces **all 5** chips (the prior version was missing "Vet said it was nothing", which silently meant FP-proxy rows could never be observed). All chips have `Key`s for widget-tests / E2E.

## 3. Dataset export — PII stripping + fine-tune readiness

The export is split for testability: `ai-service/app/training_export.py` is pure (no I/O, no env), and `scripts/export-training-dataset.py` is the thin admin CLI that uses `SUPABASE_SERVICE_ROLE_KEY` to call PostgREST.

**Three defenses against PII leakage:**

1. **Positive allowlist on the SELECT.** The PostgREST `select=` clause names only the columns we want — `triage_level`, `primary_concern`, `confidence_score`, `tier_used`, `emergency_override_applied`, `input_type`, `text_description`, `created_at`, and the embeds `pet:pets(species,breed,birth_date)` and `analysis_feedback(outcome,rating,created_at)`. **`user_id`, `pet_id`, `id`, `input_storage_key`, `image_url`, `email`, `revenuecat_user_id`, `one_signal_player_id` are NEVER even fetched from the server.**
2. **Positive allowlist on the shape.** `to_training_record(row)` reads only `CONTEXT_ALLOWED` / `AI_ALLOWED` / `OUTCOME_ALLOWED`, then ignores everything else. Even if a future PostgREST tweak accidentally selects more, those fields are dropped on the floor.
3. **`assert_no_pii(record)` guard before serialization.** A blocklist of PII-coded keys (ids, geolocation, account, R2 keys) is walked recursively — if any of them appear at *any* nesting level, the script raises `AssertionError` and writes nothing. This is belt-and-braces: defenses #1 + #2 should already prevent leaks; #3 catches contract bugs (e.g. an upstream key rename) loudly rather than silently.

**Output shape (one JSONL line per analysis-with-outcome):**

```jsonc
{
  "context": {
    "species":      "dog",
    "breed":        "Labrador",
    "age_years":    5.0,                       // computed at the time of the analysis, not the export
    "input_type":   "text",
    "symptom_text": "Buddy seems lethargic and is vomiting"
  },
  "ai_response": {
    "triage_level":     "NORMAL",
    "primary_concern":  "likely benign",
    "confidence":       0.81,
    "tier_used":        3,
    "override_applied": false
  },
  "outcome": {
    "user_outcome":     "vet_confirmed",
    "user_rating":      1,
    "days_to_feedback": 3.2
  },
  "label": "false_negative_proxy"                // matches the SQL view's CASE
}
```

The label column duplicates the view's CASE classification in Python (`_classify_signal`) — kept in sync deliberately so a JSONL extract is self-contained for downstream filtering / weighting during fine-tuning, even without re-running the view.

**Pet names inside `symptom_text` (e.g. "Buddy") are kept** — they're useful linguistic context (the model needs to know the proper noun refers to the patient) and are not user-identifying PII. If the founder later publishes the dataset externally, a separate NER pass before release is the right next step; the script header documents this explicitly.

**Fine-tune readiness.** The JSONL is ready for a downstream prompt/completion transformation (the prompt = `context.symptom_text` + `context.species/breed/age`, the completion = `ai_response.*` weighted by `outcome.user_outcome` or `label`). The `false_negative_proxy` rows are flagged in stderr at the end of the export so the founder can review them and add them to `ai-service/tests/golden_set.json` — closing the loop between the data moat and the Phase 6.1 safety eval.

**Tested without any live DB:** 13 pytest cases assert the four signal classes, the empty-outcome filter, the `age_years` computation, the strict envelope (`set(rec.keys()) == {'context', 'ai_response', 'outcome', 'label'}`), and three negative tests where the `assert_no_pii` guard is shown raising on planted leaks (`user_id`, `email`) and where serialized output never contains upstream PII strings.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check .` | **clean** |
| `pytest -q` | **152 pass** (+13 training_export) |
| `./scripts/test-accuracy-views.sh` (Docker) | **PASS** — CHECK + FP/FN/TP/TN + null-signal + lockdown |
| `node --test _shared/*.mjs` | **62 pass** (unchanged by this phase) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **91 pass** (+1 canonical-outcomes contract) |
| `./scripts/run-eval.py` (6.1 safety gate) | **exit 0** — 12/12 PASS, FN-on-EMERGENCY=0 |
| `./scripts/verify-phase-6.2.sh` | **exit 0** — incl. running the pg test; 2 MANUAL |
| `shellcheck` (verifier + harness) | **clean** |

## 5. MANUAL (founder)

- Apply `20260528020000_accuracy_views.sql` on Supabase (`supabase db push`). The views are admin-only — read them from the Supabase Studio SQL editor (which runs as postgres) or via service-role tooling.
- Periodic export: set `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` in the shell (Doppler / 1Password — never commit), then run `ai-service/.venv/bin/python scripts/export-training-dataset.py`. Output lands in `/tmp/pawdoc-training-<UTC date>.jsonl`; `*.jsonl` is gitignored. **Review any `false_negative_proxy` rows the script reports and paste the symptom text into `ai-service/tests/golden_set.json` as a new EMERGENCY case** — the Phase 6.1 safety eval then enforces the regression on every future prompt edit.
- (Optional) Schedule the export on a weekly cron later (e.g. as a Fly job running Sunday after the AI Health Journal) — out of scope for this sub-PR.

## 6. Git branch / commit / push

- Branch: `phase-6.2-outcome-feedback`
- Implementation commit (deliverables): `6b644c4d898842f62fd9874688e876a001dfa460`
- Push: pushed to `origin/phase-6.2-outcome-feedback`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-6.2-outcome-feedback

## 7. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Outcome categories locked to the 5 canonical values (server-side) | ✅ DONE | `analysis_feedback_outcome_check` CHECK |
| Outcome categories surfaced in the UI (no drift) | ✅ DONE | followup banner exposes all 5 chips + contract test in `feedback_test.dart` |
| FP / FN proxy view + summary view exist | ✅ DONE | `view_accuracy_signals`, `view_accuracy_summary` |
| Views revoked from anon/authenticated, granted to service_role | ✅ DONE | pg test asserts `has_table_privilege` |
| Dataset export script — service-role, JSONL, fine-tune-ready | ✅ DONE | `scripts/export-training-dataset.py` |
| Export strips ALL PII (no ids, no GPS, no R2 keys) | ✅ DONE | positive allowlist + `assert_no_pii` + 13 pytests + planted-leak tests |
| FN-proxy rows highlighted so they can feed the golden set | ✅ DONE | CLI prints FN count + reminder to update `golden_set.json` |
| Migration applied on Supabase + first export sampled | ⏳ MANUAL | §5 |

Stopping for approval.
