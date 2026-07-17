# Appendix A — Final Evolution Implementation Changelog

Every significant implementation, grouped by phase. Branch `feat/final-evolution` (PR #80); one commit per phase (a…f sub-commits in Phase 1). Validation state at each phase close is recorded in the main report's test table.

## Phase 0 — Foundation (`e125462`)
- Master execution roadmap written into `PAWDOC_FINAL_EVOLUTION_REPORT.md` (all sources merged/deduplicated/re-phased).
- Baseline recorded green: analyze 0 · 217 flutter · ruff · 186 pytest · 103 node.
- Dead `auth-webhook` Edge Function deleted (BE-03); `verify-phase-1.1.sh` inverted to fail if it reappears; runbook 13 marked superseded.

## Phase 1 — Subtraction (`6d48f3b`, `48300d8`, `31b2e3c`, `524a244`, `da72a2d`, `82b1618`)
- **1a** Affiliates removed from every surface — including the two revenue-share CTAs on the **emergency screen** (telehealth "licensed vet" video-consult + pet insurance). Env URLs, analytics events, l10n strings deleted; NEVER-add-monetization comment pinned on the screen.
- **1b** Referral deleted end-to-end (screen/prefs/route/RPC/table/columns/cap-trigger/portal page). Kills **RLS-01 (CRITICAL)** at the root plus PRD-01/PRD-04/UX-04/REC-03. Bonus-credit pool removed from `free_tier.mjs`.
- **1c** Family sharing deleted (3 screens, 2 Edge Functions, invites module, 4 tables, `pets.family_group_id`); RLS reverted to **owner-only explicit per-op policies**. AI journals deleted (+the **OpenAI vendor** — an undisclosed processor). b2b_lite/sitter + `client_name` deleted. PDF credit add-on deleted (premium-included; honest 402). Tier ladder collapsed: `PREMIUM_STATUSES = {premium, trial}` everywhere. 2-pet cap removed.
- **1d** Video capture deleted (client screen + keyframe extractor + Edge presigning; upload extensions restricted to images). A/B experiment machinery deleted (kill-switch survives). Re-engagement push + both crons deleted.
- **1e** Vet finder → **OS maps deep link** (both location permissions deleted from Android + iOS; `find-vets` + Places proxy deleted). **OneSignal deleted** (SDK, boot init, delete-account purge, onboarding push step; kills QA-03). **Dark-only** `themeMode` (kills UX-01). **7 static TTFs bundled** + `allowRuntimeFetching=false` + gate test (kills ENG-01/PERF-03).
- **1f** Consolidated drop migration `20260717120000_evolution_subtraction.sql` (tables, columns, triggers, RPCs, policy recreation, guarded cron unschedule). Semantic cache stripped from the Edge + `/embed`/embeddings/training_export deleted from the AI service. **`test-rls.sh` now applies EVERY migration** and runs as a new required CI job (kills RLS-02/INF-04). `ENVIRONMENT_VARS.md` flags 12 removed vars for Doppler cleanup.

## Phase 2 — Contract v2: the action ladder (`3629328`)
- Wire contract: `action ∈ GET_HELP_NOW | CALL_TODAY | BOOK_VISIT | WATCH_AND_RECHECK`; **`differential` deleted; `NORMAL` no longer exists as a value**; `observation` replaces `primary_concern`; new `vets_look_for[]`, `watch_for[]`, `recheck_hours`.
- Python: observer-not-judge system prompt; every fallback lands on the floor **with** `recheck_hours`; ladder-floor re-check replaces the borderline-NORMAL bias; golden set v2 (hard gate: 0 false negatives on GET_HELP_NOW).
- Edge/DB: `quota_gate` rename; migration `20260717130000` renames `analyses.triage_level→action` (+CHECK on the 4 values), rewrites accuracy views (adds `directed_to_care`), re-creates the followup RPC.
- Dart: result screen rebuilt (observed / what vets look for / call sooner if you see / timing / one-tap re-check reminder / share-the-entry); no reassuring green anywhere; the avatar never plays a relief beat; hardcoded escalation floor merges with AI `watch_for`. Web checker migrated. `docs/contracts/ANALYSIS_RESULT.md` rewritten with explicit invariants.
- Merged `main` (founder's squash of PR #78) into the branch; PR #80 restored to MERGEABLE.

## Phase 3 — The emergency path is not an AI feature (`daf474b`)
- `EmergencyHelpScreen`: offline red-button target — maps deep link, tap-to-dial ASPCA poison control, **5 bundled first-aid cards** (choking, bleeding, seizure, bloat, heatstroke; vet review = founder gate). Zero AI, zero network, zero monetization (CLAUDE.md NEVER rule added).
- **Client keyword router**: the 157 EN/DE keywords generated from `safety.py` into `emergency_keywords.dart`; emergency text routes to the red screen **before any network call** (offline-proof). Server override stays authoritative.
- **3-way parity gate**: `emergency_keywords_parity_test.dart` byte-compares Dart ↔ mjs (py ↔ mjs asserted node-side) — drift in the #1 safety mechanism fails the build.
- Permanent home red button; first-aid link on the GET_HELP_NOW result; OfflineBanner on capture + describe (QA-06); first-aid content safety tests (no meds/doses/diagnosis; every card routes to a vet).

## Phase 4 — The record (`385ee79`)
- Pet form: **sex / weight / medical notes editable** (E5 — the vet report read them for months with no UI).
- **Weight trend**: event metadata read back for the first time — sparkline card (pure CustomPainter) atop the timeline; weight logs refresh `pets.weight_kg`.
- Reminders: **on-device local notifications** (`flutter_local_notifications`, inexact scheduling — no exact-alarm permission), scheduled on create/update, cancelled on delete; **edit support**; the dead "Enable now" wired; the never-rendering time slot removed; contextual permission ask.
- Vaccinations: the decorative vaccine-name/next-due UI **wired** — next-due auto-creates the reminder + its notification.

## Phase 5 — The Vet Visit Prep Pack (`5de0aa4`)
- `VetVisitPrepScreen`: pet basics + medical notes, weight trend, last 5 checks (action + observation — no verdicts), vaccinations & medications extracted from events, owner questions (suggested prompts + free text), shared as a clean pack. Entry points: home button + history menu. `buildVetVisitPrepPack` pure + unit-tested.

## Phase 6 — Free = safety, paid = memory (`45f973d`)
- **Quota v3**: text guidance UNMETERED; photo logs metered **pre-AI** at 5/month — no out-of-quota request can reach a model (**BE-01 dead at the root**; no post-AI gate exists). The 402 wall carries a free offline Emergency-help escape hatch.
- One plan, honest paywall ("The health record your vet actually wants to see"); value stack lists only what Premium includes; $39.99/$6.99 fallbacks.
- **SUB-01** Restore works (entitlement refresh + outcome feedback). **SUB-02** premium = DB status ∪ RC SDK entitlement. **SUB-05** current purchase API. **G8** Manage subscription deep-links the store management page.

## Phase 7 — Consent, honesty, legal accuracy (`d81c927`)
- **LEG-03**: assent checkbox gates account creation (email + Apple); `users.accepted_terms_at` migration.
- **I2**: analytics consent is REAL — opt-in at signup (default OFF) + revocable Account toggle; PostHog initializes only after consent; Sentry `sendDefaultPii=false`.
- `privacy.md` rewritten to describe the shipped app (consent basis true; no push processor; OneSignal removed; opt-out real). Terms 18+ → 13+/16+ (counsel bracket) consistent with a 12+ store rating.
- **PRD-02** headline replaced; onboarding = 3 steps; `$0.33/day` claim removed.
- **I4** `diagnosis` deleted from the App Store keyword field; **I5** category → Lifestyle (verify note); store descriptions rebuilt around record + red button + ladder.
- **I8** overclaim guard scans `mobile/lib/src` + `web-legal` and bans `never wonder`/`LIKELY NORMAL`/video-consult claims — and passes. `docs/legal/` TEMPLATE duplicates deleted (LEG-04).
- CI fix: core-library desugaring for `flutter_local_notifications` (the CI **build** step caught it; verified with a local debug APK).

## Phase 8 — Engineering hardening (`3eec1ae`)
- iOS: `pawdoc://` scheme (REC-02), `ITSAppUsesNonExemptEncryption=false` (APPL-04), `Runner.entitlements` (SIWA) wired into all 3 Xcode configs (APPL-01). Device verification founder-gated.
- **B10**: Gemini `system_instruction` role separation — owner text no longer shares a string with the safety contract.
- **AI-03**: single guarded fetch per image; moderation gets the TRUE mime (PNG/WebP wrong-rejects dead); the same bytes feed every model call.
- **B6**: GET_HELP_NOW cross-verify is async telemetry (injectable executor; deterministic tests) — no longer doubles latency on the red path.
- **R4**: per-analysis token usage captured, summed, logged (`analysis_telemetry`), returned in meta — first spend visibility ever.
- BE-01 residual: 30/h per-user burst limit (fail-open). **BE-02**: 25s deadline on Edge→Fly. **F6**: anon IPs salted-hashed.
- **UX-03** global 1.0–1.6× text-scale clamp; **ENG-03** capture decode+quality in the compress isolate; **PERF-02** 9.8MB unreferenced icon assets deleted.
- CI-only Flutter assert fixed (ListTile-in-DecoratedBox → own transparent Material).

## Phase 9 — Test integrity (`8d2e272`)
- **The company invariant, at every layer**: Python (8 paths — every fallback returns a ladder action + timeframe + floor re-check) and Dart (every ladder value renders action + timeframe + disclaimer; `NORMAL`/`LIKELY` asserted to never render; the enum itself has no "do nothing" state).
- Router redirect extracted as pure `computeRedirect()` with full branch coverage (recovery forcing, signed-out gating, signed-in bounce).
- (Full-migration RLS harness + CI gate landed in Phase 1; golden-set FN gate green at 0.)

## Phase 10 — Final validation & reports (`this commit`)
- Full-suite validation + release AAB build; three mission reports finalized; founder blocker list + verdict.
