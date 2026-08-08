# PawDoc — Play Store review audit

**Written:** 8 August 2026 · **Build audited:** `phase-monetization-offers-aso` @ `e4b4043`
(`app.pawdoc`, `1.0.0+5`, targetSdk 36).

Two passes over the same product: a **hostile but fair Google Play reviewer** who has never
seen it, and a **brand-new user** on a fresh install.

## Method, and its limits — read this first

This audit is a **static** one. Every finding was produced by reading `mobile/lib/`,
`supabase/functions/`, `android/`, the tests, and the store assets, and by running the
build's own checks. That is enough to find claim defects, policy defects and structural
defects with high confidence, and it is what caught every finding below.

It is **not** enough for four classes of problem, and this session could not reach any of
them:

| Not covered | Why | Who must |
|---|---|---|
| Anything requiring a device or emulator | Headless environment, no device attached | Founder |
| A real purchase, restore, cancel or win-back | Play Billing cannot run from a side-loaded build, and no product exists in Play yet | Founder |
| Live Play Console / RevenueCat dashboard state | Not readable from here | Founder |
| Rendered-pixel behaviour at real text scales on real hardware | Widget tests approximate it; they do not replace it | Founder |

**Findings marked 🔵 UNVERIFIED are exactly that.** They are not passes.

**Severity key**

| | Meaning |
|---|---|
| 🔴 **HIGH** | Likely rejection, or a serious compliance/safety issue |
| 🟠 **MEDIUM** | Must fix before production |
| 🟡 **LOW** | Recommended improvement — not a rejection cause on its own |
| 🟢 **PASS** | Checked, no issue found |
| 🔵 **UNVERIFIED** | Cannot be determined without a device or a dashboard |

---

## Summary

| Severity | Count | Of which fixed in this change |
|---|---|---|
| 🔴 HIGH | 5 | 2 partially — the replacement copy exists (R-3, R-4) |
| 🟠 MEDIUM | 8 | 3 (R-7, R-8, R-17) |
| 🟡 LOW | 4 | 1 (R-16) |
| 🔵 UNVERIFIED | 6 | 0 — all need a device or a dashboard |
| 🟢 PASS | 15 | — |

**Verdict: NOT READY TO SUBMIT.** Every 🔴 is in the *listing and legal layer*, not in the
app. The app itself is the strongest part of this submission: the safety architecture, the
monetization honesty and the permission diet would survive a hostile review. What would fail
is the storefront wrapped around it — assets that describe a different product, and a privacy
policy that does not name its own operator.

None of the five HIGH findings requires new engineering. Four are content, one is a
character count.

---

# Part 1 — The Play reviewer pass

---

## 🔴 R-1 · The store assets describe a different, more confident product

**Finding.** All eight files in `ASO-image/PlayStore-ASO/` carry claims the app deliberately
refuses to make. The complete list is in
[`PAWDOC_ASO_PRODUCTION_WORKFLOW.md`](./PAWDOC_ASO_PRODUCTION_WORKFLOW.md) §A.1; the four
that a reviewer would act on:

**Evidence.**

| Asset | Renders | The app |
|---|---|---|
| `001.png`, feature graphic | "Health Score · **92** /100 · **Excellent**" | Refuses this by name — decision **D-2**, `pets/pet_profile_screen.dart:54`: *"A number that reads as a verdict on an animal's health, with nothing behind it, is exactly the reliance the product must not invite."* |
| `003.png` | "Auto-detect: **Skin Issue**" · "**Mild skin irritation detected.** Likely caused by **allergens or moisture**" | Never names a condition or a cause (contract v2) |
| `003.png` | "**AI Confidence 96%**" · "**High accuracy** AI analysis **you can trust**" | `CLAUDE.md`: *"`confidence` is never shown to users."* |
| Feature graphic | "**Trusted by pet parents**" + 4 photorealistic faces + **★★★★★** + "**10K+ Happy Pets**" | Pre-launch. Zero users, zero ratings |
| `001`, `004`, feature graphic | "**All Good!**" · "**Great job!** Buddy is in great shape" · "**All medications up to date!**" | The action ladder has **no "do nothing" rung** and may never render "normal" |

**Why it matters.** Play's Misrepresentation and Deceptive Behavior policies are about
correspondence between claim and product, and the reviewer has the app. A fabricated ★★★★★
with a user count is among the most reliably actioned defects there is. The health claims are
worse than a policy problem: a listing that tells owners their pet is *fine* attacks the one
risk this product is built around.

**Reproduction.** Open `ASO-image/PlayStore-ASO/001.png` at 100%. Install the app, open a
pet profile. The screenshot's number does not exist anywhere in the product.

**Fix.** Regenerate all ten assets from
[`PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html`](./PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html),
then run the Phase D–E pipeline. Do not correct these — the defects are baked into the
concepts.

**Code change:** No · **Console:** Yes (upload) · **Legal copy:** No
**Verification:** the 20-row checklist in the prompt library §19, per asset, at 100% zoom.

---

## 🔴 R-2 · The privacy policy does not name its data controller

**Finding.** The live legal portal still contains unfilled placeholders.

**Evidence.** `scripts/verify-no-placeholders.sh`:

```
web-legal/content/privacy.md:16   **[LEGAL ENTITY]**, **[BUSINESS ADDRESS]**
web-legal/content/terms.md:14     between you and **[LEGAL ENTITY]**
web-legal/content/gdpr.md:18      [EU REPRESENTATIVE — to be appointed]
web-legal/content/ccpa.md:55      [LEGAL ENTITY], [BUSINESS ADDRESS]
web-legal/content/deletion.md:59  [LEGAL ENTITY], [BUSINESS ADDRESS]
web-legal/content/contact.md:29   Service operator: [LEGAL ENTITY]
```

`config/legal_urls.dart:19` points the app at `https://d1klm6zb1x23me.cloudfront.net`, so
these are what a reviewer sees when they tap Privacy on the paywall.

**Why it matters.** A privacy policy that does not identify its controller is not a valid
policy under GDPR, and Play requires a valid, accessible one. Health-related apps must post
a policy detailing how personal and sensitive data is handled. A reviewer who opens the URL
and finds `[LEGAL ENTITY]` has found a defect in ten seconds.

**Fix.** Fill entity name and address, redeploy the portal, re-run the script.

**Code change:** No · **Console:** Yes (URL field) · **Legal copy:** **Yes**
**Verification:** `./scripts/verify-no-placeholders.sh --strict` and open all seven pages.

---

## 🔴 R-3 · The short description cannot be saved

**Finding.** `docs/store_metadata/google_play.md` gives an 80-character-limit short
description that is **144 characters**, and the file's own table asserts "72 ✓".

**Evidence.**

```
> "Your pet's health record, organized — symptom guidance in seconds, an
>  emergency button that works offline, and a vet-visit summary in your hand."
len = 144
```

**Why it matters.** The Console refuses it, so submission stops. The deeper problem is the
stale "72 ✓" — the count was never recomputed after the copy was rewritten, which is how a
listing ends up shipping a claim nobody re-read either.

**Fix.** Use the 72-character replacement in the prompt library §4. **Compute every
character count; never estimate one.**

**Code change:** No (docs) · **Console:** Yes · **Legal copy:** No
**Verification:** paste it into the Console and confirm it saves.

---

## 🔴 R-4 · "Not a medical device" is missing from the description

**Finding.** Play's Health Content & Services policy expects an app that is not a regulated
medical device to carry *"a clear disclaimer in their app description indicating that the app
is 'not a medical device and does not diagnose, treat, cure, or prevent any medical
condition.'"*

**Evidence.** The current description says *"It does not diagnose, does not provide
veterinary medical advice, and is not a substitute for an in-person examination by a licensed
veterinarian."* Strong, but it never says **not a medical device**, and it omits *treat, cure
or prevent*.

**Why it matters.** PawDoc must complete the Health apps declaration, and this is the
declaration's own stated expectation. The wording is nearly free to add.

**Fix.** The replacement description's closing paragraph says it verbatim.

**Code change:** No · **Console:** Yes · **Legal copy:** No
**Verification:** grep the pasted description for "not a medical device".

---

## 🔴 R-5 · No reviewer account exists

**Finding.** PawDoc gates its core behind authentication. `docs/store_metadata/ios_app_store.md:123`
still reads `[REVIEWER_DEMO_EMAIL]` / `[REVIEWER_DEMO_PASSWORD]`, and no Play App-access
instruction set has been written.

**Why it matters.** *"We could not access the app"* is a first-pass rejection. Guest sign-in
mitigates it, but a reviewer who does not notice the "Get started" affordance and tries to
sign in will simply fail.

**Fix.** Create the account, add a pet, run one text check so the timeline is not empty, and
paste the App-access instructions from
[`PAWDOC_GOOGLE_PLAY_PRODUCTION_QUESTIONNAIRE.md`](./PAWDOC_GOOGLE_PLAY_PRODUCTION_QUESTIONNAIRE.md) §1.
Do **not** hand over the `internal_tester` account — its permanent Premium grant hides the
free tier.

**Code change:** No · **Console:** Yes · **Legal copy:** No
**Verification:** sign in with it on a clean device and walk the four steps in the instructions.

---

## 🟠 R-6 · Reporting an AI reply leaves the app

**Finding.** The assistant's per-reply **Report** action opens an external web page.

**Evidence.** `assistant/assistant_screen.dart:523-533`:

```dart
AssistantAction(
  actionKey: const Key('assistant_action_report'),
  label: 'Report', caption: 'Report an issue',
  onTap: () { Navigator.pop(sheetContext); LegalUrls.open(LegalUrls.contact); },
),
```

`LegalUrls.open` launches the browser. The reported reply is not carried, so the user must
describe it from memory.

**Why it matters.** Play's AI-Generated Content policy expects users to be able to flag
offensive AI output **from within the app**. Bouncing to a contact page is a defensible-but-
weak reading, and it is the kind of thing a reviewer probing an AI app tests directly.

**⚠️ Surfaced, deliberately not fixed here.** An honest in-app report needs somewhere for the
report to *go* — a table, RLS, an Edge Function and a deploy, all founder-gated. Half-building
it would produce a control that says "Reported" when nothing was filed, which is precisely
what this codebase refuses to ship (`assistant_screen.dart:73`: *"there is no assistant-message
feedback table, and pretending a rating was filed"* is not acceptable).

**Recommended fix (one sub-PR).** `assistant_reports` table (RLS: insert-own, no select) →
`report-assistant-reply` Edge Function → an in-app sheet that shows the exact reply text
being sent, offers reason chips, files it, and confirms. Until then, the current behaviour is
better than a fake one.

**Code change:** Yes · **Console:** No · **Legal copy:** No
**Verification:** file a report on a device, then read the row back with the service role.

---

## 🟠 R-7 · Three unscoped privacy absolutes in the app — *fixed in this change*

**Finding.** Three surfaces made privacy claims broader than the data flow. The scan that
found them found four *correctly scoped* claims at the same time, which is the point: the
defect is the missing scope, not the strong word.

| Surface | Was | Problem |
|---|---|---|
| `onboarding/onboarding_flow.dart:1121` | *"Your pet's data is safe and private."* / *"**We never sell your data. Ever.**"* | An absolute in the most-read screen in the app. *Not selling* is a fact; *never, ever* is a promise about all future conduct. "Private" full stop is broader than a product that uploads photos to object storage |
| `health_check/health_check_loading_view.dart:254` | *"Your data is private, secure and **never shared**."* | On screen at the exact moment a photo is being uploaded and sent to a model provider. The claim is false where it is displayed |
| `assistant/conversation_history_screen.dart:274` | *"Your pet's data is **never shared**."* | An app-wide absolute standing in front of a feature that sends every message to a model provider |

**Why it matters.** Play's Data safety form is a binding declaration. An in-app sentence that
outruns it puts two incompatible statements on record with Google — and it is the exact
"scope inflation" class the FormAI post-mortem calls the most dangerous: *a true narrow claim
widened into a false broad one because the broad version markets better.*

**Fixed.** All three rewritten to scoped, checkable claims:
*"Your record is yours." / "No ads, and we do not sell your data."*,
*"Encrypted in transit, kept under your account, and not sold."*,
*"Only you can see your conversation history — it is stored under your account. PawDoc does
not sell it."*

**Tripwire added.** `safety_copy_test.dart` → *rule: no privacy claim broader than the data
flow*. It scans the **broad subject**, not the absolute word, so it bans *"your data is never
shared"* while allowing `ai_transparency_screen.dart`'s exemplary *"Your name, your email
address, your location and your account never leave with it"* — and allowing
`community_sections.dart`'s *"Never share someone else's address"*, which is advice to the
user, not a claim by PawDoc. Both of those were false positives on the first run, and both
are why the rule is written the way it is.

**Code change:** Done · **Console:** No · **Legal copy:** Confirm `/privacy` agrees
**Verification:** `flutter test test/safety_copy_test.dart`

---

## 🟠 R-8 · Approximate location is collected, and two comments said otherwise

**Finding.** PawDoc stores a 5-character geohash cell (~4.9 km) in `community_profiles.geohash`
when a user opts into community discovery — `community/community_onboarding_screen.dart:79`.
That is **collected approximate location** and must be declared in Data safety.

Until this change, `walks/location_service.dart` documented *"coordinates are … never sent to
or stored on PawDoc servers"* and `AndroidManifest.xml` said *"coordinates never reach PawDoc
servers"*. Both are true of the **Smart Walks** path and both are silent about the
**community** path, which stores a coarsened derivative.

**Why it matters.** Data safety is binding, and this is exactly how a wrong answer gets
written: an engineer greps for the privacy comment, reads an absolute, and ticks "no
location collected".

**Fixed in this change.** Both comments now state both paths and name the geohash cell
explicitly.

**Still to do (founder):** declare **Approximate location — collected, optional, app
functionality** in Data safety; answer **yes** to the content-rating question about sharing
location with other users; and confirm `/privacy` explains the cell.

**Code change:** Done · **Console:** Yes · **Legal copy:** Verify
**Verification:** the cross-checks in the questionnaire §5.4.

---

## 🟠 R-9 · Nothing in Play is purchasable

**Finding.** No subscription product exists in Play, and no RevenueCat catalogue exists. A
search of the whole repository returns **no product identifier at all**.

**Why it matters.** A reviewer opening the paywall sees *"Premium is not on sale yet."* That
is honest and does not fail review — but the listing must then contain **no** price, trial
or discount claim, and the app currently makes none. The risk is asymmetric: adding a price
to the listing before the SKU is live turns a clean submission into a false offer.

**Fix.** [`REVENUECAT_GOOGLE_PLAY_SUBSCRIPTIONS_HANDBOOK.md`](./REVENUECAT_GOOGLE_PLAY_SUBSCRIPTIONS_HANDBOOK.md)
§§12–13, button by button.

**Code change:** No · **Console:** Yes (both) · **Legal copy:** No
**Verification:** one real purchase and one restore from a Play-downloaded build.

---

## 🟠 R-10 · Closed-testing requirement may gate production by weeks

**Finding.** Personal developer accounts created after 13 November 2023 must run a closed
test with **≥ 12 testers opted in continuously for ≥ 14 days** before production access.

**Why it matters.** It is a calendar dependency, not an engineering one, and it is invisible
until you try to promote. Internal testing — which this project has used — **does not count**.

**Fix.** Founder checks the Play Console dashboard, which shows the requirement and a live
tester count if it applies. If it does, budget three weeks minimum.

**Code change:** No · **Console:** Yes · **Legal copy:** No

---

## 🟠 R-11 · Billing Library 8 and target API 36 are due in 23 days

**Finding.** Both deadlines fall on **31 August 2026**.

**Evidence — both satisfied as configured:**

- `purchases_flutter` 10.4.3 selects the Billing Client 8 variant:
  `missingDimensionStrategy 'billingclient', 'bc8'`.
- `targetSdk = flutter.targetSdkVersion` = **36** in Flutter 3.41.9.

**Why it is still MEDIUM.** Both are transitive facts about a pinned toolchain, and neither
has been confirmed against a merged release build. A `flutter upgrade` or a
`purchases_flutter` downgrade breaks one silently.

**Fix.** Confirm on the release AAB before submitting; do not change either pin without
re-checking.

**Code change:** No · **Console:** No · **Legal copy:** No
**Verification:** inspect the merged dependency tree and the merged manifest of the release build.

---

## 🟠 R-12 · Data safety has two answers that cannot be given from the code

**Finding.** Two rows of the Data safety form are genuinely undetermined:

1. **Device or other IDs** — PostHog's Android SDK may collect a device identifier. Not
   readable from the Dart source; it is an SDK behaviour.
2. **Is sending a photo to Gemini/Anthropic "sharing"?** — turns on whether the current
   provider terms designate them processors and whether either trains on API data.

**Why it matters.** Both are binding answers, and both are the kind that get ticked from
memory.

**Fix.** (1) Inspect the merged manifest and PostHog's current SDK documentation. (2) Read
the provider terms. Answer "not shared" only if both are processors that do not train on the
data.

**Code change:** Possibly (disable device-ID collection) · **Console:** Yes · **Legal copy:** Yes

---

## 🟠 R-17 · The store-copy safety gate was red, and one check demanded a false vet claim — *fixed*

**Finding.** `scripts/verify-phase-2.3.sh` — the gate that guards user-facing store copy —
**had six failing checks and has been red for some time.** It is not wired into CI, so
nothing surfaced it. Three of the six are worth naming.

**Evidence, on `main` before this change:**

```
FAIL  iOS:  BANNED word in visible copy -> "…never a verdict, never a diagnosis."
FAIL  Play: BANNED word in visible copy -> "It does not diagnose, does not provide…"
FAIL  Apple keyword line not found (expected line starting 'symptom,checker')
FAIL  iOS: screenshot 1 caption preserved        ← "Know exactly what your pet needs"
FAIL  iOS: screenshot 3 caption preserved        ← "End 2am anxiety spirals"
FAIL  iOS: screenshot 4 caption preserved        ← "Reviewed by veterinary experts"
FAIL  Apple keyword 'diagnosis' missing
```

**Why it matters — three separate problems, in order of severity:**

1. **A check that demanded a false veterinary claim.** `check "iOS: screenshot 4 caption
   preserved" 'Reviewed by veterinary experts'` **fails the build unless the listing says a
   veterinarian reviews PawDoc.** No veterinarian reviews anything. A verifier that fails
   unless you make a false claim is not a safety gate; it is the defect wearing the gate's
   clothes. Two sibling checks pinned *"Know exactly what your pet needs"* (a certainty
   claim) and *"End 2am anxiety spirals"* (an outcome promise) — all three were copy that had
   been deliberately removed, and the gate was demanding it back.

2. **A substring scan that cannot tell a denial from an assertion.** The rule was
   `grep -i diagnos` over the visible copy, so it flagged the two sentences that exist
   *precisely to disclaim diagnosis*. This directly blocks R-4: Play's Health Content policy
   expects the description to say the app *"does not diagnose, treat, cure, or prevent any
   medical condition"* — wording the old gate forbade.

3. **Two stale assertions** left over from decision I4, which removed `diagnosis` from the
   Apple keyword field because *"bidding on the one word the entire product posture
   disclaims was a store risk and a litigation exhibit."* The gate kept demanding it back.

**Fixed.**

- The banned-word scan now strips **negated** forms (`never a diagnosis`, `does not
  diagnose`, `cannot diagnose`, …) before scanning, so a *claim* still fails and a *denial*
  passes. A `selfcheck_banned_scan` runs on every invocation and asserts **both directions** —
  a rule that only ever passes is not a rule, and this one was just loosened.
- The three caption checks are **inverted**: `Reviewed by veterinary experts`, `vet-approved`
  and `Know exactly what` must now be **absent** from both listings, and the slot *structure*
  is what gets checked.
- The keyword check is **inverted**: the field must claim no diagnosis, cure, treatment or
  prevention — enforcing decision I4 instead of contradicting it.

**Result:** `Verifiable checks GREEN`, `shellcheck` clean.

**Code change:** Done (script) · **Console:** No · **Legal copy:** No
**Verification:** `./scripts/verify-phase-2.3.sh && shellcheck scripts/verify-phase-2.3.sh`

**Recommendation:** add this script to CI. A gate outside CI is a gate that goes red quietly,
which is exactly what happened.

---

## 🟡 R-13 · Three taglines for one product

`"Healthier pets, happier lives."` · `"Smarter care. Happier pets."` ·
`"Healthier pets. Happier lives."` — across four assets. Brand drift is a quality signal, not
a policy matter, and it dies with the asset regeneration.

## 🟡 R-14 · The app icon repeats a known structural failure

`play-sore-logo.png` has **pre-rounded corners with a visible border**, and dark square
corners behind them. Play applies its own rounded mask, so the border clips into four
disconnected arcs and the square corners show through. It is also a photograph of a puppy and
a kitten wrapped in a **stethoscope** — illegible at 48 px, and implying a veterinary service
PawDoc does not operate. The replacement is specified in the prompt library §16.

## 🟡 R-15 · A red cross emblem is used as the emergency glyph

Several assets use a red cross for "Emergency Triage". The red cross is a **protected
emblem** in many jurisdictions, and it additionally reads as a clinic. Banned in the
regenerated prompts.

## 🟡 R-16 · `docs/store_metadata/google_play.md` was a stale second source of truth — *fixed*

It held the 144-character short description (R-3) and lacked the "not a medical device"
sentence (R-4). Both are corrected in place, so the two files now agree: the short
description is 72 characters *computed*, and the closing paragraph is the "WHAT PAWDOC IS
NOT" wording. The old count is called out inline so the mistake is not repeated. A stale
metadata file is how a fixed defect gets re-shipped.

---

## What a reviewer would check, and what they would find

| Reviewer question | Answer | Evidence |
|---|---|---|
| Does the app accurately describe itself? | 🔴 **No** — the *assets* do not; the *description* mostly does | R-1 |
| Are subscriptions clearly disclosed? | 🟢 Yes | Auto-renew disclosure + Terms/Privacy/Subscription links adjacent to every purchase CTA (`_SubscriptionLegal`, `_OfferLegal`) |
| Are prices transparent? | 🟢 Yes — every figure is `StoreProduct.priceString` | `paywall_screen.dart`, `store_offer.dart` |
| Is the billing period obvious? | 🟢 Yes — "Billed monthly" / "Billed yearly" / "Billed weekly" | `_priceNote()` |
| Is auto-renewal obvious? | 🟢 Yes | *"The subscription renews automatically at the standard price until you cancel"* |
| Is cancellation understandable? | 🟢 Yes — stated, plus one tap to the store's own page | Paywall FAQ, `openManageSubscription()` |
| Are trial terms clear? | 🟢 Yes — and only shown when the *store* reports one | `_storeOffersTrial` |
| Are discount terms truthful? | 🟢 Yes — computed from Google's own integers, refused when not computable | `discountPercent`, `savingsBadge` |
| Are countdowns truthful? | 🟢 **There are none, deliberately** | `offer_policy.dart`; a test asserts the offer screen does not mutate over 5 simulated minutes |
| Are medical claims safe? | 🔴 In the app yes; in the assets no | R-1 |
| Are AI capabilities overstated? | 🟢 In the app no — labelled, disclaimed, no confidence shown. 🔴 In the assets yes | R-1 |
| Are veterinarian claims truthful? | 🟢 In the app: none made anywhere. `premium_screens_test.dart` fails the build on "verified veterinarian", "vet chat", "made by vets" | |
| Are privacy claims substantiated? | 🟢 Yes, after this change — three absolutes scoped, and a regression test added | R-7 |
| Does account deletion work? | 🔵 Code path complete and cascade-tested in CI; **never re-verified on a device this cycle** | `delete-account/index.ts`, `scripts/test-rls.sh` |
| Does the privacy policy match the implementation? | 🔴 It does not name its operator | R-2 |
| Does Data safety match the data flows? | 🟠 It can, with §5 of the questionnaire; two rows need external checks | R-8, R-12 |
| Does the app require login appropriately? | 🟢 Yes — and guest sign-in is a real anonymous account, not a local flag | `auth_controller.dart:133` |
| Can the reviewer reach the core experience? | 🔴 Not reliably without credentials | R-5 |
| Does it behave correctly offline? | 🟢 Yes — the emergency path renders with **no ProviderScope and zero network**, and its tests pump it bare | `emergency_router_test.dart:46` |
| Are there dead buttons? | 🟢 No — 12 `AccountUnavailableRow` instances say *"not built"* rather than drawing a decorative control; `AccountToggleRow.onChanged` is non-nullable, so a fake switch is unrepresentable | `account/` |
| Are there placeholder screens? | 🟢 No — `verify-no-placeholders.sh` is a CI gate and reports zero overclaims |  |
| Are there fabricated statistics? | 🔴 In the feature graphic, yes | R-1 |
| Are there fake badges or reviews? | 🔴 In the feature graphic, yes | R-1 |
| Are subscription screens consistent with real Play products? | 🟢 Yes — because there are none, and the app says so | `_PremiumComingSoon` |

---

# Part 2 — The new-user pass

A brand-new user, fresh install, no account. **Steps marked 🔵 could not be executed in this
environment** — they are listed so the founder's device pass has a script, not so this
document can claim they passed.

| # | Step | Result |
|---|---|---|
| 1 | **Onboarding** | 🟢 One page per reference screen, device-walked in a previous cycle. Two dead-ends were found and fixed then: `currentUser!.id` threw before auth, and finishing looped back to the app-open screen |
| 2 | **Account creation** | 🟢 Email, Google, or **guest**. Google's button is hidden entirely when unconfigured — no dead control |
| 3 | **Permissions** | 🟢 Camera at first capture, notifications at first reminder, location only on entering Smart Walks or community. Nothing upfront. Storage and audio are stripped from the merged manifest |
| 4 | **Pet creation** | 🟢 Name + species is enough. A pre-auth draft is held in `PendingPet` and flushed on the first authenticated frame |
| 5 | **First health interaction** | 🟢 Centre "New check" → photo / text / assistant |
| 6 | **AI interaction** | 🟢 Labelled `PawDoc AI`, permanent disclosure strip, allowance counter. 🟠 Report leaves the app (R-6) |
| 7 | **Emergency** | 🟢 **The strongest thing in the product.** A permanent nav destination, offline, model-free, five first-aid guides, maps deep link, tap-to-dial poison control. Never metered, never paywalled — server *and* client |
| 8 | **Health records** | 🟢 Timeline, weight, medications, vaccinations |
| 9 | **Trial activation** | ⛔ **Impossible today.** No trial exists in Play, so no account can ever hold one |
| 10 | **Trial completion state** | ⛔ Unreachable for the same reason. `SubscriberPhase.trialEnded` is built, tested, and inert |
| 11 | **Paywall** | 🟢 Reachable from six surfaces. With no products it shows *"Premium is not on sale yet"* — no CTA, no price, no dead button |
| 12 | **Offer surface** | 🟢 Built and unit-tested; correctly invisible until Play carries a tagged offer |
| 13 | **Purchase** | 🔵 Never performed. Requires a Play-downloaded build and a live product |
| 14 | **Premium entitlement** | 🔵 Two independent paths (webhook + SDK) merge; neither end-to-end tested against a real purchase |
| 15 | **Premium feature access** | 🟢 Exactly four rows change. Enforced server-side, pre-AI |
| 16 | **Restore** | 🔵 Implemented and always reachable; never exercised against a real store account |
| 17 | **Cancellation state** | 🟢 The plan card labels the date by `willRenew` — billing date when it renews, access-end date when it does not. 🔵 Not device-verified |
| 18 | **Win-back eligibility** | 🟢 Correctly refuses `cancelledStillActive` (the entitlement is still owned, so Play will not sell it again). 🔵 Not device-verified |
| 19 | **Community** | 🟢 Opt-in. Connections, 1:1 threads, walk proposals. **No public feed, no comment box** — the reference mockups' "verified veterinarian answering health questions in-feed" was never built, and never will be |
| 20 | **Profile** | 🟢 `ProfileScreen` is the account home. `public.users` is not client-writable, so there is no editable owner profile — and the UI says so rather than drawing a disabled field |
| 21 | **Privacy / security** | 🟢 Real controls only — a control is a real toggle, an un-tappable fact, or a row that says it is not built. `AccountToggleRow.onChanged` is non-nullable, so a decorative switch is unrepresentable. Three copy absolutes fixed in this change (R-7) |
| 22 | **Notifications** | 🟢 Two on-device local notifications at 09:00 local. No push vendor, and the screen does not pretend there is one |
| 23 | **Account deletion** | 🟢 In-app, full cascade, CI-proven. 🔵 Not re-verified on a device this cycle |
| 24 | **Logout** | 🟢 Dissociates RevenueCat, PostHog and — new in this change — clears the offer-prompt history, so one account's dismissals are not charged to the next |
| 25 | **Reinstall + login** | 🔵 Not exercised this cycle |
| 26 | **Subscription state restoration** | 🔵 Not exercised. The DB status is designed to survive a reinstall without a restore tap |

### New-user blockers

| # | Blocker | Severity |
|---|---|---|
| N-1 | Steps 13–17 and 25–26 have **never been executed against a real store** | 🔴 for an IAP release |
| N-2 | The trial the listing narrative implies does not exist (steps 9–10) | 🟠 — an honest gap, not a defect |
| N-3 | Reporting an AI reply leaves the app (step 6) | 🟠 (R-6) |

---

# Part 3 — Monetization safety audit

Each row is a dark pattern this surface would be the natural home for.

| Pattern | Present? | Evidence |
|---|---|---|
| **Fake urgency** | 🟢 **No.** No countdown ships at all | `SubscriptionOption` carries no expiry, so a timer could only count to a moment the app invented. `offer_screen_test.dart` asserts the screen does not mutate over 5 simulated minutes |
| **Fake scarcity** | 🟢 No | Page scan bans "spots left", "places left", "last chance", "limited time only" |
| **Fake personalization** | 🟢 No | `offer_recommendation.dart` runs on three counters the app already reads. A counter that could not be read produces `personalised: false` and a line that says so — it never becomes a zero |
| **Fake authority** | 🟢 No | Phrase scan on every recommendation branch bans "vet-approved", "veterinarian", "reviewed by", "our expert" |
| **Hidden renewal terms** | 🟢 No | Disclosure adjacent to every purchase CTA, asserted present by test |
| **Misleading price comparison** | 🟢 No | `savingsBadge` refuses cross-currency; `discountPercent` refuses cross-currency **and** cross-billing-period. A discounted month against a full year yields no percentage |
| **Misleading discount** | 🟢 No | Computed from `Price.amountMicros`. A free trial is badged "STARTS FREE", never "100% off" |
| **Fake vet endorsement** | 🟢 No | Build fails on the phrase |
| **Fake social proof** | 🟢 In the app. 🔴 In the feature graphic | R-1 |
| **Impossible refund promise** | 🟢 No | *"Refunds are handled by Google Play under Google's refund policy. PawDoc does not operate a separate money-back guarantee."* |
| **Unconfigured product presented as purchasable** | 🟢 No | `findTaggedOffer` → null → the surface does not exist. `_PremiumComingSoon` replaces the CTA |
| **Premium features that do not exist** | 🟢 No | One audited catalogue; four surfaces render it; a page scan fails the build on the reference set's inventions |
| **Endless re-prompting** | 🟢 No | 7-day cooldown, **3 shows ever**, persisted, and **not reset by reopening the surface** |
| **Accidental purchase** | 🟢 No | One CTA, which opens Google's own sheet. "Not now" and Restore sit beside it on every state |
| **Emergency monetised** | 🟢 No | Refused server-side, in `paywall_policy.dart`, and again in `offer_policy.dart` |

**One thing the brief asked for that is deliberately absent.** A limited-time offer with a
real expiration and a countdown. It is not built because it cannot be built honestly with
what Play exposes: `SubscriptionOption` has no expiry field, and the only real end date is
the moment a founder deactivates the offer in the Console — which the device cannot read. The
only honest construction is a server-issued, server-enforced per-account window, and that is
a backend feature nobody has asked for yet.

---

# Part 4 — Exact next actions

### Engineering (small, and none of it blocks on anyone)

| # | Action | Effort |
|---|---|---|
| E-1 | ~~Scope the three privacy absolutes~~ — **done in this change**, with a regression test | done |
| E-2 | ~~Fix the stale Play metadata file~~ — **done**: 72-char short description, "not a medical device" paragraph | done |
| E-2b | Add `scripts/verify-phase-2.3.sh` to CI — it went red unnoticed because nothing runs it | 5 min |
| E-3 | Verify PostHog device-ID collection against the merged manifest | 30 min |
| E-4 | Confirm in-app reporting of a specific AI reply is wanted, then build it (table + EF + sheet) | 1 sub-PR |
| E-5 | Regenerate the ten ASO assets, then run the Phase D–E pipeline | 1 sub-PR + generation time |

### Founder — legal (critical path)

| # | Action |
|---|---|
| F-1 | Fill `[LEGAL ENTITY]` / `[BUSINESS ADDRESS]` across all seven legal pages, redeploy, re-verify |
| F-2 | Appoint the EU (and if targeting the UK, UK) representative, or remove the claim |
| F-3 | Confirm Gemini/Anthropic processor terms before answering Data safety |

### Founder — Play Console

| # | Action |
|---|---|
| F-4 | Create `pawdoc_premium`, three base plans, prices; the three offers with the **exact** tags |
| F-5 | RevenueCat: credentials, products, entitlement `premium`, offering `default`, webhook |
| F-6 | Complete App content: App access, Ads, Content rating, Target audience, Data safety, Health apps, Financial features, Privacy policy, Data deletion |
| F-7 | Tick the AI-generated-content box on every uploaded asset |
| F-8 | Create the reviewer account; add a pet; run one check |
| F-9 | Check whether the 12-testers × 14-days requirement applies |
| F-10 | One real purchase + one restore from a Play-downloaded build; then the 13-row matrix in the handbook §15.3 |

---

## Verification run for this audit

| Check | Result |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **1098 passed** (1039 before this change) |
| `scripts/verify-disclaimers.sh` | ✅ 6/6 PASS — disclaimers are API-injected, payload-driven, UI-gated |
| `scripts/verify-no-placeholders.sh` | ✅ **zero overclaims**; 11 founder-fill placeholders remain (all in legal copy — R-2) |
| Device pass | ❌ Not possible in this environment — **founder-side, and required** |
| Real purchase / restore | ❌ Not possible — **founder-side, and required** |
| Play Console / RevenueCat state | ❌ Not readable — **founder-side** |
