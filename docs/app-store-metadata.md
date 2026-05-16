# App Store Metadata — Submission Draft

**Status:** Draft. Not yet submitted.
**Owner:** Founder (Phase 2 submission step).
**Companion:** [`sprint-a1-compliance-plan.md`](reports/sprint-a1-compliance-plan.md)

This file consolidates the App Store Connect copy + review notes for
PawDoc. Every string here has been written with two constraints in
mind:

1. **No medical-claim wording** — we are a triage information tool,
   not a medical device. Avoid "diagnose / cure / treat / prescribe /
   guaranteed" anywhere in user-visible store text.
2. **Reviewer-honest** — App Store reviewers read these strings.
   Misleading copy is a fast track to rejection.

The numbers in brackets are App Store character limits.

---

## Title (30 chars max)

```
PawDoc: Pet Health Triage
```

(25 chars)

Alternative if "Triage" feels clinical:
```
PawDoc — AI Pet Health Check
```
(29 chars)

We prefer "Triage" because it's accurate; "Check" is more colloquial
but also less precise.

---

## Subtitle (30 chars max)

```
Know when to call the vet.
```

(26 chars)

Captures the core value prop without making a medical claim.

---

## Promotional Text (170 chars max, editable post-launch)

```
AI triage in under 10 seconds, day or night. Photo, video, or text
— get an "EMERGENCY / MONITOR / NORMAL" guidance before you call the
vet. Less than $0.33 a day.
```

(166 chars; safe to edit between releases)

---

## Description (4000 chars max)

```
Worried about your pet at 2am? PawDoc gives you AI-powered triage
guidance in seconds — so you know whether to head to the emergency
vet, schedule a visit, or watch and wait.

How it works:
1. Snap a photo (or describe what you saw).
2. Our AI checks against breed-specific risk factors and common
   symptoms.
3. You get a clear "Emergency / Monitor / Normal" assessment with
   recommended next steps.

What you get with PawDoc:
• Instant AI triage — under 10 seconds on average
• Always-on emergency guidance — no waiting rooms, no scheduling
• Pet-specific context — your pet's species, breed, and age inform
  every response
• Clear next-step recommendations — what to watch for, when to call
  the vet
• Multi-pet support (Premium)

Important: PawDoc provides triage guidance, not a veterinary
diagnosis. We help you decide whether you need a vet — we never
replace one. All results carry a clear disclaimer and link to
"Find an emergency vet near me" when needed.

Subscription:
• Free tier: 3 analyses per month
• Premium: $9.99/month or $59.99/year (~$5/month)
• Family: $14.99/month or $89.99/year — unlimited pets
• Subscriptions auto-renew. Cancel anytime in your Apple ID
  settings.
• Terms of Service: https://pawdoc.app/terms
• Privacy Policy: https://pawdoc.app/privacy
```

(~1500 chars; well under the 4000 limit)

Notes:
- Uses "triage" + "guidance" + "assessment" — never "diagnosis"
- "EMERGENCY / MONITOR / NORMAL" is the literal label set, not a
  medical-grade claim
- Subscription disclosure follows Apple Guideline 3.1.2 verbatim
  structure
- "Find an emergency vet near me" foreshadows the Sprint A2 deep
  link that we are about to ship

---

## What's New (4000 chars max, per-release)

```
Phase 1 launch:
• AI triage for dogs, cats, rabbits, birds, and reptiles
• Emergency keyword detection — instant guidance on critical signs
• Pet profile + analysis history
• Premium subscription
```

(For 1.0 release. Subsequent releases append their own bullet list.)

---

## Keywords (100 chars, comma-separated)

```
pet,dog,cat,triage,vet,emergency,health,puppy,kitten,symptom,rabbit,bird
```

(73 chars)

Rationale:
- Targets the high-intent search queries from the strategy report
- No keyword stuffing
- Specifically avoid "diagnosis", "medical", "treatment"
- "emergency" is a high-CPC keyword but accurate

---

## Support URL

```
https://pawdoc.app/support
```

(must be live by submission)

## Marketing URL (optional)

```
https://pawdoc.app
```

## Privacy Policy URL (REQUIRED)

```
https://pawdoc.app/privacy
```

(must be live; subscription disclosure rule 3.1.2 requires it
reachable)

---

## Age Rating

| Concern | Rating |
|---------|--------|
| Medical/Treatment Information | Infrequent/Mild — "Triage guidance only; no medical advice" |
| Realistic Violence | None |
| Sexual Content | None |
| Profanity / Crude Humor | None |
| Horror / Fear Themes | None |
| Frequent / Intense Mature/Suggestive Themes | None |

**Expected rating:** 4+

---

## Screenshots (5 to 10 per device class)

Order matters — first 3 are shown in search results.

| # | Theme | Caption |
|---|-------|---------|
| 1 | Value prop | "Know exactly what your pet needs" + result screen (NORMAL) |
| 2 | How it works | Camera → loading → result triad (split image or 3-screen montage) |
| 3 | Anxiety relief | "No more 2am anxiety spirals." + NORMAL result with calm green badge |
| 4 | Trust | "Built with veterinary triage best practices" + disclaimer card (when vet advisor signs on — Phase 2) |
| 5 | Multi-pet (Premium) | Home screen with 3 pet cards |
| 6 | History (Premium) | Health history timeline (Phase 3) |

Phase 2 art deliverable — not part of Sprint A1.

---

## App Preview Video (optional, 30s max)

A 30-second screen-share showing: open app → tap "Check Luna" →
take photo → loading → MONITOR result. Voice-over: "PawDoc tells you
in 10 seconds whether to call the vet." Phase 2 deliverable.

---

## Review Notes (free-form, ~4000 chars max)

```
PawDoc is an AI-powered triage information tool for pet owners. It
provides "Emergency / Monitor / Normal" guidance based on a photo,
video, or text description of the pet. It is NOT a medical device and
does NOT diagnose. All results carry a clear, mandatory disclaimer
("PawDoc provides triage guidance, not a veterinary diagnosis.
Always consult a licensed veterinarian for medical decisions.").

Reviewer test account:
  Email: test-reviewer@pawdoc.app
  Password sent in the Apple Connect message.

Testing the analyze flow:
1. Sign in with the provided account.
2. The account has 3 free analyses available.
3. On the home screen tap "Check Luna" (a pre-existing pet).
4. Type "she has been quiet today" and tap Analyze.
5. You will receive a MONITOR-level result with the standard
   disclaimer.

Testing the emergency keyword path:
1. Same flow, but type "my dog had a seizure".
2. The result will be EMERGENCY with an "I understand" gate.

Testing the paywall:
1. Submit analyses until the free tier is exhausted (4th submission
   triggers the paywall).
2. The paywall shows Premium tiers; Apple sandbox handles the
   purchase.

Health-app compliance:
- We do not provide medical advice. Every result includes the
  disclaimer above.
- We do not claim to replace a veterinarian.
- The AI's role is triage (deciding when to escalate), not
  diagnosis.
- We use the term "triage" consistently in the UI and the App Store
  description.

Privacy:
- Email-OTP sign-in via Supabase (also Apple Sign In).
- No tracking SDKs. No advertising IDs. NSPrivacyTracking = false in
  PrivacyInfo.xcprivacy.
- All collected data is for app functionality only. See the
  PrivacyInfo.xcprivacy manifest for the full list.

Subscription & restore:
- Premium and Family tiers; managed via RevenueCat → StoreKit 2.
- "Restore Purchases" is on the paywall.
- Renewal disclosure and Privacy/Terms links on the paywall.
- Subscription state synced via webhook to our DB; the server is the
  authority.
```

Reviewer-facing tone: factual, calm, explicitly disclaiming medical
intent. Includes the test credential + step-by-step test flows.

---

## App Store Metadata Compliance Checklist

When submitting (Phase 2):

- [ ] Title ≤ 30 chars, no medical claim
- [ ] Subtitle ≤ 30 chars, no medical claim
- [ ] Description includes the canonical disclaimer
- [ ] Description lists subscription pricing + terms link
- [ ] Promotional text current
- [ ] What's New populated per release
- [ ] Keywords list audited (no "diagnosis", "treatment", "cure")
- [ ] Support URL live (`pawdoc.app/support`)
- [ ] Privacy Policy URL live (`pawdoc.app/privacy`)
- [ ] Terms of Service URL live (`pawdoc.app/terms`)
- [ ] Age rating 4+
- [ ] Reviewer test account created
- [ ] Review notes filled with the text above + a current screenshot
      of a NORMAL result
- [ ] All five required screenshots ready in 3-4 device sizes
- [ ] App Preview video uploaded (optional but increases conversion)
- [ ] Apple Sign In enabled in Supabase project + listed as an auth
      option in App Store Connect's Privacy practices

---

## Wording Survey — Strings I Audited

| Surface | Status |
|---------|--------|
| `mobile/lib/features/onboarding/*` | No medical-claim hits |
| `mobile/lib/features/analysis/*` | "Triage" + "disclaimer NOT a diagnosis" wording — safe |
| `mobile/lib/features/paywall/*` | Subscription disclosure correct; ToS/Privacy links pending Sprint A2 |
| `mobile/lib/features/home/*` | No medical claims |
| `mobile/lib/features/settings/*` | No claims |
| `ai-service/app/services/safety.py` | "Treatment" softened to "remedies or interventions" (Sprint A1) |
| `ai-service/app/services/orchestrator.py` | Internal — not user-visible |
| `ai-service/app/prompts/system_prompt.py` | Internal — uses "triage" framing |
| App Store description (this file) | Drafted with no medical claims |

---

*Draft last updated: 2026-05-16 (Sprint A1).*
