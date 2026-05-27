# PawDoc — Privacy Policy

> ⚠️ **TEMPLATE — NOT LEGAL ADVICE.** Engineering-drafted starting point. A licensed
> attorney / privacy specialist **must review and finalize** this for GDPR (EU/UK),
> CCPA/CPRA (California), and other applicable regimes before publication. Replace
> every `[BRACKETED]` placeholder and reconcile the **retention** section with the
> CR #9 legal-hold-vs-erasure decision (`docs/runbooks/18`).

**Effective date:** `[DATE]` · **Controller:** `[LEGAL ENTITY]`, `[ADDRESS]` · **Contact / DPO:** support@pawdoc.app

## 1. Data we collect

- **Account:** email, authentication identifiers (email / Apple / Google).
- **Pet profiles:** name, species, breed, age, sex, weight, notes you enter.
- **Inputs you submit:** photos/videos of your pet and text descriptions. (Images
  are compressed and **EXIF/GPS metadata is stripped before upload**; uploads are
  content-moderated and rejected/deleted if not appropriate.)
- **Analyses:** triage results and related metadata.
- **Subscription:** status via RevenueCat (no card data is stored by us).
- **Device/usage:** product analytics events, push token, crash diagnostics.

## 2. How we use it

To provide triage analysis, store your pet's history, send notifications you opt
into, operate billing, improve the product, and keep the service secure.

## 3. Legal bases (GDPR)

Performance of our contract (providing the App), your **consent** (e.g. push
notifications, optional analytics where required), and our legitimate interests
(security, product improvement), as applicable.

## 4. Sharing & subprocessors

We do not sell your personal data. We share it only with processors that run the
service, under data-processing agreements:

| Processor | Purpose |
|-----------|---------|
| Supabase | Database, auth, storage metadata (EU project for EU users) |
| Cloudflare R2 | Encrypted image/video storage |
| Anthropic, Google (Gemini) | AI analysis of the submitted input |
| RevenueCat | Subscription management |
| OneSignal | Push notifications |
| PostHog, Sentry | Product analytics, crash reporting |

`[Confirm the final processor list + each one's DPA and sub-processor terms with counsel.]`

## 5. International transfers & data residency

EU/UK users' data is stored in an **EU region** (Supabase EU project). Where data is
transferred internationally (e.g. to AI processors), `[Standard Contractual Clauses /
appropriate safeguards]` apply.

## 6. Retention  ⚠️ DECISION REQUIRED (CR #9)

`[CHOOSE AND DOCUMENT THE POLICY: (a) delete on account deletion + a defined purge
window (e.g. 30 days), OR (b) anonymise/de-identify and retain de-identified analysis
records under legitimate interest for safety/legal records. The codebase currently
implements full erasure on account deletion via ON DELETE CASCADE — align this section
to the chosen policy before launch.]`

## 7. Your rights

Access, rectification, erasure, restriction, portability, and objection (GDPR), and
the CCPA/CPRA rights (know, delete, correct, opt-out of sale/sharing — we do not sell).
You can **delete your account and all associated data in-app** (Settings → Delete
account); this is permanent. For other requests, contact support@pawdoc.app.

## 8. Children

PawDoc is for pet owners 18+ and is not directed to children.

## 9. Security

Row-Level Security isolates each user's data; uploads use short-lived presigned URLs
(no storage credentials on the device); images are stripped of EXIF/GPS; secrets are
held in a secrets manager, never in the app.

## 10. Changes & contact

We will notify material changes in-app and update the effective date.
Questions: support@pawdoc.app · `[LEGAL ENTITY + ADDRESS + DPO/EU representative if required]`
