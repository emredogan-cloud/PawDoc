# 20 — Paid Acquisition (Phase 4.3)

> Founder runbook for the first paid channels. **Treat campaign #1 as price
> discovery, not scale** (Critical Review #15: the roadmap's $5–12 blended CAC and
> 10% free→paid are optimistic for a consumer health app). The decision metric is
> **LTV:CAC > 3** — do not scale spend until a channel proves it.

## 0. Preconditions
- A **winning onboarding + paywall variant** from Phase 4.2 (don't pay to send
  traffic into a losing funnel).
- App **live in the stores** (gated by the Phase 2.2 legal items + 2.3 submission).
- Landing page live at `pawdoc.app` (this phase) and PostHog receiving events.
- Decide your **LTV** input first (e.g. annual price × gross margin × expected
  retention). CAC target = LTV ÷ 3.

## 1. Apple Search Ads — 5 exact-match keywords
Start with an **exact-match** campaign (tight, cheap, high intent) before broad/
discovery. Suggested seed set (validate volume in the ASA keyword tool, then keep 5):

1. `dog symptom checker`
2. `pet symptom checker`
3. `is my dog sick`
4. `cat symptom checker`
5. `pet first aid`

- One ad group, **exact match**, conservative default CPT bid; set a **daily cap**
  (e.g. $20/day) and a campaign budget cap.
- Turn on **Apple Ads Attribution** (App Store Connect → link to Apple Search Ads)
  so installs attribute to keyword/campaign.
- Add negative keywords for anything off-intent (toys, food, breeders).

## 2. TikTok test — $500 hard cap
- Create a campaign with a **lifetime budget of $500** (hard stop). Objective:
  app installs / conversions.
- 3–5 short UGC-style creatives around the core hook ("Is this a vet emergency?
  Find out in seconds"). **No medical guarantees** in creative.
- Install the TikTok SDK/events or use a MMP; pass a **campaign/UTM** param so
  installs and trials attribute back (see §3).
- Kill creatives below a CTR/CVR floor early; this budget is for **signal**.

## 3. Track CPI / Trial / Subscriber in PostHog (the LTV:CAC proof)
Map the funnel to existing events and segment by channel:

| Funnel step | PostHog event | Source |
|---|---|---|
| Install (proxy) | `onboarding_step_completed` (step 1) / first app open | client |
| Trial start | `trial_started` | client (paywall) |
| Subscriber | `subscription_converted` | client + `revenuecat-webhook` |

- **Attribute channel:** capture the acquisition channel/campaign as a PostHog
  **person property** at first open (from the install referrer / UTM / ASA token)
  so every later event is segmentable by channel.
- **Build a funnel/insight per channel** in PostHog: installs → `trial_started`
  → `subscription_converted`, with counts.
- **Cost comes from the ad platforms** (ASA + TikTok dashboards). Compute per channel:
  - **CPI** = spend ÷ installs
  - **CPT** (cost/trial) = spend ÷ `trial_started`
  - **CPS / CAC** = spend ÷ `subscription_converted`
  - **LTV:CAC** = LTV ÷ CAC  → **must exceed 3** before scaling.
- A/B variant exposure (Phase 4.2 `$feature/...` + `paywall_shown.variant`) lets you
  read conversion **by variant × channel**.

## 4. Stop-loss / scale gate
- Pause any keyword/creative with **CAC > LTV/3** after a meaningful sample.
- Do **not** raise budgets until a channel clears LTV:CAC > 3 on ≥ a few hundred
  installs. Scale the winners only.

## 5. Web deploy (this phase)
The landing + blog are a **static export** (`web/`, `output: 'export'`) on
**Cloudflare Pages** — build `npm run build`, output `out/` (see `web/README.md`).
Verify **Google Search Console** (founder) once the domain is live to track the
SEO articles.

## 6. Sign-off
Channel is "working" only when **LTV:CAC > 3** with real subscriber attribution in
PostHog — not on CPI alone.
