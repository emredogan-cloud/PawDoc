# Appendix B — PawDoc Founder Strategy Guide

**For:** a solo founder with AI agents, an unlaunched product, and a decision to make.
**Companion to:** `PAWDOC_PRODUCT_EVOLUTION_MASTERPLAN.md` (the argument) · `PRODUCT_FEATURE_MATRIX.md` (the decisions).
**This file is the practical one.** What to do, in what order, starting Monday.

---

## 0. This week — five decisions and one phone call

Everything downstream is blocked on these. None of them are code. **Do 0.1 first — it's a phone call and it prices your biggest unknown with someone else's money.**

### 0.1 · Call an insurance broker. Ask for two quotes. ☎️

Ask one broker to price two products:

> **(a)** *"AI-powered pet health triage — the app tells pet owners whether their pet needs a veterinarian."*
> **(b)** *"Pet health record-keeping and vet-visit preparation, with AI-assisted symptom logging. The app never tells owners their pet is fine and never names a condition."*

**Why this is the highest-value hour in this document:** the E&O market prices product liability for a living, with real money, and it has no opinion about your feelings. If (a) comes back expensive, exclusion-riddled, or declined — **the market has just told you this report is correct**, in a language no consultant can fake and no founder can rationalize. If they price the same, you've learned something real and should weigh this report more skeptically. Either way, `PAWDOC_FOUNDER_ACTION_PLAN.md` already lists E&O as a long-lead critical-path item. You have to make the call anyway. **Make it ask a question.**

### 0.2 · The product decision

**Do we delete `NORMAL` and the differential?** Everything in these three documents assumes yes. If your answer is no, stop reading — you're building the current product, and the right move is the old plan: fix the 6 CRITICALs and ship. That's a legitimate choice. It is not the one I'd make, and §7 explains what I think it costs.

### 0.3 · The free decisions

Zero engineering. Do them this week regardless of 0.2:

- [ ] **Delete `diagnosis` from the iOS keyword field** (`ios_app_store.md:39`). Free. Today.
- [ ] **Category: Medical → Lifestyle** (both stores). *Verify against current Apple category guidance first.*
- [ ] **Markets: EN/DE only** (arguably EN-only — you have 13 localized strings). A store-console setting.
- [ ] **Age: reconcile.** Terms say 18+; the stores say 4+/Everyone. Pick 12+ and drop Terms to 13+ (16+ where GDPR Art. 8 applies).

### 0.4 · Jurisdiction

`terms.md:65` is literally `[GOVERNING LAW / JURISDICTION]`. **Counsel cannot start without it** — it's their first question, and it gates the liability cap, the arbitration clause, and the EU/UK withdrawal wording. Pick where the entity lives.

### 0.5 · The name

**Recommendation: keep "PawDoc." Fix the frame instead.** `PawDoc` + Medical + `diagnosis` keyword + "LIKELY NORMAL" pattern-matches to a medical app. `PawDoc` + Lifestyle + records + no verdicts is a cute name on a records app. The name is only a liability *in combination with* the product.

One honest note and then I'll drop it: `pawdoc.app` is dead and unregistered, you have no listings, no users, and no brand equity. **Renaming will never again be as cheap as it is this week.** If you've had doubts, this is the moment. Otherwise keep it and stop thinking about it.

---

## 1. Launch strategy

### The sequence

```
Week 1     Decide (§0) ─────────────────────────┐
Weeks 1-2  Subtract  ────────────┐              │  Founder track runs
Weeks 3-4  Reframe   ────────────┤              │  in PARALLEL from day 1
Weeks 2-5  ┌─ Attorney ──────────┤              │  (wall-clock, not effort)
           ├─ Domain + mailbox ──┤              │
           ├─ Keystore ──────────┤              │
           └─ E&O ───────────────┘              │
Week 5     Device pass on a RELEASE-SIGNED build │
Week 6     Closed beta — Android, EN, 50 users ──┘
```

**~6–8 weeks to beta.** The June audit put the *current* product at 5–8 weeks. **The reframe is roughly time-neutral** — subtraction deletes faster than the old plan fixes, and Phase 2's cost is offset by the findings that die in Phase 1. You are not trading months for safety. **You are trading ~2 weeks for the removal of an unbounded tail risk**, and getting a better product out of it.

### Start the founder track on day one

These are **wall-clock, not effort** — they finish when other people finish them:

| Item | Lead time | Blocked by |
|---|---|---|
| **Attorney** — ask the R2 question **first** (below) | Weeks | Jurisdiction (§0.4) |
| **E&O insurance** | Weeks | §0.1 |
| **Domain + DSAR mailbox with an MX record** | Days–week | Nothing. Do it now. |
| **Legal entity → controller identity → EU rep** | Weeks | Nothing. Do it now. |
| **Upload keystore + Play App Signing** | Hours | Play account (D-U-N-S can take days) |
| **iOS entitlements + `pawdoc://` scheme** | Hours | Apple account |
| **Verify Gemini/Anthropic paid tier + no-training + DPA** | Hours | **Do this week — see §6** |
| **R2 retention policy** | Hours | A decision only you can make |

**The first question for your attorney**, before you pay for a full review:

> *"Our app shows pet owners a ranked list of possible conditions and a named suspected condition for their specific animal, with an urgency recommendation. Does that constitute the practice of veterinary medicine in [jurisdiction], and does a disclaimer cure it? If we removed the condition names and only described what was observed plus when to call a vet, does the answer change?"*

That single question is worth more than the rest of the review, because **the answer determines whether the rest of the review matters.** If the answer is "the differential is the problem," you've saved yourself the entire argument and can point at counsel instead of at me.

### Ship Android + EN first

Not because Android is better — because **iOS has literally never been run.** No entitlements file, no URL scheme, no device pass, ever. Android is where every hour of your validation went. Fix iOS properly on its own timeline; don't gate the beta on a platform you've never booted.

### The gate before beta

**One scripted device pass on a release-signed build.** Not the debug-signed one. Every "device-validated / beta-ready / ENGINEERING GO" verdict in this repo's history was produced on a build that **can never ship**, which means none of that validation transfers. Re-run it on the artifact that will actually go to Play:

- [ ] Premium purchase completes and unlocks (never once tested on a device)
- [ ] Restore Purchases works (it is currently a no-op)
- [ ] Delete account succeeds — for a plain user *and* a user with history
- [ ] Capture → real AI result → saved to the timeline
- [ ] Red button works **in airplane mode**
- [ ] An emergency-keyword text at **0 quota** is free, uncounted, unpaywalled
- [ ] Cold launch in airplane mode renders correct fonts

### What the beta measures

**Not conversion.** With 50 users, conversion is noise.

> **The only question: does anyone open it twice?**

Retention is the only thing a records product must prove, and it is the one thing no further building can tell you. If week-4 retention is dead, no paywall optimization saves you and you've learned that for the price of six weeks instead of a year. If people come back, you have a business and everything else is tuning.

Secondary: how many say *"Wasn't accurate"* in the follow-up chip — your only outcome signal (§4).

---

## 2. Monetization strategy

### The thesis

> **Acquire on anxiety. Monetize on memory. Never charge for the answer to "is my pet dying?"**

The worried 2am moment is your **acquisition** trigger — that's when someone downloads. It is a terrible thing to **sell**. Charging for medical opinions is the worst price tag in consumer software: it's what App Review's instincts are tuned for, it's what a plaintiff's lawyer opens with (*"they charged $9.99 for the advice that killed my dog"*), and it's what generates the refund.

So: **free is safety, paid is memory.** Note what that makes structurally impossible — you *cannot* paywall an emergency, because the emergency path has no AI, no meter, and no purchase. Your #1 rule stops being a discipline you enforce in four places and becomes a fact of the architecture. **That's what good design does with a hard rule: it makes breaking it impossible rather than forbidden.**

### The line

| Free, forever | Premium |
|---|---|
| 🔴 **The red button** — offline, instant, no AI, never monetized | Unlimited pets |
| Unlimited **text guidance** (cheap model, marginal cost ≈ 0) | Unlimited **history** (free keeps 30 days) |
| 1 pet · 30-day history | **Photo progression timelines** |
| ~5 photo logs/month | Unlimited photo logs |
| | **Vet Visit Prep Pack** ← *the thing they're buying* |
| | Reminders · vaccinations · medications · weight charts |
| | Export · family access |

**Why photos are paid:** under the reframe, photos are a *records* feature, not a safety mechanism. You can meter them freely without touching a safety promise. **That's the whole reason the BE-01 cost trap dissolves** — it only existed because vision was load-bearing for emergency detection.

### One plan. One price.

**Delete the tier ladder** (free/trial/premium/family/b2b_lite). Today your paywall promises *"for all your pets"* (premium caps at **2**) and *"Family & sitter sharing"* (**premium is invite-ineligible by design**), and the pet-cap prompt says *"Upgrade to Family"* → pushing a paywall with **no Family plan**. You are selling two things the plan doesn't include, to your best customer, at the moment of highest goodwill. That's a refund, a chargeback, a one-star review, and an Apple 3.1.2 problem a reviewer finds in ninety seconds.

**Segmentation is earned with data. It is not launched with.**

| | Recommendation |
|---|---|
| **Annual** | **$39.99/yr** (~$3.33/mo) — featured |
| **Monthly** | **$6.99/mo** — the decoy that makes annual obvious |
| **Trial** | 7 days, annual only |
| **Everything included** | Unlimited pets, sharing, PDF, export. No add-ons. No consumables. |

Lower than your current `$59.99/$9.99`, and deliberately: a records app is not a $60 product, and a dog costs ~$1,500/yr — $40 is 2.7% of that, an easy yes when the value is legible. **The record's value is legible; a verdict's is not.** Whatever you pick: **one price, in one place.** Right now you have `$59.99/$9.99` hardcoded, `$14.99/$24.99/$19.99` in comments, `$0.33/day` in onboarding (anchoring your *worse* plan), a `~$5 vs $4.99` conflict the playbook flags itself, and **no product IDs anywhere in the repo.**

### The honest trade-off

**The safe product converts worse.** "AI tells you if it's an emergency" demos better than "AI helps you log symptoms and prep for the vet." Anyone who tells you the reframe is free is selling something.

But: **fear converts fast and churns the moment the pet is better.** Episodic value → episodic subscription. **The record converts slower and compounds** — your data is in there, and switching cost grows every month. For a subscription business, **retention beats conversion**, so the reframe probably wins on LTV while losing on conversion rate. That's the trade. Take it with your eyes open.

### Cancellation is a feature

- **One deep link** from Account to the store's manage-subscription page. One hour of work; removes your single biggest ticket class. Today the *"Premium — manage"* tile pushes the **paywall**.
- **Make Restore work.** It's a literal no-op. Apple requires it. Guaranteed tickets and a plausible rejection.
- **Add the SDK entitlement fallback.** Premium is 100% webhook-dependent — a paid user is blocked until the webhook lands, or forever if it's misconfigured. *"I paid and I'm not premium"* is your worst ticket: angry, urgent, from your best customer, and at 2am.
- **Never dark-pattern the cancel.** You're a solo founder in a health-adjacent category. One viral "I couldn't cancel PawDoc" post costs more than a year of the saves it buys.

---

## 3. Product positioning

### The pitch

> **PawDoc — the health record your vet actually wants to see.**
>
> Free: help when it's urgent, and guidance that tells you what to watch for and when to call.
> Premium: every pet, symptom, photo, medication, and visit in one timeline — with a vet-ready summary in your hand before you walk into the room.
>
> **We never diagnose. We never reassure. We help you notice, decide, remember, and explain.**

### Words

| ✅ Say | ❌ Never say |
|---|---|
| guidance · triage · urgency · timing | diagnose · diagnosis · condition · cause |
| what to watch for · when to call | likely normal · probably fine · nothing to worry about |
| record · timeline · history · prep | verdict · assessment · confidence · accuracy |
| "your vet decides" | "never wonder if your pet needs the vet again" |
| "we wrote down what you saw" | "we told you it was fine" |

**Enforce it in CI, not in discipline.** `verify-no-placeholders.sh` currently scans `docs/store_metadata docs/legal web/app` — **`mobile/lib` is not scanned.** That single omission is exactly why *"Never wonder if your pet needs the vet again"* survived every audit and still greets every new user. Add `mobile/lib` to `ROOTS`. Add the new banned words. **A rule a machine enforces is a rule; a rule you remember is a wish.**

### The positioning already exists in your own repo

`ai-transparency.md:46` — *"We do not claim that PawDoc is as accurate as a veterinarian, and we do not publish accuracy percentages we cannot substantiate."*
`emergency.md:46` — *"We would rather you act quickly and have it turn out to be nothing than wait on an app."*
Onboarding — *"We inform; your vet decides."*

**That's the pitch. It's excellent. It's already written.** The problem is it currently reads as an *apology* for the product. After the reframe, it reads as the product. **Same words, and they stop being a hedge and start being a promise.**

---

## 4. Support strategy

You are one person. Every ticket is an hour you don't have. **Design them away; don't answer them faster.**

### Tickets that will never exist, once you subtract

| Ticket | Killed by |
|---|---|
| *"Where are my referral rewards?"* | Removing referral |
| *"It says 3 checks but I have bonus credits"* | Removing metering — **no counter, no argument** |
| *"How do I add a third pet?"* | One plan, unlimited pets |
| *"I paid for Premium but can't invite my partner"* | One plan |
| *"How do I buy the $4.99 PDF?"* (**you have no code that sells it**) | Folding PDF into Premium |
| *"The text is invisible"* | Dark-only |
| *"Delete my account"* → 500 | Removing referral (kills the FK) |
| *"Why does it want my location?"* | The maps deep link |

### Tickets you must engineer away

| Ticket | Fix |
|---|---|
| *"Restore doesn't work"* | It's a no-op. Fix it. |
| *"I paid, I'm not premium"* | SDK entitlement fallback |
| *"How do I cancel?"* | One deep link |
| *"Which plan am I on?"* | One plan |

### Self-service, day one

A single FAQ page on the same host as the legal portal: How do I cancel · Restore · Delete my account · Why do you need the camera · What does PawDoc actually do · **What PawDoc will never tell you** ← *that page is a trust asset, not a disclaimer.*

### The ticket that matters

> *"Your app said my dog was fine. He died on Tuesday."*

**Have the protocol written before launch, not during.** On that day you will be devastated and you will improvise, and improvising is how a founder turns a tragedy into a lawsuit — either by admitting fault reflexively, or by sounding like a lawyer to a grieving person. **Both are catastrophic. Neither is who you are.**

Ask counsel to write it *now*, while it's cheap and hypothetical. The shape, for them to correct:

1. **Respond as a person, within hours.** Grief deserves speed. Silence reads as guilt and it's also just cruel.
2. **Say you're sorry for their loss.** *That is not an admission of fault* — it's condolence. Counsel will confirm the wording for your jurisdiction. Do not let legal caution make you cold.
3. **Do not speculate about what happened, and do not concede the app was wrong.** You don't know yet.
4. **Preserve everything immediately** — the analysis row, `full_response`, the media, the timeline. Don't let R2 retention (§6) delete evidence you need.
5. **Refund immediately and without conditions**, if they paid. Never make a grieving person ask twice.
6. **Escalate to counsel + your carrier the same day.** That's what the E&O is for.
7. **Then look, honestly.** Was it a real false negative? Then it's a product problem, and the golden set gets a new case.

**Now notice what the reframe does to that conversation.** *"The app said your dog was fine"* has no good reply. *"The app recorded what you described, told you what to watch for, and said to call if it got worse"* is a different conversation — with the family, with counsel, with your carrier, and at 3am with yourself. **You will have this conversation someday. Choose now which version of it you get.**

---

## 5. Growth strategy

### The order matters, and you have it backwards

**Retention → then acquisition. Never the reverse.**

Referral is currently a *launch* feature. That's precisely wrong: referral amplifies whatever you have. **Amplifying a leaky bucket burns your users' social capital — the one thing that doesn't regenerate.** Every friend a user invites to a product they'll abandon in three weeks is a friend they can't invite to the version that works.

**Earn referral. Don't launch with it.** Turn it on when week-4 retention justifies it, and only then. (It's also where your CRITICAL blocker lives — see the matrix.)

### What to do at beta

- **Nothing paid.** Your own runbook is right: *"Treat campaign #1 as price discovery, not scale"* and *"do not scale spend until LTV:CAC > 3."* You cannot compute LTV without retention, and you have no retention data. **Spending money now buys you noise at $20/day.**
- **50 users you can talk to.** Pet forums, local vets, friends. Talk to every one. At 50 users your job is not growth — it's listening.
- **The one thing worth building:** ask five vets to look at the Vet Visit Prep Pack. If vets like it, you have a distribution channel money can't buy. If they shrug, **you've learned that before you spent a cent** — and that finding is worth more than the beta.

### The channel nobody is using

**The vet.** Not as a partner — as a *user of your output*. A vet who sees a clean, organized PawDoc summary walk into their room is a vet who tells the next client. That's zero-CAC distribution, it only works if the record is genuinely good, and **it is completely unavailable to an app that hands out AI verdicts** — because a verdict is something a vet has to *correct*, while a record is something a vet can *use*.

**Every hour you spend making the prep pack better is a growth investment.** That's why the record is the strategy, not just the safer product.

### Cut from the roadmap, permanently

Community Q&A (moderation is how solo apps die) · B2B API · proprietary model · insurance FNOL. **All four need a record to sell anyway.** Build the record; they become possible. Skip it; they never were.

---

## 6. Operational priorities

### Vendor diet: 12 → 7

**Keep:** Supabase · Fly · R2 · RevenueCat · PostHog · Sentry · Gemini (+Anthropic escalation)
**Cut:** AWS (fold legal into `web/`) · OneSignal (→ local notifications) · OpenAI (dies with journals) · Upstash (dies with the semantic cache) · the Terraform stack

Every removal is a bill, a secret to rotate, a Data Safety row, a privacy disclosure, and a 2am page you no longer own. **You are one person. Seven vendors is already a lot.**

### Do this week

- [ ] **Verify the Gemini + Anthropic billing tier.** Consumer/free Gemini tiers may train on inputs. If you're on one, `privacy.md` is currently false and pet health data plus photos of people's homes are in a training corpus. **Confirm paid tier, no-training terms, and execute the DPAs.** There is no DPA, no ZDR, and no no-training reference anywhere in the repo.
- [ ] **Decide R2 retention.** There is **no TTL, no lifecycle rule, no cleanup cron.** Photos that can contain people, children, and home interiors are kept **forever**, against an unresolved conflict your own schema comment names: *"'store every analysis permanently' vs GDPR erasure is unresolved."* Pick a period. Enforce it in R2. *(Then make sure the incident protocol in §4 can preserve evidence before it expires — those two rules must know about each other.)*
- [ ] **Set provider spend alerts.** BE-01 is live and **you have zero cost telemetry** — no token accounting, no spend tracking, no per-analysis cost figure anywhere in the codebase. Until the code fix lands, the vendor console is your only guard.

### Monitor, weekly, 15 minutes

| Signal | Why |
|---|---|
| **`analysis_feedback` where rating = down / "Wasn't accurate"** | **Your only quality signal.** You have no live-model monitoring (AI-02); the golden set runs against **stubs**, so a real model regression is invisible. This is it. Read every one. |
| Action-ladder distribution | A sudden shift in the mix = a model change you didn't make |
| AI spend per day | The BE-01 canary |
| Week-4 retention | The only number that matters |
| Sentry | Obvious |

### The test that guards the company

You have 217 tests and **zero e2e** — the safety path is asserted only against mocks (ENG-02/QA-02). After the reframe, write **one** integration test:

> **No output path can terminate without an action and a timeframe.**

That is the invariant the entire business rests on. Make it fail loudly. Everything else is a bug; that one is the company. And fix `test-rls.sh` to load **all** migrations and gate it in CI — a test that skips the migration containing the bug is worse than no test, because **it manufactures the confidence that let RLS-01 ship through six audits.**

### The rhythm

**Monday:** read every "not accurate" flag. **Weekly:** the 15-minute dashboard. **Monthly:** one record feature (weight chart → photo progression → prep pack). **Quarterly:** ask whether the roadmap still matches what users do.

---

## 7. If you disagree

You might read all this and conclude the triage verdict *is* the product and I've talked you out of your differentiation. That's a legitimate position, and you know things about your users that I don't. **Here is the honest version of that fork:**

**If you keep the verdict, you must accept all of this:**
- Metering safety forever, and defending it every time a reviewer asks
- An AI-cost path you cannot rate-limit without breaking your own #1 rule
- A store review that is a medical review, on every update, forever
- E&O priced for a diagnostic product (**§0.1 tells you what that costs — get the number before you decide**)
- A support inbox where the worst ticket has no good reply
- A legal portal that describes a product you don't ship, in three places, in writing, in a repo with a git history

**Then do it deliberately.** Fix the 6 CRITICALs, ship, and keep the safety spine as tight as it already is. It's a real choice, and executed knowingly it's far better than drifting into it.

**But do §0.1 and §0.3 either way.** The broker call costs an hour and prices your biggest unknown with someone else's money. The four free decisions cost nothing and remove real risk under *any* strategy. **Even if you throw the rest of this away, do those two things this week.**

---

## The one-page version

1. **Call the broker.** Two quotes. One hour. Highest-signal thing you can do. *(§0.1)*
2. **Delete `diagnosis` from your keywords.** Today. Free. *(§0.3)*
3. **Delete "LIKELY NORMAL" and the differential.** Everything else follows. *(matrix A1/A2)*
4. **Make the emergency a red button, not an AI call.** Offline, free, instant, unmonetized. *(matrix C1)*
5. **Take the affiliates off the emergency screen.** Nine lines. Today. *(matrix C2)*
6. **Delete referral, family, video, journals, A/B, tiers.** Kills 1 CRITICAL + 3 HIGHs for free. *(matrix F)*
7. **Free = safety. Paid = memory.** One plan, one price, unlimited pets. *(§2)*
8. **Promote the health report to the product.** It's already written. *(matrix E1)*
9. **Ship to 50 people and find out if they come back.** *(§1)*
10. **Write the bad-day protocol before you need it.** *(§4)*

---

*Prepared 2026-07-17. Product, risk, and business strategy — **not legal, tax, or insurance advice.** The jurisdiction, age, consent, retention, and practice-of-veterinary-medicine questions belong in front of counsel; §0.1's second question belongs in front of a broker. I read the source, not the reports — where I contradict a prior "done" claim, the file path is cited in the masterplan.*
