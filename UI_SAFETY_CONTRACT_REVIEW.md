# PawDoc — UI Safety-Contract Review

**Scope:** All 57 redesigned screens in `new-interface/`, reviewed against the frozen safety contract in
`CLAUDE.md` and `docs/contracts/ANALYSIS_RESULT.md`.
**Date:** 2026-07-30
**Status:** Review and copy proposals only. No UI redesigned, no layout changed, no code written.
**Companion documents:** `UI_ASSET_SPECIFICATION.md` (asset backlog), `UI_ASSET_PROMPT_LIBRARY.html`.

---

## 0. Executive Summary

### 0.1 What the contract says

The five rules that the redesign touches, verbatim from `CLAUDE.md`:

1. **"`confidence` is never shown to users"**
2. **"never name a condition"**
3. **"never render 'normal'"** — and *"the action ladder has no 'do nothing' rung … no output may terminate without an action and a timeframe"*
4. **"NEVER add anything to the emergency surfaces … no monetization, no affiliates, no upsells, no AI-driven content, no meter. The red path stays offline-capable and model-free."**
5. **"NEVER paywall / free-tier-block a GET_HELP_NOW result"**

### 0.2 Result

| | Count |
|---|---|
| Screens reviewed | 57 |
| Screens with at least one violation | **19** |
| Distinct violations catalogued | **24** |
| — Severity **CRITICAL** (contract-breaking, false-negative risk) | 9 |
| — Severity **HIGH** (contract-breaking, no direct false-negative path) | 8 |
| — Severity **MEDIUM** (framing / provenance) | 7 |
| Screens that are already compliant and should be used as the reference standard | 4 |
| Assets whose **visuals** must change as a result | **2 must / 2 should** (§2) |

### 0.3 The single most important finding

**`007-onboarding.png` already demonstrates the compliant pattern.** Its in-phone AI reply names no
condition, asserts no cause, gives an action plus a timeframe, and carries a correct disclaimer:

> "It depends on a few factors. A mild loss of appetite can happen for many reasons. […] If it continues
> for more than 24–48 hours or worsens, please consult your veterinarian."
> *"This is AI-generated guidance, not a diagnosis. Always consult your veterinarian."*

Every rewrite proposed below converges on that voice. **The redesign is not asking for a different product —
it is inconsistent with itself.** Four screens got it right; nineteen did not.

### 0.4 The pattern behind the violations

Three recurring mistakes account for 21 of the 24 findings:

1. **Naming a cause where the product can only describe an observation.** "Mild Skin Irritation",
   "Skin Infection", "Likely caused by licking", "mantar enfeksiyonları". The fix is always the same:
   describe *what was seen*, not *what it is*.
2. **Quantifying certainty.** `68% confidence`, `21% / 7% / 4%`. The fix is qualitative ordering.
3. **Terminating with reassurance instead of an action.** "No health issues detected", "Everything looks
   good!", "No signs of a serious condition", "Conditions 0 — Great!". The fix is to keep the positive
   tone but attach an observation window and a next step.

### 0.5 Compliant screens — do not change

| Screen | Why it is the standard |
|---|---|
| `007-onboarding.png` | Names no condition, asserts no cause, action + timeframe, correct disclaimer |
| `ai_transparency.png` | States *"Assistive, Not Diagnostic"*, *"AI insights are for informational purposes only and not a medical diagnosis"*, *"PawDoc AI does not replace a vet"* |
| `symptom_selection.png` | Symptom names are **user input**, not AI output — correctly scoped |
| `prepare_for_vet_visit.png` | Frames everything as preparation for a professional, never as an assessment |

---

## 1. Screen-by-Screen Violations

Severity key — **CRITICAL**: could cause an owner to skip or delay veterinary care (false-negative risk).
**HIGH**: breaks the contract without a direct false-negative path. **MEDIUM**: framing, provenance or
role-implication.

---

### V-01 · Confidence percentage on the primary AI result — **CRITICAL**

* **Screen:** AI Health Check — Results (low risk)
* **File:** `ai_analysis_result_low_risk.png`
* **Also appears on:** `ai_analysis_result_monitor.png`

**Exact text currently shown**

> Most Likely Cause
> **Mild Skin Irritation**   `68% confidence`

**Why it violates**

Two separate breaches in one component. `68% confidence` directly violates *"`confidence` is never shown to
users"*. "Mild Skin Irritation" as a **Most Likely Cause** violates *"never name a condition"* — it converts
an observation ("redness") into an attributed dermatological state, presented as the headline finding. The
percentage compounds the harm: 68 % reads to a lay owner as "probably fine", which is precisely the
inference that produces a false negative.

**Revised replacement** *(same card, same two-line hierarchy, same chip slot)*

> What the photo showed
> **Redness and scratching on the paw**   `Reviewed just now`

*The chip slot is preserved — it now carries a timestamp instead of a certainty value.*

---

### V-02 · Differential percentages — **CRITICAL**

* **Screen:** AI Health Check — Results (low risk)
* **File:** `ai_analysis_result_low_risk.png`

**Exact text currently shown**

> Other Possibilities
> ● Allergic Reaction (Environmental) ▬▬▬▬▬  **21%**
> ● Flea or Insect Bite ▬  **7%**
> ● Contact Irritation ▬  **4%**

**Why it violates**

A ranked differential diagnosis with probabilities. This is the most clinically loaded pattern in the whole
redesign: it names three conditions *and* quantifies each, which the contract forbids twice over. It also
implies the model performed a differential it is not qualified to perform, and the descending percentages
invite the owner to dismiss everything below the top line.

**Revised replacement** *(same list, same three rows, same bar track — bars become qualitative weight, no numerals)*

> Things a vet may want to rule out
> ● Environmental irritants ▬▬▬▬▬  `Worth mentioning`
> ● Fleas or insect bites ▬▬▬  `Worth mentioning`
> ● Contact with something new ▬▬  `Worth mentioning`
>
> *These are not findings. Share them with your vet.*

*If the owner wants a stronger simplification, the alternative that removes ordering entirely is in §3.4.*

---

### V-03 · "No signs of a serious condition" headline — **CRITICAL**

* **Screen:** AI Health Check — Results (monitor)
* **File:** `ai_analysis_result_monitor.png`

**Exact text currently shown**

> **Good news! ✨**
> **No signs of a serious condition**
> Our AI didn't detect anything serious. Keep monitoring Buddy and continue maintaining his healthy routine.

**Why it violates**

This is a rendered "normal" verdict, explicitly forbidden. Worse, it is stated as a *detection result*
("our AI didn't detect anything serious"), which a lay reader will hear as "the AI checked and it is not
serious" — a clearance the product cannot give from a single photo. It is the highest false-negative-risk
string in the redesign.

**Revised replacement** *(same two-line headline + same three-line body)*

> **Here's what we saw ✨**
> **Nothing that needs urgent action right now**
> This is not an all-clear. Keep watching Buddy over the next 48 hours and contact your vet if anything
> changes or you're unsure.

---

### V-04 · Risk chip carries a confidence value — **CRITICAL**

* **Screen:** AI Health Check — Results (monitor)
* **File:** `ai_analysis_result_monitor.png`

**Exact text currently shown**

> Overall Risk Level
> **Low**
> No urgent concerns detected.
> `68% confidence`

**Why it violates**

Same confidence breach as V-01, attached this time to the risk badge itself, where it is read as
"we are 68 % sure this is low risk" — the most dangerous possible placement for a certainty figure.
"No urgent concerns detected" additionally implies completed detection.

**Revised replacement** *(same card, same badge, chip slot retained)*

> Suggested next step
> **Monitor at home**
> Recheck in 48 hours · See a vet sooner if it changes.
> `Not a diagnosis`

---

### V-05 · Named condition on the emergency result — **CRITICAL**

* **Screen:** AI Health Check — Results (emergency)
* **File:** `ai_analysis_result_emergency.png`

**Exact text currently shown**

> **Potential Concern**
> **Skin Infection**
> Based on symptoms and visual analysis.

**Why it violates**

A named diagnosis rendered in the app's most authoritative visual treatment — large red type on the
emergency result. "Based on symptoms and visual analysis" adds a false evidentiary basis. Directly breaks
*"never name a condition"*. This tile is also the origin of the wording problem that propagates into the
`EMG-607` artwork (see §2.1).

**Revised replacement** *(same tile, same two-line hierarchy, same caption line)*

> **What to show your vet**
> **An open sore above the right eye**
> Describe when you first noticed it and whether it has changed.

---

### V-06 · Diagnostic bullet list on the emergency result — **CRITICAL**

* **Screen:** AI Health Check — Results (emergency)
* **File:** `ai_analysis_result_emergency.png`

**Exact text currently shown**

> Why it's serious:
> • **Visible skin lesion / possible infection**
> • Swelling or irritation detected
> • Discomfort may be present
> • Could worsen if left untreated

**Why it violates**

"Possible infection" names a condition. "Why it's **serious**" asserts severity as established fact rather
than as a reason to seek care. The list mixes observation ("visible lesion") with inference ("possible
infection") with prognosis ("could worsen") in one undifferentiated bullet set, so the owner cannot tell
which parts the app actually saw.

**Revised replacement** *(same heading + same four bullets)*

> Why we're flagging this:
> • An open, raw area of skin is visible
> • The surrounding area looks swollen
> • Buddy's posture suggests he may be uncomfortable
> • Skin injuries can worsen quickly without treatment

---

### V-07 · "for faster diagnosis" — **HIGH**

* **Screen:** AI Health Check — Results (emergency)
* **File:** `ai_analysis_result_emergency.png`

**Exact text currently shown**

> Share this report with your vet
> Show this result to your veterinarian for **faster diagnosis**.

**Why it violates**

Positions the AI output as a diagnostic input that accelerates clinical decision-making. This both
overstates the artefact's clinical value and implies the vet should weight it. The report is a symptom
record and a photo, not a diagnostic aid.

**Revised replacement** *(same two lines)*

> Share this record with your vet
> Give your veterinarian the photo, symptoms and timeline in one place.

---

### V-08 · Health Score used as a clinical verdict — **HIGH**

* **Screen:** AI Health Check — Results (emergency)
* **File:** `ai_analysis_result_emergency.png`

**Exact text currently shown**

> Health Score
> **36**  **At Risk**
> Needs immediate attention

**Why it violates**

A composite score presented as a clinical status. The score is computed from record completeness and
logging activity, not from a physical examination — but "36 / At Risk" reads as a measured deterioration.
It is also a *meter*, and the emergency path is explicitly meter-free under rule 4. The inverse problem
appears on the low-risk screens, where "92 Excellent" sits beside a symptom the owner is actively worried
about.

**Revised replacement** *(same tile — remove the numeric ring on the emergency variant, keep the tile)*

> Care status
> **Action needed**
> Contact a veterinarian now

*On the non-emergency result screens, relabel the ring "Record completeness — 92%" so the number describes
what it actually measures. See V-19.*

---

### V-09 · Home screen renders an all-clear — **CRITICAL**

* **Screen:** Home
* **File:** `010-home-page.png`

**Exact text currently shown**

> **Buddy is doing great! ✨**
> **No health issues detected**

**Why it violates**

This is the first thing every user sees, every session, and it is a rendered "normal" verdict presented as
a detection outcome. The app has detected nothing — it is reporting the absence of logged records. An owner
whose pet is quietly unwell is told, on the home screen, that no health issues exist. Highest-traffic
false-negative surface in the product.

**Revised replacement** *(same two-line card, same vitals row beneath)*

> **Buddy's day at a glance ✨**
> **Nothing logged that needs action today**

---

### V-10 · Timeline entry asserts a cause — **CRITICAL**

* **Screen:** Health Timeline
* **File:** `health_timeline.png`

**Exact text currently shown**

> **AI Skin Analysis**  `Low Risk`   10:24 AM
> Mild redness detected on Buddy's paw. **Likely caused by licking.** Monitor for 2–3 days.

**Why it violates**

"Likely caused by licking" is a causal attribution the model cannot make from a photograph, written into
the pet's **permanent health record**. Once saved to the diary and later exported into the PDF report, an
AI guess becomes indistinguishable from a clinical note. `Low Risk` as a persisted label compounds it.

**Revised replacement** *(same title + chip + same two-line body)*

> **AI Photo Review**  `Monitor`   10:24 AM
> Redness noted on Buddy's paw. Cause not determined. Recheck in 2–3 days; see a vet if it spreads.

---

### V-11 · Assistant names conditions as causes — **CRITICAL**

* **Screen:** AI Assistant — Chat *(Turkish)*
* **File:** `ai_assistant_chat.png`

**Exact text currently shown**

> "Patisindeki kızarıklık birkaç farklı nedenden kaynaklanabilir. En yaygın nedenler arasında **alerjiler,
> tahriş, mantar enfeksiyonları veya yabancı cisimler** bulunur."
> *(= "…the most common causes include allergies, irritation, fungal infections or foreign bodies.")*

and, in the second reply:

> "Alerji genellikle kaşıntı, kızarıklık, sık yalama, gözlerde sulanma veya **kulak enfeksiyonlarıyla**
> birlikte görülür."

**Why it violates**

Enumerates named conditions (fungal infection, allergy, ear infection) as the causes of the user's pet's
current symptom. The disclaimer at the bottom does not cure this — the contract forbids naming the
condition, not merely forbids claiming certainty.

**Revised replacement** *(same bubble, same paragraph + bullet structure, Turkish preserved)*

> "Patisindeki kızarıklığın pek çok farklı nedeni olabilir ve bunu bir fotoğraftan anlamak mümkün değil.
> Şimdilik şunları yapabilirsin:"
> *(= "Redness on the paw can have many different causes, and it isn't possible to tell from a photo.
> For now you can:")*
> • Patisini ılık suyla nazikçe temizle.
> • İyice kurula.
> • Yalama veya kaşımayı önlemek için yakından takip et.
> • **48 saat içinde düzelmezse ya da kötüleşirse veterinere başvur.**

Second reply:

> "Kaşıntı, kızarıklık ve sık yalama birlikte görüldüğünde bunun nedenini ancak bir veteriner
> belirleyebilir. Belirtileri ne zaman başladığını not et ve veterinerinle paylaş."

---

### V-12 · Suggestion chips presuppose conditions — **HIGH**

* **Screen:** AI Assistant — Chat *(Turkish)*
* **File:** `ai_assistant_chat.png`

**Exact text currently shown**

> `Mantar enfeksiyonu belirtileri nelerdir?`  ·  `Alerji mi, enfeksiyon mu?`
> *(= "What are the symptoms of a fungal infection?" · "Is it an allergy or an infection?")*

**Why it violates**

The second chip invites the assistant to choose between two named diagnoses for this specific pet — the
app is proposing that the user request a diagnosis. Chip text is app-authored, so this is PawDoc's voice,
not the user's.

**Revised replacement** *(same four chips, same icons)*

> `Pati bakımı nasıl yapılır?` · `Ne zaman veterinere gitmeliyim?` · `Nelere dikkat etmeliyim?` · `Aşı takvimi nasıl olmalı?`

---

### V-13 · Onboarding assistant names conditions — **HIGH**

* **Screen:** Onboarding — Meet your AI Pet Assistant
* **File:** `006-onboarding.png`

**Exact text currently shown**

> "**Sneezing can be caused by mild irritants, allergies, or infections.**"

**Why it violates**

Names three conditions in the product's own marketing demo. This is the first impression of how the
assistant behaves, and it teaches users to expect cause attribution. Note `007-onboarding.png` — the very
next screen — models the correct behaviour, so the redesign contradicts itself one screen apart.

**Revised replacement** *(same single line, same position)*

> "Sneezing on its own usually isn't urgent, but the cause isn't something I can determine."

---

### V-14 · Onboarding triage card renders "Low urgency" as a finding — **HIGH**

* **Screen:** Onboarding — AI insights
* **File:** `003-onboarding.png`

**Exact text currently shown**

> AI Triage Result
> **Monitor at Home**   ● Low urgency
> **Why?**
> **No critical signs detected.** Keep observing your pet and monitor any changes.

Also on this screen — a **spelling error in the disclaimer**:

> "PawDoc provides guidance, not diagnosis. Always consult your **veterinarion**."

**Why it violates**

"No critical signs detected" is a rendered clearance. "AI Triage **Result**" frames the output as a
conclusion rather than a suggestion. The misspelling of "veterinarian" in the one line that carries the
legal disclaimer is separately unacceptable in a safety-critical product.

**Revised replacement** *(same card, same label + status + reason structure)*

> Suggested next step
> **Monitor at home**   ● Recheck in 24–48 h
> **Why?**
> Nothing here calls for urgent action right now. Keep watching and contact a vet if anything changes.

> "PawDoc provides guidance, not diagnosis. Always consult your **veterinarian**."

---

### V-15 · Capability claims promise identification — **HIGH**

* **Screen:** AI Health Check — Start
* **File:** `ai_health_check_start.png`

**Exact text currently shown**

> Skin & Coat — **Identify irritation, allergies & more**
> Eyes, Ears & Nose — **Check for signs of infection**

and, lower on the same screen:

> Recent Checks — Buddy · **Skin irritation check** · **Low risk**

**Why it violates**

"Identify … allergies" and "check for signs of infection" are explicit promises to detect named conditions,
made *before* the user has even started. They set the expectation the rest of the flow then fulfils.
The saved-check label "Skin irritation check / Low risk" persists a named condition plus a clearance.

**Revised replacement** *(same four capability tiles, same title + description structure)*

> Skin & Coat — Spot changes in skin and fur
> Eyes, Ears & Nose — Note discharge, redness or swelling

> Recent Checks — Buddy · Paw photo review · Monitor

---

### V-16 · AI triage placed on the emergency surface — **CRITICAL** *(contract rule 4)*

* **Screen:** Emergency Hub
* **File:** `emergency_hub.png`

**Exact text currently shown**

> Quick Actions → **AI Triage** / Check symptoms now
> Your Pets → **At Risk Pets  1** · Luna · ⚠ **Needs Attention** · **Based on recent symptoms (Vomiting, Loss of appetite)** · [View Triage]
> **Heat Alert in Your Area** — High temperatures can be dangerous for pets. [See Tips] [×]

**Why it violates**

Rule 4 is absolute: *"NEVER add anything to the emergency surfaces … no AI-driven content … The red path
stays offline-capable and model-free."* Three separate additions breach it — an AI triage entry point, an
AI-derived "At Risk / Needs Attention" assessment, and a dismissible promotional alert strip. The
model-dependency is the core problem: if the AI service is unreachable, these controls fail on the one
screen that must work offline.

**Revised replacement** *(preserve the five-tile Quick Actions row and the pet row; change what the first
tile does and how the pet row is labelled)*

> Quick Actions → **Emergency Checklist** / What to do right now  *(offline, static content)*
> Your Pets → **Recently logged  1** · Luna · **Symptoms logged 2 days ago** · Vomiting, Loss of appetite · [View records]
> *Remove the Heat Alert strip from this screen entirely; relocate it to Home.*

**Note:** the AI Triage entry point is not being deleted from the product — it moves to Home and the AI Care
tab, where it already exists. Only the emergency surface is cleared.

---

### V-17 · AI triage on the first-aid surface — **CRITICAL** *(contract rule 4)*

* **Screen:** First Aid Guide
* **File:** `first_aid_guide.png`

**Exact text currently shown**

> **Not sure what's wrong?**
> Answer a few questions and our **AI Triager** will guide you.
> [ ✨ **Start AI Triage** ]   `✨ AI Powered`

**Why it violates**

The same rule-4 breach as V-16, in the most consequential position: a model-dependent call-to-action
occupying the hero slot of the first-aid screen. An owner arriving here has an animal in front of them and
needs static instructions immediately. "Not sure what's wrong?" also frames first aid as a diagnostic
funnel. This banner is the sole reason asset `AI-306` exists — see §2.1.

**Revised replacement** *(same hero banner, same headline + body + button + corner badge geometry)*

> **Not sure where to start?**
> Find the right first-aid steps by what you can see right now.
> [ **Browse by symptom** ]   `Works offline`

---

### V-18 · Conversation title states a condition as fact — **MEDIUM**

* **Screen:** Conversation History
* **File:** `conversation_history.png`

**Exact text currently shown**

> **Patrondaki mantar enfeksiyonu**
> Mantar enfeksiyonları halk arasında ringworm olarak…
> *(= "The fungal infection on the paw pad" / "Fungal infections are commonly known as ringworm…")*

**Why it violates**

The conversation is titled with a definite named condition — "*the* fungal infection", not "a question
about". Because this list is app-generated from the thread, PawDoc is asserting the pet had a fungal
infection, and that assertion persists in the history.

**Revised replacement** *(same title + preview line)*

> **Pati bakımı hakkında soru**  *(= "Question about paw care")*
> Kızarıklık ve tahriş belirtileri için nelere dikkat edilmeli…

---

### V-19 · "Conditions 0 — None — Great!" — **HIGH**

* **Screen:** Pet Profile
* **File:** `pet_profile.png`

**Exact text currently shown**

> ⚠ **Conditions**
> **0**
> None
> 🙂 **Great!**

**Why it violates**

Zero *recorded* conditions is being rendered as zero *existing* conditions, then celebrated. This is a
"normal" verdict derived from an empty database. A newly onboarded user with a sick pet sees "Conditions 0
— Great!" on day one.

**Revised replacement** *(same tile, same four-line hierarchy)*

> ⚠ **Conditions**
> **0**
> None recorded
> `Add a condition ›`

---

### V-20 · Baseline screen renders an all-clear — **HIGH**

* **Screen:** Know Your Baseline
* **File:** `know_your_baseline.png`

**Exact text currently shown**

> **Everything looks good! 🎉**
> Buddy's vitals are stable and well within his normal range.

**Why it violates**

A clearance statement about **vital signs** — heart rate, respiratory rate, body temperature. PawDoc has no
sensors; these values are owner-entered and sparse. Presenting them as monitored vitals that are "within
normal range" implies clinical surveillance the product does not perform, and "Everything looks good"
terminates with no action.

**Revised replacement** *(same headline + body + button)*

> **Your log is consistent 🎉**
> The values you've logged for Buddy have stayed inside the range you set. This reflects what you've
> entered, not a health assessment.

**Additional requirement (not a wording change):** every vital-sign tile on this screen must carry a
"self-reported" provenance marker. See §4.2.

---

### V-21 · Statistics screen renders an all-clear — **MEDIUM**

* **Screen:** Pet Statistics
* **File:** `pet_statistics.png`

**Exact text currently shown**

> 🐾 **All good! Keep it up**
> **Great Job!** Buddy's health score has improved by 14 points in the last 3 months.

**Why it violates**

Same class as V-09/V-20 — a wellness verdict derived from record-keeping activity. "Health score improved
by 14 points" describes better logging, not better health, but is worded as a health improvement.

**Revised replacement** *(same two callouts)*

> 🐾 **Records up to date**
> **Nice work!** Buddy's records have been 14 points more complete over the last 3 months.

---

### V-22 · PDF report cannot distinguish AI output from vet records — **HIGH**

* **Screen:** PDF Health Report Preview
* **File:** `pdf_health_report_preview.png`

**Exact text currently shown**

> Recent Visits → Apr 10, 2026 · **Skin Infection Follow-up** · PawCare Veterinary Clinic · Dr. Emily Carter
> Recent Visits → Mar 02, 2026 · **Gastroenteritis** · CityVet Hospital · Dr. Michael Brown
> Active Medications → Apoquel 16mg · **For Allergic Dermatitis**
> Allergies → **Food Allergy** · Chicken, Beef · Severity **Moderate**
> Health Summary → **2 Lab Results — Normal**

**Why it violates**

**These specific strings are legitimate.** They are vet-origin records attributed to named clinicians with
dates — the contract restricts *AI output*, not the owner's or the vet's own medical records. Suppressing
them would make the report clinically useless.

The violation is **provenance**: the report is generated by PawDoc, exported under the PawDoc masthead, and
carries a "Scan to verify" QR — but nothing on the page distinguishes a veterinary diagnosis from an
owner's note from an AI photo review. Once V-10's "AI Skin Analysis / Likely caused by licking" is saved to
the diary, it flows into this report and reads as clinical record. A vet receiving the PDF cannot tell
which lines to trust.

**Revised replacement** *(no wording change to the records themselves — add a provenance column and a legend
band; both fit the existing card layout)*

> Each record row gains a small source tag: `Vet` · `Owner` · `AI review`
> Footer legend: **"`Vet` entered from a veterinary visit · `Owner` entered by the pet's owner ·
> `AI review` an automated photo observation, not a diagnosis."**
> Health Summary tile: "2 Lab Results — **Normal (per vet report)**"

**Additional requirement:** AI-origin rows must be excluded from the "Recent Visits" and "Allergies"
sections entirely — those sections imply clinical authorship.

---

### V-23 · "AI Vet Assistant" implies a veterinarian — **MEDIUM**

* **Screens:** AI Assistant — Chat, AI Assistant — Home, Conversation History
* **Files:** `ai_assistant_chat.png`, `ai_assistant_home.png`, `conversation_history.png`

**Exact text currently shown**

> PawDoc AI ✨
> **AI Vet Assistant**

**Why it violates**

"Vet Assistant" is ambiguous between *"an assistant for vets"*, *"an assistant that is a vet"* and
*"an assistant for vet-related topics"*. In several jurisdictions, implying veterinary practice without a
licence is a regulatory matter, not just a copy question. `ai_transparency.png` already states the correct
position — "Assistive, Not Diagnostic" — so this label contradicts the app's own disclosure screen.

**Revised replacement** *(same two-line header, same type scale)*

> PawDoc AI ✨
> **Pet care assistant**

---

### V-24 · Emergency tab displaced by Premium — **HIGH** *(contract rule 5, structural)*

* **Screens:** `premium_home.png`, `subscription_plans.png`, `upgrade_benefits.png`, `usage_limits.png`, `privacy_security.png`, `account_management.png`, `profile.png`, `notifications.png`, `ai_transparency.png`
* **Files:** as listed (9 screens)

**Exact state currently shown**

Bottom navigation on `emergency_hub.png` and `first_aid_guide.png`:
`Home · Pets · AI Care · Community · **Emergencies** · Profile`

Bottom navigation on the nine screens above:
`Home · Pets · AI Care · Community · **Premium** · Profile`

**Why it violates**

The emergency entry point is removed from the tab bar and replaced by a monetisation tab on nine screens,
including every billing screen. An owner on the subscription screen whose pet begins choking has no
one-tap route to the emergency surface. This is not a wording issue and cannot be fixed with copy — it is
a navigation-structure decision that contradicts *"NEVER paywall / free-tier-block a GET_HELP_NOW result"*
in spirit and removes the offline red path in practice.

**Revised replacement** *(no redesign — the slot assignment changes)*

> `Emergencies` occupies a permanent tab-bar slot on **all** screens.
> `Premium` moves into Profile as a row, which is where `profile.png` and `account_management.png` already
> surface it ("PawDoc Premium · Active · Manage Plan").

---

## 2. Asset Prompt Corrections

Only assets whose **visuals** must change because of the revised wording. Unaffected prompts are not
reproduced. All edits are applied in `UI_ASSET_SPECIFICATION.md` §6 and carried into
`UI_ASSET_PROMPT_LIBRARY.html`.

### 2.1 MUST change

---

#### `EMG-607` — Dog with facial skin lesion

* **Filename:** `emg-dog-lesion-clinical@3x.webp`
* **Screen(s):** `ai_analysis_result_emergency.png`
* **Driver:** V-05, V-06 — the tile changed from "Skin Infection" to "An open sore above the right eye". The
  artwork was written to depict an *infected* lesion; it must now depict an *observable injury* without
  implying infection.

**Old prompt**

> Photorealistic clinical photograph of an adult Golden Retriever lying down on a soft surface with its head
> resting on its front paws, eyes open but subdued, expression tired and unwell. Above the right eyebrow
> there is a visible circular skin lesion roughly two centimetres across: reddened inflamed skin with hair
> loss around the margin and **a moist raw centre**. No blood, no pus, no gore — a realistic but restrained
> **dermatological presentation**. Warm desaturated colour grade, soft directional window light from the
> front-left, very shallow depth of field with a blurred neutral background. Sombre but not distressing.
> Veterinary-reference photography quality, no text, no instruments, no human hands in frame.

**New corrected prompt**

> Photorealistic photograph of an adult Golden Retriever lying down on a soft surface with its head resting
> on its front paws, eyes open but subdued, expression tired and low-energy. Above the right eyebrow there
> is a clearly visible sore patch roughly two centimetres across: reddened, slightly swollen skin with
> thinned fur around the edges and a shallow open graze at the centre. It must read as **a visible injury an
> owner would photograph to show a vet** — obvious and worth attention, but not clinically characterised: no
> crusting, no discharge, no pus, no weeping, no blood, no gore, nothing that suggests a specific diagnosis.
> Warm desaturated colour grade, soft directional window light from the front-left, very shallow depth of
> field with a blurred neutral background. Sombre but not distressing. Natural photography, no text, no
> medical instruments, no human hands in frame.

---

#### `AI-306` — First-aid guide hero banner

* **Filename:** `ai-triage-banner-cross-hud@3x.webp` → **rename** `emg-firstaid-banner@3x.webp`
* **Screen(s):** `first_aid_guide.png`
* **Driver:** V-17 — the banner is no longer an "AI Triager" entry point but a "Browse by symptom" entry
  point that works offline. The HUD/radar/scan-line treatment exists solely to signal AI analysis and must
  be removed; a scanning reticle on a first-aid screen also implies the app is examining the animal.
* **Reclassification:** family `AI` → `EMG`; folder `assets/images/ai/` → `assets/images/emergency/`;
  the C-5 HOLD is released by this rewrite.

**Old prompt**

> A wide dark banner artwork. On the right third, a photorealistic Golden Retriever head in three-quarter
> view looking toward the camera, warm golden fur, cinematic side light, emerging from darkness. On the
> left-of-centre, a bright glowing green medical cross (equal rounded arms) sits inside **two concentric
> thin green HUD rings with short tick marks around the circumference, like a radar or targeting reticle.
> Thin horizontal scan lines and fine green particles drift across the dark left half.** Deep black
> background fading to dark green near the reticle. Strong neon bloom on the cross and rings, warm natural
> light on the dog. No text, no UI chrome, no lettering.

**New corrected prompt**

> A wide dark banner artwork. On the right third, a photorealistic Golden Retriever head in three-quarter
> view resting calmly and looking toward the camera, warm golden fur, soft cinematic side light, emerging
> from darkness with a reassuring rather than clinical mood. On the left-of-centre, a bright glowing green
> medical cross with equal rounded arms, surrounded by **two soft concentric halo rings of light with
> smooth, even edges and no tick marks, no crosshairs, no scan lines and no targeting geometry**. A gentle
> green glow falls off evenly into the dark left half. Deep black background fading to dark green near the
> cross. Warm natural light on the dog, calm neon bloom on the cross. Nothing in the image should suggest
> scanning, measuring or analysing the animal. No text, no UI chrome, no lettering.

---

### 2.2 SHOULD change

These two are defensible either way; the link to a wording change is real but weaker than §2.1. Flagged so
the owner can decide rather than have it decided silently.

---

#### `AI-303` — AI scan HUD overlay (dog head)

* **Filename:** `ai-scan-hud-dog@3x.webp` *(layer 2 only — the photo layer is unchanged)*
* **Screen(s):** `003-onboarding.png`
* **Driver:** V-14 — the card beneath changed from "AI Triage Result / No critical signs detected" to
  "Suggested next step / Monitor at home". The overlay's facial-landmark mesh depicts biometric measurement
  precision the product does not have, and it is the visual that sells "the AI examined your dog".

**Old prompt** *(layer 2)*

> A futuristic green facial-analysis overlay made of thin bright lime-green `#4ADE50` lines: four L-shaped
> corner brackets framing a square scan area; a faint square wireframe grid across the whole area; **about
> eight small glowing circular landmark nodes placed along a muzzle-eye-ear path, connected by thin straight
> lines into a mesh**; and one bright horizontal scanning beam sweeping across the middle with a soft glow
> falloff above and below it. Fine drifting light particles. Strong neon bloom, no text, no numbers, no UI
> panels.

**New corrected prompt** *(layer 2)*

> A soft green photo-review overlay made of thin bright lime-green `#4ADE50` lines: four L-shaped corner
> brackets framing a square area, indicating a photo being viewed rather than a subject being measured; a
> very faint square grid at low opacity across the area; and one gentle horizontal light sweep across the
> middle with a soft glow falloff above and below it. **No landmark nodes, no connecting mesh, no facial
> tracking points, no biometric markers and nothing anchored to the animal's anatomy.** Fine drifting light
> particles. Soft neon bloom, no text, no numbers, no UI panels.

---

#### `DOC-1501` — PDF health-report page thumbnails

* **Filename:** `doc-pdf-page-thumb-{01..06}@3x.webp`
* **Screen(s):** `pdf_health_report_preview.png`
* **Driver:** V-22 — the report gains a per-row provenance tag and a footer legend band. The thumbnails are
  deliberately illegible, but the page silhouette changes: rows become slightly taller and a distinct
  legend band appears at the foot of the page.

**Old prompt**

> Six small vertical document-page thumbnails on a dark background, each showing a blurred, unreadable
> dark-themed report layout: a header band at the top, two or three rounded content cards with faint lime
> and grey horizontal lines standing in for text, and small coloured dots standing in for icons.
> Deliberately illegible — this is a shrunken-page impression, not readable content. Slight variation in
> card arrangement between the six. No real text, no lettering, no logos.

**New corrected prompt**

> Six small vertical document-page thumbnails on a dark background, each showing a blurred, unreadable
> dark-themed report layout: a header band at the top, two or three rounded content cards with faint lime
> and grey horizontal lines standing in for text, and small coloured dots standing in for icons.
> **Each content row ends with a very small pill-shaped tag mark at its right edge, and a narrow separated
> band sits at the foot of every page carrying three tiny pill marks in a row, standing in for a source
> legend.** Deliberately illegible — this is a shrunken-page impression, not readable content. Slight
> variation in card arrangement between the six. No real text, no lettering, no logos.

---

### 2.3 Explicitly NOT changed

Checked and confirmed unaffected — recorded so the decision is not revisited:

| Asset | Why the wording change does not reach it |
|---|---|
| `INF-504` clinical paw-redness thumbnail | Prompt already specifies "mild irritation … not a wound, no blood, no discharge" — descriptive, no condition implied |
| `ICN-802` symptom pictograms (24) | Depict **user-selected symptoms**, which the contract permits |
| `ICN-803` anatomy glyphs (12) | Serve breed-level education on `breed_detail`; V-25 in §4.1 adds framing copy, not new artwork |
| `ICN-805` first-aid topic tiles (8) | Bleeding / Choking / Poisoning / Heatstroke are **first-aid topics**, not diagnoses of the user's pet |
| `ILL-403` leaf illustration | Decorative; survives the "Possible Cause" → "What the photo showed" relabel |
| `EMG-603` red shield with `!` | Severity mark, not a condition claim; V-04's relabel keeps it |
| `AI-304` loading scan composite | Its arc is **load progress**, already specified with no baked-in numerals |
| `AI-305` hologram dog + cat | Lives on `ai_transparency.png`, the compliant reference screen |
| `PRM-701` 3D "AI Health Insights" robot | Premium feature iconography, makes no health claim |

---

## 3. Confidence, Probability & Percentage Review

Every numeric value in the redesign that could be read as certainty was located and classified.

### 3.1 Values that MUST be removed

| # | Screen | File | Current value | Context | Replacement |
|---|---|---|---|---|---|
| 1 | AI Result (low risk) | `ai_analysis_result_low_risk.png` | **68% confidence** | Chip beside "Most Likely Cause: Mild Skin Irritation" | `Reviewed just now` |
| 2 | AI Result (monitor) | `ai_analysis_result_monitor.png` | **68% confidence** | Chip inside the "Overall Risk Level: Low" card | `Not a diagnosis` |
| 3 | AI Result (low risk) | `ai_analysis_result_low_risk.png` | **21%** | Differential — "Allergic Reaction (Environmental)" | `Worth mentioning` |
| 4 | AI Result (low risk) | `ai_analysis_result_low_risk.png` | **7%** | Differential — "Flea or Insect Bite" | `Worth mentioning` |
| 5 | AI Result (low risk) | `ai_analysis_result_low_risk.png` | **4%** | Differential — "Contact Irritation" | `Worth mentioning` |

**That is the complete set.** Five values across two screens. No other confidence, probability, certainty
or likelihood figure exists anywhere in the 57 screens.

### 3.2 Values searched for and NOT found as certainty

The brief asked specifically about `82%` and `91%`. Both strings **do** appear in the redesign, but neither
is a confidence value:

| Value | Where it actually appears | Classification |
|---|---|---|
| `82` | `pet_statistics.png` — Health Score Trend chart, Jun '24 data point | Health-score history, not a percentage |
| `91` | `pet_statistics.png` — Health Score Trend chart, Nov '24 data point | Health-score history, not a percentage |

No screen displays "82% confidence" or "91% confidence". Reported plainly rather than forced into the
violation list.

### 3.3 Percentages that are legitimate — do NOT change

Removing these would damage the product for no safety gain. Each measures something real and non-clinical:

| Screen | Value | What it actually measures | Verdict |
|---|---|---|---|
| `ai_analysis_loading.png` | **72%** | Analysis **load progress** | Keep — label the ring "Analyzing… 72%" so it can never read as certainty |
| `medication_tracker.png` | **96%**, **100%** | Medication **adherence** (doses taken ÷ doses due) | Keep |
| `know_your_baseline.png` | **92%** | **Logging** consistency | Keep — relabel "Logging consistency" (currently just "Consistency") |
| `pet_statistics.png` | **24 / 34 / 14 / 10 / 18%** | Record-type **distribution** in a donut chart | Keep |
| `weather_walk_advisor.png` | **85/100**, hourly 68–92 | **Walk comfort** score from weather | Keep |
| `weather_walk_advisor.png` | **%48** | Atmospheric **humidity** | Keep |
| `subscription_plans.png` | **Save 33%** | Pricing discount | Keep |
| `upgrade_benefits.png` | — | — | No percentages present |

### 3.4 The Health Score — a separate decision

`92/100 Excellent`, `36 At Risk` and `Baseline Strength 92/100` are **not** confidence values, so they fall
outside the brief's scope. They are flagged here because they carry the same risk by a different route:
a number that looks like a clinical measurement but is computed from record completeness.

Three options, in order of preference:

1. **Relabel** — "Record completeness · 92%" / "Care activity · 92". Cheapest, honest, preserves every ring
   and gauge in the layout. **Recommended.**
2. **Restrict** — keep "Health Score" but never render it on an AI result screen or the emergency surface
   (removes V-08's "36 At Risk" and the jarring "92 Excellent" beside an active symptom).
3. **Remove** — delete the metric. Highest design cost: touches 9 screens and 4 assets.

### 3.5 Alternative for the differential block

If the owner prefers to remove ranked ordering entirely rather than keep V-02's three qualitative rows,
this variant collapses the block and preserves the card:

> **Things that can cause this**
> Redness like this has many possible causes — environmental irritants, parasites, or contact with
> something new are all common. Only a vet can tell which applies to Buddy.
> `Share this list with your vet ›`

Trade-off: loses the scannable three-row rhythm the design uses, but eliminates any implied ranking.

---

## 4. Additional Findings

Outside the brief's three passes, but discovered during the review and material to safety or quality.

### 4.1 Framing gaps

| # | Screen | Issue | Proposed fix |
|---|---|---|---|
| V-25 | `breed_detail.png` | "Common Health Conditions — Hip Dysplasia · Risk: Moderate" sits in a pet-specific context. Breed-level statistics can be misread as an assessment of *this* dog. | Add a caption under the card heading: **"Breed-level information. Not an assessment of Buddy."** Keep the icons and risk dots. |
| V-26 | `ai_health_check_start.png` | "Get AI-powered insights about your pet's health **in minutes**" — speed framing on a health-assessment surface encourages substituting the app for a visit. | "Get a second set of eyes on what you're seeing." |
| V-27 | `first_aid_guide.png` | Topic list is sorted "Most relevant" — an algorithmic ordering on an offline safety surface. | Sort by fixed priority (Bleeding, Choking, Poisoning, Heatstroke first), no model input. |

### 4.2 Provenance markers (applies to 6 screens)

Any value the app displays as if measured must state its source. Affects `know_your_baseline.png`
(all five vital tiles), `010-home-page.png` (Energy / Mood / Activity), `ai_assistant_home.png`
(health-at-a-glance row), `pet_profile.png`, `pet_statistics.png`, `pdf_health_report_preview.png`.

Proposed marker set: `Self-reported` · `From vet record` · `AI observation`. Rendered as a small caption,
no layout change.

### 4.3 Copy defects found while reviewing

| Screen | Defect |
|---|---|
| `003-onboarding.png` | "Always consult your **veterinarion**" — misspelling in the legal disclaimer |
| `010-home-page.png` | "Weather-aware walk **timess** for Buddy" — doubled letter |
| `ai_analysis_result_emergency.png` | Stray "." on its own line beneath "Based on symptoms and visual analysis." |

### 4.4 Language inconsistency

`ai_assistant_chat.png`, `conversation_history.png`, `smart_walks.png` and `weather_walk_advisor.png` are in
Turkish; the other 53 screens are in English. Every rewrite above is supplied in the screen's own language.
Confirm all strings live in Flutter ARB files — none of the proposed copy should be baked into artwork.

---

## 5. Implementation Priority

| Wave | Findings | Why first |
|---|---|---|
| **S0 — before any build** | V-16, V-17, V-24 | Rule-4 / rule-5 breaches. Structural, not copy. Block `AI-306` and the nav until decided. |
| **S1 — before beta** | V-01 – V-06, V-09, V-10, V-11 | CRITICAL false-negative paths. All are copy-only, all preserve layout. |
| **S2** | V-07, V-08, V-12 – V-15, V-19, V-20 | HIGH. Copy-only. |
| **S3** | V-18, V-21, V-22, V-23, §4.1, §4.2 | MEDIUM — framing, provenance, role. V-22 needs a PDF template change. |
| **S4** | §3.4 Health Score decision, §4.3 typos, §4.4 localisation audit | Quality and consistency. |

---

## 6. Change Log Against `UI_ASSET_SPECIFICATION.md`

| Spec section | Change |
|---|---|
| §1.6 conflict table | C-3 → resolved by V-05/V-06 rewrite; C-4 → V-16; C-5 → V-17 (HOLD released via the `AI-306` rewrite); C-7 → V-24 |
| §6.4 `AI-306` | Prompt replaced; reclassified `AI` → `EMG`; renamed; HOLD released |
| §6.4 `AI-303` | Layer-2 prompt replaced (SHOULD) |
| §6.7 `EMG-607` | Prompt replaced; HOLD released |
| §6.16 `DOC-1501` | Prompt replaced (SHOULD) |
| §9 P0 gate | C-3/C-5 rows closed; C-4/C-7 remain owner decisions |

---

**End of review.** No UI was redesigned, no layout altered, no Flutter code written, no assets generated.
