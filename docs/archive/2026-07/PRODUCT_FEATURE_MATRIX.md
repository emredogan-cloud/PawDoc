# Appendix A — PawDoc Product Feature Matrix

**One decision per feature.** Companion to `PAWDOC_PRODUCT_EVOLUTION_MASTERPLAN.md`. Every row was read from source on 2026-07-17 against `feat/legal-portal-integration`.

**Decision key**

| | Meaning |
|---|---|
| **KEEP** | Ships as-is. Don't touch it. |
| **SIMPLIFY** | Right idea, too much machinery. Cut it down. |
| **REPLACE** | Right need, wrong mechanism. Swap it. |
| **REMOVE** | Delete. Either built for scale you don't have, or actively harmful. |

Two decisions beyond the four requested, because a product-evolution matrix that can't say *"build this"* is only half a matrix:

| | Meaning |
|---|---|
| **ADD** | Doesn't exist and should. |
| **DON'T BUILD** | Correctly absent today. Keep it that way — noted so a future roadmap doesn't "fix" it. |

**106 features reviewed · 30 KEEP · 16 SIMPLIFY · 26 REPLACE · 23 REMOVE · 8 ADD · 3 DON'T BUILD**

**Removing and replacing eliminates 1 CRITICAL, 3 HIGH, and ~10 MEDIUM/LOW audit findings without fixing any of them.**

---

## A. The AI output — where the business risk lives

| # | Feature | Decision | Justification |
|---|---|---|---|
| A1 | **`NORMAL` triage level → "LIKELY NORMAL"** (`result_screen.dart:84-88`) | **REMOVE** | The one output that reduces care-seeking, and the least valuable thing you produce. 100% of the false-negative exposure sits in this enum value. It cannot be made safe by accuracy work — only by not saying it. **This single deletion is the report.** |
| A2 | **`differential` → "Possible causes"** (`result_screen.dart:269`) | **REMOVE** | A ranked differential *is* the diagnostic act. Your own `vet-disclaimer.md:29-35` says PawDoc does not "name a definitive condition"; the contract's canonical example is `["GDV", "ascites"]`. Knowing GDV-vs-ascites changes **nothing** an owner can do — both mean *go now*. Maximum legal weight, near-zero user value. It exists because it demos well. |
| A3 | **Triage enum `EMERGENCY \| MONITOR \| NORMAL`** | **REPLACE** | → an action ladder with no terminal "do nothing" rung: `GET_HELP_NOW \| CALL_TODAY \| BOOK_VISIT \| WATCH_AND_RECHECK`. Bottom rung is "watch and re-check," never "you're fine." Primes escalation instead of closure, and creates a return visit. Same AI call. |
| A4 | **`primary_concern`** (e.g. *"Suspected bloat (GDV)"*) | **SIMPLIFY** | Keep the field; change what goes in it. Plain-language **observation** ("a swollen, firm belly"), never a suspected disease. The vet names things. |
| A5 | **`confidence` score** | **KEEP** (internal only) | Correctly used for routing (≤0.85 escalate, <0.60 → insufficient-information) and correctly **never rendered** — I grepped `mobile/lib`; it appears only in the parser. Never surface it. A number implies a precision you cannot support, and `ai-transparency.md:46` already promises you won't claim one. |
| A6 | **`recommended_actions`, `urgency_timeframe`** | **KEEP** | The action + timing framing is exactly right and becomes the whole output under A3. |
| A7 | **System prompt** (`prompts.py:19-49`) | **REPLACE** | Rewrite as **observer, not judge**. It currently says *"you do NOT diagnose"* while demanding `"differential": ["most to least likely"]` in the same schema. Resolve the contradiction in the prompt's favour: describe, never conclude; never name a condition; never a no-action outcome. |
| A8 | **Species-specific guidance** (rabbit GI stasis, etc., `prompts.py:55-79`) | **KEEP** | Genuinely good veterinary judgment — *"GI stasis is a TRUE EMERGENCY... not 'monitor'"*. Exotic-pet owners are underserved and this is real differentiation. Zero added risk: it escalates. |
| A9 | **Hardcoded escalation triggers** (`result_screen.dart:90-94`) | **KEEP** | *"Symptoms get worse", "stops eating or drinking", "You feel something is wrong"* — hardcoded, not AI output, and the last one is the best line in the product. Under A3 these become more prominent, not less. |

## B. Safety spine — the part you got right

| # | Feature | Decision | Justification |
|---|---|---|---|
| B1 | **Pre-AI hardcoded emergency override** (157 keywords, `safety.py`) | **KEEP** — with a new job | Excellent design: runs before any model call, returns fixed EMERGENCY at `confidence=1.0`, byte-identical across `safety.py` and `emergency_keywords.mjs`. **Its role changes from producing a verdict to routing to the red button (C1).** Same code, better job. |
| B2 | **Keywords are server-only** | **REPLACE** | Move the list **client-side** as an offline router. An owner in a dead zone typing "my dog is choking" currently gets *"couldn't analyze"* (QA-06). The server list stays authoritative for the record. |
| B3 | **EN/DE-only keyword lists** | **SIMPLIFY** | Not by translating — **by restricting the store to EN/DE markets.** A French owner typing *"mon chien s'étouffe"* gets no override; your #1 safety guarantee silently degrades to best-effort model output for most of the planet, and nothing says so. *(Reinforcing: only **13 strings** are localized — the rest of the app is hardcoded English. You are not bilingual; you have a bilingual safety list on an English app. **Consider EN-only for v1.**)* |
| B4 | **Server-forced `disclaimer_required`** (`pipeline.py:147`) | **KEEP** | `model_copy(update={"disclaimer_required": True})` on every return path. The UI cannot suppress it. Textbook. |
| B5 | **Degrade → MONITOR, never NORMAL** (4 fallbacks, `confidence=0.0`) | **KEEP** | Right instinct, right implementation. Under A3 the fallback becomes `WATCH_AND_RECHECK`. |
| B6 | **EMERGENCY cross-verification** (2nd Claude call) | **SIMPLIFY** → async | It **cannot change the outcome** (EMERGENCY is kept regardless; disagreement only flips a boolean nobody displays). So it buys telemetry at the cost of a full Claude call and double latency **on your most time-critical path**. Return first, verify in background, log. Same signal, zero user latency, half the cost. |
| B7 | **Confidence floor 0.60 → insufficient-information** | **KEEP** | Never fabricate. Correct. |
| B8 | **Temperature 0.1** | **KEEP** | Correct for a health path. |
| B9 | **Moderation, fail-closed** (`moderation.py`) | **SIMPLIFY** | Keep fail-closed. Fix the two defects: hardcoded `image/jpeg` for PNG/WebP (legit photos wrongly rejected, AI-03), and the double fetch (moderator + provider each fetch the same URL). Derive MIME from the object; fetch once. |
| B10 | **Gemini prompt concatenation** (`providers.py:68-72`) | **REPLACE** | Your **primary tier** joins the system prompt, pet context, and **4,000 chars of owner free text** into one string — no role separation on the safety-critical path. Use `system_instruction`. Low likelihood (the attacker would be the victim), trivial to fix, wrong to leave in a safety-critical app. |

## C. Emergency experience

| # | Feature | Decision | Justification |
|---|---|---|---|
| C1 | **AI-driven EMERGENCY flow** | **REPLACE** — *the most important change in this document* | → **A red button on home. Offline. Zero AI. Zero network.** Maps link + poison-control dialer + bundled first-aid card. Today the emergency path needs connectivity, a single 512MB Fly machine, a reachable Gemini, and a correct model — and can take **6 sequential model calls / up to 48s**. Your slowest, most expensive, most fragile path is your emergency path. A phone number has none of those failure modes, costs nothing, and makes *"if this is an emergency, don't use the app — press this and drive"* literally true. |
| C2 | **Telehealth affiliate on the EMERGENCY screen** (`emergency_result_screen.dart:100`) | **REMOVE** — *highest reputational risk in the product* | A revenue-share *"Talk to a vet now — On-demand video consult with a licensed vet"* button, on the screen that says the pet may be dying. Three problems: it monetizes panic; **no partner is named anywhere in the repo** (an unqualified licensed-vet claim your CI regex doesn't catch); and **a video consult is the wrong action in a real emergency** — a bloating dog needs a car, not a webcam. Your #1 rule is "never paywall an EMERGENCY." You applied it to subscriptions and then sold the emergency to an affiliate. Nine lines. Delete them. |
| C3 | **Insurance affiliate on emergency + result screens** | **REMOVE** (from those screens) | Selling insurance to someone whose pet may be dying is the worst-timed upsell in consumer software. May return later on the pet profile in a calm moment. Never on a result. |
| C4 | **Red scaffold + explicit white text + ack gate** (`PopScope(canPop: _acknowledged)`) | **KEEP** | Well-built and the only screen immune to the light-mode bug. The forced acknowledgment is correct. |
| C5 | **First-aid content** | **ADD** (part of C1) | Choking, bleeding, seizure, bloat, heatstroke. Static, vet-reviewed, bundled in the binary. **This is educational content about conditions — the most defensible thing you can ship** and the highest-value thing at 2am. |

## D. Capture

| # | Feature | Decision | Justification |
|---|---|---|---|
| D1 | **Photo capture + compression + EXIF stripping** | **KEEP** | `image_compressor.dart:46-71` genuinely strips EXIF/GPS. Quality ladder, blur/lighting gates, isolate offload. Good work. |
| D2 | **Photo *analysis*** | **REPLACE** | → **Photo progression.** The AI **describes** ("a raised, dark ~1cm lesion on the left flank") and **never judges** — no "benign," no "probably fine." Then: *"Vets care about **change**. Re-photograph in 7 days and we'll show you both."* Same pixels, same UX: retention loop, subscription justification, a better clinical artifact than one photo + an AI opinion, and zero liability because it never reassures. |
| D3 | **Video capture** (≤30s → 5 keyframes) | **REMOVE** (v1) | 5× moderation calls + 5× uploads + a video model path + a whole screen — for marginal gain over a photo and a sentence. It is your most expensive input on an unmetered free path. Re-add in Phase 7 if photos prove insufficient. |
| D4 | **Text symptom input** (12–1000 chars, example chips) | **KEEP** | Cheapest input, highest coverage, becomes the free tier's primary path. |
| D5 | **Client-side `emergencyHints`** (18 stems bypassing the min-length gate) | **KEEP** + promote | Already the seed of B2 — you have client-side emergency stems *just to skip a character count*. Promote them to the offline router. |
| D6 | **Voice input** | **DON'T BUILD** | Not present. Keep it that way: a mic permission, a transcription vendor, and a privacy disclosure to replace typing. |
| D7 | **Gallery picker** | **DON'T BUILD** | Correctly absent. Adds `NSPhotoLibraryUsageDescription` and a "why do you need this" rejection risk for near-zero gain. `camera_screen.dart` copy — *"Photos are private — location removed"* — is exactly right. |

## E. The record — this is the actual product

| # | Feature | Decision | Justification |
|---|---|---|---|
| E1 | **Markdown health report** (`export/health_report.dart`) | **KEEP** → **PROMOTE TO CORE** | ~100 lines, pure, unit-tested, zero liability, buried in an overflow menu. **This is the highest-value, lowest-risk feature in the codebase and the only thing a competitor can't rebuild in a weekend.** Make it the **Vet Visit Prep Pack** — a destination you open before every appointment. This promotion is most of the business. |
| E2 | **History timeline** (analyses + events, bucketed) | **KEEP** → **PROMOTE** | Well-built. Becomes the home screen of the new product. Empty state — *"{Pet}'s health story starts here"* — is already selling the right product. |
| E3 | **Health events** (5 types) | **KEEP** | The record's atoms. |
| E4 | **Weight tracking** | **REPLACE** | Currently written to `metadata` and **never read back anywhere. No chart, no trend, no view.** The single most useful longitudinal signal for a pet is write-only. Build the chart — it's a subscription justification, a retention loop, and pure record value. |
| E5 | **`sex`, `weight_kg`, `photo_url`, `medical_notes`** | **REPLACE** | In the model, in the DB, **editable in no screen** — and `health_report.dart:28-29` *reads* `sex`/`weight_kg` for the vet report. **Your vet report prints two fields the user cannot fill in.** Add the fields or drop the columns. |
| E6 | **Pet photo picker** | **ADD** | Absent (*"A real photo picker is separate"*). It's the emotional anchor of a record product. |
| E7 | **Vaccinations** | **SIMPLIFY** → structure it | Currently a free-text note under an event type. Give it a name + date + due-date and it drives reminders, the prep pack, and retention. Zero liability: you record what the vet did. |
| E8 | **Medications** | **SIMPLIFY** — deliberately dumb | Record + remind **only**. Never compute a dose. Never check an interaction. Never suggest. *"Record what your vet prescribed"* is a filing cabinet; anything more is pharmacy practice. |
| E9 | **PDF report + `$4.99` consumable** | **SIMPLIFY** | The consumable is a support surface **and it does not work**: the app says *"buy one for $4.99"* but **no client code purchases `pdf_report_addon`**. Fold PDF into Premium. Delete `pdf_reports_remaining` and the add-on entirely. |
| E10 | **Breed insights** (static, client-side) | **KEEP** | Zero-risk educational content, zero marginal cost, real value. **This is the shape of content you want more of** — about a *breed*, not about *your dog*. |
| E11 | **Weekly AI health journal** (OpenAI `gpt-4o-mini`) | **REMOVE** | An AI writing **unprompted health narrative** about a pet nobody asked about. Adds a **third AI provider that is missing from the privacy policy's processor table**, generates prose you must stand behind, and nobody requested. Pure liability, no pull. Kills a vendor with it. |
| E12 | **Result feedback (thumbs + 72h follow-up)** | **KEEP** → **PROMOTE** | Your **only** quality signal in a product with no live-model monitoring (AI-02) — and it partially answers Play's Gen-AI policy expectation of an in-app reporting path. The follow-up chips (*"Vet confirmed it"*, *"Wasn't accurate"*) are the closest thing you'll ever get to outcome data. **Route "Wasn't accurate" somewhere you actually read.** |

## F. Growth scaffolding — built for scale you don't have

| # | Feature | Decision | Justification |
|---|---|---|---|
| F1 | **Referral** (screen, RPC, table, +3/+3, cap 30) | **REMOVE** | **Contains the audit's CRITICAL account-deletion blocker (RLS-01)** — the referral FKs lack `ON DELETE`, so deletion 500s for anyone in a referral relationship. **You cannot 500 on a foreign key that doesn't exist.** Also: links point at a **dead domain** with no App Links (PRD-01), copy says *"Amazing rewards"* and *"when they subscribe"* while the RPC grants +3 on **claim** (PRD-04), the social buttons are cosmetic, and the "They get: 3 free checks" is what every new user already gets. **You are blocked from launch by a growth feature you have no users to grow.** |
| F2 | **Family sharing** (groups, members, invites, 3 screens, 2 Edge Functions) | **REMOVE** (v1) | 4 tables, a `SECURITY DEFINER` recursion workaround, 48h tokens, a cross-tenant injection hole already patched once (`20260613130000_family_update_boundary.sql`), **retroactive exposure of a pet's entire history on join**, and an invite email that leaks the inviter's address as the display name. Sophisticated machinery for households that don't exist yet. Re-add when users ask. |
| F3 | **A/B experiments** (`onboarding_variant`, `paywall_variant`, `pulse_pet_variant`) | **REMOVE** | **You cannot run an experiment with no traffic.** All silently serve control without PostHog (PRD-03), Variant B shows a paywall before any value and can dead-end on "coming soon" (PRD-05), and one flag key has zero call sites. Three paywall layouts for zero users. Delete the framework; keep the analytics. |
| F4 | **Re-engagement push** (*"We miss you 🐾"*, 30d inactivity cron) | **REMOVE** | A retention mechanic for users you don't have, requiring a push vendor, a cron, and a Data Safety row. Nudging someone about a healthy pet is also the exact wrong instinct: **the record earns the reopen.** |
| F5 | **B2B-Lite / sitter mode** (`b2b_lite` tier, `pets.client_name`) | **REMOVE** | A **B2B tier before a single consumer user**. `client_name` stores *a third party's name* and prints it into the PDF. Delete the tier, the column, and the migration. |
| F6 | **Anonymous web checker** (`analyze-anonymous`, Turnstile, 3/IP/24h) | **SIMPLIFY** | **Zero mobile call sites** — it's a web funnel only. It stores **raw unhashed IP** in Upstash and runs `CORS: *`. Keep it *only* if the web funnel is a real acquisition channel; hash the IP either way. Otherwise remove and delete a whole Edge Function + an attack surface. |
| F7 | **Community Q&A** (roadmap Phase 7.4) | **REMOVE** from roadmap | UGC moderation is an unbounded, un-delegable, 24/7 commitment. **This is how solo consumer apps die.** Don't start. |
| F8 | **Proprietary fine-tuned model** (Phase 8.1) | **REMOVE** from roadmap | Today a wrong answer is Google's model. Train your own and it becomes **your** model, your training data, your negligence — while giving up two frontier labs' safety research. A liability transfer *toward* you, sold as a moat. |
| F9 | **Training-data export** (`training_export.py`) | **REMOVE** | Strips ids/emails via an allowlist but **deliberately retains `symptom_text`** — the exact field where an owner types *"my daughter was bitten."* Its own header says the scrub pass "is the founder's call." **It is not implemented.** Feeds F8, which is cut anyway. |
| F10 | **B2B API** (Phase 7.3) · **Insurance FNOL** (Phase 8.3) | **REMOVE** from roadmap | FNOL is claims intake — a regulated activity in most jurisdictions, dragging you toward licensure you cannot support solo. Both need a record to sell anyway. **Build the record first; these become possible, not the reverse.** |

## G. Monetization

| # | Feature | Decision | Justification |
|---|---|---|---|
| G1 | **Free tier = 3 metered analyses/month** | **REPLACE** | You are **metering the safety feature** — charging for medical opinions, the worst thing to attach a price to on every axis (store review, plaintiff's exhibit, refund, App Review instinct). → **Unlimited free text guidance + the red button.** Free is safety; paid is memory. |
| G2 | **Quota counter UI** (*"2 of 3 free checks left"*) | **REMOVE** | Not a feature — a **support contract**. It already misreports: it ignores bonus credits and the monthly reset the server honors (SUB-03). Remove metering (G1) and the counter, the argument, and the ticket class all vanish. |
| G3 | **Out-of-quota visual runs the AI anyway** (`blockBeforeAi` = false for visuals) | **REPLACE** | The honest consequence of "never paywall an emergency" + "emergencies are detected by paid vision": **an unbounded free path to your Gemini/Anthropic bill, with no cost telemetry anywhere** (BE-01). Not a bug — a structural trap. **It dissolves the moment vision stops being a safety mechanism (C1).** Then photos are records and you can rate-limit them freely. |
| G4 | **Tier ladder** (free/trial/premium/family/b2b_lite) | **REPLACE** → **one plan** | The paywall promises *"for all your pets"* (premium caps at **2**) and *"Family & sitter sharing"* (**premium is invite-ineligible by design**). Hitting the pet cap says *"Upgrade to Family"* → pushes a paywall **with no Family plan**. **Your paywall sells two things the plan doesn't include.** One plan, one price, everything in. Segmentation is earned with data, not launched with. |
| G5 | **Pricing** | **REPLACE** | Unreconciled across the repo: `$59.99/yr` + `$9.99/mo` hardcoded; `$14.99`/`$24.99`/`$19.99` in comments; `$0.33/day` claimed in onboarding; the playbook flags its own `~$5 vs $4.99` conflict. **No product IDs defined anywhere.** One price, one place. Annual-first. |
| G6 | **Restore Purchases** | **REPLACE** | **A literal no-op** — return value discarded, empty catch, no feedback, no navigation, no `ref.invalidate` (SUB-01). Apple requires it to function. Guaranteed tickets and a guaranteed rejection. |
| G7 | **Premium recognition = 100% webhook** | **REPLACE** | No SDK entitlement fallback, no `addCustomerInfoUpdateListener` (SUB-02). A paid user is blocked until the webhook lands — or forever if it's misconfigured. **"I paid and I'm not premium" is your worst ticket:** angry, urgent, and from your best customer. |
| G8 | **Manage/cancel subscription** | **REPLACE** | The *"Premium — manage"* tile pushes the **paywall** — the same destination as "Upgrade." **Add one deep link to the store's subscription page.** One hour of work removes the single biggest subscription ticket class, and a visible cancel path is the cheapest trust signal in consumer software. |
| G9 | **Paywall trust rule** (`paywall_policy.dart`) | **KEEP** | Never after EMERGENCY, never in onboarding, only after first value, ≤1/day, never for premium. Pure, unit-tested, exactly right. Under the new design it becomes almost unnecessary — which is the point. |
| G10 | **`_PremiumComingSoon`** fallback | **KEEP** | Correct defensive behavior — no placeholder prices, no dev text. *It must not be live at review* (APPL-03), but as a fallback it's right. |
| G11 | **Deprecated `purchasePackage`** | **REPLACE** | SUB-05. Use the current API. |
| G12 | **Ads** | **DON'T BUILD** | Correctly absent. Never put ads in a health product. |

## H. Platform, infra, vendors

| # | Feature | Decision | Justification |
|---|---|---|---|
| H1 | **Vet finder** (Google Places proxy + **FINE + COARSE** location) | **REPLACE** | → **a maps deep link** (`maps://?q=emergency+vet+near+me`). The OS handles location; you request **no permission** and store **no coordinates**. Kills PLAY-03, a permission prompt at the worst possible moment, a Data Safety category, a privacy disclosure, an Edge Function, and the `geolocator` dependency — for a *better* result (the OS maps app has more vets than Places-via-proxy). |
| H2 | **OneSignal push** | **REPLACE** | → **on-device local notifications.** A medication reminder does not need a push server. Kills a vendor, a device token, a Data Safety row, a privacy disclosure, an hourly cron, `users.one_signal_player_id`, and **the unfixed crash-on-exit when `ONESIGNAL_APP_ID` is unset** (QA-03) — which is currently "mitigated" only by remembering to set config. |
| H3 | **AWS + CloudFront + Terraform** (for 15 static legal pages) | **REPLACE** | → **serve from the Next.js site in `web/`.** A 4th cloud, a Terraform codebase with **local-only unlocked state** (INF-03), a **TLSv1.0** floor (INF-06), and an ephemeral CloudFront hostname as your store privacy URL (REC-04) — to host static text. Same content, one host, three findings dead, one cloud account closed. |
| H4 | **OpenAI `gpt-4o-mini`** | **REMOVE** | Only used by the journal (E11). A third AI provider, undisclosed in the privacy policy. Dies with the feature. |
| H5 | **Google Fonts runtime fetch** | **REPLACE** | Bundle the `.ttf`s; `allowRuntimeFetching = false`. An unconsented third-party call to Google before any consent, on first launch, that breaks typography offline (ENG-01/PERF-03). |
| H6 | **Light theme** (`themeMode: system` + 13 forced-dark screens) | **REMOVE** | Ship dark-only. **One line kills a HIGH launch blocker** (UX-01) that currently renders safety guidance near-invisible for every light-mode user. Build a real light theme later or never. |
| H7 | **Fly.io Python AI service** | **KEEP** | Don't rewrite tested safety code to save $5/mo. *Note the double hop* (client → Edge → Fly → provider) and the **single 512MB machine with no scaling or alerting** (INF-05) — a viral spike takes down all triage. Under the new design that's survivable, because the emergency path no longer depends on it. |
| H8 | **Semantic cache** (embeddings + Upstash) | **REMOVE** (v1) | Same-user + same-species + text-only ≥0.90 cosine. A cost optimization for traffic you don't have, costing an embedding model, a vendor, and a `vector(1536)` column. Re-add when the bill justifies it. |
| H9 | **PostHog** | **KEEP** + gate it | You need funnel data. But it currently fires unconditionally and identifies to the Supabase uid while `privacy.md:47` claims **consent** is the legal basis — see I2. |
| H10 | **Sentry** | **KEEP** | Set `sendDefaultPii: false` explicitly in Flutter to match `main.py:75`, which already does it correctly. |
| H11 | **RLS on 13 tables · presigned uploads · fail-closed moderation · gitleaks** | **KEEP** | The security posture is the best thing in the repo. Untouched by everything here. |
| H12 | **12 vendors → 7** | **SIMPLIFY** | Cut AWS, OneSignal, OpenAI, Upstash, and the Terraform stack. Each removal is a bill, a secret, an outage, a Data Safety row, and a 2am page you don't own. |

## I. Legal, privacy, store

| # | Feature | Decision | Justification |
|---|---|---|---|
| I1 | **15-page legal portal** | **KEEP** (content) · **SIMPLIFY** (hosting → H3) | Genuinely well-drafted — `vet-disclaimer.md`, `emergency.md`, and `ai-transparency.md:46` are better than most funded startups ship. **Which is exactly the problem:** it describes a more careful product than you ship, and every gap is an exhibit. Fix the product; the portal becomes true. |
| I2 | **Consent** | **ADD** — *this is a live inaccuracy, not a gap* | `privacy.md:47-48` names **consent (Art. 6(1)(a))** as the basis for analytics/push and `:89` promises an opt-out. **No consent screen, no opt-out, no age gate exists anywhere.** Under GDPR, naming consent and not collecting it means **no legal basis**. `GO_LIVE_MASTER_PLAN.md:81` claims "PR-13 already wired the checkbox" — **it does not exist.** Ship the checkbox + a real analytics toggle, then rewrite the policy to match what ships. |
| I3 | **AI-provider terms** | **ADD** | **No DPA, no zero-retention, and no no-training reference exists for any provider anywhere in the repo** — while you send pet health data and photos that `delete-account/index.ts:9` admits "can contain people/homes." **Verify the Gemini/Anthropic billing tier this week:** consumer/free Gemini tiers may train on inputs, which would make `privacy.md` false in a second, more serious way. |
| I4 | **`diagnosis` in the iOS keyword field** | **REMOVE** — *do this today, it's free* | `ios_app_store.md:39` bids on `diagnosis`; `:34-36` says in writing it *"must never appear in the visible description."* Apple reviews metadata **including keywords**. And in discovery, a repo file documenting the intent to hide the claim from users is not a compliance note — **it's a confession with a git blame.** |
| I5 | **Primary category: Medical** (both stores) | **REPLACE** → **Lifestyle** | You **chose** maximum scrutiny and then wrote copy to survive it. Apple's Medical category is oriented to human health; a pet records app is Lifestyle. *Verify against current Apple category guidance first — miscategorization is its own rejection risk.* |
| I6 | **Age: iOS 4+ / Play Everyone vs. Terms 18+** | **REPLACE** | Your store says "fine for a four-year-old"; your Terms say "you must be 18." A reviewer can read both in one sitting. Drop Terms to 13+ (16+ where GDPR Art. 8 applies), set the rating to **12+**, add the assent checkbox. **A subscription app that shows a dying pet is not 4+.** |
| I7 | **Global store availability** | **SIMPLIFY** → **EN/DE only** | Your safety spine is bilingual and your app is really English (13 localized strings). List where the guarantee holds. A store-console setting. Expand a market when its keyword list exists — never before. |
| I8 | **CI overclaim guard** (`verify-no-placeholders.sh`) | **SIMPLIFY** | `ROOTS=(docs/store_metadata docs/legal web/app)` — **`mobile/lib` is not scanned.** That is precisely why *"Never wonder if your pet needs the vet again"* survived every audit. Add `mobile/lib`. Add `never wonder` to the regex. Add the unqualified `licensed vet` claim from the telehealth CTA (dying with C2 anyway). |
| I9 | **Onboarding headline** *"Never wonder if your pet needs the vet again."* | **REPLACE** | The **first thing a new user reads**, directly contradicting your own disclaimer 3 screens later and the trust pillar *"We inform; your vet decides"* (PRD-02, HIGH). *"Less than $0.33/day"* on the same screen is also a price claim made before any offering loads — and it anchors to your **worse** plan. |
| I10 | **R2 media retention** | **ADD** — *currently nothing exists* | **No TTL, no lifecycle rule, no cleanup cron.** Photos that can contain people, children, and home interiors are kept **forever**, against an unresolved conflict your own schema comment names: *"'store every analysis permanently' vs GDPR erasure is unresolved."* Objects die only on moderation reject or account deletion. **Pick a retention period and enforce it in R2.** |
| I11 | **Governing law / jurisdiction** | **ADD** | `terms.md:65` is literally `[GOVERNING LAW / JURISDICTION]`. **Counsel cannot start without this** — it's the first question they'll ask, and it gates the liability cap, the arbitration clause, and the EU/UK withdrawal wording. |
| I12 | **Divergent `docs/legal/` duplicates** | **REMOVE** | Still marked TEMPLATE, with a **conflicting DPO contact** vs. the live portal (LEG-04). Two published versions of your privacy terms is worse than one imperfect one. Delete the duplicates. |

## J. Everything else

| # | Feature | Decision | Justification |
|---|---|---|---|
| J1 | **Email auth + Sign in with Apple** | **KEEP** | SIWA is mandatory once you offer social login. Needs the missing iOS entitlements file (APPL-01) and the `pawdoc://` scheme (REC-02) — **iOS has never been run at all.** |
| J2 | **5-step onboarding** | **SIMPLIFY** | Structure is good (value → pet → trust → push → activation). Fix I9; drop the push-permission step (H2 removes the need to ask); reduce to **3 steps: value → pet → first check.** |
| J3 | **Trust-signal screen** (*"We inform; your vet decides"*) | **KEEP** | The honest core of the product. Under the reframe it stops being an apology and becomes the pitch. |
| J4 | **Pet CRUD, species chips, soft delete** | **KEEP** | Solid. 7 species incl. exotics is real differentiation (A8). |
| J5 | **2-pet cap on free/trial/premium** | **REMOVE** | Nobody churns *to* you over pet #3. It exists only to sell the Family tier that G4 deletes. |
| J6 | **Reminders** | **SIMPLIFY** | Keep the feature (it's the ambient retention spine — a pet health app is used 3× a year unless something brings you back). Fix: **no edit, delete only**; `_formatTime()` **always renders `''`**; and the *"Tip: Enable notifications"* card has an **"Enable now" button whose handler is an explicit no-op.** Move to local notifications (H2). |
| J7 | **Account + delete-account screens** | **KEEP** | Deletion is real, cascades correctly, purges R2 + third parties, and the copy (*"Your pets (and we) will miss you"*) is lovely. Needs RLS-01 — **which F1 deletes.** |
| J8 | **Offline banner** | **SIMPLIFY** | Home only. Put it on capture/describe too — a user shouldn't discover they're offline *after* submitting (QA-06). C1 makes this much less critical. |
| J9 | **Design system, motion, reduce-motion, Rive avatars** | **KEEP** | Genuinely premium and reduce-motion is honoured everywhere. Under dark-only (H6) it's ~90% done. |
| J10 | **Loading messages** (*"Comparing against common conditions…"*) | **REPLACE** | Rewrite for the new frame. *"Comparing against common conditions"* narrates a diagnosis you're about to stop making. |
| J11 | **Large-screen `maxContentWidth`** (defined, used on 2 of 15 screens) | **SIMPLIFY** | Apply the wrapper everywhere (UX-02). Cheap; the token already exists. |
| J12 | **Text-scale clamp** | **ADD** | Unclamped against fixed-height cards (UX-03). Your audience is older pet owners who use large fonts. |
| J13 | **No integration/e2e layer** | **ADD** | 217 tests, **zero e2e** (ENG-02/QA-02). The safety path is asserted only against mocks. **After the reframe, add one test that fails if any output path can terminate without an action** — that's the invariant the whole company rests on. |
| J14 | **`test-rls.sh` loads a curated subset, ungated in CI** | **REPLACE** | Load **all** migrations; gate in CI (RLS-02/INF-04). This is *why* RLS-01 went unseen — a test that skips the migration containing the bug is worse than no test: it manufactures confidence. |
| J15 | **Dead `auth-webhook` Edge Function** | **REMOVE** | Superseded by the DB trigger; risks accidental redeploy (BE-03). |
| J16 | **49.5MB AAB** (7.4MB unused icons, full-res decodes) | **SIMPLIFY** | PERF-01/02/03. Delete dead assets, add `cacheWidth/cacheHeight`, bundle fonts. |
| J17 | **Debug-signed release build** | **REPLACE** | SEC-01/INF-01/PLAY-01/REC-01. A hard Play rejection — and **every "device-validated / beta-ready" verdict in this repo's history was produced on a build that can never ship.** |

---

## What subtraction buys you

Deleting F1–F5, D3, E11, H1–H4, H6, H8 removes — **without fixing anything**:

| Eliminated | ID | Severity |
|---|---|---|
| Account-deletion 500 via referral FK | **RLS-01** | 🔴 **CRITICAL** |
| Referral loop non-functional | PRD-01 | 🟠 HIGH |
| Light-mode illegibility on 13 screens | UX-01 | 🟠 HIGH |
| Unbounded AI-cost abuse | BE-01 | 🟠 HIGH |
| Referral reward copy contradicts mechanic | PRD-04 | 🟡 MED |
| Onboarding paywall variant dead-ends | PRD-05 | 🟡 MED |
| Bonus-credit counter misreports | SUB-03 | 🟡 MED |
| `ACCESS_FINE_LOCATION` over-declared | PLAY-03 | 🟡 MED |
| OneSignal crash-on-exit | QA-03 | 🟡 MED |
| Google Fonts runtime fetch | ENG-01 / PERF-03 | 🟡 MED |
| Terraform state local + unlocked | INF-03 | 🟡 MED |
| CloudFront TLSv1.0 floor | INF-06 | 🟡 MED |
| Ephemeral CloudFront legal hostname | REC-04 | 🟡 MED |
| Dead-domain share/referral links | REC-03 / UX-04 | 🟡 MED / LOW |
| Play Data Safety scope | PLAY-02 | *materially shrunk* |

**1 CRITICAL + 3 HIGH + ~10 MEDIUM/LOW — gone, not fixed.**

Also gone: **5 tables** (referrals, family_groups, family_members, family_invites, health_journals), **~6 screens**, **5+ Edge Functions**, **3 vendors**, **1 cloud account**, **1 Terraform codebase**, and the entire tier-ladder logic.

**The shortest path to the App Store is the delete key.**

---

*Read from source 2026-07-17 against `feat/legal-portal-integration`. Decisions are product/risk strategy, not legal advice — I2, I3, I5, I6, I10, and I11 belong in front of counsel; A2 belongs there first.*
