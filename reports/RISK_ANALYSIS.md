# PawDoc: Risk Analysis Report
**Version 1.0 | May 2026**

---

## Executive Summary

PawDoc operates in a high-emotional-stakes category where AI quality failures carry disproportionate consequences. The primary risk profile is **asymmetric**: most failures are recoverable, but a small number (viral false-negative incident, regulatory action, major security breach) are existentially threatening. Risk management strategy must focus disproportionately on preventing low-probability, high-severity events.

**Overall Risk Rating: 6.2/10** (Manageable with correct mitigations; high if safety systems are deprioritized)

---

## Risk Matrix

| Risk | Probability | Severity | Risk Score | Mitigation Status |
|------|------------|---------|-----------|-----------------|
| Viral false-negative incident | 8% per year | 10/10 | Critical | Partially mitigated |
| AI quality degradation | 15% | 8/10 | High | Mitigated |
| Apple App Store rejection | 40% (initial) | 5/10 | Medium | Mitigated |
| Well-funded competitor launches | 25% in 18 months | 7/10 | High | Partially mitigated |
| Regulatory action (FTC/state vet board) | 5% | 9/10 | High | Mitigated |
| API provider outage (Anthropic/Google) | 10% per quarter | 6/10 | Medium | Partially mitigated |
| GDPR/privacy violation | 5% | 8/10 | High | Mitigated |
| Data breach | 3% | 9/10 | High | Mitigated |
| Prompt injection attack | 5% | 5/10 | Medium | Mitigated |
| Founder burnout / exit | 20% at 12 months | 10/10 | Critical | Unmitigated |
| Revenue stagnation (churn > new) | 30% | 7/10 | High | Partially mitigated |
| Subscription fatigue / price sensitivity | 35% | 5/10 | Medium | Partially mitigated |

---

## 1. EXISTENTIAL RISKS

### 1.1 Viral False-Negative Incident
**Description:** A pet dies or is seriously harmed after PawDoc classified the presenting symptoms as LIKELY NORMAL or MONITOR. The owner posts publicly ("PawDoc killed my dog"). Content goes viral. Press coverage follows.

**Why it matters:** Pet owners have profound emotional attachment to their animals. Negative outcomes spread catastrophically on social media in the pet owner community. One credible, well-documented incident can permanently destroy brand trust and trigger regulatory scrutiny.

**Probability:** ~8% per year once at meaningful scale (100K+ analyses/year). Scales with usage.

**Mitigation (Required, Not Optional):**
- Conservative triage bias: when confidence is uncertain, bias toward MONITOR rather than LIKELY NORMAL
- Emergency keyword hardcodes: known life-threatening symptoms trigger EMERGENCY regardless of AI assessment
- Cross-verification: all EMERGENCY classifications verified by second AI call
- E&O insurance: $100K-300K coverage; purchase before launch
- Analysis logging: every analysis permanently logged for legal review
- Response protocol: pre-written response template for negative incidents; respond within 2 hours
- Quality review: monthly manual review of 50 random analyses to catch systematic issues early

**Residual risk:** Cannot be reduced to zero. The mitigation strategy must minimize probability AND have a response protocol ready.

---

### 1.2 Founder Burnout / Exit
**Description:** Solo founder quits before reaching sustainable revenue (most likely around months 6-12 when numbers are still small).

**Why it matters:** This is the most probable existential risk. Consumer apps take 12-18 months to reach meaningful revenue. The trough of disillusionment is real.

**Probability:** 20% at 12 months for a solo consumer health app.

**Mitigation:**
- Set explicit 18-month runway commitment before starting
- Establish monthly revenue milestones with "continue vs. pivot" decision criteria
- Identify the single most motivating success metric (first $1K MRR, first 100 users) and celebrate it
- Join a founder community (YC Startup School, Indie Hackers) for accountability
- Consider co-founder if engineering + content marketing bandwidth is insufficient

---

### 1.3 Regulatory Action
**Description:** FTC challenges AI health claims; a state veterinary board attempts to classify PawDoc as practicing veterinary medicine; EU AI Act classifies pet health AI as high-risk.

**Probability:** 5% but with material risk under specific scenarios.

**Mitigation:**
- Language: NEVER use "diagnose," "treatment," or "prescription" in any user-facing text
- Always present outputs as "information and guidance" not "veterinary advice"
- Consult a health tech attorney before launch ($1,500-3,000 one-time cost)
- Monitor FTC and AVMA guidance on AI pet health products quarterly
- Maintain "clearly not practicing veterinary medicine" position: no human vet involvement, no prescription recommendations, explicit disclaimers

---

## 2. PRODUCT RISKS

### 2.1 AI Quality Degradation
**Description:** Foundation model API updates, behavior changes, or increased refusal rates result in lower analysis quality or more frequent "I cannot determine" outputs.

**Probability:** 15% — AI providers do update model behaviors.

**Mitigation:**
- Version-pin to specific model versions where possible (e.g., `claude-sonnet-4-6` not `claude-sonnet-latest`)
- Maintain evaluation suite of 100+ test cases with expected outputs; run on each model version before upgrading
- Multi-provider architecture: if Claude quality degrades, can route to GPT-4o within 24 hours
- Monitor `confidence_score` distribution weekly — sudden shift indicates model behavior change

### 2.2 Onboarding Friction / Low Activation
**Description:** Users install the app but fail to complete onboarding or submit a first analysis. Core value proposition never experienced.

**Probability:** 25-35% of installs don't activate.

**Mitigation:**
- 5-screen onboarding maximum (see roadmap Section 6)
- First analysis must be accessible within 2 minutes of install
- No login required before first value experience
- A/B test onboarding variants starting in Phase 4
- Track `onboarding_step_{n}_completed` events to identify drop-off point

### 2.3 Low-Frequency Use → Churn
**Description:** Subscribers don't experience enough symptom events per month to justify subscription. Cancel after 1-2 months.

**Probability:** 30% of monthly subscribers in months 2-3.

**Mitigation:**
- Vaccination reminders create monthly utility touchpoints
- Monthly health summary email creates value delivery even without symptom events
- Seasonal alerts (tick season, heatstroke risk) create proactive value
- Annual plan default: annual subscribers don't churn monthly (22% vs. 48% annual churn)
- Health journal creates engagement between acute events

---

## 3. COMPETITIVE RISKS

### 3.1 Well-Funded Direct Competitor
**Description:** A YC-backed startup or well-funded team launches a similar product 6-12 months after PawDoc with larger engineering team, better design, and paid acquisition budget.

**Probability:** 25% in 18 months.

**Defense:**
- Ship first — first-mover advantage in App Store ratings compounds
- Build brand trust before competitor arrives (4.7+ App Store rating is a moat)
- Content SEO moat: articles ranking #1 for "dog symptom checker" are hard to displace
- Data moat: analyses collected early become training data competitors can't replicate

### 3.2 Chewy Launches AI Triage
**Description:** Chewy (50M+ customers) adds vision-based AI triage to their app.

**Probability:** 15% in 24 months.

**Response:**
- Chewy is a retailer, not a health AI company — their product will likely be shallow
- If Chewy launches well, the outcome may be an acquisition offer (positive)
- PawDoc's brand positioning as independent, safety-first, AI-specialized is defensible
- Data moat becomes more valuable if Chewy competes — larger acquirer justification

### 3.3 Foundation Model Companies Enter Consumer Apps
**Description:** OpenAI or Google builds a pet health feature into ChatGPT or Gemini.

**Probability:** 10% in 18 months for a meaningful pet health feature.

**Response:**
- General-purpose AI is not a pet health app — specialization and trust signals matter
- PawDoc's breed-specific personalization, health history, and reminders create product depth that ChatGPT won't replicate in a feature
- Domain-specific data and safety systems are not features GPT-4o will match by default

---

## 4. TECHNICAL RISKS

### 4.1 API Provider Outage
**Description:** Anthropic or Google AI experiences an outage, making analysis requests fail.

**Probability:** 10% per quarter for a multi-hour outage.

**Mitigation:**
- Multi-provider fallback: if Claude API fails → route Tier 3 to GPT-4o
- Graceful degradation: "AI analysis is temporarily unavailable — please try again in a few minutes or contact your vet"
- NEVER show an error for EMERGENCY-classified symptoms — fall back to hardcoded emergency guidance
- Monitor API uptime at Better Uptime; alert on failure within 1 minute

### 4.2 Supabase Service Degradation
**Description:** Supabase experiences downtime or performance degradation.

**Mitigation:**
- Local cache (Hive): recent analyses and pet profiles cached on device for 24 hours
- Read-only mode: app can display cached data even if Supabase is unreachable
- Daily backups: Supabase Pro automated backup + manual monthly export to S3

### 4.3 Cost Spike (Viral Moment)
**Description:** A viral TikTok or Reddit post drives 10x normal traffic overnight, spiking AI API costs unexpectedly.

**Probability:** 15% — this is actually a good problem, but can hurt margins temporarily.

**Mitigation:**
- Per-user daily analysis cap (10/day) enforced at Edge Function level
- AI API cost alerts: trigger Slack alert if daily API spend exceeds 2x normal
- Fly.io autoscaling configured with maximum machine limit to prevent runaway compute costs
- Upstash Redis burst protection

---

## 5. SECURITY RISKS

### 5.1 Data Breach
**Description:** Unauthorized access to user data (email addresses, pet health information, analysis history).

**Probability:** 3% (small team, limited attack surface if implemented correctly).

**Mitigation:**
- RLS on all tables — application-level bugs cannot leak cross-user data
- All API keys in Doppler — never in code or logs
- Input validation on all endpoints — injection attacks blocked
- Principle of least privilege — AI service uses service_role only for writes; reads use JWT
- Monitor for anomalous access patterns (Supabase built-in audit logging)
- Incident response plan documented before launch

### 5.2 Prompt Injection
**Description:** User crafts a malicious symptom description that manipulates the AI's system prompt or produces misleading output.

**Probability:** 5% (more annoying than dangerous with structured output enforcement).

**Mitigation:**
- Structured JSON output enforcement — free-text manipulation can't override the schema
- System prompt boundary: explicit instruction to ignore meta-instructions in user content
- Output validation: responses that don't conform to schema are rejected and logged
- Regular red-team testing: include prompt injection attempts in evaluation suite

---

## 6. FINANCIAL RISKS

### 6.1 Revenue Stagnation
**Description:** Churn rate exceeds new subscriber rate; MRR plateaus or declines.

**Probability:** 30% for months 4-8 before retention features are fully built.

**Mitigation:**
- V1 retention features (Phase 3) must ship before paid acquisition scales
- Monitor monthly churn rate weekly — alert if churn > 6%
- Cancellation survey: understand WHY users are canceling before optimizing

### 6.2 App Store Commission Impact
**Description:** Apple (30%) and Google (15% after year 1) take significant commission on subscription revenue.

**Reality check:** This is structural, not a risk. It must be factored into unit economics from the start.
- At $9.99/month: effective take is $7.00 (Apple) or $8.49 (Google year 2+)
- LTV and CAC calculations must use platform-adjusted revenue, not gross

### 6.3 AI Cost Overrun
**Description:** AI API costs grow faster than subscription revenue in early stages.

**Probability:** Low — AI costs are ~4% of subscription revenue at any meaningful scale.

**Monitoring:** Weekly AI cost / MRR ratio. Alert if this ratio exceeds 8%.

---

## Risk Mitigation Priority Order

**Execute in this order — do not defer:**

1. **E&O Insurance** — Purchase before ANY public launch. Non-negotiable.
2. **Emergency override system** — Hardcoded keyword detection before AI call. Phase 1 requirement.
3. **Analysis logging** — Every analysis permanently stored. Legal requirement.
4. **Conservative triage bias** — Prompt engineering: when uncertain, bias toward MONITOR not NORMAL.
5. **Multi-provider fallback** — Claude fails → GPT-4o. Service continuity.
6. **Rate limiting** — Server-side, per-user. Phase 1 requirement.
7. **Disclaimer injection at API level** — Cannot be removed by UI changes.
8. **Health tech attorney consultation** — One-time, before public launch.
9. **Response protocol for negative incidents** — Written before launch; practiced.
10. **Founder mental health plan** — Accountability structure; defined success milestones.
