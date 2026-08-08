# PawDoc — Google Play production questionnaire

**Written:** 8 August 2026 · **App:** `app.pawdoc` · **Track:** production.

Every Console declaration PawDoc must complete, with the recommended answer, the evidence in
the code for that answer, and what has to change if the code does not support it.

**How to use it.** The Play Console's own **Policy → App content** page has a *"Needs
attention"* tab, and **that list is authoritative** — Google adds and retires declarations
without notice. Work from the Console's list, and use this document for the *answers*.
Anything below marked ⚠️ is a judgement call, not a fact; read the reasoning before
answering.

**Nothing here guarantees approval.** Play review is discretionary; a well-founded answer
reduces risk, it does not remove it.

---

## 0 · Facts every answer below depends on

Read out of the repository on 8 August 2026.

| Fact | Value | Source |
|---|---|---|
| Package name | `app.pawdoc` | `android/app/build.gradle.kts:40` |
| Target SDK | **36** | `flutter.targetSdkVersion`, Flutter 3.41.9 |
| Version | `1.0.0+5` | `mobile/pubspec.yaml:19` |
| Permissions requested | `INTERNET`, `CAMERA`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `ACCESS_COARSE_LOCATION` | `AndroidManifest.xml` |
| Permissions explicitly **removed** | `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` | same, `tools:node="remove"` |
| Advertising ID | **not used** — no `AD_ID` permission, no ad SDK | manifest + `pubspec.yaml` |
| Ads | **none**, on either plan | `entitlements.dart` |
| Account required | Yes, but **guest (anonymous) sign-in** is offered | `auth_controller.dart:133` |
| Account deletion | In-app, full cascade | `delete-account/index.ts` |
| Legal pages | Live at `https://d1klm6zb1x23me.cloudfront.net` (CloudFront) | `config/legal_urls.dart:19` |
| Third parties receiving data | Supabase (DB/auth), Cloudflare R2 (media), Fly.io (AI service), Google Gemini + Anthropic (model inference), Sentry (crashes), PostHog (analytics), RevenueCat (purchases) | `CLAUDE.md`, `ENVIRONMENT_SETUP.md` |
| Push vendor | **none** — notifications are local, on-device, 09:00 local | `notifications/` |

---

## 1 · App access

**Console:** Policy → App content → **App access**

**Question:** *Is all or part of your app restricted based on log-in credentials or other
forms of authentication?*

**Answer: "All or some functionality is restricted."** Then provide instructions.

**Why.** PawDoc's core flows require an account. A reviewer who cannot sign in will see a
gateway and nothing else, and *"the reviewer could not access the app"* is one of the most
common rejection reasons there is.

**What to enter** — one instruction set:

| Field | Value |
|---|---|
| Name | `Full app — email sign-in` |
| Username | *(founder to create a real reviewer account)* |
| Password | *(founder)* |
| Any other instructions | See the block below |

```
PawDoc is a pet-health record and triage app.

Sign in with the email and password above, or tap "Get started" on the
welcome screen to continue as a guest — guest mode is a real anonymous
account and reaches every screen except purchase.

To reach the main features:
1. Add a pet when prompted (name + species is enough).
2. Home > the centre "New check" button > "Describe symptoms" > type
   "not eating for two days" > Submit. This produces a triage result.
3. The red "Emergency" tab works with no account and with no network
   connection. Airplane mode is a valid way to test it.
4. Health tab > the pet's timeline shows the saved check.

There is no separate demo mode and no test code to enter.
```

⚠️ **What must change if this is wrong.** The founder must actually create the account, sign
in with it once, and confirm it has at least one pet. An empty account lands the reviewer on
an onboarding screen with no content behind it. Do **not** give the reviewer the
`internal_tester` QA account unless a Premium walkthrough is wanted — it carries a permanent
Premium grant, which makes the free-tier experience untestable.

---

## 2 · Ads

**Console:** Policy → App content → **Ads**

**Question:** *Does your app contain ads?*

**Answer: No.**

**Evidence.** No ad SDK in `pubspec.yaml`; no `AD_ID` permission; `entitlements.dart` lists
no ad-related row on either plan; the paywall's assurance strip states *"No ads. No data
sale."*

**Consequence if wrong.** An undeclared ad SDK is a policy violation. Re-answer this if any
mediation, offerwall or sponsored content is ever added.

---

## 3 · Content rating

**Console:** Policy → App content → **Content rating** → complete the IARC questionnaire

**Answers to the questions that actually apply:**

| IARC question | Answer | Why |
|---|---|---|
| Category | **Reference, News, or Educational** | PawDoc is an information + record-keeping tool. *(The store listing category is separately set to Lifestyle — evolution decision I5.)* |
| Violence, sexuality, language, controlled substances, gambling | **No** to all | None present |
| Does the app share the user's location with other users? | ⚠️ **Yes** | Community shows an **approximate** distance derived from a 5-char geohash cell (~4.9 km) to other opted-in members. It is opt-in and coarse, but it is user-to-user. Answering "no" would contradict Data safety. |
| Does the app allow users to interact or exchange content? | **Yes** | Community: connection requests and 1:1 message threads |
| Is there user-generated content that is publicly visible? | **No** | ⚠️ Important: PawDoc has **no public post feed and no comment box.** Content is 1:1 between connected members. |
| Digital purchases | **Yes** | Subscriptions |

**Expected outcome.** Teen / PEGI 12-equivalent, consistent with the Terms' 13+ minimum
(`web-legal/content/terms.md`) and with what `docs/store_metadata/google_play.md` already
records.

⚠️ **VERIFIED, and time-sensitive:** as of the **15 July 2026** policy update, *"unrated apps
are no longer permitted on Google Play."* This questionnaire is not optional.

---

## 4 · Target audience and content

**Console:** Policy → App content → **Target audience and content**

| Question | Answer | Why |
|---|---|---|
| Target age groups | **18 and over** only | The Terms set a 13+ minimum, but the app takes payment, offers 1:1 messaging and approximate-distance discovery. Selecting any under-18 band pulls PawDoc into **Families** policy — designed-for-families requirements, ad-content restrictions, and a far stricter data regime. There is no product reason to accept that. |
| Could the app unintentionally appeal to children? | **No** | Nothing is styled for children; the subject is adult pet ownership |
| Store listing appeals to children? | **No** | The listing copy and assets are adult-directed |

**What must change if you answer otherwise.** Selecting an under-13 band would require a
Families-policy review, verified parental-consent handling, and would make the community
features and the geohash cell very hard to justify.

---

## 5 · Data safety

**Console:** Policy → App content → **Data safety**

This is a **binding declaration** and the single item most likely to contradict something
else. Every screenshot, every line of the store description and every in-app privacy claim
must agree with the table below.

### 5.1 Global answers

| Question | Answer | Evidence |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Below |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Supabase, R2, Fly.io and every SDK are HTTPS/TLS only |
| Do you provide a way for users to request that their data be deleted? | **Yes** | In-app: Account → Delete account. Also a web route at `/deletion` |

### 5.2 The data table

*Collected* = leaves the device. *Shared* = transferred to a third party that is **not**
processing it on PawDoc's behalf.

| Data type | Collected | Shared | Required? | Purpose | Evidence |
|---|---|---|---|---|---|
| **Email address** | Yes | No | Optional¹ | Account management | Supabase auth |
| **User IDs** | Yes | No | Required | Account management, analytics, crash logs | Supabase uid; RevenueCat `app_user_id` = the same uid |
| **Name** | Yes | No | Optional | App functionality | `community_profiles.display_name`, only when community is joined |
| **Approximate location** | **Yes** | No | Optional | App functionality (nearby-owner discovery) | ⚠️ `community_onboarding_screen.dart:79` coarsens a fix to a 5-char geohash cell (~4.9 km) and stores it in `community_profiles.geohash`. **Precise location is never collected and `ACCESS_FINE_LOCATION` is not declared.** Smart Walks uses coordinates on-device only and stores nothing |
| **Photos** | Yes | No | Optional | App functionality | Uploaded to Cloudflare R2 via a short-lived presigned PUT. **EXIF/GPS is stripped client-side before upload** |
| **Videos** | Yes | No | Optional | App functionality | Same path |
| **Other user-generated content** | Yes | No | Optional | App functionality | Pet profiles, symptom descriptions, health records, journal entries, assistant messages, community messages |
| **Purchase history** | Yes | No | Optional | App functionality | RevenueCat + `users.subscription_status` |
| **Crash logs** | Yes | No | Optional | Crash logging, diagnostics | Sentry (`SENTRY_DSN`) |
| **Diagnostics** | Yes | No | Optional | Analytics | PostHog |
| **App interactions** | Yes | No | Optional | Analytics | PostHog events (`analytics/analytics.dart`) |
| **Device or other IDs** | ⚠️ Verify | No | — | Analytics | **Do not answer from memory.** PostHog's Android SDK may collect a device identifier. Confirm against the merged manifest and PostHog's current SDK docs before ticking either box |
| Advertising ID | **No** | No | — | — | No `AD_ID` permission, no ad SDK |
| Precise location | **No** | No | — | — | `ACCESS_FINE_LOCATION` not declared |
| Contacts, calendar, SMS, call logs, audio, health/fitness *(of the user)*, financial info, web browsing | **No** | No | — | — | No permission, no code path |

¹ Optional because guest (anonymous) sign-in requires no email.

### 5.3 The three judgement calls — read these before answering

**⚠️ A · Is the pet's health data "Health info"?**
Play's *Health and fitness → Health info* category covers **the user's own** health. PawDoc
records an **animal's** health. Declaring it as the user's health info would be inaccurate
in the other direction and drags in expectations (Health Connect, medical-device framing)
that do not apply.
**Recommendation:** declare it under **Other user-generated content**, and — if the Console
offers a free-text field — say plainly that the records concern the user's pet, not the
user. Separately, complete the **Health apps declaration** (§6), which is where the health
framing belongs.

**⚠️ B · Is sending a photo to Gemini/Anthropic "sharing"?**
Play excludes transfers to a *"service provider"* that processes data on your behalf.
Google Gemini and Anthropic are used as inference providers under PawDoc's own API keys.
**Recommendation:** answer **not shared**, and before submitting, confirm (a) the current
provider terms designate them as processors, and (b) neither trains on API data by default.
If either is untrue, the honest answer flips to **shared**.

**⚠️ C · Does "we do not sell your data" belong in the listing?**
Yes, and only in that form. `memory/…settings_five_final_batch` records that onboarding still
carries **"We never sell your data. Ever."** — an unscoped absolute. *Not selling* is a
factual statement PawDoc can stand behind; *"never, ever"* is a promise about the future.
Prefer the scoped version everywhere, and never write *"100% private"* or *"your data stays
on your device"*: photos genuinely do leave the device.

### 5.4 Cross-checks that must pass before submitting

- [ ] No screenshot or description line claims data stays on the device
- [ ] The description's data paragraph matches this table sentence for sentence
- [ ] The privacy policy at `/privacy` names every third party in §0
- [ ] Approximate location is declared here **and** the content rating says location is
      shared with other users **and** the privacy policy explains the geohash cell

---

## 6 · Health apps declaration

**Console:** Policy → App content → **Health apps** *(section name may read "Health Content
and Services")*

**VERIFIED:** *"All developers must complete the Health apps declaration form on the App
content page."* It applies even to apps that are not primarily health apps.

| Question | Answer | Why |
|---|---|---|
| Does your app provide health-related content or services? | **Yes** | It gives symptom guidance and keeps health records — for animals |
| Is your app a regulated medical device? | **No** | It performs no measurement, makes no diagnosis and names no condition. It is not marketed for the diagnosis, treatment or prevention of disease |
| Does your app access Health Connect? | **No** | No integration, no permission |
| Does it handle prescription drugs / pharmacy? | **No** | Medications can be *recorded* by the owner. Nothing is prescribed, suggested, sold or dispensed |
| Clinical services / telehealth? | **No** | No veterinarian is employed, contracted, verified or reachable. **This is the answer most worth getting right** |
| Human-subjects research? | **No** | — |
| Privacy policy link | `https://d1klm6zb1x23me.cloudfront.net/privacy/` | Also linked in-app |

**Required in the store description.** Non-medical-device health apps are expected to carry
*"a clear disclaimer in their app description indicating that the app is 'not a medical
device and does not diagnose, treat, cure, or prevent any medical condition.'"*

⛔ **The current description does not contain it.** `docs/store_metadata/google_play.md` says
*"does not diagnose, does not provide veterinary medical advice, and is not a substitute for
an in-person examination"* — close, but it never says **not a medical device**. The
replacement description in
[`PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html`](./PAWDOC_PLAY_STORE_ASO_PROMPT_LIBRARY.html) §4
says it verbatim. Use that one.

**Supporting evidence, if Google asks:** the disclaimer is API-injected and cannot be turned
off in the UI (`scripts/verify-disclaimers.sh` proves the flag is server-forced); the action
ladder has no "do nothing" rung and never renders "normal"; confidence below 0.60 returns
"insufficient information" rather than a guess.

---

## 7 · AI-generated content

Two distinct things, both current, both PawDoc's.

### 7.1 In-app generative AI — Play's AI-Generated Content policy

| Requirement | PawDoc | Evidence |
|---|---|---|
| Disclose that output is AI-generated | ✅ | The assistant is labelled `PawDoc AI` and carries a permanent disclosure strip |
| Prevent generation of restricted content | ✅ | Structured JSON only; safety keyword override runs **before** any model call; uploads are moderated fail-closed |
| **In-app reporting of offensive AI output** | ⚠️ **VERIFY** | A feedback path exists (`feedback_test.dart`, `Analytics.feedbackSubmitted`). Confirm on-device that a user can report a *specific* AI reply without leaving the app. **If they cannot, build it before submitting** — this is an explicit policy expectation, not a nicety |

### 7.2 The store-asset declaration

**VERIFIED:** Play now asks developers to declare AI-generated or AI-edited store assets
during the content-creation flow (store listing, promotional content, YouTube video, asset
library), via a standardised checkbox. It is a **self-declaration** model, assessed per
asset.

**Answer: Yes**, for every screenshot, the feature graphic and the icon — all ten are
produced by an image model. Tick it on each upload.

---

## 8 · Financial features

**Console:** Policy → App content → **Financial features**

**Answer: "My app doesn't provide any financial features."**

**Why.** A subscription paid through Google Play billing is not a financial feature. PawDoc
has no lending, no investments, no crypto, no tokenised digital assets, no insurance, no
money transmission.

---

## 9 · Government apps · News apps · COVID-19 apps

| Declaration | Answer |
|---|---|
| Government apps | **No** — not developed on behalf of, or in partnership with, any government |
| News apps | **No** — the Encyclopedia is static reference content, not news |
| COVID-19 contact tracing / status | **No** |

---

## 10 · Privacy policy

**Console:** Policy → App content → **Privacy policy** → URL field

**Enter:** `https://d1klm6zb1x23me.cloudfront.net/privacy/`

⛔ **BLOCKER — the policy is not submittable as written.** `scripts/verify-no-placeholders.sh`
reports unfilled placeholders in the live legal content:

```
web-legal/content/privacy.md:16   **[LEGAL ENTITY]**, **[BUSINESS ADDRESS]**
web-legal/content/privacy.md:119  Operator: [LEGAL ENTITY], [BUSINESS ADDRESS]
web-legal/content/terms.md:14     between you and **[LEGAL ENTITY]**
web-legal/content/gdpr.md:18      [EU REPRESENTATIVE — to be appointed]
web-legal/content/ccpa.md:55      [LEGAL ENTITY], [BUSINESS ADDRESS]
web-legal/content/deletion.md:59  [LEGAL ENTITY], [BUSINESS ADDRESS]
web-legal/content/contact.md:29   Service operator: [LEGAL ENTITY]
```

A privacy policy that does not name its data controller is not a valid privacy policy under
GDPR, and a reviewer opening the URL sees the brackets. **Fill the entity name and address,
redeploy the portal, then re-run the script.**

**Also confirm the policy names:** every third party in §0; the geohash cell; that EXIF/GPS
is stripped before upload; the in-app deletion route; and a working contact address.

---

## 11 · Data deletion

**Console:** Store listing → **Data deletion** (URL and/or in-app route)

| Field | Value |
|---|---|
| In-app route | **Yes** — Account → Delete account |
| Web URL | `https://d1klm6zb1x23me.cloudfront.net/deletion/` |

**Evidence.** `supabase/functions/delete-account/index.ts` performs the erase; the cascade is
proven in CI by `scripts/test-rls.sh`; RevenueCat subscriber purge is included (a silent
GDPR bug there was fixed in the release-candidate programme).

⚠️ **Verify on a device before submitting:** create a throwaway account, add a pet, delete
the account, and confirm the rows are gone. This is on the checklist because it is the step
most often assumed.

---

## 12 · Permissions

No **Permissions declaration form** is required: PawDoc requests none of the high-risk
permissions that trigger it.

| Permission | Declared? | Justification |
|---|---|---|
| `INTERNET` | Yes | Everything |
| `CAMERA` | Yes | Photo/video capture for a health check. Asked contextually, at first capture |
| `POST_NOTIFICATIONS` | Yes | Local reminders. Asked at first reminder creation, never upfront |
| `RECEIVE_BOOT_COMPLETED` | Yes | Re-arms scheduled local notifications after a restart |
| `ACCESS_COARSE_LOCATION` | Yes | Weather + nearby parks (on-device), and the opt-in community cell |
| `ACCESS_FINE_LOCATION` | **No** | Deliberate. Nothing needs street-level accuracy |
| `READ_MEDIA_IMAGES` / storage | **No** | Removed via `tools:node="remove"`. Gallery picking uses the system photo picker, which needs no permission |
| `RECORD_AUDIO` | **No** | Removed. Capture runs with `enableAudio: false` |
| Background location | **No** | Never requested |
| `QUERY_ALL_PACKAGES` | **No** | Not present |

⚠️ **Verify against the *merged* manifest**, not the source one — plugins merge permissions
in. `flutter build apk --release` then inspect the merged output. This project already strips
four such permissions; a new dependency can add a fifth.

---

## 13 · Store listing

| Field | Value | Limit | Status |
|---|---|---|---|
| App name | `PawDoc: Pet Health Checker` | 30 | 26 ✓ |
| Short description | `Describe a symptom, get a clear next step. Emergency help works offline.` | 80 | 72 ✓ |
| Full description | See ASO prompt library §4 | 4000 | ≈2,750 ✓ |
| Category | Lifestyle | — | Decision I5 |
| Contact email | *(founder — must be monitored: DSR requests run on a statutory clock)* | — | ⛔ |
| Icon / feature graphic / screenshots | Regenerate — see the ASO workflow | — | ⛔ |

⛔ **The short description currently in `docs/store_metadata/google_play.md` is 144
characters** and the Console will refuse it. The file's own table claims "72 ✓", which was
never recomputed after the copy was rewritten. **Count characters; do not estimate them.**

---

## 14 · Testing and production access

⚠️ **VERIFIED and potentially blocking.** Personal developer accounts created after
13 November 2023 must run a **closed test with at least 12 testers, opted in continuously
for at least 14 days**, before production access can be requested. The 14 days must be
consecutive; a tester who opts out and back in restarts.

| Question | Answer |
|---|---|
| Is the PawDoc account subject to this? | ⚠️ **Founder must check.** Play Console → Dashboard shows the requirement and a live tester count if it applies. Organisation accounts are generally exempt |
| If it applies | Budget **at least three weeks** before production, starting from a working closed-test build. This is a calendar dependency, not an engineering one |
| Prior state | Internal testing has been used (`PAWDOC_INTERNAL_TEST_FINAL_READY.md`). **Internal testing does not count** toward the closed-test requirement |

---

## 15 · Monetization declarations

| Item | Answer | Evidence |
|---|---|---|
| Does the app contain in-app purchases? | **Yes** — auto-renewing subscription | See the subscriptions handbook |
| Uses Google Play billing? | **Yes**, exclusively | `purchases_flutter` → Billing Library 8 |
| Alternative billing / external offers? | **No** | Not enrolled |
| Subscription terms shown before purchase? | **Yes** | Auto-renew disclosure + Terms/Privacy/Subscription links adjacent to every purchase CTA |
| Free trial claims in the listing? | **None** | Nothing is configured in Play, so nothing is claimed anywhere |

⛔ **Do not put any price, trial or discount in the listing until the products are Active in
Play**, and then only figures that match the live SKUs, with terms.

---

## 16 · The blocker list

Ordered by what stops a submission.

| # | Blocker | Owner | Class |
|---|---|---|---|
| 1 | Legal-entity placeholders in the live privacy policy, terms, GDPR, CCPA, deletion and contact pages | Founder + legal | Policy · **hard** |
| 2 | Store assets: all ten regenerated, validated and uploaded | Engineering → founder | Listing · **hard** |
| 3 | Short description exceeds 80 characters | Engineering (done — use the new copy) | Listing · **hard** |
| 4 | "Not a medical device" absent from the description | Engineering (done — use the new copy) | Health policy · **hard** |
| 5 | Play subscription products + RevenueCat catalogue do not exist | Founder | Monetization · **hard for IAP** |
| 6 | One real purchase + restore never performed | Founder | Monetization · **hard for IAP** |
| 7 | Reviewer account not created | Founder | App access · **hard** |
| 8 | Closed-test requirement — 12 testers × 14 consecutive days, if applicable | Founder | Release · **hard, and slow** |
| 9 | In-app reporting of a *specific* AI reply — verify it exists | Engineering | AI policy · **medium** |
| 10 | Device-ID collection by PostHog — verify before ticking Data safety | Engineering | Data safety · **medium** |
| 11 | Gemini/Anthropic processor terms — confirm before answering "not shared" | Founder | Data safety · **medium** |
| 12 | Onboarding still says "We never sell your data. Ever." | Engineering | Data safety consistency · **medium** |
| 13 | Contact email monitored | Founder | Listing · **medium** |
| 14 | Account-deletion cascade re-verified on a device | Founder | Data deletion · **medium** |

---

## Sources

- [Health Content and Services — Play Console Help](https://support.google.com/googleplay/android-developer/answer/16679511)
- [Declaring AI-generated content in Play Console](https://support.google.com/googleplay/android-developer/answer/17262077)
- [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Policy announcement: July 15, 2026](https://support.google.com/googleplay/android-developer/answer/17134731) — unrated apps no longer permitted; third-party AI under User Data
- Repository evidence as cited inline, verified 8 August 2026.
