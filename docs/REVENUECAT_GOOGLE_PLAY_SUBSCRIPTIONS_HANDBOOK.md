# PawDoc — RevenueCat + Google Play subscriptions handbook

**Written:** 8 August 2026 · **App:** `app.pawdoc` · **Platform in scope:** Android / Google Play only.

This is an operational manual, not an overview. Everything below is either

- **VERIFIED** — read out of this repository or out of current official
  documentation, with the file or the URL named, or
- **RECOMMENDATION** — a product decision proposed here, not yet true, or
- **INFERENCE** — a conclusion drawn from the two above.

Nothing in this document asserts that a Play Console or RevenueCat dashboard is
configured. **This session could not read either dashboard**, so every statement
about them is a statement about what the *code* requires them to contain.

> **iOS is out of scope.** PawDoc has never been built or run on iOS
> (`memory/…final_production_storeready`), and the App Store half of RevenueCat
> is untouched. Where an iOS-only API is mentioned it is to explain why it is
> *not* used.

---

## Table of contents

1. [Status at a glance](#1-status-at-a-glance)
2. [Current architecture](#2-current-architecture-verified)
3. [Product IDs, base plans, offers](#3-product-ids-base-plans-offers)
4. [Entitlements](#4-entitlements)
5. [Offerings and packages](#5-offerings-and-packages)
6. [Pricing strategy](#6-pricing-strategy)
7. [Trial strategy](#7-trial-strategy)
8. [Win-back strategy — the mechanism, and why](#8-win-back-strategy--the-mechanism-and-why)
9. [Purchase flow](#9-purchase-flow-verified)
10. [Restore flow](#10-restore-flow-verified)
11. [Cancellation, grace period, billing retry](#11-cancellation-grace-period-billing-retry)
12. [Google Play Console setup — button by button](#12-google-play-console-setup--button-by-button)
13. [RevenueCat setup — button by button](#13-revenuecat-setup--button-by-button)
14. [Server-side enforcement and the webhook](#14-server-side-enforcement-and-the-webhook)
15. [Testing](#15-testing)
16. [Release checklist](#16-release-checklist)
17. [Troubleshooting](#17-troubleshooting)
18. [Policy-risk checklist](#18-policy-risk-checklist)
19. [Exact current configuration vs intended future configuration](#19-exact-current-configuration-vs-intended-future-configuration)

---

## 1. Status at a glance

| Area | State |
|---|---|
| RevenueCat SDK integrated in the app | ✅ **IMPLEMENTED NOW** — `purchases_flutter ^10.4.2`, `mobile/pubspec.yaml:69` |
| Purchase, restore, error mapping | ✅ **IMPLEMENTED NOW** — `paywall_screen.dart`, `purchase_error_message.dart` |
| Entitlement webhook + server gates | ✅ **IMPLEMENTED NOW** — `supabase/functions/revenuecat-webhook/`, `_shared/premium.mjs` |
| Second-chance / win-back offer surface | ✅ **IMPLEMENTED NOW** (this change) — `offer_screen.dart` + the five files beside it |
| Weekly / monthly / yearly ladder in the paywall | ✅ **IMPLEMENTED NOW** (this change) — renders whichever the store returns |
| Play Console subscription, base plans, offers | ⛔ **NEEDS CONFIGURATION — EXTERNAL** — no product ID exists anywhere in this repo |
| RevenueCat products / entitlement / offering | ⛔ **NEEDS CONFIGURATION — EXTERNAL** — runbook 09 explicitly stopped before this |
| A real purchase ever completed | ⛔ **NEVER DONE** — Play Billing cannot be tested from a side-loaded APK |
| Named entitlement identifier check in the client | 🟠 **GAP** — see [§4](#4-entitlements) |
| Billing Library 8 (mandatory 31 Aug 2026) | ✅ **SATISFIED** — see [§15.4](#154-billing-library-version) |

---

## 2. Current architecture (VERIFIED)

```
Flutter app                      Google Play                RevenueCat            Supabase
───────────                      ───────────                ──────────            ────────
Purchases.configure(publicKey)
Purchases.logIn(supabase uid) ──────────────────────────────► app_user_id
getOfferings() ─────────────────► base plans + offers ──────► Offering/Packages
purchase(PurchaseParams…) ──────► Play purchase sheet
                                        │
                                        └─ receipt ─────────► validates
                                                                  │
                                                        webhook (Authorization: secret)
                                                                  ▼
                                                          /revenuecat-webhook
                                                                  │  service_role UPDATE
                                                                  ▼
                                                          users.subscription_status
getCustomerInfo() ◄──── entitlement ◄───────────────────────────┘
        │                                                          analyze / assistant-chat /
        └── merged with users.subscription_status ─────────────►  generate-pdf-report gate on it
```

**Two independent sources of truth, merged.** `mobile/lib/src/account/user_profile.dart:51`

```dart
bool get isPremium =>
    premiumTiers.contains(subscriptionStatus) || sdkEntitlementActive;
```

The DB status is webhook-written and survives a reinstall; the SDK entitlement is
device truth and does not wait on the webhook. Neither alone can lock a paying
user out. This is deliberate and predates this change (SUB-02).

**Files that matter**

| File | Role |
|---|---|
| `mobile/lib/main.dart:113-138` | `Purchases.configure`, `logIn(uid)` on sign-in, `logOut` on sign-out |
| `mobile/lib/src/config/env.dart:36` | `Env.hasRevenueCat` — the guard every store call is behind |
| `mobile/lib/src/monetization/paywall_screen.dart` | The paywall: offerings, ladder, purchase, restore |
| `mobile/lib/src/monetization/subscription_state.dart` | "What plan am I on" for the account screen |
| `mobile/lib/src/monetization/subscriber_phase.dart` | *(new)* trial-ended / lapsed / cancelled derivation |
| `mobile/lib/src/monetization/store_offer.dart` | *(new)* reads a tagged Play offer, computes an honest discount |
| `mobile/lib/src/monetization/offer_policy.dart` | *(new)* when an unprompted offer may appear |
| `mobile/lib/src/monetization/offer_screen.dart` | *(new)* the second-chance / win-back surface |
| `mobile/lib/src/monetization/entitlements.dart` | The audited catalogue of what Premium actually changes |
| `supabase/functions/_shared/premium.mjs` | The one server definition of "is premium" |
| `supabase/functions/_shared/revenuecat.mjs` | Webhook event → subscription status |
| `supabase/functions/revenuecat-webhook/index.ts` | Auth, idempotency, the write |

---

## 3. Product IDs, base plans, offers

### 3.1 What exists today

**VERIFIED: nothing.** A search of the whole repository for a subscription
product identifier returns no hit. The app never names one — it asks the
offering for `annual`, `monthly` and `weekly` packages and renders whatever
comes back. That is why the paywall has a *"Premium is not on sale yet"* state
(`paywall_screen.dart` `_PremiumComingSoon`): it is the state the app is in
right now, on every device.

The single historical mention is a **consumable** proposal in
`sub-pr-report/SUBPR_PHASE_6.3.md:243` (`pdf_report_addon`, $4.99). That add-on
was **deleted** in PR #80 when the product moved to one plan. Do not create it.

### 3.2 RECOMMENDATION — the identifiers to create

Play Console product IDs must start with a number or lowercase letter, may
contain lowercase letters, digits, `_` and `.`, and are **permanent** — a
product ID cannot be renamed or reused after deletion. Choose once.

| Level | ID | Notes |
|---|---|---|
| Subscription (product) | `pawdoc_premium` | One product. PawDoc has one plan (`entitlements.dart`). |
| Base plan — yearly | `annual` | Auto-renewing, 1 year |
| Base plan — monthly | `monthly` | Auto-renewing, 1 month |
| Base plan — weekly | `weekly` | Auto-renewing, 1 week |
| Offer — free trial | `intro-trial` on `annual` | Eligibility: **New customer acquisition** |
| Offer — second chance | `second-chance` on `monthly` | Eligibility: **Developer determined**, tags `pawdoc-second-chance`, `rc-ignore-offer` |
| Offer — win-back | `winback` on `monthly` | Eligibility: **Developer determined**, tags `pawdoc-winback`, `rc-ignore-offer` |

**The two tags are load-bearing and are compiled into the app.**
`mobile/lib/src/monetization/store_offer.dart:45-56`:

```dart
const String kWinBackOfferTag      = 'pawdoc-winback';
const String kSecondChanceOfferTag = 'pawdoc-second-chance';
const String kIgnoreOfferTag       = 'rc-ignore-offer';
```

A tag typed differently in the Console — a capital letter, an underscore, a
trailing space — does not produce an error anywhere. It produces an offer screen
that never appears, silently, forever. **Copy and paste them.**

`rc-ignore-offer` is RevenueCat's own tag meaning *never auto-select this offer
as the package's price*. Without it, the ordinary paywall can quietly print the
win-back price to everybody who opens it.
*(Source: RevenueCat, "Google Play Offers".)*

---

## 4. Entitlements

### 4.1 What the app checks today

**VERIFIED — and this is a gap.** Three places ask RevenueCat whether the user
is premium, and all three ask the same way:

```dart
info.entitlements.active.isNotEmpty      // user_profile.dart:86
info.entitlements.active.values.firstOrNull  // subscription_state.dart:79
result.customerInfo.entitlements.active.isNotEmpty  // paywall_screen.dart:128
```

**Any** active entitlement grants Premium. No identifier is named.

- **Today that is harmless**, because RevenueCat will be configured with exactly
  one entitlement.
- **It becomes a defect** the moment a second entitlement is ever added (a
  future tier, an add-on, a promotional grant): every one of them silently
  becomes full Premium.

🟠 **RECOMMENDATION.** Create the entitlement with identifier **`premium`** and,
when a second entitlement is ever contemplated, change these three call sites to
`info.entitlements.active.containsKey('premium')` *first*. Recorded here rather
than changed now, because renaming the check before the dashboard exists would
turn a working merge into a silent `false` for every user — the identifier has
to be created in RevenueCat in the same change.

### 4.2 What "premium" means on the server

`supabase/functions/_shared/premium.mjs` — **VERIFIED**:

```js
export const PREMIUM_STATUSES = new Set(["premium", "trial", "internal_tester"]);
```

- `premium` — a paid, active entitlement.
- `trial` — the store's free-trial phase (`period_type == "TRIAL"`).
- `internal_tester` — a **service-role-only** permanent grant for PawDoc's QA
  account. The client cannot set it: `authenticated` holds no `UPDATE` grant on
  `public.users` at all. The webhook is explicitly forbidden from overwriting it
  (`.neq("subscription_status", INTERNAL_TESTER_STATUS)`).

### 4.3 What Premium actually changes — the whole list

From `mobile/lib/src/monetization/entitlements.dart`, which is the audited
catalogue every premium surface renders. **Exactly four rows change:**

| Capability | Free | Premium | Enforced by |
|---|---|---|---|
| Photo health checks | 5 / month | Unlimited | `_shared/free_tier.mjs` — server, pre-AI |
| Assistant messages | 20 / day | Unlimited | `_shared/assistant_chat.mjs` — server |
| Journal entries | 20 total | Unlimited | `memories/memory.dart` — client |
| PDF health report | — | Included | `generate-pdf-report/index.ts` → HTTP 402 |

**Everything else is identical on both plans**, including emergency help,
symptom checks by text, pets, records, reminders, vet-visit prep, text export
and community. Any listing, screenshot, paywall or offer that implies otherwise
is wrong, and `mobile/test/premium_screens_test.dart` fails the build for a list
of specific inventions (vet chat, money-back, 4.9/5, 1 GB, priority support…).

---

## 5. Offerings and packages

**VERIFIED.** The app reads `offerings.current` and then three well-known
packages:

| Dart | RevenueCat package identifier | Renders as |
|---|---|---|
| `offering.weekly` | `$rc_weekly` | "Weekly" column |
| `offering.monthly` | `$rc_monthly` | "Monthly" column |
| `offering.annual` | `$rc_annual` | "Yearly" column |

`paywall_screen.dart` builds the toggle from **whichever of the three actually
resolved**, so an offering with two packages renders two columns and an offering
with one renders no toggle at all. Nothing is asserted that the store did not
return.

The unprompted offer surface is different: `offer_state.dart` iterates
`offering.availablePackages` and takes the **first package whose store product
carries the tag**, so the founder may attach the win-back offer to any base plan
without touching the app.

**RECOMMENDATION.** One offering, identifier `default`, marked *Current*, with
all three packages. Do not use a second offering for the win-back — the offer
lives on the base plan, not on a parallel offering, and a second offering would
have to be fetched by identifier and kept in sync.

---

## 6. Pricing strategy

### 6.1 The proposed ladder

**RECOMMENDATION — these are targets, not configuration.** No price exists in
Play today.

| Plan | Target (US) | Annualised at that rate | Position |
|---|---|---|---|
| Weekly | $3.99 / week | **52 × $3.99 = $207.48** | Deliberately the expensive way to buy a year |
| Monthly | $16.99 / month | 12 × $16.99 = $203.88 | The reasonable-looking middle |
| Yearly | $49.99 / year | $49.99 | **Best value — 75% less than monthly × 12** |

### 6.2 What the app will and will not say about them

This is the part that matters, and it is enforced in code rather than in a style
guide.

**It will say** — `PaywallPricing.savingsBadge`, `paywall_pricing.dart:37`:

> **Save 75%** on the yearly column

…but **only** when the annual and monthly plans both loaded, are priced **in the
same currency**, the monthly price is positive, and annual genuinely costs less.
Any of those failing hides the badge. The comparison basis is monthly × 12,
which is the comparison a subscriber would actually make.

**It will say** — `PaywallPricing.weeklyAnnualisedNote`, added in this change:

> Billed weekly · **52 weeks at this price is ≈ $207.48**

The multiplier is named so the reader can check it, and 52 weeks is exactly 364
days, so the sentence is true as written. It is a **cost** statement, never a
"you save" statement.

**It will never say:**

- a price that is not `StoreProduct.priceString` — the store's own localized
  string, in the store's own currency;
- a struck-through "original price" that nobody was ever going to be charged;
- a percentage computed across two currencies, or across two different billing
  periods (`store_offer.dart` `discountPercent` refuses both, and
  `offer_eligibility_test.dart` pins it);
- "Save 100%" for a free trial. A free trial is a free trial and says so.

### 6.3 Regional pricing (VERIFIED, official)

Play converts and rounds automatically per country, and prices in other
currencies **will not** be your USD figure converted at spot. This is why the
app never hardcodes a price and never computes one across currencies. Set the US
price, let Play generate the rest, then spot-check Türkiye (the founder's own
storefront) — a prior release shipped a paywall mixing `$39.99` with `₺569,99`
beside a constant "Save 52%", which is exactly what these guards prevent.

### 6.4 Is the decoy arrangement policy-safe? (INFERENCE)

Yes, as built. What Play polices is **misrepresentation** — a price you will not
charge, a discount that is not a discount, a term you do not honour. Presenting
three real, purchasable, accurately-labelled plans in ascending commitment is
ordinary retail. What would not be safe is the version this implementation
refuses: an inflated "was" price, a saving computed against a plan that does not
exist, or an annualised weekly figure presented without its multiplier.

---

## 7. Trial strategy

### 7.1 The hard fact

**VERIFIED: PawDoc has no trial.** There is no PawDoc-run trial period, no local
"trial started on…" record, and no server-side trial clock. The word "trial"
appears in exactly two legitimate places:

1. `subscription_status == 'trial'`, written by the webhook when RevenueCat
   reports `period_type == "TRIAL"` — i.e. **Google Play's** free-trial phase;
2. `PeriodType.trial` on the SDK's entitlement, which
   `subscriber_phase.dart` reads.

Both are the *store's* statement, not PawDoc's. The paywall's trial copy is
gated on `storeProduct.introductoryPrice != null` and says so:

> "Google Play is offering an introductory period on this product. The exact
> terms are shown in the Play purchase sheet before you confirm."

And when there is none:

> "Not on this product today. … PawDoc does not run trials of its own."

### 7.2 To actually have a 7-day trial

Create it as a Play **offer** with a **free trial** phase and eligibility
**New customer acquisition** ([§12.5](#125-create-the-free-trial-offer)). Then,
and only then, does the paywall's trial copy appear — with no code change,
because the app reads it rather than asserting it.

**Consequence for the brief's "after the initial 7-day trial" flow:** until that
offer exists in Play, `SubscriberPhase.trialEnded` can never occur, because no
account can ever hold a `PeriodType.trial` entitlement. The second-chance
surface is built, tested and inert. That is the correct behaviour, not a bug.

---

## 8. Win-back strategy — the mechanism, and why

### 8.1 The mechanisms that were considered

| Candidate | Verdict |
|---|---|
| **Play "win-back offer" eligibility criterion** | ❌ **Does not exist.** Play supports exactly three offer eligibility criteria: *New customer acquisition*, *Upgrade*, *Developer determined*. There is no win-back criterion. |
| **StoreKit win-back offers** (`WinBackOffer`, `getEligibleWinBackOffersForPackage`) | ❌ **iOS only.** The SDK's own doc comment says so verbatim: *"[winBackOffer] iOS only"*. Irrelevant to an Android build. |
| **Play Store "Resubscribe"** | ➖ Real, and already on by default for eligible SKUs for up to one year after expiry — but it is *Google's* surface in the Play subscriptions centre, at full price, and PawDoc cannot put a discount on it. |
| **A separate "win-back SKU"** (a second product at a lower price) | ❌ Rejected. It fragments the catalogue, produces a second entitlement to reason about, and is the pattern Play's offers replaced. |
| **RevenueCat win-back *campaigns*** | ❌ Rejected. Email + a **Web Purchase Link**, i.e. a purchase outside Play billing; it is in beta; and it needs an email programme PawDoc does not run. |
| **A Play offer with *Developer determined* eligibility, found by tag** | ✅ **SELECTED.** |

### 8.2 The selected mechanism, and why

> A Play Console **offer** on the base plan, eligibility **Developer
> determined**, identified by an **offer tag**, fetched from
> `StoreProduct.subscriptionOptions`, purchased with
> `PurchaseParams.subscriptionOption(...)`, with eligibility decided in the app
> from RevenueCat's `CustomerInfo`.

Because it is the only mechanism that is (a) supported on Android today, (b)
purchasable inside Play billing, and (c) able to express "used to subscribe,
does not now".

Google's own documentation describes this exact use: developer-determined
eligibility exists so *"you could define and evaluate if a user is eligible for
second-chance free trials, or win-back offers for lapsed subscribers"*, and it
gives the worked example of *a 50% discount for three months targeting past
subscribers who have previously cancelled.*

### 8.3 The consequence Play hands to us

An offer with *Developer determined* eligibility is **always** returned in
`subscriptionOptions`, for every user, including people who have never
subscribed. Google filters the other two criteria; it does not filter this one.

**So the discount is un-gated unless the app gates it**, which is the entire
reason `subscriber_phase.dart` exists. The gate is:

| Phase | Win-back shown? | Why |
|---|---|---|
| `neverSubscribed` | ❌ | Nothing to win back |
| `inTrial` / `active` | ❌ | Already paying |
| `cancelledStillActive` | ❌ | **Still owns the entitlement — Play will not sell it again.** A discount here is un-purchasable |
| `billingRetry` | ❌ | Access has not stopped; a sales screen is the wrong response to a card problem |
| `trialEnded` | second-chance | A trial ran and did not convert |
| `lapsed` | ✅ win-back | A paid subscription expired |
| `unknown` | ❌ | The store could not be read. Nothing may be claimed |

### 8.4 The 50% claim

`StoreOffer.discountPercent` produces a percentage **only** when the offer's own
paid intro phase and the base plan's full-price phase are in the same currency
and cover the same billing period, and the offer is genuinely cheaper. It is
computed from `Price.amountMicros` — Google's own integers — not from a config
value. If Play returns a 50%-off offer, the badge says `SAVE 50%`. If the
founder changes it to 30% in the Console, the badge says `SAVE 30%` with no app
release. If the arithmetic cannot be done honestly, **there is no badge**.

### 8.5 Countdown: not shipped, and why

`SubscriptionOption` carries an id, tags, and pricing phases. It carries **no
expiry**. The only end date an offer has is the moment a founder deactivates it
in the Console, which the device cannot read.

A timer on this screen could therefore only count down to a moment PawDoc
invented, after which nothing would change. That is the definition of fake
urgency, so no countdown ships, and
`offer_screen_test.dart` asserts the screen does not mutate over five simulated
minutes.

**If a genuine window is ever wanted**, the only honest construction is: the
server issues a per-account offer window, stores it, refuses the discount after
it, and the app *reads* that timestamp. That is a backend feature, not a UI one.

---

## 9. Purchase flow (VERIFIED)

**Ordinary paywall** — `paywall_screen.dart:127`:

```dart
final result = await Purchases.purchase(PurchaseParams.package(pkg));
if (result.customerInfo.entitlements.active.isNotEmpty) { … }
```

**Offer surface** — `offer_screen.dart`:

```dart
final result = await Purchases.purchase(
    PurchaseParams.subscriptionOption(_c.offer.option));
```

⚠️ **The difference is load-bearing.** `PurchaseParams.package(pkg)` buys the
package's *default* option — the base plan. On the offer screen that would
charge full price on a screen that just promised a discount. Only
`PurchaseParams.subscriptionOption` buys the offer being displayed.

After a successful purchase both paths:

1. capture the conversion event,
2. `ref.invalidate(userProfileProvider)` — premium is reflected immediately from
   the SDK, never waiting on the webhook round-trip (SUB-02),
3. show the premium welcome, then pop.

**Store reported success but no entitlement is active** (deferred payment,
pending purchase) is handled explicitly and says so rather than ending in
silence. Errors are mapped to one sentence by `purchase_error_message.dart`; a
user who simply backed out of the Play sheet sees nothing at all.

---

## 10. Restore flow (VERIFIED)

`Purchases.restorePurchases()` on both surfaces, both reachable at all times
(`Key('paywall_restore')`, `Key('offer_restore')`), and both **say what
happened**:

- entitlement found → premium welcome (restored) → pop;
- nothing found → *"No previous purchase found for this store account."*;
- failure → *"Could not restore right now. Please try again."*

Restore was a silent no-op once (SUB-01). It is asserted present on every offer
state by `offer_screen_test.dart`.

---

## 11. Cancellation, grace period, billing retry

### 11.1 What the user does

`openManageSubscription()` (`account/manage_subscription.dart`) prefers
RevenueCat's `managementURL` — which deep-links the exact store account that
purchased — and falls back to
`https://play.google.com/store/account/subscriptions`. This is the single
biggest support-ticket class and it is one tap from Account.

### 11.2 What the app shows

`SubscriptionSnapshot` (`subscription_state.dart`) reads `willRenew`,
`expirationDate`, `periodType` and `billingIssueDetectedAt`, and the plan card
labels the date **according to `willRenew`** — a next billing date when it
renews, an access-end date when it does not. Getting that backwards after a
cancellation is the defect that shape exists to prevent.

### 11.3 What the server does

`_shared/revenuecat.mjs` — **VERIFIED**:

| RevenueCat event | `subscription_status` written |
|---|---|
| `INITIAL_PURCHASE`, `RENEWAL`, `UNCANCELLATION`, `PRODUCT_CHANGE` | `trial` if `period_type == "TRIAL"`, else `premium` |
| `EXPIRATION` | `free` |
| `CANCELLATION` | **no change** — access runs to the end of the paid period |
| `BILLING_ISSUE`, `TRANSFER`, anything else | **no change** |

`CANCELLATION` deliberately writes nothing. Cancelling is a statement about the
*next* charge; access continues, and stripping it early would be taking away
something already paid for.

**Grace period / account hold** are Play-side settings ([§12.7](#127-set-grace-period-and-account-hold)).
While Play retries, the entitlement stays active and RevenueCat sets
`billingIssueDetectedAt`, which surfaces as `SubscriberPhase.billingRetry` — a
state in which **nothing is sold**: the right response to a failed card is to
say so, not to open a paywall.

---

## 12. Google Play Console setup — button by button

> **Prerequisite:** the app must have at least one release (any track) containing
> the Play Billing Library before Monetize → Products becomes usable, and
> `app.pawdoc` must be the uploaded package name.
>
> **Everything in this section is FOUNDER-ONLY.** No agent can perform it.

### 12.1 Confirm billing is enabled

1. **Play Console** → select **PawDoc** (`app.pawdoc`)
2. Left nav → **Monetize with Play** → **Products** → **Subscriptions**
3. **Verify:** the page loads a "Create subscription" button rather than a
   *"Your app doesn't use Google Play's billing system"* notice.
   - **If it shows the notice:** you have not yet uploaded a build containing
     the Billing Library to any track. Upload the AAB to Internal testing first.

### 12.2 Create the subscription

1. **Monetize with Play → Products → Subscriptions → Create subscription**
2. **Product ID** → enter exactly: `pawdoc_premium`
   - *Why:* one product, because PawDoc has one plan. **Permanent** — it cannot
     be renamed, and cannot be reused after deletion.
3. **Name** → `PawDoc Premium`
   - *Why:* user-visible in the Play subscriptions centre. 55 characters max.
4. **Create**
5. On the subscription page → **Edit subscription details**
6. **Benefits** → add up to four, each ≤ 40 characters. Use only real ones:
   - `Unlimited photo health checks`
   - `Unlimited assistant messages`
   - `Unlimited journal entries`
   - `PDF health report`
   - ⚠️ **Do not** write "vet chat", "priority support", "unlimited storage" or
     anything else absent from `entitlements.dart` — these strings appear in the
     Play UI and are a listing claim like any other.
7. **Save changes**
8. **Verify:** the subscription shows status *Inactive* with 0 base plans. That
   is expected.

**Common mistake:** creating three *subscriptions* (weekly / monthly / yearly)
instead of three *base plans* under one subscription. Three subscriptions means
three products, three entitlement mappings, and a user who "upgrades" ends up
holding two. Use one subscription, three base plans.

### 12.3 Create the three base plans

Repeat for each row:

| Base plan ID | Type | Billing period |
|---|---|---|
| `annual` | Auto-renewing | 1 year |
| `monthly` | Auto-renewing | 1 month |
| `weekly` | Auto-renewing | 1 week |

1. On `pawdoc_premium` → **Add base plan**
2. **Base plan ID** → e.g. `annual` — **permanent**, unique within the
   subscription
3. **Type** → **Auto-renewing**
   - *Why not Prepaid:* prepaid does not renew, so there is nothing to win back
     and no `willRenew` to read. *Why not Installments:* not available in most
     markets and irrelevant at this price.
4. **Billing period** → `1 year` / `1 month` / `1 week`
5. **Grace period** → see [§12.7](#127-set-grace-period-and-account-hold)
6. **Tags** → leave empty on base plans. Tags are how the app finds *offers*; a
   tag on a base plan would be matched by nothing (`findTaggedOffer` skips
   `isBasePlan`) and only creates confusion.
7. **Set prices** → **Manage country/region availability** → select the
   countries you sell in (start: all, or your target set)
8. Enter the price for one anchor country, then **Apply** Play's suggested
   conversions for the rest
   - `annual` → **$49.99**, `monthly` → **$16.99**, `weekly` → **$3.99** (US)
9. **Save** → **Activate**
10. **Verify:** the base plan shows **Active**. An inactive base plan is
    invisible to `getOfferings()` and produces the app's "not on sale yet"
    screen with no error anywhere.

### 12.4 Set the tax and compliance fields

1. On `pawdoc_premium` → **Edit subscription details** → **Tax and compliance**
2. **Tax category** → leave the default (standard digital goods) unless an
   accountant says otherwise.
3. **Verify:** no warning banner remains on the subscription page.

### 12.5 Create the free-trial offer

*(Only if a trial is wanted — [§7](#7-trial-strategy).)*

1. `pawdoc_premium` → base plan **`annual`** → **Add offer**
2. **Offer ID** → `intro-trial`
3. **Eligibility criteria** → **New customer acquisition** → *"has never had
   entitlement to this subscription"*
   - *Why:* Google evaluates it, and ineligible users never see the offer in
     `subscriptionOptions` at all. That is exactly the semantics wanted, and it
     is the one place we should *not* be deciding eligibility ourselves.
4. **Tags** → leave empty.
   - *Why:* this offer **should** be auto-applied to the package price, so the
     paywall's `introductoryPrice != null` check lights up the trial copy.
     Adding `rc-ignore-offer` here would suppress the trial the whole flow
     depends on.
5. **Add phase** → **Free trial** → **7 days**
6. **Countries** → the same set as the base plan (a subset is allowed, never a
   superset)
7. **Save** → **Activate**
8. **Verify:** open the paywall on a device signed in with a *fresh* Google
   account. The `INTRO OFFER` chip and the *"Google Play is offering an
   introductory period"* copy must appear. If they do not, the offer is not
   Active, or the test account has held this subscription before.

### 12.6 Create the win-back and second-chance offers

**This is the mechanism from [§8](#8-win-back-strategy--the-mechanism-and-why).
Get the tags exactly right.**

**Win-back:**

1. `pawdoc_premium` → base plan **`monthly`** → **Add offer**
2. **Offer ID** → `winback`
3. **Eligibility criteria** → **Developer determined**
   - *Why:* Play has no win-back criterion. This is the only criterion that lets
     the app decide, and `subscriber_phase.dart` is the decision.
   - ⚠️ *Consequence:* this offer is returned to **every** user, including
     people who never subscribed. The app must gate it, and does.
4. **Tags** → add **two**, one at a time, exactly:
   - `pawdoc-winback`
   - `rc-ignore-offer`
5. **Add phase** → **Discounted recurring payments**
   - **Price override** → **Percentage discount** → **50%**
   - **Duration** → **3** billing periods
   - *Result:* Play returns `$8.49/month × 3, then $16.99/month`, and
     `StoreOffer.discountPercent` computes **50** from those two integers.
6. **Countries** → same set as the base plan
7. **Save** → **Activate**

**Second chance:** identical, except **Offer ID** `second-chance`, tag
`pawdoc-second-chance` (+ `rc-ignore-offer`), and a phase appropriate to a
trial that did not convert (a shorter discount, or a second free trial).

8. **Verify (the only reliable way):** with a license-tester account that has
   let a subscription expire, open the app. `offerCandidateProvider` must
   produce a candidate and the offer screen must appear on the first launch
   after expiry. There is no dashboard readout for this.

**Common mistakes, all silent:**

| Mistake | Symptom |
|---|---|
| Tag typed `pawdoc_winback` (underscore) | Offer screen never appears. No error. |
| `rc-ignore-offer` omitted | The 50% price leaks onto the ordinary paywall for everyone |
| Eligibility set to *New customer acquisition* | Play hides the offer from the lapsed users it is for — the exact inverse of the intent |
| Offer left *Draft* | Not returned by `getOfferings()` |
| Offer countries ⊂ base plan countries, and your tester is outside | Offer invisible to that tester only |

### 12.7 Set grace period and account hold

1. `pawdoc_premium` → each base plan → **Grace period**
2. Choose a duration (Play's default is a sensible start).
   - *Why it matters here:* during grace the entitlement stays **active** and
     RevenueCat reports `billingIssueDetectedAt`. PawDoc reads that as
     `SubscriberPhase.billingRetry` and shows **no** sales surface.
3. **Account hold** is applied by Play after grace. During hold the entitlement
   is inactive → the account becomes `lapsed` → the win-back surface becomes
   eligible. That is intended.

### 12.8 Add license testers

1. Play Console → **(top-left, all-apps view)** → **Settings** → **License
   testing**
2. **License testers** → add the Google accounts that will test purchases
3. **License response** → `RESPOND_NORMALLY`
4. **Save changes**
5. **Verify:** on a device signed in with that account, the Play purchase sheet
   shows *"Test card, always approves"*.

⚠️ **VERIFIED, and it has bitten this project before:** Play Billing **cannot**
be tested from a side-loaded APK. A build installed over ADB returns
`DEVELOPER_ERROR` by design. The build must be **downloaded from Play** on an
Internal-testing track, signed with the app-signing key.

---

## 13. RevenueCat setup — button by button

**Prerequisite:** runbook `docs/runbooks/09-revenuecat-project.md` created the
project and registered both app identifiers, and deliberately stopped there. This
section is everything it deferred.

### 13.1 Link the Google Play service account

1. **app.revenuecat.com** → project **PawDoc** → **Apps** → the **Google Play**
   app (`app.pawdoc`)
2. Field **Service Account credentials JSON** → upload the JSON for a Google
   Cloud service account that has been granted access in Play Console
   (Play Console → **Users and permissions** → **Invite new users** → the
   service-account email → app permissions: **View financial data** and
   **Manage orders and subscriptions**)
   - *Why:* without it RevenueCat cannot validate purchases or receive real-time
     developer notifications, and every purchase silently fails validation.
3. **Save**
4. **Verify:** the app row shows a green/valid credentials state, not a warning.
   Google can take up to ~36 hours to propagate a newly granted permission — a
   validation failure immediately after granting is expected and not a
   misconfiguration.

> The repository root contains `pawdoc-prod-109678c4897b.json`, a Google service
> account key, **untracked and gitignored**. It is the likely candidate. Do not
> ever `git add -A` in this repository.

### 13.2 Import the products

1. Project → **Product catalog** → **Products** → **+ New**
2. **Store** → **Play Store** → **App** → `app.pawdoc`
3. Add one product row per **base plan**, using the `product:base_plan` form:
   - `pawdoc_premium:annual`
   - `pawdoc_premium:monthly`
   - `pawdoc_premium:weekly`
4. **Save**
5. **Verify:** each product resolves and shows its price. A product that shows
   *"not found"* is inactive in Play, in a country your account cannot see, or
   was created less than a few minutes ago.

### 13.3 Create the entitlement

1. Project → **Product catalog** → **Entitlements** → **+ New**
2. **Identifier** → `premium`
   - *Why this exact string:* see [§4.1](#41-what-the-app-checks-today) — the
     client does not name it today, but every future check should, and the
     server's `PREMIUM_STATUSES` already uses the word.
3. **Description** → `Full PawDoc Premium access`
4. **Attach products** → all three `pawdoc_premium:*` rows
5. **Verify:** the entitlement lists three attached products. **An entitlement
   with no products attached is the single most common cause of "the purchase
   succeeded but the user is not premium".**

### 13.4 Create the offering and packages

1. Project → **Product catalog** → **Offerings** → **+ New**
2. **Identifier** → `default` · **Description** → `PawDoc Premium`
3. Open it → **+ New package** three times:

   | Package identifier | Attach product |
   |---|---|
   | `$rc_annual` | `pawdoc_premium:annual` |
   | `$rc_monthly` | `pawdoc_premium:monthly` |
   | `$rc_weekly` | `pawdoc_premium:weekly` |

   - *Why the `$rc_` identifiers:* they are what populate `offering.annual`,
     `.monthly` and `.weekly` in the SDK, which is what `paywall_screen.dart`
     reads. A custom identifier would resolve to null there and the column would
     not render.
4. Offerings list → set `default` as **Current**
   - *Why:* the app reads `offerings.current`. An offering that is not current is
     invisible to it.
5. **Verify:** **Product catalog → Offerings → default** shows three packages,
   each with a resolved price, and the *Current* badge.

### 13.5 Configure the webhook

1. Project → **Integrations** → **Webhooks** → **+ New**
2. **Webhook URL** →
   `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`
3. **Authorization header value** → the exact value of Doppler's
   `REVENUECAT_WEBHOOK_SECRET`
   - *Why:* `revenuecat-webhook/index.ts` compares this in **constant time** and
     returns `401` on mismatch. An unsigned webhook must never be able to grant
     premium (CR #21). A plain `!==` would leak the secret through response
     timing, which is why `timingSafeEqual` is used.
4. **Environment** → send both Sandbox and Production while testing
5. **Save**
6. **Verify:** RevenueCat's **Send test event** returns **200** with body
   `{"ok":true,...}`. A `401` means the header value does not match Doppler; a
   `400 no app_user_id` on a synthetic test event is acceptable and still proves
   authentication passed.

### 13.6 Record the public SDK key

The Android public SDK key is injected at build time as
`--dart-define=REVENUECAT_PUBLIC_SDK_KEY=…` (`env.dart:17`). Doppler holds it as
`REVENUECAT_PUBLIC_SDK_KEY_ANDROID`; the build must map one to the other.

**Verify:** with the key absent, `Env.hasRevenueCat` is false and every store
call is skipped — the paywall shows "not on sale yet" and the offer surface
never appears. That is a correct build, not a broken one, and it is what CI
builds.

---

## 14. Server-side enforcement and the webhook

**VERIFIED — this is the half a client cannot fake.**

1. **`revenuecat-webhook`** authenticates (constant-time secret compare), claims
   `event.id` in `processed_rc_events` **before** applying anything (a duplicate
   delivery hits `23505` and is skipped), maps the event, and writes
   `users.subscription_status` + `users.revenuecat_user_id` with the service
   role — never touching an `internal_tester` row. On a failed write it
   *releases* the idempotency claim so RevenueCat's retry can succeed.

2. **`_shared/premium.mjs`** is the one definition of premium, imported by
   `analyze`, `assistant-chat` and `generate-pdf-report`.

3. **The quota gate runs pre-AI and server-side.** A client that lies about its
   plan gets a 402, not a free analysis.

4. **Emergency bypasses the gate entirely**, server-side and client-side. A
   `GET_HELP_NOW` result is never paywalled on any plan, and no offer surface
   may follow one (`offer_policy.dart`).

⚠️ `verify_jwt` is disabled on this function because RevenueCat calls it without
a user JWT. The shared secret is therefore the *only* thing standing between the
public internet and a `service_role` write to `users`. Rotate it if it is ever
pasted anywhere.

---

## 15. Testing

### 15.1 What is automated (runs in CI)

| Suite | Covers |
|---|---|
| `mobile/test/offer_eligibility_test.dart` | 44 tests: phase derivation from every store state, eligibility in every phase, cooldown/cap, tag matching, discount arithmetic (incl. cross-currency and cross-period refusals), the annualised-weekly formatter, recommendation branches |
| `mobile/test/offer_screen_test.dart` | 15 tests: both surfaces, dates, terms, restore/close always present, renewal disclosure, dark-pattern page scan, "the screen does not mutate over time" |
| `mobile/test/paywall_policy_test.dart` | The original paywall trust rule |
| `mobile/test/paywall_pricing_test.dart` | Savings badge |
| `mobile/test/premium_screens_test.dart` | The product-truth scan over all four premium surfaces |
| `node --test supabase/functions/_shared/*.test.mjs` | Webhook event mapping, premium status set |

### 15.2 What cannot be automated

**A real purchase.** No emulator, no CI, no unit test. It requires:

1. an AAB uploaded to **Internal testing**,
2. **downloaded from Play** on a physical device (a side-loaded APK returns
   `DEVELOPER_ERROR` — verified on this project),
3. signed in as a **license tester**,
4. products **Active** in a country that account can buy in.

### 15.3 The manual matrix (FOUNDER)

| # | Case | Expected |
|---|---|---|
| 1 | Fresh account opens the paywall | Three columns; prices from the store; "Save N%" on Yearly only if computable |
| 2 | Buy the annual plan | Play sheet → premium welcome → `users.subscription_status = 'premium'` within seconds |
| 3 | Reinstall, sign in, do nothing | Still premium (webhook-written status) |
| 4 | Reinstall, tap Restore | Premium welcome (restored) |
| 5 | Cancel in Play, reopen the app | Plan card shows the **access-end** date, not a billing date. **No offer screen** |
| 6 | Let it expire, reopen | Win-back screen once. `SAVE 50%` matches the Console. Terms sentence matches the Play sheet |
| 7 | Dismiss it, reopen the app the same day | **No screen** (cooldown) |
| 8 | Reopen after 7 days, ×3 | Shown on the 2nd and 3rd; **never a 4th time** |
| 9 | Buy from the win-back screen | Charged the **offer** price, not the base price |
| 10 | Airplane mode, open the app | No offer screen; no crash; paywall shows "not on sale yet" |
| 11 | Sign out, sign in as another account | Prompt history cleared; the new account's own phase applies |
| 12 | Emergency check, then any surface | No offer, no paywall, ever |
| 13 | Internal tester account | Premium; no offer surface; webhook `EXPIRATION` does **not** strip it |

### 15.4 Billing Library version

**VERIFIED, and time-critical.** Google requires **Billing Library 8 or later**
for all new apps and all updates from **31 August 2026** (extension available to
1 November 2026 on request).

`purchases_flutter` 10.4.x selects the `bc8` variant of `purchases-android`:

```gradle
// ~/.pub-cache/…/purchases_flutter-10.4.3/android/build.gradle:53
missingDimensionStrategy 'billingclient', 'bc8'
```

✅ **PawDoc satisfies the requirement as configured.** Confirm on the next
release build by inspecting the merged dependency tree, and do not downgrade
`purchases_flutter` below 10.x.

Also due the same day: **target API level 36**. `mobile/android/app/build.gradle.kts:42`
uses `flutter.targetSdkVersion`, which is **36** in the pinned Flutter 3.41.9
(`FlutterExtension.kt:34`). ✅ Satisfied.

---

## 16. Release checklist

**Engineering** (all ✅ at the time of writing unless noted)

- [x] `flutter analyze` clean
- [x] `flutter test` green
- [x] `node --test supabase/functions/_shared/*.test.mjs` green
- [x] No price, discount, trial length or renewal term hardcoded in any Dart file
- [x] Billing Library 8 · target API 36
- [ ] 🟠 Name the entitlement identifier in the three client checks — *do this in
      the same change that creates `premium` in RevenueCat* ([§4.1](#41-what-the-app-checks-today))

**Play Console** (founder)

- [ ] `pawdoc_premium` created; three base plans **Active**; prices set per country
- [ ] Offers created with the **exact** tags; eligibility **Developer determined**
- [ ] Grace period configured
- [ ] License testers added, `RESPOND_NORMALLY`
- [ ] Benefits text contains only real capabilities

**RevenueCat** (founder)

- [ ] Play service-account credentials valid
- [ ] Three products imported and resolving a price
- [ ] Entitlement `premium` created **with all three products attached**
- [ ] Offering `default` **Current**, with `$rc_annual` / `$rc_monthly` / `$rc_weekly`
- [ ] Webhook returns 200 on a test event

**Device** (founder)

- [ ] One real purchase and one restore, from a Play-downloaded build
- [ ] The full manual matrix in [§15.3](#153-the-manual-matrix-founder)

---

## 17. Troubleshooting

| Symptom | First thing to check |
|---|---|
| Paywall shows "Premium is not on sale yet" | Offering not **Current**; or products not attached to packages; or base plans not **Active**; or the build has no `REVENUECAT_PUBLIC_SDK_KEY` |
| Paywall sits on "Asking your store for prices…" | It cannot any more — the call is timeout-bounded and skipped when unconfigured. If it happens, `Env.hasRevenueCat` is true with a *wrong* key |
| Purchase succeeds, user is not premium | **Entitlement has no products attached** (most common). Then: webhook 401, or `logIn(uid)` never ran so `app_user_id` is an anonymous RevenueCat id |
| `DEVELOPER_ERROR` on purchase | Side-loaded build. Download from Play. Also check the account is a license tester and the products are Active |
| Webhook returns 401 | Header value ≠ `REVENUECAT_WEBHOOK_SECRET` in Doppler. Both bare and `Bearer <secret>` are accepted; nothing else is |
| Webhook 200 but `{"changed":false}` | The event was `CANCELLATION`/`BILLING_ISSUE` (no status change by design), or a duplicate delivery (`idempotent: true`) |
| Offer screen never appears | In order: is the account genuinely `lapsed`? is the offer **Active**? is the tag byte-identical? is `rc-ignore-offer` also present? has the 3-show cap been spent? is the cooldown running? |
| The win-back price shows on the ordinary paywall | `rc-ignore-offer` missing from the offer's tags |
| "Save N%" never appears | The two plans are in different currencies, or the annual plan is not actually cheaper than monthly × 12 |
| Wrong currency in a comparison | It cannot happen — every comparison refuses mismatched currencies. If a *single* price looks wrong, it is Play's regional price, not the app's |
| Subscription tile inert / screen hangs | The classic unconfigured-SDK hang. Every call in this codebase is now behind `Env.hasRevenueCat` **and** a timeout; a new one must be too |

---

## 18. Policy-risk checklist

Run before any release that touches monetization.

| Check | Where it is enforced |
|---|---|
| No fake urgency — no countdown, no timer | `offer_policy.dart` (documented refusal) + `offer_screen_test.dart` (asserts no mutation over time) |
| No fake scarcity — no "spots left", "selected" | `offer_screen_test.dart` dark-pattern scan |
| No fake personalization | `offer_recommendation.dart` — a null counter says so; it never becomes a zero |
| No fake authority — no vet, no clinician, no person | `offer_eligibility_test.dart` phrase scan |
| Renewal terms adjacent to the purchase CTA | `_OfferLegal` / `_SubscriptionLegal`, asserted present |
| Cancellation path stated and reachable | Paywall FAQ + `openManageSubscription()` |
| Price comparisons true and same-basis | `savingsBadge`, `discountPercent` — both refuse rather than approximate |
| No unconfigured product presented as purchasable | `findTaggedOffer` → null → the surface does not exist |
| Emergency never paywalled | Server (`analyze`) + `paywall_policy.dart` + `offer_policy.dart` |
| Only real capabilities named | `entitlements.dart` + `premium_screens_test.dart` |
| Restore always reachable | Asserted on every offer state |

---

## 19. Exact current configuration vs intended future configuration

### IMPLEMENTED NOW

- RevenueCat SDK wired, `app_user_id` = Supabase uid, logout dissociation.
- Paywall: offerings read, weekly/monthly/yearly ladder, savings badge,
  annualised weekly note, purchase, restore, error mapping, legal disclosure,
  "not on sale yet" state, trial copy gated on the store.
- Second-chance / win-back: phase derivation, eligibility with cooldown and
  lifetime cap, tag-based offer lookup, honest discount arithmetic, the screen,
  the single trigger in `RootShell`, prompt history cleared on sign-out.
- Webhook: authenticated, idempotent, `internal_tester`-safe.
- Server gates on `analyze`, `assistant-chat`, `generate-pdf-report`.
- 59 new automated tests; **1098** in the mobile suite overall (was 1039).

### NEEDS CONFIGURATION (external, founder-only — **BLOCKED**)

- Play: `pawdoc_premium`, three base plans, prices per country, the three offers
  with exact tags, grace period, license testers.
- RevenueCat: service-account credentials, three products, entitlement
  `premium`, offering `default` with three `$rc_` packages, webhook.
- One real purchase + one restore on a Play-downloaded build.

### PLANNED / NOT YET IMPLEMENTED

- Naming the entitlement identifier in the three client checks ([§4.1](#41-what-the-app-checks-today)).
- A genuinely enforced, server-issued offer window, if a countdown is ever
  wanted ([§8.5](#85-countdown-not-shipped-and-why)).
- iOS: nothing. Never built, never run.

---

## Sources

Official documentation consulted 8 August 2026:

- [Understanding subscriptions — Play Console Help](https://support.google.com/googleplay/android-developer/answer/12154973) (offer eligibility criteria)
- [Create and manage subscriptions — Play Console Help](https://support.google.com/googleplay/android-developer/answer/140504) (Console fields and steps)
- [About subscriptions — Play Billing](https://developer.android.com/google/play/billing/subscriptions) (product/base plan/offer model, resubscribe)
- [Google Play Billing Library version deprecation](https://developer.android.com/google/play/billing/deprecation-faq) (BL8 by 31 Aug 2026)
- [RevenueCat — Google Play Offers](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers/google-play-offers) (`subscriptionOptions`, `rc-ignore-offer`)
- [RevenueCat — Google Play Product Setup](https://www.revenuecat.com/docs/getting-started/entitlements/android-products)
- [RevenueCat — Win-back campaigns](https://www.revenuecat.com/docs/web/winback-campaigns) (beta; web purchase links)
- `purchases_flutter` 10.4.3 source, read locally from the pub cache.
