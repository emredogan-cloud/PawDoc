# PawDoc — Final Evolution Report

**Mission:** transform PawDoc per the approved product vision (`PAWDOC_PRODUCT_EVOLUTION_MASTERPLAN.md`, `PRODUCT_FEATURE_MATRIX.md`, `FOUNDER_STRATEGY_GUIDE.md`) into the strongest possible pre-launch product.
**Branch:** `feat/final-evolution` (off `feat/legal-portal-integration` = `main` + PR #78) · **Started:** 2026-07-17
**Companions:** `IMPLEMENTATION_CHANGELOG.md` (Appendix A) · `FUTURE_FEATURE_CATALOG.md` (Appendix B)

> **STATUS: IN PROGRESS.** This file is updated as phases complete. Sections marked ⏳ are pending.

---

## Executive Summary

⏳ *Written at mission completion.*

**Baseline (2026-07-17, before any change):** `flutter analyze` 0 issues · **217/217** Flutter tests · ruff clean · **186/186** pytest · **103/103** node Edge tests. Every phase below must end at least this green.

**Approved product reframe being executed:** triage *verdicts* → a *record and a plan*. Delete `LIKELY NORMAL` and the differential; action ladder with no "do nothing" rung; emergency becomes an offline red button with zero AI and zero monetization; free = safety, paid = memory; one subscription plan; growth scaffolding removed until retention earns it back.

---

## Master Execution Roadmap

Every task from the three vision documents, the 2026-07-06 pre-launch audit (64 findings), the store checklist, and prior sprint reports — merged, deduplicated, and re-phased. Source IDs cite the audit (`SEC-01`…) and the feature matrix (`A1`…). Ordering principle: **subtract before you build** (deletion clears 1 CRITICAL + 3 HIGHs for free), **contract before UI** (everything renders the contract), **safety path before monetization** (quota semantics depend on the red button existing).

Items an agent cannot execute (keystore, attorney, store consoles, DNS, live deploys, device passes, protected-`main` merges) are **founder-gated** and tracked in [Remaining Blockers](#remaining-blockers--founder-gated-work), not in the phases.

### Phase 0 — Foundation *(this phase)*
| Task | Source |
|---|---|
| Branch `feat/final-evolution`; confirm toolchain; baseline validation (all suites green) | mission |
| Master roadmap written (this document) | mission |
| Delete dead `auth-webhook` Edge Function | BE-03 / J15 |
| CI recon: ci.yml gates = ruff+pytest, shellcheck, gitleaks, node tests, no-placeholders, flutter analyze+test+**apk+aab build** | mission |

### Phase 1 — Subtraction
*Deletes ~1 CRITICAL + 3 HIGH + ~10 MEDIUM findings by removal, 5 tables, 7 Edge Functions, 3 vendors. Order within phase: client-leaf features first, then shared plumbing, then migrations, so the tree compiles at every commit.*

| Task | Source |
|---|---|
| Remove referral: screen, prefs, deep link `/r/:code`, `claim-referral` fn, `referral.mjs`, RPC, `referrals` table, `users.referred_by_user_id` + `bonus_analyses` + cap trigger, portal page link-outs, share copy | **RLS-01 CRITICAL**, PRD-01/04, REC-03, UX-04, F1 |
| Remove family sharing: 3 screens, `/family` + `/invite/:token` routes, invite prefs, `invite-family-member` + `accept-family-invite` fns, `invites.mjs`, 4 tables, `pets.family_group_id`, RLS rewritten owner-only, deletion-cascade trigger removed | F2, LEG (invite email leak), QA-01 scope |
| Remove affiliates: `TelehealthButton`, `InsuranceAffiliateCta`, env URLs, analytics events, l10n strings | **R3 / C2-C3** — emergency-screen monetization |
| Remove video: capture screen, keyframe extractor, home tile, `frame_urls` path in Edge + AI service + video model config | D3, AI cost |
| Remove journals: screen, card, `is_journal_enabled`, `health_journals` table, `generate-journals` fn, `journal.py`, `journal.mjs`, **OpenAI vendor** | E11, H4, undisclosed processor |
| Remove A/B experiments: `feature_flags.dart` variants, onboarding Variant B paywall, paywall variants B/C, `pulse_pet_variant` | F3, PRD-03/05 |
| Remove re-engagement push + `process-reminders` cron (reminders go local in Phase 4), `reminders.mjs` push half, `users.last_reengagement_sent_at`, `users_to_reengage` RPC | F4 |
| Remove b2b_lite/sitter: tier, `pets.client_name`, eligibility sets | F5 |
| Remove PDF $4.99 add-on: `pdf_reports_remaining`, `ADDON_PRODUCTS`, 402 gate → premium-included | E9, G-matrix |
| Remove semantic cache: `semantic_cache.mjs`, `analyses.embedding`, `match_analyses` RPC, embed path | H8 |
| Remove training export (`training_export.py`) — unscrubbed PII | F9 |
| Remove 2-pet cap (`pet_limits.dart` gate → unlimited) | J5, G4 |
| Vet finder → OS maps deep link; drop `geolocator`, both location permissions, `find-vets` fn, `places.mjs` | H1, PLAY-03 |
| OneSignal → `flutter_local_notifications`: delete service, player-id column, vendor; reminders schedule on-device (wired fully in Phase 4) | H2, QA-03 |
| Dark-only: `themeMode: ThemeMode.dark` (+ boot error app) | **UX-01 HIGH** |
| Bundle Inter + Bricolage Grotesque `.ttf`; `allowRuntimeFetching=false` | ENG-01/PERF-03, H5 |
| Migrations: drop the above tables/columns/RPCs; `delete-account` simplification (R2 purge + auth delete remain) | RLS-01 root fix |

### Phase 2 — AI Output Reframe *(the product decision)*
| Task | Source |
|---|---|
| Contract v2 (frozen, 3 languages): `action` = `GET_HELP_NOW \| CALL_TODAY \| BOOK_VISIT \| WATCH_AND_RECHECK`; **`differential` deleted**; `primary_concern` → plain-language `observation`; add `watch_for[]`, `vets_look_for[]`, `recheck_hours`; keep `confidence` internal-only | A1–A4, R1, R2 |
| System prompt rewritten: observer-not-judge; never name a condition; never a no-action terminal; species guidance kept | A7, A8 |
| `safety.py` override → `GET_HELP_NOW`; degrade paths → `WATCH_AND_RECHECK` with explicit re-check; confidence floor/routing unchanged | B1, B5, B7 |
| Edge Function + `quota_gate.mjs`/`free_tier.mjs` enum rename (semantics unchanged until Phase 6); DB `triage_level` → `action` | mechanical |
| Dart `AnalysisResult` v2; result screen rebuilt: what you described · what vets look for · watch for · timing · logged ✅ · re-check CTA; no "Possible causes"; no "LIKELY NORMAL" | A1–A3, R1 |
| Golden set re-labeled; **zero false negatives on GET_HELP_NOW** stays the hard gate; loading messages rewritten | J13 seed |
| All three test suites updated | mission |

### Phase 3 — Emergency Redesign *(no AI in the emergency path)*
| Task | Source |
|---|---|
| Permanent red button on home → offline emergency screen: maps deep link (`geo:`/Apple Maps), ASPCA poison-control tap-to-dial, bundled vet-reviewed-pending first-aid cards (choking, bleeding, seizure, bloat, heatstroke) | C1, C5, R5 |
| 157 EN/DE keywords ported to Dart as instant client-side router (offline, pre-network); server override stays authoritative; **3-way parity test** (Dart ↔ py ↔ mjs) | B1, B2, QA-06 |
| Offline banner on capture/describe screens | J8, QA-06 |
| `CLAUDE.md` NEVER rule: nothing may ever be added to the emergency screen (no AI, no meter, no monetization, no analytics-driven CTA) | R3 |

### Phase 4 — The Record
| Task | Source |
|---|---|
| Pet form: `sex`, `weight_kg`, `medical_notes` editable (vet report already reads them) | E5 |
| Weight trend chart (CustomPainter; reads back event metadata + seeds from profile) | E4 |
| Reminders: edit support; time display fixed; dead "Enable now" wired; local-notification scheduling with contextual permission ask | J6, H2 |
| Structured vaccination logging (name + date + next-due → auto-reminder) | E7 |
| Pet photo via permissionless system picker (PHPicker/Photo Picker) — else deferred to catalog | E6/D7 tension |

### Phase 5 — Vet Visit Prep Pack *(the paid product's centerpiece)*
| Task | Source |
|---|---|
| Prep-pack destination screen: pet basics · current concerns (recent guidance) · timeline extract · weight trend · meds/vaccines · owner questions checklist | E1 |
| Share as text/markdown + PDF (premium-included); entry points on home + timeline | E1, E9 |

### Phase 6 — Monetization Redesign
| Task | Source |
|---|---|
| One plan: Premium only; `family`/`b2b_lite` statuses collapse (webhook maps any active entitlement → premium) | G4, R10 |
| Free = safety, paid = memory: **text guidance unmetered**; photo logs metered **pre-AI** (~5/mo — kills BE-01 since vision is no longer a safety mechanism); 30-day history view free; `GET_HELP_NOW` never blocked (belt over the client router) | G1, G3, BE-01 |
| `free_tier.mjs`/`quota_gate.mjs` rewritten to photo-metering; upgrade sheet copy honest | G1–G3 |
| Restore Purchases: real call + feedback + entitlement refresh | SUB-01, G6 |
| SDK entitlement fallback (`addCustomerInfoUpdateListener` + post-purchase local grant) | SUB-02, G7 |
| Manage-subscription deep link from Account | G8 |
| Current purchase API (replace deprecated `purchasePackage`) | SUB-05, G11 |
| Paywall rebuilt: one plan, honest value stack (record-centric), `$39.99/yr` / `$6.99/mo` fallbacks, annual featured | G5, R10 |

### Phase 7 — Consent, Legal, Honesty
| Task | Source |
|---|---|
| Affirmative Terms/Privacy assent at signup (logged `accepted_terms_at`) | LEG-03, I2 |
| Analytics toggle in Account that actually gates PostHog; consent-checked init; `sendDefaultPii=false` for Sentry | I2, R6 |
| Onboarding: 3 steps (value → pet → first check); **"Never wonder…" headline replaced**; push-permission step dropped (contextual ask at reminder creation); `$0.33/day` price claim removed | PRD-02, I9, J2 |
| CI overclaim guard: `mobile/lib` added to ROOTS; regex extended (`never wonder`, licensed-vet claims) | I8 |
| Legal content updated to describe what ships (processors accurate post-OpenAI removal; consent basis now real; retention per R2 policy decision) — counsel brackets kept | I1, R6 |
| Legal portal content folded into `web/` as routes; **CloudFront stays live until founder deploys replacement** (sequencing challenge to masterplan — don't delete live infra first); Terraform marked deprecated, not deleted | H3 amended |
| Store metadata drafts: category → Lifestyle (founder verifies), age 12+, **`diagnosis` keyword deleted**, EN/DE market note, copy re-centered on record + red button | I4–I7, R9 |
| Delete divergent `docs/legal/` TEMPLATE duplicates | LEG-04, I12 |

### Phase 8 — Engineering Hardening
| Task | Source |
|---|---|
| iOS: `pawdoc://` scheme registered; `ITSAppUsesNonExemptEncryption=false`; `Runner.entitlements` (SIWA) + pbxproj wiring — device verification founder-gated | REC-02, APPL-01/04 |
| Gemini `system_instruction` role separation (owner text out of the system string) | B10, SEC-02 adjacent |
| Moderation: MIME from object, single fetch | AI-03, B9 |
| Async `GET_HELP_NOW` cross-verify (respond first, verify in background, log) | B6, R4 |
| Cost telemetry: per-analysis usage/cost logging + response meta | R4, G3 |
| Burst rate limit on `/analyze` (per-user) | BE-01 residual |
| Edge→Fly outbound timeout (`AbortSignal.timeout`) | BE-02 |
| Anon web checker: hash IPs (keep as web funnel) | F6 |
| `maxContentWidth` wrapper on all screens; text-scale clamp; capture decode off UI isolate; asset cleanup + `cacheWidth` | UX-02/03, ENG-03, PERF-01/02 |

### Phase 9 — Test Integrity
| Task | Source |
|---|---|
| **THE invariant test** ×3 layers: no output path terminates without an action and a timeframe (pytest pipeline-wide · node Edge contract · Dart widget) | J13, R1 |
| Router/redirect widget tests (headless-runnable — challenge to audit's integration_test proposal: no emulator exists in CI) | ENG-02, QA-02 |
| Emergency widget tests incl. offline client router | C1 |
| `test-rls.sh` loads **all** migrations; CI job added (Docker available on GH runners) | RLS-02, INF-04, J14 |
| Golden-set gate re-asserted post-reframe | AI safety |

### Phase 10 — Final Validation & Reports
| Task | Source |
|---|---|
| Full suite + release AAB build; push; PR; **CI green** | mission |
| `PAWDOC_FINAL_EVOLUTION_REPORT.md` finalized · `IMPLEMENTATION_CHANGELOG.md` · `FUTURE_FEATURE_CATALOG.md` (Must/Should implemented during phases; rest cataloged) | mission |
| Final readiness verdict with evidence | mission |

### Explicitly rejected during roadmap merge (with reasons)
- **Deleting the AWS/Terraform legal stack now** (masterplan 1.9): wrong order — the CloudFront portal is the *live* store-facing legal host; code-side replacement lands in Phase 7, infra teardown is founder-gated post-deploy.
- **`integration_test/` harness in CI** (audit ENG-02 solution): no emulator in CI or this environment; router/redirect coverage is achievable as widget tests — same assertions, actually runnable.
- **Translating the safety keyword lists to more locales**: market restriction (EN/DE) is the honest fix; translation without native review of *emergency medical vocabulary* is fake safety.
- **Deleting `analyze-anonymous`**: kept as the web funnel with hashed IPs (matrix F6) — it's the only pre-install acquisition surface.

---

## Completed Phases

### ✅ Phase 0 — Foundation
- Branch `feat/final-evolution` created at `63a316b`.
- Baseline validation: **all green** (numbers above) — recorded as the regression floor.
- CI workflows read; every later push must keep 6 jobs green including APK+AAB build.
- `auth-webhook` deleted (BE-03); `verify-phase-1.1.sh` inverted to fail if it reappears.

### ✅ Phase 1 — Subtraction (commits `6d48f3b`…)
**Removed end-to-end, DB included:** affiliates (emergency-screen telehealth + insurance — the R3 reputational risk), referral (the RLS-01 CRITICAL dies with its FKs), family sharing (4 tables, RLS reverted to owner-only per-op policies), AI journals + the OpenAI vendor, b2b_lite/sitter + `client_name`, PDF credit add-on (premium-included now), the 2-pet cap, video capture (client + Edge + AI service), A/B experiment machinery (kill-switch survives), re-engagement push + both crons, vet finder → OS maps deep link (location permissions deleted from both platforms), OneSignal → deleted (local notifications land in Phase 4), semantic cache + `/embed` + `analyses.embedding`, `training_export.py` (unscrubbed PII exporter).

**Added:** dark-only `themeMode` (UX-01 dead); 7 bundled TTFs + `allowRuntimeFetching=false` + gate test (ENG-01/PERF-03 dead); consolidated drop migration `20260717120000_evolution_subtraction.sql`; **`test-rls.sh` now applies EVERY migration** (RLS-02/INF-04 pulled forward — the curated-subset false-confidence is gone) and runs as a new required CI job; paywall value stack reduced to only true claims (R10); one-plan collapse server+client (`PREMIUM_STATUSES = {premium, trial}`).

**Audit findings eliminated by this phase alone:** RLS-01 (CRITICAL) · PRD-01, UX-01, BE-01\* (HIGH; \*cost path shrinks now, meter lands Phase 6) · PRD-04, PRD-05, SUB-03, PLAY-03, QA-03, ENG-01, PERF-03, RLS-02, INF-04, REC-03, UX-04 + Data Safety scope (PLAY-02) materially reduced.

**Validation at phase close:** `flutter analyze` 0 · **187** flutter tests · **64** node tests · **150** pytest · ruff clean · shellcheck all-green · disclaimers verifier PASS · **full-migration RLS + deletion-cascade suite PASS in Docker** (referrer/referee deletion can no longer 500 — the FKs don't exist).

⏳ *Phases 2–10 appended as completed.*

---

## Test Results

| Checkpoint | flutter analyze | flutter test | ruff | pytest | node | Notes |
|---|---|---|---|---|---|---|
| Baseline (pre-change) | 0 issues | 217/217 | clean | 186/186 | 103/103 | debug tree, phase start |
| Phase 1 close | 0 issues | 187/187 | clean | 150/150 | 64/64 | counts drop with deleted features' tests; + full-migration RLS suite PASS (Docker) |

⏳ *Rows appended per phase.*

## CI History
⏳ *Populated after first push.*

## Remaining Blockers — Founder-Gated Work
⏳ *Finalized at mission end; running list maintained from `PAWDOC_FOUNDER_ACTION_PLAN.md` minus items dissolved by subtraction.*

## Final Launch Readiness
⏳

## Future Roadmap
⏳ *See `FUTURE_FEATURE_CATALOG.md`.*
