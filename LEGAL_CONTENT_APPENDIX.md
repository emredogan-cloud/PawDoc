# PawDoc — Legal Content Appendix

> **Supporting Appendix 1** to `PAWDOC_LEGAL_PORTAL_REPORT.md`. Contains the final text of all 15 legal pages, exactly as deployed to the public legal portal.

- **Portal (live, public HTTPS):** https://d1klm6zb1x23me.cloudfront.net
- **Effective date:** 2026-06-15
- **Document set version:** v1.0
- **Source of truth:** `web-legal/content/*.md` (rendered to HTML by `web-legal/build.mjs`)

> ⚠️ **Attorney review required before public launch.** These drafts were prepared to be accurate, truthful, and founder-protective, and are grounded in cited research (Apple/Google store policies, GDPR, CCPA/CPRA, COPPA, AVMA/VCPR guidance, EU AI Act Art. 50, FTC AI guidance, and US/EU auto-renewal law). They are **not legal advice** and have **not** been reviewed by a licensed attorney. All `[BRACKETED]` values are placeholders the operator must complete (legal entity, address, EU/UK representatives, governing law, contact mailboxes). Nothing here claims PawDoc diagnoses animals or replaces a veterinarian.

## Contents

1. [Privacy Policy](#1-privacy) — `/privacy`
2. [Terms of Service](#2-terms) — `/terms`
3. [Contact & Legal Notice](#3-contact) — `/contact`
4. [Veterinary Disclaimer](#4-disclaimer) — `/disclaimer`
5. [Emergency Disclaimer](#5-emergency) — `/emergency`
6. [AI Transparency & Limitations](#6-ai-transparency) — `/ai-transparency`
7. [Acceptable Use Policy](#7-acceptable-use) — `/acceptable-use`
8. [Subscription Terms](#8-subscriptions) — `/subscriptions`
9. [Referral Program Terms](#9-referrals) — `/referrals`
10. [Account Deletion Policy](#10-deletion) — `/deletion`
11. [Data Retention Policy](#11-data-retention) — `/data-retention`
12. [Cookie Policy](#12-cookies) — `/cookies`
13. [Your GDPR Rights](#13-gdpr) — `/gdpr`
14. [Your California Privacy Rights](#14-ccpa) — `/ccpa`
15. [Children's Privacy](#15-children) — `/children`

---

<a id="1-privacy"></a>

## 1. Privacy Policy

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/privacy · **Slug:** `/privacy` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

PawDoc ("**PawDoc**," "**we**," "**us**") provides an AI-assisted pet-health triage app that helps you decide whether and how urgently to seek veterinary care. This Privacy Policy explains what personal information we collect, why, who we share it with, how long we keep it, and the choices and rights you have.

> [!NOTE] **Entity details to be finalized.** PawDoc is operated by **[LEGAL ENTITY]**, **[BUSINESS ADDRESS]** (the "data controller"). Bracketed values are placeholders that the operator will complete before public launch. Privacy questions: [privacy@pawdoc.app](mailto:privacy@pawdoc.app).

## At a glance

| Topic | Summary |
|---|---|
| What we collect | Your account email, pet profiles, the photos/videos/text you submit, triage results, subscription status, and basic device/usage data. |
| Why | To run the triage service you ask for, keep your pet's history, operate billing, send notifications you opt into, secure the service, and improve it. |
| Selling data | **We do not sell your personal information**, and we do not use your pet's photos or health inputs for advertising. |
| AI | Your inputs are processed by third-party AI providers (Google Gemini and Anthropic Claude) to generate guidance. We disclose this and never present AI output as a diagnosis. |
| Your control | You can view, correct, export, or **permanently delete your account and data** at any time (see [Account Deletion](/deletion/)). |

## 1. Information we collect

- **Account information** — your email address and authentication identifiers (email, or Sign in with Apple / Google).
- **Pet profiles** — the name, species, breed, age, sex, weight, and notes you enter about your pet.
- **Inputs you submit for triage** — photos, short videos, and text describing your pet's symptoms. Images are compressed and **EXIF/GPS location metadata is stripped before upload**, and uploads are automatically content-moderated and rejected or deleted if they are not appropriate pet-health content.
- **Analyses** — the triage result (emergency, monitor, or likely normal), related guidance, and metadata such as timestamps.
- **Subscription information** — your plan and entitlement status, provided through RevenueCat and the app stores. **We never receive or store your full card number** — payments are handled by Apple and Google.
- **Device and usage data** — app interaction events, a push-notification token (if you opt in), language/region, and crash diagnostics.
- **Support communications** — messages you send us and their contents.

## 2. How we use your information and our legal bases (GDPR)

Where the EU/UK GDPR applies, we rely on the following legal bases (Art. 6):

| Purpose | Legal basis |
|---|---|
| Create your account; provide triage; store your pet's history | Performance of a contract (Art. 6(1)(b)) |
| Process the photo/video/text you submit to generate guidance | Performance of a contract (Art. 6(1)(b)) |
| Operate subscriptions and keep billing/tax records | Contract (Art. 6(1)(b)) and legal obligation (Art. 6(1)(c)) |
| Product analytics and crash reporting | Your consent (Art. 6(1)(a)), or our legitimate interest in security/debugging where strictly necessary (Art. 6(1)(f)) |
| Push notifications and any marketing | Your consent (Art. 6(1)(a)) — you can withdraw it at any time |
| Keep the service secure and prevent abuse | Legitimate interests (Art. 6(1)(f)) |

## 3. How PawDoc's AI guidance works

PawDoc's triage guidance is **generated by artificial intelligence**, not by a veterinarian. To produce it, the information you submit is sent to third-party AI providers — **Google (Gemini)** and **Anthropic (Claude)** — which process it on our behalf to return structured guidance. We disclose this third-party AI processing here and in the app, and we never present the output as a veterinary diagnosis. The guidance is decision-support that always directs you to a licensed veterinarian; it has no legal or similarly significant effect on you. For more on how the AI works and its limits, see [AI Transparency & Limitations](/ai-transparency/). You can contact us to ask about the logic involved.

## 4. Who we share information with

We do not sell your personal information. We share it only with service providers ("processors") that operate the service under contract, and only as needed:

| Processor | Purpose |
|---|---|
| Supabase | Database, authentication, and storage metadata (EU region for EU users) |
| Cloudflare R2 | Encrypted object storage for your images and videos |
| Google (Gemini), Anthropic (Claude) | AI processing of the input you submit, to generate guidance |
| RevenueCat | Subscription and entitlement management |
| Apple App Store, Google Play | Payment processing and billing |
| OneSignal | Push notifications (if you opt in) |
| PostHog | Product analytics |
| Sentry | Crash and error diagnostics |

We may also disclose information if required by law, to enforce our [Terms of Service](/terms/), or to protect the rights, safety, and security of users, the public, or PawDoc. The list above reflects our current processors and will be kept current.

## 5. International data transfers

PawDoc is available internationally, and some of our processors are located in the United States or other countries. EU/UK users' core account data is stored in an **EU region**. Where personal data is transferred outside the EEA/UK, we rely on an appropriate safeguard under GDPR Chapter V — either the provider's certification under the **EU–US Data Privacy Framework**, or **Standard Contractual Clauses** where the provider is not certified. You can contact us for details of the safeguard applicable to a given transfer.

## 6. How long we keep it

We keep personal information only as long as needed for the purposes above, and then delete or de-identify it. When you delete your account, your data is permanently removed (subject to limited, disclosed exceptions such as records we must keep for tax or legal-compliance reasons). See the [Data Retention Policy](/data-retention/) for specifics and the [Account Deletion Policy](/deletion/) for how to delete your data.

## 7. Your rights and choices

Depending on where you live, you may have some or all of these rights:

- **Access** a copy of your personal information.
- **Correct** information that is inaccurate.
- **Delete** your account and associated data — available in-app and on the web (see [Account Deletion](/deletion/)).
- **Export / portability** of data you provided.
- **Restrict or object** to certain processing, and **withdraw consent** at any time (without affecting earlier processing).
- **Opt out** of analytics and marketing.
- **Lodge a complaint** with your data protection authority.

For details specific to your region, see [Your GDPR Rights](/gdpr/) (EU/UK) and [Your California Privacy Rights](/ccpa/). To exercise any right, use the in-app controls or email [privacy@pawdoc.app](mailto:privacy@pawdoc.app). We will verify your request and respond within the timeframes required by law.

## 8. How we protect your information

- Row-Level Security isolates each user's data so users can only access their own.
- Uploads use short-lived, single-use presigned URLs — **no storage credentials are ever placed in the app**.
- Images have **EXIF/GPS location metadata stripped** before upload, and uploads are content-moderated.
- Secrets are held in a managed secrets vault, never embedded in the app.

No system is perfectly secure, but we work to protect your information using safeguards appropriate to its sensitivity.

## 9. A note on pet data

Most of what you submit is about your **pet**. Information about an animal is generally **not** "special category" personal data under GDPR (which protects information about people). However, a photo or video can incidentally capture a person, a home interior, or location metadata — which is one reason we strip GPS/EXIF data and moderate uploads. Your own account and contact details are personal data and are fully protected as described here.

## 10. Children

PawDoc is intended for adults and is not directed to children. See our [Children's Privacy](/children/) page.

## 11. Changes to this policy

We may update this Privacy Policy. If we make a material change, we will notify you in-app and update the "Last updated" date above. Your continued use after an update means you accept the revised policy.

## 12. Contact us

- **Privacy:** [privacy@pawdoc.app](mailto:privacy@pawdoc.app)
- **General support:** [support@pawdoc.app](mailto:support@pawdoc.app)
- **Operator:** [LEGAL ENTITY], [BUSINESS ADDRESS]
- **EU/EEA representative (Art. 27):** [EU REPRESENTATIVE — to be appointed]
- **UK representative:** [UK REPRESENTATIVE — if targeting UK users]

---

<a id="2-terms"></a>

## 2. Terms of Service

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/terms · **Slug:** `/terms` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

These Terms of Service ("**Terms**") are a binding agreement between you and **[LEGAL ENTITY]** ("**PawDoc**," "**we**," "**us**"), the operator of the PawDoc app (the "**App**"). By creating an account or using the App, you agree to these Terms and to our [Privacy Policy](/privacy/). **If you do not agree, do not use the App.**

> [!IMPORTANT] **PawDoc is not a veterinarian and does not diagnose.** PawDoc provides general educational information and urgency triage. It does **not** diagnose, prescribe, treat, or practice veterinary medicine, and using it does **not** create a veterinarian-client-patient relationship. Always consult a licensed veterinarian. See the [Veterinary Disclaimer](/disclaimer/) and [Emergency Disclaimer](/emergency/).

## 1. What PawDoc is — and is not

PawDoc helps you decide **whether and how urgently** to seek veterinary care by giving triage guidance — typically **emergency**, **monitor**, or **likely normal** — generated with the help of AI.

- Triage results are **informational only**. They are not a diagnosis, prognosis, treatment plan, or prescription.
- PawDoc is **not a substitute** for examination, diagnosis, and treatment by a licensed veterinarian.
- **In an emergency, contact a veterinarian or emergency clinic immediately** — do not wait for or rely on the App.
- **You are solely responsible** for all decisions about your pet's care.

## 2. Eligibility

You must be at least **18 years old** and able to form a binding contract to use the App. The App is intended for adults and is not directed to children (see [Children's Privacy](/children/)).

## 3. Your account

You are responsible for your account and for keeping your credentials secure. You agree to provide accurate information and to use the App only for your own pets. You may delete your account at any time, in-app or on the web, which permanently removes your data (see [Account Deletion](/deletion/)).

## 4. Acceptable use

You agree to use the App lawfully and as described in our [Acceptable Use Policy](/acceptable-use/). In short: do not misuse the service, upload unlawful or non-pet/explicit content, attempt to reverse-engineer or overload the service, or use it for any unlawful purpose. Uploads are moderated and may be rejected.

## 5. Subscriptions and billing

PawDoc offers a free tier with a limited number of analyses and an optional auto-renewing premium subscription. Subscriptions are **billed by the Apple App Store or Google Play** (managed through RevenueCat) — not by us directly — and **auto-renew until cancelled**. Full details, including how to cancel and how refunds work, are in the [Subscription Terms](/subscriptions/).

**Emergency results are never placed behind a paywall.** If the App identifies a potential emergency, the safety guidance and prompt to seek a veterinarian are shown regardless of your plan or remaining free checks.

## 6. AI limitations and no warranty

PawDoc's guidance is produced by AI models that can be **incomplete, inaccurate, or wrong** — including both false alarms and missed conditions. The quality of any result depends on the quality of the information you provide. To the maximum extent permitted by law, the App and its content are provided **"AS IS" and "AS AVAILABLE," without warranties of any kind**, express or implied, including any warranty that results are accurate, complete, current, or fit for a particular purpose. See [AI Transparency & Limitations](/ai-transparency/).

## 7. Limitation of liability

To the maximum extent permitted by law, PawDoc and its operators, officers, and suppliers will not be liable for any indirect, incidental, special, consequential, exemplary, or punitive damages, or for any veterinary outcome, loss, or harm, arising out of or relating to your use of, or reliance on, the App or its guidance. To the maximum extent permitted by law, our total aggregate liability for any claim relating to the App is limited to the greater of the amount you paid us in the **[12]** months before the claim or **[USD 50]**. **[Counsel to confirm the cap, carve-outs, and any non-waivable consumer protections for each launch jurisdiction.]**

Nothing in these Terms excludes or limits liability that cannot be excluded or limited under applicable law, including statutory consumer rights.

## 8. Indemnification

You agree to indemnify and hold PawDoc harmless from claims, damages, and expenses arising from your misuse of the App or violation of these Terms, to the extent permitted by law.

## 9. Changes to the service and these Terms

We may modify or discontinue features, and we may update these Terms. If a change is material, we will notify you in-app and update the "Effective date." Continued use after a change constitutes acceptance. If you do not agree, stop using the App and delete your account.

## 10. Governing law and disputes

These Terms are governed by the laws of **[GOVERNING LAW / JURISDICTION]**, without regard to conflict-of-laws rules. **[Counsel to add venue and, if used, an arbitration agreement and class-action waiver, drafted for the chosen jurisdiction(s).]**

## 11. Contact

Questions about these Terms: [support@pawdoc.app](mailto:support@pawdoc.app) · [LEGAL ENTITY], [BUSINESS ADDRESS].

---

*EU/UK users: nothing in these Terms limits the non-waivable statutory rights you have as a consumer.*

---

<a id="3-contact"></a>

## 3. Contact & Legal Notice

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/contact · **Slug:** `/contact` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

We're glad to hear from you. Use the right contact below so your message reaches the correct place quickly.

## How to reach us

| Topic | Contact |
|---|---|
| **General support** (the app, your account, billing questions) | [support@pawdoc.app](mailto:support@pawdoc.app) |
| **Privacy requests** (access, correction, deletion, GDPR/CCPA rights) | [privacy@pawdoc.app](mailto:privacy@pawdoc.app) |
| **Legal notices** | [legal@pawdoc.app](mailto:legal@pawdoc.app) |
| **Account deletion** | In-app, or see [Account Deletion](/deletion/) |

> [!NOTE] **In an emergency, do not email us.** PawDoc cannot respond to emergencies. Contact an emergency veterinarian or animal poison control immediately — see the [Emergency Disclaimer](/emergency/).

## Operator (legal notice)

- **Service operator:** [LEGAL ENTITY]
- **Registered address:** [BUSINESS ADDRESS]
- **Company/registration number:** [REGISTRATION NUMBER, if applicable]
- **Contact email:** [support@pawdoc.app](mailto:support@pawdoc.app)

## Data protection contacts

- **EU/EEA representative (GDPR Art. 27):** [EU REPRESENTATIVE — to be appointed]
- **UK representative:** [UK REPRESENTATIVE — if targeting UK users]
- **Data Protection Officer:** [DPO — only if appointed; PawDoc may not be required to appoint one]

## Response times

We aim to respond to support messages promptly and to privacy requests within the timeframes required by applicable law (for example, generally within 30 days under GDPR and 45 days under the CCPA, with extensions where permitted).

> [!IMPORTANT] **Placeholders.** Bracketed details above are placeholders the operator will complete, and the contact addresses must be live mailboxes, before public launch.

---

<a id="4-disclaimer"></a>

## 4. Veterinary Disclaimer

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/disclaimer · **Slug:** `/disclaimer` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

Please read this disclaimer carefully. It explains exactly what PawDoc does and does not do for your pet.

> [!WARNING] **PawDoc is not a veterinary medical device and does not diagnose, treat, cure, or prevent any condition.** It provides general educational information and urgency guidance only. **Always consult a licensed veterinarian** for diagnosis, treatment, and decisions about your pet's care.

## 1. What PawDoc provides

PawDoc gives two things:

- **General educational information** about pet health, and
- **Triage (urgency guidance)** — a best estimate of *whether* and *how urgently* your pet may need to be seen by a veterinarian, typically expressed as **emergency**, **monitor**, or **likely normal**.

That is the whole of what PawDoc offers. It is a starting point to help you decide what to do next — not an answer about what is wrong with your pet.

## 2. What PawDoc does not do

PawDoc does **not**:

- diagnose your pet or name a definitive condition;
- prescribe, recommend, or adjust any medication, dose, or treatment;
- provide a prognosis or a treatment plan;
- examine your pet or run any test; or
- practice veterinary medicine.

Diagnosing, prescribing, and treating are acts of veterinary medicine that require a licensed veterinarian who has examined your pet. PawDoc is software and does none of these things.

## 3. No veterinarian-client-patient relationship (VCPR)

A veterinarian-client-patient relationship is the professional relationship that must exist before a veterinarian can diagnose or treat a specific animal, and — per veterinary-profession guidance — it generally requires an **in-person examination** of your pet. **Using PawDoc does not create a VCPR**, because PawDoc is not a veterinarian and performs no examination. General information and triage of this kind are recognized as activities that can be offered *without* an established VCPR, precisely because they stop short of patient-specific diagnosis and treatment.

## 4. Always consult a licensed veterinarian

PawDoc is designed to point you toward professional care, not away from it. A licensed veterinarian who examines your pet can do what PawDoc cannot: reach a diagnosis, order tests, and prescribe treatment. **You remain fully responsible for your pet's health and for decisions about its care.** When in doubt, contact your veterinarian.

## 5. Accuracy and AI

PawDoc's guidance is generated with the help of artificial intelligence and can be incomplete or wrong. Its quality depends on the photos, video, and description you provide. PawDoc is provided **"as is," without any warranty of accuracy or completeness**. For details on how the AI works and its limits, see [AI Transparency & Limitations](/ai-transparency/).

## 6. Emergencies

If your pet may be experiencing a life-threatening problem, **do not wait for or rely on PawDoc** — seek emergency care immediately. See the [Emergency Disclaimer](/emergency/) for red-flag signs and what to do.

## 7. Questions

Contact [support@pawdoc.app](mailto:support@pawdoc.app). This disclaimer is part of, and incorporated into, our [Terms of Service](/terms/).

---

<a id="5-emergency"></a>

## 5. Emergency Disclaimer

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/emergency · **Slug:** `/emergency` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

> [!EMERGENCY] **If your pet may be in a life-threatening situation, contact an emergency veterinarian or an animal poison control center right now.** Do not wait for, or rely on, PawDoc. PawDoc is not an emergency service and cannot respond to or monitor an emergency.

## 1. PawDoc is not an emergency service

PawDoc gives general guidance based only on what you submit, when you submit it. It does **not** continuously monitor your pet, it cannot call for help, and its AI-generated guidance can be wrong or delayed. In any situation that looks serious, **treat it as an emergency and seek professional care immediately** — that is always the safer choice.

## 2. Red-flag signs — seek emergency care immediately

Contact an emergency veterinarian right away if your pet shows any of these signs (this list is not exhaustive):

- **Difficulty or labored breathing**, choking, or blue/pale gums or tongue
- **Collapse**, sudden severe weakness, or unresponsiveness
- **Seizures** — especially repeated, clustered, or lasting more than a couple of minutes
- A **suddenly swollen, bloated, or distended abdomen**, especially with unproductive retching
- **Suspected poisoning** or ingestion of a toxin, medication, or foreign object
- **Severe bleeding** or major trauma (for example, hit by a car or a significant fall)
- **Inability to urinate**, or repeated straining to urinate (especially in male cats)
- Signs of **heatstroke** or overheating, such as severe panting and distress after heat exposure
- **Severe or persistent vomiting or diarrhea**, or any rapid, serious decline

When in doubt, **err on the side of caution and contact a veterinarian.**

## 3. Who to contact

- **Your veterinarian or the nearest emergency veterinary hospital.** If you do not know one, search for a 24-hour emergency animal hospital near you, or call your regular clinic for their emergency instructions.
- **United States — ASPCA Animal Poison Control Center:** **(888) 426-4435**, available 24 hours a day, 365 days a year. *A consultation fee may apply.*
- **Outside the United States:** contact your nearest emergency veterinary hospital or your local/national pet poison helpline.

> [!NOTE] PawDoc does not provide emergency telephone support and is not affiliated with the services above. Phone numbers are provided for your convenience; please verify current contact details for your area.

## 4. Why we say this

We would rather you act quickly and have it turn out to be nothing than wait on an app. PawDoc's emergency guidance exists to **push you toward professional care faster** — never to delay or replace it. Even when PawDoc suggests "monitor" or "likely normal," trust your own judgment: if your pet seems to be in distress, seek care.

## 5. Related

This disclaimer is part of our [Terms of Service](/terms/) and works alongside the [Veterinary Disclaimer](/disclaimer/) and [AI Transparency & Limitations](/ai-transparency/).

---

<a id="6-ai-transparency"></a>

## 6. AI Transparency & Limitations

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/ai-transparency · **Slug:** `/ai-transparency` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

We believe you should understand the tool you are trusting with your pet. This page explains, in plain language, how PawDoc's AI works and where its limits are.

> [!NOTE] **You are interacting with an AI system.** PawDoc's triage guidance is generated by artificial intelligence — not written or reviewed by a veterinarian in real time.

## 1. How it works

When you submit a photo, short video, or description along with your pet's profile, PawDoc sends that information to third-party AI models — currently **Google Gemini** and **Anthropic Claude** — which analyze it and return structured guidance. PawDoc organizes that into a simple triage signal (**emergency**, **monitor**, or **likely normal**) plus general information and a recommendation about seeing a veterinarian.

To keep results as safe and consistent as possible, PawDoc:

- runs hard-coded safety checks for emergency keywords **before** any AI call, so obvious emergencies are surfaced regardless of what the AI returns;
- constrains the AI to a fixed, structured response format and rejects off-format output;
- uses a low-randomness setting for health analysis; and
- responds with **"insufficient information"** rather than guessing when confidence is low.

## 2. What AI can do well — and what it cannot

AI is good at quickly surfacing patterns and giving you a sensible starting point. But it has real limitations you must keep in mind:

- **AI can be wrong.** It can miss a serious problem (a false "likely normal") or raise a false alarm.
- **AI can "hallucinate."** It can produce confident, fluent statements that are simply incorrect.
- **It is probabilistic.** Results are best estimates, not definitive findings.
- **It depends entirely on your input.** A blurry photo, a partial video, or an incomplete description can produce a wrong or uncertain result. PawDoc cannot see, touch, smell, or test your pet.
- **It does not monitor your pet.** PawDoc only responds to what you send, when you send it. It does not watch for changes or follow up.
- **It is not a veterinarian.** It cannot replace professional judgment, an in-person examination, or diagnostic testing.

## 3. What this means for you

Use PawDoc as **one input** to your decision, not the decision itself. If your own judgment says something is wrong, trust it and contact a veterinarian — even if PawDoc says "likely normal." In anything that looks like an emergency, seek care immediately and do not rely on the app (see the [Emergency Disclaimer](/emergency/)).

## 4. Honesty about accuracy

We do not claim that PawDoc is as accurate as a veterinarian, and we do not publish accuracy percentages we cannot substantiate. PawDoc is **guidance and triage**, not diagnosis. If we ever make a specific performance claim, it will be backed by evidence and clearly scoped.

## 5. Reporting a problem

If PawDoc ever returns guidance that seems offensive, unsafe, or badly wrong, please tell us at [support@pawdoc.app](mailto:support@pawdoc.app) so we can investigate and improve. Your reports help make the service safer.

## 6. Model identifiers

PawDoc refers to AI models by their technical identifiers (for example, `claude-sonnet-4-6`, `gemini-2.0-flash`) rather than marketing names, and the specific models may change over time as we improve the service.

## 7. Related

See the [Veterinary Disclaimer](/disclaimer/), the [Privacy Policy](/privacy/) (how your inputs are processed), and the [Terms of Service](/terms/).

---

<a id="7-acceptable-use"></a>

## 7. Acceptable Use Policy

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/acceptable-use · **Slug:** `/acceptable-use` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

This Acceptable Use Policy is part of our [Terms of Service](/terms/). It keeps PawDoc safe and useful for everyone. By using PawDoc, you agree to these rules.

## 1. Use PawDoc as intended

PawDoc is for **pet owners seeking general guidance and urgency triage for their own animals**. Use it for that purpose, and remember it is not a diagnosis and not a substitute for a veterinarian (see the [Veterinary Disclaimer](/disclaimer/)).

## 2. Content you submit

You may submit photos, short videos, and text **about a pet's health**. You must have the right to submit that content. By submitting it, you confirm it is appropriate pet-health content and not otherwise prohibited.

**Do not upload:**

- content that is not related to pet health;
- sexual, explicit, violent, or graphic content unrelated to a legitimate pet-health concern;
- content depicting animal cruelty or abuse;
- other people's personal information, or images of people without their consent;
- anything unlawful, infringing, or that you do not have the right to share.

Uploads are **automatically moderated** and may be rejected or deleted. Location metadata (EXIF/GPS) is stripped from images before upload.

## 3. Prohibited conduct

You agree **not** to:

- use PawDoc for any unlawful purpose, or in violation of these or any applicable rules;
- rely on PawDoc in place of professional veterinary care, or use it to delay seeking emergency care;
- attempt to reverse-engineer, decompile, scrape, or extract the service's models or data;
- probe, attack, overload, disrupt, or circumvent the security or rate limits of the service;
- use bots or automated means to access the service except as expressly permitted;
- resell, sublicense, or commercially exploit the service or its output without our permission;
- impersonate others or misrepresent your identity; or
- abuse referrals or promotions (see [Referral Program Terms](/referrals/)).

## 4. Human safety

PawDoc is **only** for animal health. It is **not** for human medical questions or emergencies. If a person needs medical help, contact a doctor or your local emergency number.

## 5. Enforcement

If you violate this policy, we may remove content, limit or suspend your access, or terminate your account, with or without notice, as appropriate and as permitted by law. We may also report unlawful activity to the authorities.

## 6. Contact

Questions or reports: [support@pawdoc.app](mailto:support@pawdoc.app).

---

<a id="8-subscriptions"></a>

## 8. Subscription Terms

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/subscriptions · **Slug:** `/subscriptions` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

These Subscription Terms are part of our [Terms of Service](/terms/) and apply if you buy PawDoc Premium. Please read them before subscribing.

> [!IMPORTANT] **PawDoc Premium is an auto-renewing subscription.** It renews automatically and bills you each period until you cancel. You cancel through your Apple App Store or Google Play account — see [How to cancel](#how-to-cancel).

## 1. Free tier and Premium

PawDoc offers a **free tier** with a limited number of analyses per period and an optional **Premium** subscription that unlocks additional usage and features. The current plans, prices, and benefits are shown in the app at the point of purchase.

> [!NOTE] **Emergency results are never paywalled.** If PawDoc identifies a potential emergency, the safety guidance and prompt to seek a veterinarian are always shown — regardless of your plan or how many free checks remain.

## 2. Billing is handled by the app stores

PawDoc subscriptions are sold and billed through the **Apple App Store** or **Google Play** (managed via RevenueCat). **We do not process your payment or receive your card details.** Your purchase is also subject to the app store's own terms.

- **Price** is shown in the app before you confirm, in your local currency.
- **Billing period** (for example, monthly or yearly) is shown before purchase.
- Payment is charged to your app store account at confirmation.

## 3. Auto-renewal

Your subscription **automatically renews** at the end of each billing period at the then-current price, and your account is charged for the next period, **unless you cancel at least 24 hours before the current period ends**. This continues until you cancel.

## 4. Free trials and introductory offers

If we offer a free trial or introductory price, the length of the trial and the price you will be charged when it ends are shown before you start. **A free trial automatically converts to a paid subscription** unless you cancel before the trial ends. Any unused portion of a free trial is forfeited when you buy a subscription, where applicable.

## 5. How to cancel

You manage and cancel your subscription in your app store account — **we cannot cancel it for you**:

- **iPhone/iPad:** Settings → your name → Subscriptions → PawDoc → Cancel.
- **Android:** Google Play → Profile → Payments & subscriptions → Subscriptions → PawDoc → Cancel.

Cancellation takes effect at the **end of the current paid period**; you keep access until then. Deleting the app does **not** cancel your subscription.

## 6. Refunds

Because billing is handled by the app stores, **refunds are governed by Apple's and Google's policies**:

- **Apple** processes refund requests centrally at [reportaproblem.apple.com](https://reportaproblem.apple.com).
- **Google Play** offers refunds per its policies (including a limited automatic window after purchase) via [play.google.com](https://play.google.com).

Cancelling stops future renewals but does not by itself refund the current period. Where we have discretion over a post-window request, we will consider it in good faith and in line with applicable law.

## 7. Price changes

If we change the subscription price, we will give you advance notice and, where required by your app store or by law, your renewal will not proceed at the new price without the consent the store requires. You can cancel before a change takes effect.

## 8. EU/UK consumers — right of withdrawal

If you are a consumer in the EU or UK, you normally have a **14-day right to withdraw** from a purchase of digital content. **However**, by starting to use PawDoc Premium immediately, you expressly request immediate performance and acknowledge that **you lose your 14-day right of withdrawal** once the service has been fully provided. This does not affect your other statutory rights. **[Counsel to confirm wording and any store-flow specifics for EU/UK.]**

## 9. United States — auto-renewal disclosures

We aim to present subscription terms clearly and to obtain your affirmative consent before charging, and to make cancellation easy through your app store, consistent with applicable auto-renewal laws (including the federal Restore Online Shoppers' Confidence Act and state automatic-renewal laws such as California's). **[Note for the operator: as of June 2026 the FTC's amended Negative Option ("Click-to-Cancel") Rule was vacated by the Eighth Circuit in July 2025 and is not in force; ROSCA, the FTC Act, and state ARLs still apply. Confirm current status with counsel before launch.]**

## 10. Contact

Billing questions: [support@pawdoc.app](mailto:support@pawdoc.app). For payment issues, also contact your app store.

---

<a id="9-referrals"></a>

## 9. Referral Program Terms

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/referrals · **Slug:** `/referrals` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

If PawDoc offers a referral program, these terms govern it. They are part of our [Terms of Service](/terms/). By participating, you agree to them.

## 1. Eligibility

You must have a PawDoc account and be of legal age in your country. Referral invitations should be sent only to people you personally know who would genuinely want to use PawDoc. **Do not spam**, buy lists, or post your link where it violates a platform's rules or any anti-spam law.

## 2. How it works

When you refer a friend with your unique link, and that friend is a **new** PawDoc user who completes the qualifying action we describe in the app (for example, creating an account and running their first check), you may each receive a reward, such as additional free checks or account credit. The current reward and qualifying conditions are shown in the app and may change.

## 3. Rewards

- Rewards are **promotional benefits** with **no cash value**, are **non-transferable**, and are **not redeemable for cash** unless we expressly state otherwise.
- Rewards are issued only after the qualifying conditions are met and verified.
- We may set limits on the number of referrals or rewards per person or period.
- Referral rewards are **separate** from any paid subscription entitlement and do not change how store billing works (see [Subscription Terms](/subscriptions/)).

## 4. Anti-fraud and forfeiture

To keep the program fair, we may **withhold, reduce, revoke, or reverse** rewards and may disqualify participants if we reasonably believe there has been:

- self-referral or referring accounts you control;
- duplicate, fake, or automated accounts;
- fraud, abuse, or manipulation of the program;
- a refund, chargeback, or cancellation of a qualifying purchase; or
- any violation of these terms or our [Acceptable Use Policy](/acceptable-use/).

## 5. Taxes

You are responsible for any taxes that may apply to rewards you receive. In some countries, rewards above a threshold may be reportable income. **[Operator/counsel: confirm any tax-reporting obligations, such as US Form 1099 thresholds, for cash-equivalent rewards.]**

## 6. Changes and termination

We may **modify, suspend, or end** the referral program, or change the rewards and qualifying conditions, at any time, with notice where required by law. Changes do not affect rewards already validly earned.

## 7. Not an investment

The referral program is a promotional incentive only. It is not an investment, security, or business opportunity, and creates no expectation of profit.

## 8. Contact

Questions: [support@pawdoc.app](mailto:support@pawdoc.app).

---

<a id="10-deletion"></a>

## 10. Account Deletion Policy

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/deletion · **Slug:** `/deletion` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

You can delete your PawDoc account and associated data at any time. This page explains how — including how to request deletion **on the web, without reinstalling or signing back into the app**.

> [!IMPORTANT] **Deletion is permanent.** When your account is deleted, your data is permanently removed and cannot be recovered. If you have an active subscription, **cancel it first in the App Store or Google Play** — deleting your account does not cancel store billing (see [Subscription Terms](/subscriptions/)).

## 1. Delete from inside the app (fastest)

1. Open PawDoc and go to **Account**.
2. Scroll to **Danger zone → Delete account**.
3. Confirm. We will permanently delete your account and associated data.

This option is always available in the app and does not require contacting us.

## 2. Request deletion on the web

If you can't access the app — for example, you've uninstalled it or changed phones — you can still request deletion:

> [!NOTE] **Web deletion request:** Email **[privacy@pawdoc.app](mailto:privacy@pawdoc.app?subject=Delete%20my%20PawDoc%20account)** from the email address on your PawDoc account, with the subject **"Delete my account."** We will verify that the request comes from the account holder and then permanently delete the account and associated data. We aim to complete verified requests promptly and within the timeframes required by applicable law.

You do **not** need to reinstall the app or buy anything to request deletion this way.

## 3. What gets deleted

Deleting your account permanently removes:

- your account and authentication record;
- your **pet profiles**;
- the **photos and videos** you uploaded;
- your **triage analyses and history**;
- your reminders and in-app preferences; and
- your subscription/entitlement record held by us.

## 4. What may be retained, and why

We may retain a **limited** amount of information where the law requires it or where we have a lawful, disclosed reason — for example, basic transaction and tax records for accounting/legal-compliance purposes, or minimal records needed to prevent fraud or abuse. Any retained data is kept only as long as necessary and is protected as described in our [Privacy Policy](/privacy/) and [Data Retention Policy](/data-retention/). Backups are purged on a rolling schedule.

## 5. Deleting specific data without closing your account

You don't have to delete your whole account to remove individual items. Within the app you can delete individual pets, analyses, and uploads. To request removal of specific data, contact [privacy@pawdoc.app](mailto:privacy@pawdoc.app).

## 6. Your broader rights

Deletion is one of several rights you may have. See [Your GDPR Rights](/gdpr/) and [Your California Privacy Rights](/ccpa/) for the full set and how to exercise them.

## 7. Contact

[privacy@pawdoc.app](mailto:privacy@pawdoc.app) · [LEGAL ENTITY], [BUSINESS ADDRESS].

---

<a id="11-data-retention"></a>

## 11. Data Retention Policy

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/data-retention · **Slug:** `/data-retention` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

This policy explains how long PawDoc keeps your information. We keep personal data only for as long as necessary for the purposes described in our [Privacy Policy](/privacy/), and then delete or de-identify it.

> [!NOTE] The periods below are PawDoc's current targets. **[The operator should confirm final retention periods with counsel before launch]**, particularly statutory tax-record periods, which vary by country.

## Retention at a glance

| Data | How long we keep it |
|---|---|
| **Account data** (email, auth identifiers) | For the life of your account; deleted when you delete your account |
| **Pet profiles** | For the life of your account; deleted on account deletion or when you remove the pet |
| **Uploaded photos/videos** | Stored to provide and revisit your analyses; deleted on account deletion (and removable individually at any time) |
| **Triage analyses & history** | For the life of your account; deleted on account deletion |
| **Reminders & in-app preferences** | For the life of your account; deleted on account deletion |
| **Subscription/entitlement records** | While active, plus the period required for accounting/legal compliance |
| **Billing/tax records** | As required by applicable tax and accounting law — **[e.g. 6–10 years; confirm per jurisdiction]** |
| **Product analytics events** | Retained in de-identified/aggregated form; **[confirm provider retention window]** |
| **Crash/error diagnostics** | A limited rolling window for debugging — **[e.g. 30–90 days]** |
| **Support communications** | A limited period after your request is resolved |
| **Backups** | Purged on a rolling schedule after deletion from production |

## Deletion

When you delete your account (see [Account Deletion](/deletion/)), we permanently remove your account and associated data from our active systems, and the data ages out of backups on the rolling schedule above. We may retain a limited set of records where the law requires it or where we have a lawful, disclosed reason (such as fraud prevention or tax compliance); any such records are minimized and protected.

## De-identification

Where we keep information for analytics or to improve the service, we use **aggregated or de-identified** data that does not identify you wherever practical.

## Changes

If we change our retention practices, we will update this page and the "Last updated" date. Questions: [privacy@pawdoc.app](mailto:privacy@pawdoc.app).

---

<a id="12-cookies"></a>

## 12. Cookie Policy

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/cookies · **Slug:** `/cookies` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

This Cookie Policy explains how PawDoc uses cookies and similar technologies. It supplements our [Privacy Policy](/privacy/).

## 1. The PawDoc mobile app

The PawDoc **mobile app does not use browser cookies**. Like most apps, it uses on-device storage and similar technologies — for example, to keep you signed in, remember your preferences, and (if you allow it) to gather analytics and diagnostics. These are described in our [Privacy Policy](/privacy/), and you can manage analytics, notifications, and other permissions in the app and in your device settings.

## 2. This website

This legal website is intentionally lightweight. It uses:

- **Strictly necessary storage** — for example, a small `localStorage` value that remembers your light/dark theme preference. This is essential to the site working as you expect and does not track you.

We do **not** use advertising cookies or third-party tracking cookies on this website. If that ever changes, we will update this page and provide any consent controls required by law.

## 3. Similar technologies in the app

Depending on your choices, the app and its service providers may use identifiers and SDKs for:

- **Analytics** (PostHog) — to understand how the app is used and improve it.
- **Crash/error diagnostics** (Sentry) — to find and fix problems.
- **Push notifications** (OneSignal) — only if you opt in.

You can opt out of analytics and notifications; see the [Privacy Policy](/privacy/) and your device settings.

## 4. Your choices

- **In the app:** manage notification and tracking permissions in your device settings, and analytics options where offered.
- **On this website:** clear your browser's storage for this site to reset the theme preference.

## 5. Contact

Questions: [privacy@pawdoc.app](mailto:privacy@pawdoc.app).

---

<a id="13-gdpr"></a>

## 13. Your GDPR Rights

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/gdpr · **Slug:** `/gdpr` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

If you are in the European Economic Area (EEA), the United Kingdom, or another region governed by the GDPR, this page summarizes your rights. It supplements our [Privacy Policy](/privacy/), which contains the full detail on what we process and why.

## 1. Controller and representative

The data controller is **[LEGAL ENTITY]**, **[BUSINESS ADDRESS]**. Our EU/EEA representative under Article 27 is **[EU REPRESENTATIVE — to be appointed]**, and our UK representative is **[UK REPRESENTATIVE — if targeting UK users]**. You can contact us about data protection at [privacy@pawdoc.app](mailto:privacy@pawdoc.app).

## 2. Your rights

Under the GDPR you have the right to:

- **Access** — obtain confirmation of whether we process your data and a copy of it (Art. 15).
- **Rectification** — have inaccurate data corrected (Art. 16).
- **Erasure** — have your data deleted ("right to be forgotten") (Art. 17). You can do this yourself via [Account Deletion](/deletion/).
- **Restriction** — limit how we process your data in certain cases (Art. 18).
- **Data portability** — receive data you provided in a portable format (Art. 20).
- **Object** — object to processing based on legitimate interests, and to direct marketing (Art. 21).
- **Withdraw consent** — at any time, where we rely on consent, without affecting prior processing.
- **Not be subject to solely automated decisions** with legal or similarly significant effects (Art. 22). PawDoc's triage is decision-support that always refers you to a veterinarian and does not have such effects; you can still contact us about it.
- **Complain** to a supervisory authority in your country.

## 3. Legal bases

We process your data under the bases set out in our [Privacy Policy](/privacy/) — principally **performance of a contract** (to provide the service), **consent** (for analytics, notifications, and marketing), **legal obligation** (billing/tax records), and **legitimate interests** (security and improving the service).

## 4. International transfers

Where your data is transferred outside the EEA/UK, we rely on appropriate safeguards — the **EU–US Data Privacy Framework** for certified providers, or **Standard Contractual Clauses** otherwise. See the [Privacy Policy](/privacy/) for details and how to request a copy of the safeguards.

## 5. A note on pet data

Information about your **pet** (including pet photos) is generally **not** "special category" data under Article 9, which protects information about people. Your own account and contact information are ordinary personal data and are fully protected. Because images can incidentally capture a person or location, we strip EXIF/GPS metadata and moderate uploads.

## 6. How to exercise your rights

Use the in-app controls (including [Account Deletion](/deletion/)) or email [privacy@pawdoc.app](mailto:privacy@pawdoc.app). We will verify your identity and respond within **one month**, extendable by two further months for complex requests, as the GDPR allows. There is normally no charge.

---

<a id="14-ccpa"></a>

## 14. Your California Privacy Rights

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/ccpa · **Slug:** `/ccpa` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

This notice is for California residents and describes your rights under the California Consumer Privacy Act, as amended (the **CCPA/CPRA**). It supplements our [Privacy Policy](/privacy/).

> [!NOTE] PawDoc applies these protections to California residents. Some CCPA obligations apply only to businesses above certain thresholds; we provide this notice for transparency regardless.

## 1. Categories of personal information

In the past 12 months, PawDoc may have collected these categories of personal information (as defined by the CCPA):

| Category | Examples | Collected? |
|---|---|---|
| Identifiers | Email, account/user ID, device identifiers | Yes |
| Customer records | Account details you provide | Yes |
| Commercial information | Subscription status, transaction records | Yes |
| Internet/network activity | App usage and interaction data | Yes |
| Geolocation | We **strip GPS/EXIF** from images; we do not collect precise location | No (by design) |
| Audio/visual | Photos and videos you submit of your pet | Yes |
| Sensitive personal information | We do not seek SSN, financial-account, precise geolocation, or similar consumer sensitive data | No |

We collect these from **you** and from your **device/use of the app**, for the business purposes described in our [Privacy Policy](/privacy/) (providing and securing the service, billing, analytics, and support).

## 2. We do not sell or "share" your personal information

PawDoc **does not sell** your personal information, and **does not "share"** it for cross-context behavioral advertising, as those terms are defined under the CCPA. Because we do not sell or share, no "Do Not Sell or Share My Personal Information" action is required — but you may still exercise the rights below. **[Operator: confirm the sale/share determination for analytics SDKs before launch; if any qualifies, add the opt-out link and honor Global Privacy Control signals.]**

## 3. Your rights

California residents have the right to:

- **Know** the categories and specific pieces of personal information we have collected, the sources, the purposes, and the categories of third parties we disclose to.
- **Delete** personal information we hold (with limited statutory exceptions). Use [Account Deletion](/deletion/).
- **Correct** inaccurate personal information.
- **Opt out** of sale or sharing — not applicable, as we do none.
- **Limit** the use of sensitive personal information — we do not use sensitive PI beyond permitted purposes.
- **Non-discrimination** — we will not discriminate against you for exercising your rights.

## 4. How to exercise your rights

Submit a request by emailing [privacy@pawdoc.app](mailto:privacy@pawdoc.app) or using the in-app controls. We will **acknowledge** your request within 10 business days and **respond** within 45 calendar days (extendable by 45 more where permitted). We will **verify** your identity before fulfilling a request, and may be unable to comply if we cannot verify it. You may use an **authorized agent** to submit a request on your behalf, with proof of authorization.

## 5. Contact

[privacy@pawdoc.app](mailto:privacy@pawdoc.app) · [LEGAL ENTITY], [BUSINESS ADDRESS].

---

<a id="15-children"></a>

## 15. Children's Privacy

**Live URL:** https://d1klm6zb1x23me.cloudfront.net/children · **Slug:** `/children` · **Effective:** 2026-06-15 · **Last updated:** 2026-06-15

PawDoc is intended for **adults** (pet owners 18 and older) and is **not directed to children**. This page explains how we approach children's privacy.

## 1. Not directed to children

PawDoc is a general-audience pet-health tool. Its content, design, and subject matter are not aimed at children, and we do not market it to children.

## 2. We do not knowingly collect children's data

We **do not knowingly collect personal information from children under 13** (the threshold under the U.S. Children's Online Privacy Protection Act, "COPPA"), or under the minimum age that applies in your country. If you are under the applicable age, please do not use PawDoc or provide any personal information.

If we learn that we have collected personal information from a child without the required parental consent, we will **delete it promptly**. If you believe a child has provided us with personal information, contact [privacy@pawdoc.app](mailto:privacy@pawdoc.app) and we will take appropriate action.

## 3. Age thresholds differ by region

Minimum ages for online services vary:

- **United States (COPPA):** the children's-privacy threshold is **under 13**.
- **EU/EEA (GDPR Art. 8):** the age of digital consent is **16 by default**, though individual countries may set it as low as 13.

Because PawDoc requires users to be **18 or older** (see our [Terms of Service](/terms/)), these thresholds are addressed by our eligibility requirement together with the "we do not knowingly collect" commitment above.

## 4. Parents and guardians

If you are a parent or guardian and believe your child has used PawDoc or given us their information, please contact [privacy@pawdoc.app](mailto:privacy@pawdoc.app). We will help you review and delete that information.

## 5. Contact

[privacy@pawdoc.app](mailto:privacy@pawdoc.app) · See also our [Privacy Policy](/privacy/).

---

*End of Legal Content Appendix — 15 documents.*
