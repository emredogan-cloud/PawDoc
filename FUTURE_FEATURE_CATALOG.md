# Appendix B — Future Feature Catalog

Ideas discovered or deferred during the Final Evolution Program, classified per the mission (Must Have / Should Have were implemented during the phases when consistent with the vision; everything else is cataloged here). Each idea: description, user value, business value, effort, legal risk, operational cost, recommended priority.

**The bar for re-adding anything:** it must serve the record ("free = safety, paid = memory"), never touch the emergency path, and be justified by observed beta behavior — not anticipation.

## Implemented during the program (for the record)
Must/Should-Have items that were built because they fit the vision: offline red button + first-aid cards · client keyword router + 3-way parity gate · action-ladder contract · one-tap re-check reminders · weight trend chart · editable record fields · structured vaccinations with auto-reminders · Vet Visit Prep Pack · analytics consent + assent gate · manage-subscription deep link · SDK entitlement fallback · cost telemetry · per-user burst limit.

---

## SHOULD HAVE (first post-beta iterations)

### 1. Photo progression timelines (side-by-side re-photograph)
The masterplan's D2 end-state: after a photo log, prompt "re-photograph in 7 days" and render the two shots side-by-side with dates. **User value:** vets diagnose change, not snapshots — this is genuinely better clinical input than any single-photo opinion. **Business value:** THE premium retention loop; justifies the photo meter. **Effort:** M (pairing UI + storage keys already exist). **Legal risk:** none — it never judges. **Ops cost:** none. *(The re-check reminder CTA built in Phase 2 is the hook; this completes it.)*

### 2. Pet profile photo (permissionless system picker)
`image_picker` via PHPicker / Android Photo Picker — no permission strings needed. Deferred from Phase 4 because the avatar system is Rive-based and the display integration touched every screen. **User value:** emotional anchor of a record product. **Effort:** M. **Legal risk:** photos of homes/people — covered by existing moderation + deletion. **Priority:** early post-beta.

### 3. Persisted "questions to ask" per pet
Phase 5 keeps owner questions session-only. Persist per-pet (new column or `health_events` type `question`), check them off in the exam room. **Effort:** S. **Risk:** none.

### 4. Weekly digest — LOCAL summary, not AI
A weekly on-device notification: "3 entries this week · weight steady · vaccine due in 12 days." Computed from the record, zero AI, zero server. Replaces what the deleted AI journal pretended to do, honestly. **Effort:** S-M. **Risk:** none.

### 5. `maxContentWidth` sweep (UX-02 completion)
The 480dp cap is applied on auth screens only; Phase 8 shipped the text clamp but deferred the width sweep (cosmetic, MEDIUM). Apply the shared wrapper to the ~12 remaining scroll bodies. **Effort:** S.

## NICE TO HAVE

### 6. Multi-pet prep packs & household export
One shareable pack across pets (boarding/sitters). **Effort:** S. **Risk:** none.

### 7. Breed education library expansion
`breed_insights.dart` is the safest content class in the app (about breeds, never about your dog). Expand seasonally (heat, ticks, holidays-foods). **Effort:** content-only. **Risk:** none if it stays general.

### 8. Localization completion (DE first)
Only ~13 strings are localized; the safety spine is EN/DE but the app is EN. Full DE l10n before marketing in DE. **Effort:** M-L. *(Store availability should remain EN/DE-only until then — and expand only with native-reviewed keyword lists.)*

### 9. Vet-facing share link (read-only web view of a prep pack)
A signed, expiring URL a vet can open. **Business value:** the zero-CAC vet channel from the founder guide. **Effort:** M (new public surface — auth design needed). **Risk:** access control must be exact; do post-beta with care.

### 10. Legal portal folded into `web/`
Deviation from the masterplan recorded in the roadmap: NOT done during the program because the CloudFront portal is the live store-facing host and the custom-domain decision is founder-side. Fold the 15 pages into the Next.js site once the domain exists, then retire the AWS/Terraform stack (INF-03/INF-06 close then). **Effort:** S-M + founder DNS.

## FUTURE VISION (revisit only with a team and counsel)

### 11. Family sharing v2
Re-add only when real households ask. Requirements learned from v1's flaws: join-forward visibility (no retroactive history exposure), no inviter-email leak, owner-revocable, and RLS designed from the sharing model first. **Effort:** L. **Risk:** privacy-sensitive.

### 12. Referral
Only after week-4 retention justifies amplification. v2 must be: live domain + App Links/Universal Links, reward copy that matches the RPC, no bonus-credit accounting on the safety meter (credits apply to photo logs only). **Effort:** M. *(Deleted v1 contained the launch-blocking FK defect; nothing forces its shape on v2.)*

### 13. Video capture
Re-add only if photo progression proves insufficient for movement signs (limping, breathing). Cost profile is 5× photos; meter it like photos. **Effort:** M (the removed code is in git history).

### 14. Insurance affiliate — calm surfaces only
If ever re-added: pet profile / account, NEVER a result or emergency surface (CLAUDE.md rule). Disclose the affiliate relationship in-app. **Risk:** reputational if misplaced — the emergency-screen version was the single highest-risk object the audit found.

### PERMANENTLY CUT (not "later" — cut)
Proprietary fine-tuned model · community Q&A · B2B API · insurance FNOL — the liability-escalation ladder from the masterplan (R8). Every rung moves medical judgment onto PawDoc's balance sheet; all four need the record to exist first anyway. Revisit, if ever, with a team, counsel, and E&O sized for it.
