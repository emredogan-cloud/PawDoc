# PawDoc — Product Evolution Masterplan

> **Thesis: PawDoc has engineered a dangerous product into a safe implementation. That effort succeeded on its own terms — and it is still the wrong problem. You cannot engineer a safe way to tell a worried owner their pet is probably fine. The risk is not in the code. It is in the output.**

**Date:** 2026-07-17 · **Basis:** `feat/legal-portal-integration` (= `main` + PR #78), read directly — source, prompts, schema, legal portal, store metadata, roadmap.
**Companion files:** `PRODUCT_FEATURE_MATRIX.md` (Appendix A) · `FOUNDER_STRATEGY_GUIDE.md` (Appendix B)

**Recommendation in one line:** Keep the safety spine, delete the growth scaffolding, and change what the AI *says* — from a verdict about your pet to a record and a plan. Ship a third of what you built.

---

## Executive Summary

The 2026-07-06 audit asked "can we ship this?" and answered *no — fix 6 CRITICALs*. This report asks a different question: **should we ship this shape at all?** Reading the source rather than the reports, the answer is that the launch blockers are the smaller problem. Three structural facts sit underneath them:

**1. All the liability is concentrated in the one output that creates the least value.** PawDoc returns `EMERGENCY | MONITOR | NORMAL`. Two of those tell the user to escalate — they are safe by construction. Only one reduces care-seeking: `NORMAL`, rendered to the user as the hero text **"LIKELY NORMAL"** (`result_screen.dart:84-88`). Every false negative, every lawsuit, every "the app said my dog was fine" review lives in that single enum value. And it is the least valuable output you produce — the user who hears "likely normal" got permission to do nothing, which is what they were going to do anyway. **You are carrying 100% of the product's existential risk to deliver your weakest moment.** No amount of confidence flooring, cross-verification, or temperature tuning fixes this, because it is not an accuracy problem. It is a decision to render verdicts.

**2. "Never paywall an emergency" and "detect emergencies with paid AI vision" cannot both be true at a sustainable cost.** The code already proves it. `quota_gate.mjs` documents the trap in its own comments: an out-of-quota photo *cannot* be blocked before the AI runs, because "a photo/video emergency (pale gums, bloat) can't be detected from text." So `blockBeforeAi()` returns false for every visual request, the full paid pipeline runs, and the result is **thrown away** unless it comes back EMERGENCY. A free user has an unbounded, un-rate-limited path to your Gemini and Anthropic bills (audit BE-01), and there is **no cost telemetry anywhere in the codebase** to see it happening. This is not a bug — it is the honest consequence of an ethical rule colliding with an architecture. You cannot fix it while the AI is the thing that detects emergencies.

**3. Your legal documents describe a more careful product than your app ships — and every gap is an exhibit.** This is the finding that should worry you most, because the legal portal is genuinely well-drafted and that is precisely what makes it dangerous:

| Your document says | Your product does |
|---|---|
| `vet-disclaimer.md:29-35` — PawDoc does not "diagnose your pet or **name a definitive condition**" | `result_screen.dart:269` renders the AI's `differential` under the heading **"Possible causes"**. The frozen contract's own canonical example is `"primary_concern": "Suspected bloat (GDV)"`, `"differential": ["GDV", "ascites"]` |
| `privacy.md:47-48` — analytics and push rely on **"Your consent (Art. 6(1)(a))"**; `:89` — users can **"Opt out of analytics and marketing"** | PostHog fires unconditionally and identifies to the Supabase uid (`main.dart:59-74`); OneSignal initializes at boot (`main.dart:78`). **No consent screen, no opt-out UI, and no age gate exist anywhere in the app.** |
| `ios_app_store.md:34-36` — "diagnosis" "must never appear in the visible description" | The **App Store keyword field bids on `diagnosis`** (`ios_app_store.md:39`), and the file states in writing that it is placed where users cannot see it |

Individually these are compliance gaps. Together they are a pattern, and the pattern has a name in litigation: **knowledge**. A disclaimer that describes a product you don't ship is worse than no disclaimer, because it establishes that you knew the standard and shipped past it anyway. The keyword line is the sharpest example — in discovery, a file that says *"'diagnosis' is included here only, for search — it must never appear in the visible description"* is not a compliance note. It is a confession of intent, written by the defendant, in the repository, with a git blame.

**And one finding no prior audit caught.** On the EMERGENCY screen — red background, "This may be an emergency", a user whose pet may be dying — the app renders two revenue-share affiliate CTAs directly beneath the vet CTA (`emergency_result_screen.dart:98-104`): a telehealth button labelled **"Talk to a vet now — On-demand video consult with a licensed vet"**, and a pet-insurance affiliate. Three problems, escalating: it monetizes panic; it advertises a licensed-vet service with **no partner named anywhere in the repo**; and a video consult is *the wrong action in a real emergency* — a bloating dog needs a car and a hospital, not a webcam. **Your #1 rule is "NEVER paywall an EMERGENCY." You applied it to subscriptions and then sold the emergency to an affiliate.** This is the single highest reputational-risk object in the product and it is nine lines of code to remove.

**What this adds up to.** The engineering is not the problem — it is the reason you can afford to fix this. The safety spine (pre-AI keyword override, disclaimer injection, RLS on 13 tables, presigned uploads, EXIF stripping, degrade-to-MONITOR-never-NORMAL) is real, verified, and stays. What has to go is the *product decision underneath it*: that PawDoc's job is to render a judgment about your animal. Change that one thing and the store risk, the legal risk, the cost structure, the support burden, and the roadmap all resolve together — because they are all downstream of it.

**The recommended product:** free, offline, un-monetized emergency help that never touches the AI; free, unmetered guidance that never says "normal"; and a paid health record that is the actual business. **Acquire on anxiety. Monetize on memory. Never sell the answer to "is my pet dying?"**

**The best news in this report:** the fastest path to the store is the delete key. Removing the referral feature eliminates the audit's CRITICAL account-deletion blocker (RLS-01) — you cannot 500 on a foreign key that doesn't exist. Subtraction clears **1 CRITICAL, 3 HIGHs, and ~10 MEDIUMs without fixing a single one of them.** The reframe is roughly time-neutral to launch and removes an unbounded tail risk.

---

## Current Product Assessment

### What you actually built

| Dimension | Reality |
|---|---|
| Client | 15,222 LOC Dart · **24 screens** · **25 feature modules** · 217 tests |
| AI service | 2,224 LOC Python · 3 providers (Gemini, Anthropic, **OpenAI**) · 186 tests |
| Data | 2,787 LOC SQL · 23 migrations · **13 user tables** · RLS on all |
| Backend | ~13 Edge Functions |
| Infra | **4 clouds** (Supabase, Fly, Cloudflare R2, AWS) + Terraform |
| Vendors | **12** (Supabase, Fly, R2, AWS, Doppler, RevenueCat, OneSignal, PostHog, Sentry, Gemini, Anthropic, OpenAI, Upstash) |
| Roadmap | **1,900 hours** planned; Phases 7–8 (480h) target a proprietary model, B2B API, insurance FNOL |
| Monetization surfaces | **3** — subscription, affiliate revenue-share, consumable PDF credits |
| Users | **Zero** |

That is an enterprise surface area for a pre-launch solo founder. Every vendor is a bill, an outage, a secret to rotate, a Data Safety row, a privacy disclosure, a console to check, and a support ticket. Every screen is a light-mode bug, a text-scale overflow, and a translation. You are carrying the operational cost of a Series-A company against zero revenue and zero learning.

The single most important number above is the last one. **You have built for 18 months against assumptions no user has ever tested.** The false-negative risk is real — but it is not currently your largest risk. Your largest risk is that you never learn anything because nothing ships, and the reason nothing ships is that you keep building surface that has to be secured, tested, localized, disclosed, and reviewed before any of it can be validated.

### What is genuinely excellent — and stays

Be clear that this is not a rebuke of the engineering. The hard, expensive, easy-to-get-wrong things are right:

- **The pre-AI hardcoded emergency override.** 157 keywords, executed before any model call, returning a fixed result at `confidence=1.0`. An emergency is never gated behind a model decision. Byte-identical between `safety.py` and `emergency_keywords.mjs` across all 10 lists. This is excellent design and it *survives the redesign with its role changed.*
- **Server-forced disclaimers.** `pipeline.py:147` does `model_copy(update={"disclaimer_required": True})` on every return path. The UI cannot suppress it. Correct.
- **Degrade never returns NORMAL.** Four distinct fallbacks, all MONITOR, all `confidence=0.0`. Correct instinct, correctly implemented.
- **Security discipline.** Presigned PUT uploads, no R2 keys in the client, real EXIF/GPS stripping (`image_compressor.dart:46-71`), RLS with `USING` + `WITH CHECK` on 13 tables, service_role confined to writes, gitleaks in CI, moderation fails closed.
- **Honesty guardrails that worked.** Fabricated testimonials ("Sarah M.", "★4.8", "Reviewed by veterinary experts") were caught and scrubbed, and a CI regex now blocks their return. `ai-transparency.md:46` — *"we do not publish accuracy percentages we cannot substantiate"* — is exactly right.

**Keep all of it.** The redesign below does not weaken one safety mechanism. It removes the product decision that made all those mechanisms load-bearing in the first place.

### The three contradictions at the center

Everything wrong with PawDoc is one of these three:

**Contradiction 1 — "We don't diagnose" vs. a UI that diagnoses.** The system prompt (`prompts.py:19-49`) says *"You are NOT a veterinarian and you do NOT diagnose"* — and in the same schema demands `"differential": ["most to least likely"]`. A ranked differential *is* the diagnostic act; naming it `differential` is what medicine calls it. The app then renders it under **"Possible causes."** The word "diagnosis" is avoided everywhere while the thing itself is shipped, keyworded, and displayed. **This is the contradiction the whole product is built on, and no disclaimer resolves it.**

**Contradiction 2 — Safety-first ethics vs. safety-first economics.** "Never paywall an emergency" is the right ethic. Implemented against AI-vision emergency detection, it produces an unbounded free inference path with no telemetry. The ethic is not wrong. The architecture that makes it unpayable is.

**Contradiction 3 — A global store listing vs. a bilingual safety spine.** The emergency override has keyword lists for **English and German only** (23 EN / 36 DE global + species lists). Everything else falls back to English (`safety.py:137-143`, and PR #74 made the *UI* fall back to English too). So a French owner typing *"mon chien s'étouffe"* or a Turkish owner typing *"köpeğim boğuluyor"* gets **no pre-AI override at all** — the mechanism you describe as the safety spine simply does not fire. The models will often still catch it, but your #1 guarantee silently degrades to "best-effort model output" for most of the planet, and nothing in the app or the store listing says so. **If you list globally, the safety claim is false for most of your users.** No prior audit caught this.

---

## Risk Assessment

Ordered by expected cost, not by likelihood. For each: what it is, why it exists, and the redesign that removes it — not a mitigation, a removal.

### R1 — "LIKELY NORMAL" · the existential one

**The risk.** One enum value carries the entire false-negative exposure. It is also, behaviorally, the worst thing you can hand an anxious owner: research on health triage consistently finds *false reassurance* is more dangerous than false alarm, because it changes behavior in the harmful direction. Worse — **the reassurance is what users came for.** They will use the app specifically to hear it. The demand is for the one thing you must never sell.

**Why it exists.** The product was conceived as a triage classifier, so it needs a "no action" class.

**The redesign.** Delete the `NORMAL` class from the user-facing product. Replace the three-level verdict with an **action ladder that has no terminal "do nothing" state**:

| Ladder step | Meaning | User sees |
|---|---|---|
| **Get help now** | Emergency indicators present | Red screen, vet + poison control, no AI, no monetization |
| **Call today** | Signs that warrant same-day contact | Timing + what to say |
| **Book a routine visit** | Worth a professional look, not urgent | Timing + what to ask |
| **Watch and re-check** | Not enough signal to act on yet | **What to watch for + a scheduled re-check** — never "it's fine" |

The bottom rung is `Watch and re-check`, not `Likely normal`. The difference is not cosmetic. "Likely normal" *closes* the case; "watch for X, Y, Z and re-check in 24h" *primes escalation* and creates a return visit. Same AI call. Same information. Inverted risk. Better retention.

**What the user actually gets** — strictly more useful than a verdict:

> **What you described** — Rex, 4y Labrador. Limping on the right hind leg since this morning. Eating normally, no yelping.
> **What vets look for with limping** — whether they'll bear weight, swelling or heat in the joint, whether it's worse after rest or after exercise.
> **Call sooner if you see** — no weight-bearing at all · swelling or heat · yelping on touch · worse tomorrow than today.
> **Reasonable timing** — if it's the same or worse in 24h, book a routine appointment.
> ✅ Logged to Rex's timeline · [Add a photo] · [Re-check me in 24h]

The user still gets their answer — *I don't need the ER tonight* — but they **derive** it from the guidance instead of being **told** it. PawDoc never owns the reassurance. That is the entire trick, and it is worth understanding why it is more than a word game: information about a *condition class* ("what vets look for with limping") is educational content; a verdict about *your specific animal* is the thing that looks like practice. The first is defensible. The second is the exposure.

### R2 — Practicing veterinary medicine without a licence

**The risk.** In most jurisdictions, diagnosing an animal is a licensed act, and veterinary practice acts define it broadly. Your own `vet-disclaimer.md:41` correctly identifies that no VCPR exists. But the defense "we're information, not diagnosis" is undercut by your own product: a per-animal, per-symptom **ranked differential** with a **named suspected condition** and a **confidence score**, rendered under "Possible causes," is a diagnostic act in everything but the label. **The disclaimer describes the product you meant to build. The differential is the product you built.**

> ⚠️ I am not your lawyer and this is not legal advice. Treat this as the highest-priority question to put to counsel, phrased exactly as: *"Does rendering a ranked differential and a named suspected condition for a specific animal constitute the practice of veterinary medicine in our launch jurisdictions, and does the disclaimer cure it?"* Ask it **before** you pay for the rest of the review — the answer determines whether the rest matters.

**The redesign.** **Delete the `differential` field from the contract and the "Possible causes" section from the UI.** Ask yourself what it buys the user: knowing "GDV vs. ascites" changes *nothing* an owner can act on — both mean *go now*. The differential carries nearly all of the diagnostic/legal weight and nearly none of the user value. It exists because it looks impressive in a demo. Cut it, and `primary_concern` becomes a plain-language observation ("a swollen, firm belly") instead of a suspected disease ("Suspected bloat (GDV)").

### R3 — Monetizing the emergency screen

**The risk.** Ethical, legal, and reputational at once. You render "This may be an emergency," then offer a revenue-share video-consult button — an action that can **delay physical transport** — plus an insurance affiliate. If a pet dies after an owner took the video consult you promoted and profited from, "we never paywalled the emergency" will not survive the first hour of cross-examination. And the CTA promises *"On-demand video consult with a licensed vet"* with **no partner named in the repo** — an unqualified licensed-vet claim your CI overclaim regex does not catch and your store checklist never mentions.

**The redesign.** **Remove every monetization surface from the emergency path.** No affiliates, no upsell, no insurance, no telehealth, no analytics-driven CTA. The emergency screen contains exactly: what we saw, get to a vet, poison control, and the disclaimer. Nothing else may ever be added to that screen — write it into `CLAUDE.md` as a NEVER rule, next to the paywall rule it was supposed to be covered by. Delete `TelehealthButton` outright; if insurance affiliates return later, they live on the pet profile in calm moments, never on a result.

### R4 — The unbounded AI-cost path

**The risk.** Out-of-quota visual analyses run the full paid pipeline and discard the result (BE-01). No rate limit, no cost telemetry, no per-analysis cost figure anywhere. Worst-case EMERGENCY = **6 sequential model calls** (2× Tier 2 + 2× Tier 3 escalation + 2× cross-verify) at 8s timeouts = up to **48 seconds of provider time** with no end-to-end cap. Your slowest, most expensive path is your emergency path. That is exactly backwards.

**The redesign.** Three moves, each independently worth doing:
1. **Take the AI out of the emergency path entirely** (see R5). Then photos are a *records* feature, and you can rate-limit them freely without ever touching a safety promise. The BE-01 trap dissolves — it was only a trap because vision was load-bearing for safety.
2. **Make the EMERGENCY cross-verify asynchronous.** Today it fires a second full Claude call, **cannot change the outcome** (EMERGENCY is kept regardless; disagreement only flips a boolean nobody displays), and doubles latency on the highest-stakes path. Its only value is telemetry. Return the result immediately, then cross-verify in the background and log. Same signal, zero user-visible latency, half the emergency cost.
3. **Add cost telemetry before you add a rate limit.** You cannot manage what you cannot see, and right now you cannot see a single cent.

### R5 — The emergency promise you cannot keep

**The risk.** The app's reason for existing is catching emergencies — and the emergency path requires connectivity, a healthy Fly machine (a **single 512MB instance**, INF-05), a reachable Gemini, and a correct model. Offline, `analysis_runner.dart` falls to a generic error screen; there is no client-side keyword check (QA-06). **An owner in a dead zone typing "my dog is choking" gets "couldn't analyze."** Worse: an owner who opens PawDoc instead of calling a vet has been *harmed by the app existing* — you inserted latency into an emergency.

**The redesign — the most important structural change in this document.**

> **The emergency feature must not be an AI feature.**

Make it a **red button, permanently on the home screen**, that works offline, instantly, with zero network calls and zero model calls:
- **Nearest emergency vets** — a maps deep link (no location permission needed, see R7)
- **Poison control** — a tap-to-dial number, bundled in the app
- **A bundled first-aid card** — choking, bleeding, seizure, bloat, heatstroke. Static content, written once, reviewed by a vet, shipped in the binary.
- **The 157 keywords move to the client** as a *router*: type something that matches, and you land on the red screen instantly — online or offline, before any network call. The server override stays authoritative for the record.

This is better on every axis simultaneously: **safer** (works offline, zero latency, no model dependency, no single point of failure), **cheaper** (zero marginal cost), **easier to approve** (a directory and a phone number are not a medical claim), **honest** (it does what it says), and it **frees the AI path to be metered** because it is no longer the safety mechanism. It also means the sentence *"if this is an emergency, don't use the app — press this button and drive"* becomes literally true, which is the only defensible thing a pet-triage app can say.

### R6 — Consent, and a privacy policy that describes a different app

**The risk.** This is a live inaccuracy in a published legal document, not a gap. `privacy.md` names **consent (Art. 6(1)(a))** as the legal basis for analytics and push, and promises an opt-out. Neither exists. Under GDPR, if you name consent as your basis and never collect it, **you have no legal basis** for that processing. Promising an opt-out you don't ship is separately a deceptive-practice exposure. `PAWDOC_GO_LIVE_MASTER_PLAN.md:81` claims "PR-13 already wired the checkbox" — **that checkbox does not exist in the current tree.**

Compounding it: **no DPA, no zero-retention, and no no-training terms are referenced for any AI provider anywhere in the repo.** You send pet health data and photographs (which `delete-account/index.ts:9` acknowledges "can contain people/homes") to Google and Anthropic, and nothing documents what they may do with it. If the Gemini key is on a free/consumer tier, **inputs may be used for model training** — which would make `privacy.md` false in a second, more serious way.

**The redesign.**
1. **Ship real consent.** An affirmative Terms/Privacy accept at signup (LEG-03) plus an analytics/crash toggle in Account that actually gates PostHog init. Not a dark pattern — a checkbox and a switch, one day of work.
2. **Verify the AI billing tier today.** Confirm Gemini and Anthropic are on paid tiers with no-training terms, execute the DPAs, and name **OpenAI** in the processor table — it is missing from `privacy.md`, because the journal feature quietly added a third AI provider nobody wrote down. (Or delete the journal and the vendor with it; see the matrix.)
3. **Rewrite the policy to match the app**, then keep them matched with a test. The rule: *the policy documents what ships; it never aspires.*

### R7 — Permission and vendor surface you don't need

Each of these buys little and costs a permission prompt, a Data Safety row, a privacy disclosure, a vendor bill, and a support surface:

| Today | Cost | Redesign |
|---|---|---|
| `ACCESS_FINE_LOCATION` for the vet finder | Permission prompt at the worst moment, Play permissions review, Data Safety row, a geolocator dependency | **Maps deep link.** `maps://?q=emergency+vet+near+me` — the OS handles location, you request **no permission and store no coordinates.** Kills PLAY-03 and a whole privacy category. |
| OneSignal push | A vendor, a device token to disclose, a cron, `users.one_signal_player_id`, and an unfixed **crash-on-exit** when `ONESIGNAL_APP_ID` is unset (QA-03) | **On-device local notifications.** A medication reminder does not need a push server. Works offline, no vendor, no token, no disclosure, no cron, no crash. |
| AWS + CloudFront + Terraform for 15 static legal pages | A 4th cloud, a Terraform codebase with **local-only unlocked state** (INF-03), a **TLSv1.0** floor (INF-06), and an ephemeral hostname as your store privacy URL (REC-04) | **Serve them from the Next.js site in `web/`.** Same content, one host, one deploy, kills three findings and a cloud account. |
| OpenAI `gpt-4o-mini` for weekly AI health journals | A 3rd AI provider, undisclosed in the privacy policy, generating **unprompted health narrative** about a pet nobody asked about | **Delete the feature.** An AI writing health prose no user requested is pure liability with no pull. |

**12 vendors → 7.** Every removal is a Data Safety row you don't fill, a secret you don't rotate, and an outage you don't absorb at 2am.

### R8 — The roadmap escalates liability and calls it a moat

Phases 7–8 (480h) plan: a **proprietary fine-tuned model**, a **B2B API**, **community Q&A**, and **insurance FNOL**. Read as a risk ladder, every rung increases your ownership of the medical judgment:

- **Proprietary model.** Today, when the model is wrong, it is Google's model. Train your own and it is *your* model, your training data, your negligence — while giving up the safety research of two frontier labs. This is a liability transfer *toward* you, sold as a moat.
- **The dataset that feeds it is not clean.** `training_export.py` strips ids and emails via an allowlist but **deliberately retains `symptom_text`** — the exact free-text field where an owner types "my daughter was bitten." Its own header says a scrub pass "is the founder's call." **It is not implemented.**
- **Community Q&A.** UGC moderation for a solo founder is an unbounded, un-delegable, 24/7 operational commitment. It is how solo consumer apps die.
- **Insurance FNOL.** Participating in claims intake is a regulated activity in most jurisdictions and drags you toward licensure you cannot support.

**The redesign.** Cut all four. **Your moat was never the verdict — anyone can call Gemini, including your competitors, today, for a fraction of a cent.** Your moat is the thing only you have: 18 months of *this* dog's weight curve, photos, medications, and vet visits. That data has zero liability, compounds monthly, and creates switching cost that a model never will. **Own the record, not the judgment.**

### R9 — Store-review posture is self-inflicted

You **chose** the maximum-scrutiny position and then wrote copy to survive it:

| Choice | Consequence | Redesign |
|---|---|---|
| **Primary category: Medical** (both stores) | Every review, forever, is a medical review under Apple 1.4.1 and Play's health policy. You invited the scrutiny your copy then fights | **Lifestyle.** Apple's Medical category is oriented to human health; a pet records app is Lifestyle. *Verify against current Apple category guidance before switching — miscategorization is its own rejection risk.* |
| **Keyword field bids on `diagnosis`** | Apple reviews metadata **including keywords**. Bidding on the one word your entire defense denies, in a file that says in writing to hide it from users, is a store risk and a litigation exhibit | **Delete `diagnosis` from the keyword field.** Free. Do it today. |
| **Age: iOS 4+ / Play Everyone; Terms require 18+** | Your store says "fine for a four-year-old"; your Terms say "you must be 18." A reviewer can read both in one sitting | **Reconcile.** Drop Terms to 13+ (16+ where GDPR Art. 8 requires), set the rating to 12+, and add the assent checkbox. A subscription app that shows a dying pet is not 4+. |
| Global availability, EN/DE safety spine | Your safety guarantee doesn't fire for most of the world (Contradiction 3) | **Launch EN/DE markets only.** A store-console setting. Expand a market when its keyword list exists — never before. |

**None of the four costs engineering time. All four are decisions.**

### R10 — The paywall sells three things the plan does not include

**The risk.** This is the most concrete, provable defect in this report, and it is a refund engine, an App Review 3.1.2 problem, and an FTC-shaped problem at once. The paywall's value stack (`paywall_screen.dart:400-406`) promises five things. **Two are not in the tier you buy:**

| Paywall promises | Reality |
|---|---|
| *"Unlimited AI health checks, history, and reminders **for all your pets**"* (`:150`) | `pet_limits.dart:10-14` — free, trial, **and premium** are capped at **2 pets**. Only `family` / `b2b_lite` are unlimited. |
| *"**Family & sitter sharing**"* (`:405`) | `invites.mjs:3-5` — *"Premium ($14.99) is **excluded by design** — upgrading to Family ($24.99) is the upsell that unlocks sharing."* **The plan you just bought cannot invite anyone.** |
| *"Buy a PDF Health Report ($4.99)"* (`generate-pdf-report/index.ts:85`) | **No client code purchases `pdf_report_addon`.** The only purchase call in the app is the annual/monthly package. The app instructs users to buy a product it has no path to sell. |

And the dead ends compound: hitting the 2-pet cap shows *"Upgrade to Family for unlimited pets"* → which pushes a paywall **that offers no Family plan** (`add_pet_flow.dart:31-41`).

**Root cause.** The tier ladder (free → premium → family → b2b_lite) was designed in migrations and Edge Functions; the paywall was written separately and never reconciled to it. Nobody has ever bought anything, so nobody has hit it.

**Why it matters more than it looks.** A user pays $14.99, tries to add a third pet or invite their partner, and discovers they bought the wrong thing. That is a refund, a chargeback, a one-star review, and a support ticket — from your *best* customer, at the moment of highest goodwill. Apple 3.1.2 requires subscription descriptions to accurately state what the purchase includes; a reviewer who buys Premium and taps "invite" finds this in ninety seconds.

**The redesign.** **One plan. One price. Everything included.** The tier ladder exists to serve a segmentation strategy for a business with no customers. Delete `family` and `b2b_lite`; make Premium unlimited pets, unlimited history, sharing included, PDF included. Then the paywall cannot lie, the upsell dead-ends vanish, three tables of tier logic collapse, and the support tickets never happen. **Pricing tiers are a thing you earn with data — not a thing you launch with.**

*(Related: pricing itself is unreconciled across the repo. `$59.99/yr` + `$9.99/mo` hardcoded in the paywall; `$14.99` premium / `$24.99` family / `$19.99` b2b_lite in comments; `$0.33/day` claimed in onboarding before any offering loads; and the remediation playbook flags its own `~$5 vs $4.99` conflict. **No product IDs are defined anywhere in the repo.** Pick one price and put it in one place.)*

### R11 — Support burden is designed in

Predicting the solo founder's inbox from the code, in order of volume:

| Ticket | Cause in code | Designed away by |
|---|---|---|
| "Restore Purchases does nothing" | **It is a literal no-op** (SUB-01) | Fix it. Guaranteed tickets otherwise. |
| "I paid, I'm not premium" | Premium is 100% webhook-dependent, no SDK fallback (SUB-02) | Client entitlement fallback |
| "How do I cancel?" | No manage-subscription link | **One deep link to the store's subscription page.** Removes the single biggest subscription ticket class for one hour of work. |
| "Where are my referral rewards?" | Copy says *"Amazing rewards"* and *"when they subscribe"*; the RPC grants +3 on **claim** (PRD-04) | **Remove referral** |
| "It says 3 checks but I have bonuses" | UI ignores bonus credits + monthly reset (SUB-03) | **Remove metering of the free tier** — no counter, no argument |
| "The AI was wrong about my pet" | Verdicts | **Stop rendering verdicts** |
| "Delete my account" (and it 500s) | RLS-01 | **Remove referral** (kills the FK) |
| "The text is invisible" | 13 forced-dark screens, `themeMode: system` (UX-01) | **Ship dark-only** — one line |

Notice how many are **monetization** tickets, and how many die by deletion rather than by fixing. For a solo founder, every mechanism is a surface. **The quota counter is not a feature; it is a support contract.**

---

## Feature Review

Full decisions with justification for **106 features** are in **`PRODUCT_FEATURE_MATRIX.md`**. The shape:

| Decision | Count | The logic |
|---|---|---|
| **KEEP** | 30 | The safety spine, the security posture, the record, auth — the things that already work |
| **REPLACE** | 26 | Right need, wrong mechanism — the verdict, the emergency flow, the vet finder, push, the tier ladder |
| **REMOVE** | 23 | Built before there was anything to grow, or actively harmful |
| **SIMPLIFY** | 16 | Right idea, too much machinery — reminders, moderation, onboarding, legal hosting |
| **ADD** | 8 | The record features that were never finished, plus consent and retention |
| **DON'T BUILD** | 3 | Correctly absent (voice, gallery picker, ads) — flagged so a future roadmap doesn't "fix" them |

**The three that matter most:**

1. **REPLACE — the triage verdict.** `EMERGENCY | MONITOR | NORMAL` + differential + confidence → an action ladder with no "do nothing" rung, plain-language observation, and no named condition. *This is the whole redesign; everything else is consequence.*
2. **REPLACE — the emergency flow.** AI-driven red screen → offline red button (directory + dialer + first-aid card), zero AI, zero monetization, works in a dead zone.
3. **REMOVE — the growth scaffolding.** Referral, family sharing, video, journals, A/B experiments, affiliates, B2B/sitter mode, PDF credits, re-engagement push. All built for scale you do not have, all carrying findings, cost, and support burden today.

### The feature you already built and buried

`mobile/lib/src/export/health_report.dart` builds a clean Markdown health report — pet basics, recent history, recent events — with the footer *"share with your veterinarian."* Pure, unit-tested, ~100 lines, no dependencies.

**This is the highest-value, lowest-risk feature in the entire codebase, and it is a share-sheet action buried in an overflow menu.** It has zero liability (it reports what the user logged), it is the reason someone pays you, it is the thing a vet actually wants, and it is the only thing in the product a competitor cannot rebuild in a weekend with an API key.

**Make it the product.** Not a share action — the **destination**: a Vet Visit Prep Pack you open before every appointment. That single promotion is most of the business.

### The tell: your record features are half-built and invisible

If you want one piece of evidence that PawDoc has been optimizing the wrong axis, it is this — the growth features are *finished and dead*, while the record features are *unfinished and hidden*:

| Record feature | State |
|---|---|
| **Weight tracking** | Logged as a health event with `metadata: {'weight_kg': kg}` — and **the metadata is never read back anywhere.** It renders as a generic timeline row. **No chart. No trend. No history view.** The single most useful longitudinal signal for a pet is write-only. |
| **`sex`, `weight_kg`, `photo_url`, `medical_notes`** | In the model. In the database. **Editable in no screen.** `health_report.dart:28-29` *reads* `sex` and `weight_kg` for the vet report — fields the user has no way to fill in. |
| **Pet photo** | No picker exists. `pet_form_screen.dart`: *"A real photo picker is separate — see report."* |
| **Vaccinations / medications** | A free-text note under an event type. No vaccine name, no due date, no dose, no schedule, no adherence. |
| **Reminders** | Delete only — **no edit**. Time-of-day is collected but `_formatTime()` always renders `''`, so it never displays. A "Tip: enable notifications" card has an **"Enable now" button whose handler is an explicit no-op.** |

Meanwhile: the referral flow has a gift-open celebration animation, five social share buttons, and server-side fraud invariants with row-level locking. The A/B framework has deterministic bucketing across devices. The family-sharing model has a `SECURITY DEFINER` function to avoid RLS recursion.

**You built beautiful machinery for the growth loop of a product with no users, and left the weight chart unbuilt.** The vet report reads two fields the user cannot enter. That is the whole strategic error in one line of code — and the fix is not more building. It is pointing the same care at the other half.

---

## Product Evolution Strategy

### The reframe

| | From | To |
|---|---|---|
| **Job** | Tell me if my pet is OK | Help me notice, decide, remember, and explain |
| **Output** | A verdict about my animal | A record + a plan |
| **AI role** | Judge | **Observer and scribe** |
| **Emergency** | An AI feature | A phone number |
| **Free tier** | 3 metered verdicts | Unlimited guidance + the red button |
| **Paid tier** | More verdicts | The record |
| **Moat** | The model | **The history** |
| **Category** | Medical | Lifestyle |
| **Liability** | We told you it was fine | We wrote down what you saw |

### Three surfaces, one rule each

**🔴 RED — Get help now.** *Free. Offline. No AI. Never monetized.*
Permanent on home. Emergency vets, poison control, first-aid card. Keywords route here client-side, instantly. **Rule: nothing may ever be added to this screen.**

**🟡 AMBER — Something's off.** *Free. Unlimited. Cheap text model.*
Describe it → structured log entry + what vets look for + what to watch + when to call + a re-check reminder. **Rule: it never says "normal," never names a condition, never terminates without an action and a timeframe.**

**🔵 BLUE — The record.** *Paid. This is the business.*
Timeline, photo progression, reminders, vaccinations, medications, weight, **Vet Visit Prep Pack**, export. **Rule: it stores and organizes; it never judges.**

**Free = safety. Paid = memory.** Note what this makes structurally impossible: you *cannot* paywall an emergency, because the emergency path has no AI, no meter, and no purchase. The rule stops being a discipline you enforce and becomes a fact of the architecture. That is what a good design does with a hard rule.

### Photo: from diagnosis to progression

Same capture UX, same pixels, inverted risk. The AI **describes** ("a raised, dark, roughly 1cm lesion on the left flank") and **never judges** — no "benign," no "probably fine." It goes in the record. Then:

> *"Vets care most about **change** — size, colour, bleeding. Re-photograph in 7 days and we'll show you both side by side."*

That is a retention loop, a subscription justification, a genuinely better clinical artifact (a vet would rather see two photos a week apart than one photo and an AI's opinion), and it is **zero-liability because it never reassures.** Photo Progression replaces Photo Diagnosis: better product, lower risk, meterable cost.

### Why this is more useful, not just safer

The honest test: does the safe product still solve a real problem?

Owners are mostly *not* bad at knowing when something is an emergency — when they truly can't tell, they call. What they are genuinely bad at, every single time:
- "When exactly did the limping start?" — *nobody remembers*
- "Is this lump bigger than last month?" — *no baseline*
- "What did the last vet say about the medication?" — *lost*
- "What was I going to ask?" — *forgotten in the room*
- "Which vaccine is due?" — *unknown*

**Every one of those has zero liability and no good solution today.** The prep pack answers all five. That is the product. The triage verdict was never solving the real problem — it was solving the *emotional* one, at 2am, at maximum legal exposure, for free, and then trying to charge for it.

### The honest trade-off

**The safe product is a worse pitch.** "AI tells you if it's an emergency" demos better than "AI helps you log symptoms and prep for the vet." Anyone who says the reframe costs nothing is selling you something. It costs conversion.

But look at what it buys:
- Fear converts **faster** — and churns the moment the pet is better. Episodic value, episodic subscription.
- The record converts **slower** — and compounds. Your data is in there. Switching cost grows monthly.

**For a subscription business, retention beats conversion.** The reframe likely wins on LTV even while losing on conversion rate. And the resolution is not either/or: **the worried moment is your acquisition trigger — that's when they download. The record is what you sell.** Use the fear to acquire. Never charge for it.

---

## Phased Roadmap

Sequenced by dependency, not ambition. **Phases 1 and 3 run in parallel** — Phase 3 is founder wall-clock (attorney, DNS, store accounts) and must start day one.

### Phase 0 — Decide · ~1 week · founder only · blocks everything

No code. Four decisions and one phone call that determine whether the rest of the plan is even the right plan.

| # | Decision | Why it gates everything |
|---|---|---|
| 0.1 | **Verdict → guidance?** Do we delete `NORMAL` and the differential? | Everything below assumes yes. If no, stop reading — you're building the current product and should fix the 6 CRITICALs instead. |
| 0.2 | **Category → Lifestyle? Keyword `diagnosis` → deleted? Markets → EN/DE?** | Free. Decisions, not work. |
| 0.3 | **Jurisdiction.** `terms.md:65` is `[GOVERNING LAW / JURISDICTION]` | Counsel cannot start without it. It is the first question they'll ask. |
| 0.4 | **Name.** Keep "PawDoc"? | See below. |
| 0.5 | **Call the E&O broker. Get two quotes.** | **The cheapest, highest-signal thing in this document.** |

**On 0.5 — do this first, this week.** Ask one broker for two quotes: (a) *"AI-powered pet health triage — the app tells owners whether their pet needs a vet,"* and (b) *"pet health record keeping and vet-visit preparation, with AI-assisted symptom logging."* The delta is the insurance market pricing your risk with real money. If (a) is expensive, exclusion-riddled, or declined — **that is the market telling you this report is right**, in a language no consultant can fake. If they're close, you have new information and should weigh it. Either way it costs a phone call and it prices your biggest unknown.

**On 0.4 — the name.** "Doc" is a claim, and your entire legal defense is that you are not one. But: it is survivable **if the product changes**. `PawDoc` + Medical + `diagnosis` keyword + "LIKELY NORMAL" is a pattern-match to a medical app. `PawDoc` + Lifestyle + records + no verdicts is a cute name on a records app. **Recommendation: keep the name, fix the frame.** Worth one honest note, though — `pawdoc.app` is dead and unregistered, you have no listings and no users, so **renaming will never again be as cheap as it is this week.** If you've ever had doubts, this is the moment. Otherwise keep it and move on.

### Phase 1 — Subtract · ~1–2 weeks · agent-executable

**Delete first. It's faster than fixing, and it clears a CRITICAL for free.**

| Step | Action | Findings eliminated |
|---|---|---|
| 1.1 | **Remove referral** — screen, RPC, `referrals` table, `users.referred_by_user_id`, `bonus_analyses`, portal page | **RLS-01 (CRITICAL)** · PRD-01 (HIGH) · PRD-04 · UX-04 · part of REC-03 |
| 1.2 | **Remove family sharing** — groups, members, invites, tokens, accept flow, 3 screens, 2 Edge Functions | Invite-token surface · retroactive-history exposure · part of QA-01 |
| 1.3 | **Remove the affiliates from emergency + result screens.** Delete `TelehealthButton` | **The R3 reputational risk** · the unqualified licensed-vet claim |
| 1.4 | **Remove video** — capture screen, keyframes, video model path | Halves AI cost · removes 5× moderation per analysis |
| 1.5 | **Remove journals** (+ the OpenAI vendor), A/B experiments, re-engagement push, B2B-lite/sitter mode, PDF credits, semantic cache, training export | PRD-05 · a vendor · an undisclosed processor · an unscrubbed-PII export |
| 1.6 | **Ship dark-only** (`themeMode: ThemeMode.dark`) | **UX-01 (HIGH)** — one line |
| 1.7 | **Replace vet finder with a maps deep link**; drop `geolocator` + both location permissions | **PLAY-03** · a permission · a Data Safety category |
| 1.8 | **Replace OneSignal with local notifications** | **QA-03** · a vendor · a token disclosure · a cron |
| 1.9 | **Fold the legal portal into `web/`**; delete the AWS + Terraform stack | INF-03 · INF-06 · REC-04 · a cloud |
| 1.10 | **Bundle fonts**, `allowRuntimeFetching = false` | ENG-01 · PERF-03 · an unconsented third-party call |

**Result: ~1 CRITICAL + 3 HIGH + ~10 MEDIUM/LOW gone. Not fixed — gone.** Plus 5 tables, ~6 screens, 5 Edge Functions, 3 vendors, and a cloud.

### Phase 2 — Reframe · ~2 weeks · agent-executable

| Step | Action |
|---|---|
| 2.1 | **New contract.** Drop `NORMAL` and `differential`. `triage_level` → `action` (`GET_HELP_NOW \| CALL_TODAY \| BOOK_VISIT \| WATCH_AND_RECHECK`). Keep `confidence` **internal only** — never rendered (it already isn't). Update Dart/Python/TS together — the contract is frozen across three languages. |
| 2.2 | **New prompt.** Observer, not judge. Describe, never conclude. Never name a condition. Never a "no action" outcome. |
| 2.3 | **The red button.** Home screen. Offline. Maps link + poison control dialer + bundled first-aid card. Move the 157 keywords client-side as a router. |
| 2.4 | **New result screen.** What you described · what vets look for · what to watch · reasonable timing · logged ✅ · re-check reminder. |
| 2.5 | **Cross-verify → async.** Return immediately, verify in the background, log. Halves emergency latency and cost, changes no outcome. |
| 2.6 | **Consent + assent.** Terms/Privacy accept at signup; analytics toggle that actually gates PostHog. Rewrite `privacy.md` to match what ships. |
| 2.7 | **Fix the honesty gap.** Kill *"Never wonder if your pet needs the vet again."* Add `mobile/lib` to the CI overclaim guard's `ROOTS` — **it currently scans only `docs/store_metadata docs/legal web/app`, which is exactly why that headline survived.** |
| 2.8 | **Gemini `system_instruction`.** Today `providers.py:68-72` concatenates the system prompt, pet context, and **owner free text** into one string on your primary tier — no role separation, 4,000 chars of user-controlled input sitting next to your safety contract. Low likelihood (the attacker is the victim), trivial to fix, and it's the safety-critical path. |
| 2.9 | **Cost telemetry.** Log per-analysis provider cost. Then rate-limit photos — now safe to do, because vision is no longer a safety mechanism. |

### Phase 3 — Founder gates · parallel with 1–2 · 2–4 weeks wall-clock

Unchanged from `PAWDOC_FOUNDER_ACTION_PLAN.md`, minus what subtraction killed. **Start day one** — these are wall-clock, not effort.

Keystore + Play App Signing · domain + DSAR mailbox with MX · legal entity + controller identity + EU rep · **attorney (ask the R2 question first)** · **verify Gemini/Anthropic paid tier + no-training + DPA** · iOS entitlements + `pawdoc://` scheme · Data Safety (now a much smaller form) · RevenueCat offerings + demo account · **E&O** · merge PR #78 · **R2 retention policy — currently there is no TTL, no lifecycle rule, and photos of people and homes are kept forever against an unresolved "store permanently vs. GDPR erasure" conflict in your own schema comments.**

### Phase 4 — Ship · closed beta

**Android, EN/DE markets, 50 users.** Gate: a scripted device pass on a **release-signed** build (QA-01 — every prior "validated" build was debug-signed and can never ship). iOS follows once entitlements are verified on a physical device — **iOS has never been run at all** (REC-02).

**What you're measuring:** not conversion. *Does anyone open it twice?* Retention is the only thing a records product must prove, and it is the one thing you cannot learn from any amount of further building.

### Phase 5 — Build the actual product · post-launch

Promote the health report to **Vet Visit Prep Pack** as a first-class destination. Photo progression timelines. Re-check reminders. Weight curves. Pre-appointment "what to ask."

### Phase 6 — Monetize the record

Paywall the *record*, never the guidance. Annual-first. See `FOUNDER_STRATEGY_GUIDE.md`.

### Phase 7 — Earn it back

Re-add **only** what data justifies, in this order: family sharing (if households ask), referral (only once you have retention worth amplifying — referring people to a leaky bucket is how you burn your network), video (if photos prove insufficient), insurance affiliates (calm surfaces only, never a result screen).

**Permanently cut:** proprietary model, B2B API, community Q&A, insurance FNOL. If PawDoc succeeds, revisit with a team and a lawyer. Not before, and not solo.

### Effort reality

| Phase | Effort | Owner |
|---|---|---|
| 0 — Decide | ~1 week | Founder |
| 1 — Subtract | 1–2 weeks | Agent |
| 2 — Reframe | ~2 weeks | Agent |
| 3 — Founder gates | 2–4 weeks wall-clock ‖ | Founder + attorney |
| 4 — Ship | 1 week | Both |
| **To beta** | **~6–8 weeks** | |

The June audit put the current product at ~5–8 weeks out. **The reframe is roughly time-neutral** — Phase 1 deletes faster than the old plan fixes, and Phase 2's cost is offset by the findings that die in Phase 1. You are not trading months for safety. **You are trading roughly two weeks for the removal of an unbounded tail risk, and getting a better product out of it.** That is the most favorable trade in this document, and it is the reason to do it now rather than "after launch" — after launch, the contract is frozen by users, the store listing is public, and the reframe costs ten times as much.

---

## Final Recommended Product Vision

> ### PawDoc — the health record your vet actually wants to see.
>
> **Free, forever:** a red button that gets you to help — offline, instantly, no AI, never monetized. Unlimited symptom guidance that tells you what to watch for and when to call, and never tells you your pet is fine.
>
> **Premium:** every pet, every symptom, every photo, every medication, every visit — in one timeline, with a vet-ready summary in your hand before you walk into the room.
>
> **We never diagnose. We never reassure. We help you notice, decide, remember, and explain.**

**Five rules, permanent, written into `CLAUDE.md`:**

1. **Never say "normal."** No output terminates without an action and a timeframe.
2. **Never name a condition.** Describe what is observed. The vet names things.
3. **The emergency path has no AI, no meter, and no monetization.** Nothing may ever be added to that screen.
4. **Free is safety. Paid is memory.** Never charge for the answer to "is my pet dying?"
5. **The documents describe what ships.** Never what we meant to build.

**What this looks like at scale.** ~6 screens. ~7 vendors. 1 free tier with no counter to argue about. 1 subscription with one price. Zero UGC. Zero affiliates on a result. A record that gets more valuable every month and more expensive to leave. An AI bill that scales with revenue instead of against it. A store listing that reviews as Lifestyle. And a product where the honest sentence — *"if this is an emergency, don't use the app; press the red button and drive"* — is literally true.

**Why the record is the right bet.** It is the only asset in this product a competitor cannot replicate. Gemini is an API key. The safety spine is 600 lines anyone can copy. But 18 months of *this* dog's weight, photos, meds, and visits exists in exactly one place, took the user 18 months to create, and is unbearable to abandon. It carries zero liability, compounds monthly, and — this is the part that matters most — **it is the substrate for every ambitious thing you might do later.** Telehealth needs a record. Insurance needs a record. B2B needs a record. A proprietary model needs a record. **The record is the foundation of all of them. The verdict is the foundation of none of them.**

You are not choosing the small version of PawDoc. You are choosing the only version that can become the big one.

---

## The Final Question

> **"If you were founding PawDoc today, what would you build differently to maximize long-term success while minimizing operational, legal, and product risk?"**

**Eight things. Honestly.**

**1. I would never ship "LIKELY NORMAL."** Not a softened version. Not a lower-confidence version. Not one behind a better disclaimer. The one output that closes the case is the one that kills the company, and it is the least valuable thing you produce. Every other decision here follows from that one.

**2. I would not put AI in the emergency path.** The emergency feature is a red button, a phone number, and a first-aid card that works in a dead zone with a dead server. The moment I made "detect the emergency" an AI job, I made my safety promise depend on connectivity, a 512MB Fly machine, and a model having a good day — and I made it structurally impossible to meter. A phone number has none of those failure modes.

**3. I would meter memory, not safety.** The current design charges for verdicts, which means it charges for medical opinions — the worst thing to attach a price to, on every axis: store review, plaintiff's exhibit, refund request, and App Review's oldest instinct. Free guidance, paid record. Then "never paywall an emergency" stops being a rule you enforce and becomes a thing the architecture cannot do.

**4. I would cut the differential on day one.** "GDV vs. ascites" changes nothing an owner can do. It carries nearly all the diagnostic weight and nearly none of the value, and it exists because it demos well. **It is the single most attackable object in the product, sitting under a heading that says "Possible causes," directly contradicting your own published disclaimer.**

**5. I would have shipped six months ago with a fifth of this.** 15,000 lines, 24 screens, 25 modules, 13 tables, 12 vendors, 4 clouds, a 1,900-hour roadmap, 64 open findings — and **zero users**. Every month of that was a month of compounding on assumptions nobody tested. The false-negative risk is real, but right now your bigger risk is that you have built a company-sized surface area around a hypothesis. **Referral, family sharing, B2B mode, journals, A/B tests, and affiliate revenue are all scaffolding for scale you do not have — and one of them (referral) contains the CRITICAL blocker that stops you shipping.** You are being blocked from launch by a growth feature you have no users to grow.

**6. I would own the record, not the judgment.** The roadmap's endgame — proprietary model, B2B API, community, insurance FNOL — is a liability escalation ladder wearing a moat costume. Every rung moves the medical judgment further onto your balance sheet, and the top rung hands you the negligence Google currently absorbs. Meanwhile the real moat was sitting in `export/health_report.dart` the whole time — **already built, unit-tested, ~100 lines, and buried behind a share sheet.**

**7. I would keep every safety mechanism and change what they protect.** Nothing in this report weakens the override, the disclaimer injection, the RLS, the fail-closed moderation, or degrade-never-NORMAL. That work is excellent and it is exactly why you can afford to subtract now. **You built a vault. My argument is only about what you decided to put in it.**

**8. And I would take one hard look at the sentence I wrote in my own repository.** `ios_app_store.md:34-36`: *"'diagnosis' is included **here only**, for search — it must never appear in the visible description, subtitle, or screenshots."*

That sentence is the whole report in miniature. It knows exactly where the line is. It knows the product is on the wrong side of it. And it resolves that not by moving the product — but by moving the claim to where users can't see it. **You already know. The team that wrote the world's most careful pre-AI emergency override is the same team that bid on `diagnosis` in a hidden field.** That is not a compliance defect. It is a product that has been quietly fighting its own conscience for eighteen months, and it will keep fighting until the product stops being the thing the disclaimer keeps apologizing for.

**Stop apologizing for the product. Change the product. Then the disclaimer is just true — and you can stop writing reports like this one.**

---

*Prepared 2026-07-17 against `feat/legal-portal-integration`. Read from source: prompts (`prompts.py`), contract (`ANALYSIS_RESULT.md`), result UI (`result_screen.dart`, `emergency_result_screen.dart`), quota (`quota_gate.mjs`), schema (23 migrations), legal portal (15 pages), store metadata, and the decomposed roadmap. This is product and risk strategy, not legal advice — R2, R6, and the age/jurisdiction items belong in front of counsel, and R2 belongs there first.*
