# Appendix A — PawDoc Product Expansion Roadmap

**Date:** 2026-07-18 · **Branch:** `feat/release-candidate` · Built on the Final Evolution baseline (`main` @ `b959523`, PR #80).

This roadmap merges three inputs: the `FUTURE_FEATURE_CATALOG.md` from the evolution program, the RC static UX audit (all 20 screens), and the on-device release-build test. **Guiding discipline (from the catalog's own bar, and appropriate to a release *candidate*):** a feature earns its place only if it serves the record, never touches the emergency path, and is justified by real use — not anticipation. So the RC itself ships **quality and correctness**, and net-new surfaces are scheduled for the first post-beta iterations rather than absorbed into the submission candidate.

Every idea below carries: **why · effort · business value · legal impact · maintenance cost · priority.**

---

## 1. Implemented in this RC (shipped on `feat/release-candidate`)

These are product improvements a first-time owner directly feels — not just refactors. All are covered by `flutter analyze` clean + 222 green tests (+6 new).

| Improvement | Why it matters | Effort |
|---|---|---|
| **Friendly error handling** (`friendly_error.dart`) | On-device, a failed sign-in showed the raw `SocketException: Failed host lookup …` and a raw `{"code":"unexpected_failure"…}`. A first-time owner must never see that. Now: calm, human copy; real error logged. | S · unit-tested |
| **Safe reminder deletion** | The "bell" on upcoming reminders deleted instantly with **no confirmation** — silent data loss behind a misleading icon. Now a clear trash icon behind a confirm dialog. | S |
| **No raw wire tokens** (`action_labels.dart`) | `GET_HELP_NOW` leaked verbatim into the pets-list chip, home fallback, and prep pack. One shared friendly-label source now feeds all of them (and the timeline chip). | S |
| **False affordances removed** | A non-tapping "+" on symptom prompts and a targetless "Learn more" both did nothing when tapped — embarrassing in review. Removed. | XS |
| **Accessibility / overflow** | Paywall plan title made `Flexible` (overflowed at 1.6× text); camera offline-banner + lighting chip no longer overlap; capture labels wrapped. | S |
| **RevenueCat GDPR purge fix** | `delete-account` read `REVENUECAT_SECRET_API_KEY` but the provisioned slot is `REVENUECAT_API_KEY` — the subscriber purge silently no-op'd on deletion. Code aligned (with legacy fallback). | XS |

---

## 2. Discovered opportunities (new this pass) — SHOULD-HAVE, first post-beta

### S1. Persisted "questions to ask your vet" — **no migration required**
The prep pack's owner-questions are session-only. `health_events.event_type` is **free-form text** (no CHECK constraint), so questions can persist as `health_events` rows (`type: 'question'`) under the **existing owner-only RLS** — no schema change, no new table.
- **Why:** the exam-room checklist is the single most-requested "record" behavior; it makes the paid prep pack materially better. **Effort:** S (repository read/write + checkbox UI). **Business value:** high — strengthens the premium loop. **Legal:** none (owner's own notes). **Maintenance:** low. **Priority: HIGH (do first post-RC).**

### S2. Design-system convergence for the last three screens
`pet_form`, `reminder_form`, and `recovery` still render on plain Material (no `PawBackground`/`PawCard`, legacy buttons) while ~13 siblings use the Paw UI — so add/edit-pet looks like an older app.
- **Why:** visual consistency is what "would I proudly submit this to Apple?" is made of. **Effort:** S–M (mirror the already-migrated `health_event_form`). **Business value:** medium (polish/trust). **Legal:** none. **Maintenance:** low. **Priority: HIGH.** *(Deferred from the RC only because a cosmetic multi-screen refactor is regression risk days before submission — it is the first UI task after.)*

### S3. `maxContentWidth` sweep (tablet / large-screen)
The 480 dp content cap is applied only on the two auth screens; on iPad and foldables the content stretches edge-to-edge.
- **Why:** Apple reviews on iPad; stretched phone layouts read as unpolished. **Effort:** S (introduce a shared `PawMaxWidth` wrapper, apply to ~12 scroll bodies). **Business value:** low–medium. **Legal:** none. **Maintenance:** low. **Priority: MEDIUM.**

### S4. Typography-token convergence
`reminders_screen` (`_HeroSection`/`_EmptyState`/`_SectionHeader`) and the account analytics tile hardcode `fontSize`, so they don't scale/restyle with the token system.
- **Why:** consistency + large-text correctness. **Effort:** S. **Value:** low. **Legal:** none. **Priority: LOW-MEDIUM.**

### S5. Decide the Google auth provider
`[auth.external.google]` is `enabled = true` and provisioned in prod, but the app offers **only** email + Apple. Either add a Google button (parity, faster onboarding) or disable the provider to shrink the auth surface.
- **Why:** don't ship an enabled-but-unreachable auth path. **Effort:** S (button) or XS (disable). **Value:** medium (onboarding conversion). **Legal:** a new processor disclosure if surfaced. **Priority: MEDIUM — founder decision.**

---

## 3. Carried Should-Have (from the evolution catalog)

### C1. Photo progression timelines — *the premium retention loop*
After a photo log, prompt "re-photograph in 7 days" and render the two shots side-by-side. **Why:** vets diagnose change, not snapshots — genuinely better clinical input, and it justifies the photo meter. **Effort:** M (pairing UI + storage keys exist). **Business value:** highest of any item. **Legal:** none (never judges). **Maintenance:** low. **Priority: HIGH — the flagship first-iteration feature.** *(RC-deferred: touches capture + storage; wants the backend restored and real beta photos first.)*

### C2. Pet profile photo (permissionless system picker)
`image_picker` via PHPicker / Android Photo Picker — no permission strings. **Why:** the emotional anchor of a record product. **Effort:** M (display integration touches many screens). **Legal:** covered by existing moderation + deletion. **Priority: MEDIUM.**

### C3. Weekly digest — LOCAL summary, zero AI
An on-device weekly notification: "3 entries this week · weight steady · vaccine due in 12 days," computed from the record. **Why:** honest re-engagement without a server or a model. **Effort:** S–M. **Legal:** none. **Priority: MEDIUM.**

---

## 4. Nice-to-Have (later)
- **Multi-pet prep packs / household export** — S, no risk.
- **Breed education library expansion** — content-only (safest content class: about breeds, never about *your* dog).
- **DE localization completion** — M–L; only ~13 strings localized while the safety spine is EN/DE. Gate DE-market availability on this + native-reviewed keyword lists.
- **Vet-facing read-only share link** (signed, expiring URL) — M; a new public surface, so access control must be exact. Post-beta with care.
- **Legal portal folded into `web/`** — S–M + founder DNS; retires the AWS/Terraform stack once a custom domain exists.

## 5. Future Vision (only with a team + counsel)
Family sharing v2 (privacy-designed from the sharing model first) · Referral v2 (live domain + App/Universal Links; no bonus-credit accounting on the safety meter) · Video capture (meter like photos; ~5× cost) · Insurance affiliate on **calm** surfaces only (never a result/emergency screen — CLAUDE.md rule).

## 6. Permanently cut (not "later" — cut)
Proprietary fine-tuned model · community Q&A · B2B API · insurance FNOL — every rung moves medical judgment onto PawDoc's balance sheet. Revisit, if ever, only with a team, counsel, and E&O sized for it.

---

## Merged sequencing

| Phase | Contents | Gate |
|---|---|---|
| **RC (this branch)** | §1 quality/correctness fixes | ✅ done, CI-validated |
| **Iteration 1 (post-beta)** | S1 persisted questions · S2 design convergence · C1 photo progression | needs restored backend + first beta signal |
| **Iteration 2** | S3 maxContentWidth · S5 Google decision · C2 pet photo · C3 weekly digest | product signal |
| **Iteration 3+** | DE l10n · vet share link · legal-into-web | market expansion |
| **With a team** | Future Vision items | counsel + E&O |

**Backlog owner note:** none of the deferred items is blocked by engineering — they're scheduled, not stuck. The RC deliberately optimizes for a stable, honest, submittable build over new surface area.
