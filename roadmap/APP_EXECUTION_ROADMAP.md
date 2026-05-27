# PawDoc: AI-Native Pet Health App — Complete Execution Roadmap
**Version 1.0 | May 2026 | Solo Founder Edition**

> This roadmap transforms the PawDoc concept into a production-grade, growth-optimized, AI-powered mobile application. Designed to be executed by AI coding agents and human founders alike — from initial infrastructure setup through venture-scale platform.

---

# 1. STARTUP OVERVIEW

## One-Sentence Description
PawDoc is an AI-native mobile app that analyzes pet symptoms via photo, video, or text, delivering instant triage guidance (EMERGENCY / MONITOR / LIKELY NORMAL) to reduce pet owner anxiety, prevent unnecessary vet visits, and catch genuine emergencies early.

## Target Users

| Segment | Profile | Priority |
|---------|---------|----------|
| Urban Millennial/Gen Z, 1-2 pets | Dog/cat owner, high smartphone usage, anxiety-driven health decisions | P0 |
| New pet owner (0-6 months) | Peak query frequency, highest anxiety, brand-formative period | P0 |
| Multi-pet household (3+ pets) | High LTV, family plan conversion, referral potential | P1 |
| Senior pet owner (pet 7+ years) | Highest emotional attachment, highest query frequency | P1 |
| Exotic pet owner (rabbits, birds, reptiles) | Near-zero alternatives, premium WTP, niche community flywheel | P2 |
| Rural pet owner | Nearest vet 1+ hour away, genuine high-value triage need | P2 |

## Core Value Proposition
**"Know if your pet needs the vet — in 10 seconds, at 2am, for less than 1/10th the cost of an emergency visit."**

## Competitive Positioning
- **vs. Pawp ($24/mo):** 10-second AI vs. 20-40 minute human response. 60% cheaper.
- **vs. Airvet ($30-60/consult):** For 80% of "should I worry?" queries, AI is sufficient and instant
- **vs. Chewy's free telehealth:** Depth-first health product vs. retail cross-sell feature
- **vs. WebMD/Google:** Calm, structured, pet-specific guidance vs. worst-case catastrophizing

## North Star Metric
**Monthly Active Analyses (MAA)** — analyses submitted per month across all users. Captures activation, engagement, and retention in a single number.

## MVP Success Metrics
- 100 active users in first 30 days post-launch
- 10% free-to-paid conversion rate
- 4.0+ App Store rating at launch
- Zero catastrophic false-negative incidents
- P95 analysis latency under 10 seconds
- D7 retention ≥ 30%

---

# 2. PRODUCT-MARKET ANALYSIS

## User Pain Points (Ranked by Severity)

| Pain Point | Severity | Frequency per Pet per Year |
|------------|----------|--------------------------|
| "Is this an emergency at 11pm?" | 10/10 | 1-3x |
| "Should I spend $400 on a vet visit?" | 9/10 | 4-8x |
| "Google is giving me cancer diagnoses" | 8/10 | 8-15x |
| "I feel guilty for not noticing sooner" | 8/10 | Ongoing |
| "The vet can't see us until Thursday" | 7/10 | 4-6x |

## Competitor Weaknesses

| Competitor | Core Weakness | PawDoc Advantage |
|------------|--------------|-----------------|
| Pawp ($24/mo) | Zero AI; 20-40 min human wait | 10-second AI at 60% lower cost |
| Airvet ($30-60/consult) | Expensive; requires scheduling | Always-on, instant, affordable |
| Chewy telehealth | Shallow product; retail cross-sell | Deep, AI-first health product |
| PetMD (static) | No triage; generic content | Personalized, interactive analysis |

## AI Leverage Opportunities

1. **Vision-first triage** — Analyze photos/video for visible symptoms with structured output
2. **Breed context injection** — Automatically surface breed-specific risk factors per analysis
3. **Longitudinal pattern detection** — Identify subtle changes across multiple analyses
4. **Personalized follow-up** — "48 hours ago you reported eye irritation — how is Luna doing?"
5. **Semantic caching** — Reduce API costs 10-15% through query similarity matching at scale

---

# 3. RECOMMENDED TECH STACK

## Decision Matrix

| Layer | Technology | Why | Key Tradeoff |
|-------|-----------|-----|-------------|
| **Mobile** | Flutter 3.x | Single iOS+Android codebase; excellent camera plugins; native performance | Dart learning curve; larger binary than native |
| **State** | Riverpod 2.x | Compile-safe; testable; async-first | More verbose than Bloc for simple cases |
| **Navigation** | go_router | Type-safe; deep links; web-compatible for V2 | Slightly more boilerplate |
| **Backend** | Supabase | PostgreSQL + Auth + Storage + Edge Functions in one; BaaS optimal for solo | Self-host needed at 1M+ MAU |
| **AI Orchestration** | Python FastAPI on Fly.io | Flexible for complex AI pipeline; async; rich ML libraries | Additional service to manage |
| **Database** | PostgreSQL 16 (Supabase) | ACID; JSONB for AI output; RLS for multi-tenant security | Read replicas needed at 100K+ MAU |
| **Storage** | Cloudflare R2 | **Zero egress fees** — critical for image-heavy app; S3-compatible | R2-specific SDK |
| **Auth** | Supabase Auth | Email/Apple/Google; JWT; RLS integration built-in | Limited customization vs Auth0 |
| **Payments** | RevenueCat | Industry standard for mobile subscriptions; StoreKit 2 + Play Billing 5 | Free up to $2.5K MRR |
| **Analytics** | PostHog (self-hosted) | Open-source; funnel analysis; feature flags; A/B testing; session recording — all in one | Maintenance overhead |
| **Push** | OneSignal | Free up to 1M subscribers; segmentation; cross-platform | Vendor dependency |
| **Email** | Resend | Developer-friendly; React Email; excellent deliverability | Cost scales with volume |
| **Errors** | Sentry | Industry standard; Flutter SDK maintained | — |
| **Secrets** | Doppler | Syncs to GitHub Actions, Fly.io, Supabase | Cost ~$10/mo |
| **CI/CD** | GitHub Actions + Fastlane | Flutter test + build; TestFlight + Play Store automation | Fastlane cert management complexity |

## AI Tier Architecture

```
Tier 1 — On-Device (instant, $0):
  ├── CoreML (iOS) / TFLite (Android)
  ├── Pet detection: is this an animal?
  ├── Species classification: dog/cat/other
  ├── Image quality check: blur, lighting, crop
  └── Estimated cost saving: 15-20% of API calls

Tier 2 — Fast Cloud (1-3s, ~$0.001/query):
  ├── Gemini 2.0 Flash ($0.35/1K tokens)
  ├── Run on ALL queries that pass Tier 1
  ├── Output: triage level + confidence score
  └── If confidence > 0.85 → return directly (60% of queries)
      If confidence < 0.85 → escalate to Tier 3

Tier 3 — Primary Analysis (2-5s, ~$0.01/query):
  ├── Claude 3.5 Sonnet (claude-sonnet-4-6) ($3/1K input tokens)
  ├── Full reasoning chain with pet context
  ├── Detailed structured output
  └── Cross-verify ALL EMERGENCY classifications

Tier 4 — Emergency Verification (3-8s, ~$0.05/query):
  ├── Claude Opus (claude-opus-4-7)
  ├── Second opinion on EMERGENCY-only
  └── Cost justified by liability reduction
```

---

# 4. SYSTEM ARCHITECTURE

## High-Level Architecture

```mermaid
graph TB
    subgraph Client["Flutter App (iOS + Android)"]
        UI[Material 3 UI] --> State[Riverpod State]
        State --> Camera[In-App Camera]
        State --> Cache[Hive Local Cache]
        Camera --> OnDevice[CoreML/TFLite Pre-filter]
    end

    subgraph CF["Cloudflare Edge"]
        WAF[WAF + DDoS] --> R2[R2 Object Storage]
    end

    subgraph SB["Supabase Platform"]
        Auth[Auth + JWT]
        DB[(PostgreSQL 16 + pgvector)]
        EF[Edge Functions Deno]
        RT[Real-time]
    end

    subgraph AI["AI Service — Fly.io Python FastAPI"]
        Orch[Orchestrator]
        Redis[Upstash Redis Cache]
        Safety[Safety Layer]
    end

    subgraph AIProviders["AI Providers"]
        G2[Gemini 2.0 Flash Tier 2]
        CS[Claude Sonnet Tier 3]
        CO[Claude Opus Tier 4]
    end

    Client -->|Upload compressed image| CF
    Client -->|Auth + queries| SB
    Client -->|Submit analysis| EF
    EF -->|Route to AI| AI
    Orch -->|Fast screen| G2
    Orch -->|Full analysis| CS
    Orch -->|Emergency verify| CO
    Orch <-->|Cache| Redis
    AI -->|Store result| DB
    DB <-->|RLS enforced| Auth
```

## Analysis Request Data Flow

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant R2 as Cloudflare R2
    participant EF as Supabase Edge Fn
    participant AI as AI Service
    participant G2 as Gemini Flash
    participant CS as Claude Sonnet
    participant DB as PostgreSQL

    App->>App: On-device pre-filter (pet detection + quality)
    App->>R2: Upload compressed image (<2MB)
    R2-->>App: Storage key
    App->>EF: POST /analyze {pet_id, r2_key, text, session}
    EF->>DB: Load pet profile (breed, age, history, conditions)
    EF->>AI: Forward with full pet context
    AI->>AI: Check semantic cache (pgvector similarity >90%)
    alt Cache hit
        AI-->>EF: Cached result
    else Cache miss
        AI->>G2: Tier 2 analysis
        G2-->>AI: {triage, confidence}
        alt Confidence > 0.85
            AI->>AI: Apply hardcoded safety overrides
            AI-->>EF: Tier 2 result
        else Low confidence
            AI->>CS: Tier 3 full analysis
            CS-->>AI: Detailed structured output
            opt EMERGENCY classification
                AI->>CS: Cross-verify call
            end
            AI-->>EF: Tier 3 result
        end
    end
    EF->>DB: Store analysis record
    EF-->>App: Structured triage result
```

## Project Folder Structure

```
/PawDoc
├── mobile/                      # Flutter app
│   ├── lib/
│   │   ├── app/
│   │   │   ├── router.dart
│   │   │   └── theme.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── onboarding/
│   │   │   ├── home/
│   │   │   ├── analysis/        # Camera, upload, result
│   │   │   ├── pets/
│   │   │   ├── history/
│   │   │   ├── reminders/
│   │   │   ├── paywall/
│   │   │   └── settings/
│   │   ├── shared/
│   │   │   ├── models/
│   │   │   ├── services/
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   └── platform/
│   │       ├── ios/             # CoreML model
│   │       └── android/         # TFLite model
│   └── test/
├── supabase/
│   ├── migrations/
│   └── functions/
│       ├── analyze/
│       ├── auth-webhook/
│       ├── revenuecat-webhook/
│       └── reminders-cron/
├── ai-service/                  # Fly.io Python FastAPI
│   ├── main.py
│   ├── routers/analyze.py
│   ├── services/
│   │   ├── orchestrator.py
│   │   ├── gemini_client.py
│   │   ├── claude_client.py
│   │   ├── safety.py
│   │   ├── cache.py
│   │   └── parser.py
│   ├── models/schemas.py
│   ├── prompts/
│   │   ├── system_prompt.py
│   │   └── breed_context.py
│   └── tests/
└── web/                         # Next.js (V2) — SEO + web checker
    ├── app/
    ├── blog/
    └── check/                   # Free web symptom checker
```

---

# 5. DATA MODEL DESIGN

## Schema

```sql
-- Users table
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  subscription_status text DEFAULT 'free', -- free | trial | premium | family
  subscription_tier text,
  revenuecat_user_id text,
  one_signal_player_id text,
  preferred_locale text DEFAULT 'en',
  free_analyses_used_this_month int DEFAULT 0,
  free_analyses_reset_at timestamptz DEFAULT date_trunc('month', now()) + interval '1 month',
  created_at timestamptz DEFAULT now(),
  last_active_at timestamptz DEFAULT now()
);

-- Pets table
CREATE TABLE pets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  species text NOT NULL, -- dog | cat | rabbit | bird | reptile | other
  breed text,
  birth_date date,
  sex text,
  weight_kg decimal(5,2),
  photo_url text,
  medical_notes text,
  is_active bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Analyses table
CREATE TABLE analyses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id uuid REFERENCES pets(id),
  user_id uuid REFERENCES users(id),
  input_type text NOT NULL, -- photo | video | text
  input_storage_key text,   -- Cloudflare R2 key
  text_description text,
  triage_level text,         -- EMERGENCY | MONITOR | NORMAL
  primary_concern text,
  full_response jsonb,       -- Complete structured AI output
  model_used text,
  tier_used int,             -- 2 | 3 | 4
  confidence_score decimal(4,3),
  ai_latency_ms int,
  emergency_override_applied bool DEFAULT false,
  embedding vector(1536),    -- For semantic cache (pgvector)
  created_at timestamptz DEFAULT now()
);

-- Health events table
CREATE TABLE health_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id uuid REFERENCES pets(id) ON DELETE CASCADE,
  event_type text NOT NULL, -- vaccination | vet_visit | medication | weight | custom
  event_date date NOT NULL,
  notes text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

-- Reminders table
CREATE TABLE reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id uuid REFERENCES pets(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id),
  reminder_type text NOT NULL,
  due_date date NOT NULL,
  is_sent bool DEFAULT false,
  notification_sent_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Analysis feedback table
CREATE TABLE analysis_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  analysis_id uuid REFERENCES analyses(id),
  outcome text, -- resolved_on_own | vet_confirmed | vet_said_nothing | still_monitoring | other
  rating int,   -- 1-5
  comment text,
  created_at timestamptz DEFAULT now()
);

-- Referrals table
CREATE TABLE referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_user_id uuid REFERENCES users(id),
  referred_email text,
  referral_code text UNIQUE,
  converted bool DEFAULT false,
  converted_at timestamptz,
  created_at timestamptz DEFAULT now()
);
```

## Row Level Security Policies

```sql
-- RLS on all user-data tables
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_pets" ON pets
  USING (auth.uid() = user_id);

CREATE POLICY "users_own_analyses" ON analyses
  USING (auth.uid() = user_id);

-- Service role bypasses RLS for AI service writes
-- AI service uses service_role key ONLY for writing analyses
-- All reads by users go through authenticated JWT + RLS
```

## Key Indexes

```sql
CREATE INDEX idx_analyses_pet_id ON analyses(pet_id);
CREATE INDEX idx_analyses_user_id_created ON analyses(user_id, created_at DESC);
CREATE INDEX idx_analyses_triage_level ON analyses(triage_level);
CREATE INDEX idx_pets_user_id ON pets(user_id) WHERE is_active = true;
CREATE INDEX idx_reminders_due ON reminders(due_date) WHERE is_sent = false;
CREATE INDEX idx_users_subscription ON users(subscription_status);
CREATE INDEX idx_analyses_embedding ON analyses USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

## Scaling Concerns

| Concern | Threshold | Mitigation |
|---------|-----------|-----------|
| analyses table growth | 10M+ rows | Partition by `created_at` (monthly) |
| jsonb storage overhead | At scale | Move AI responses to R2 blobs; store pointer in DB |
| pgvector performance | 1M+ embeddings | Migrate to dedicated Pinecone |
| Connection limits | 200+ concurrent users | Enable pgBouncer (Supabase Pro) |
| Read performance | 100K+ MAU | Add read replicas; route analytics to replica |

---

# 6. GROWTH & RETENTION STRATEGY

## Onboarding Flow (5 Screens, Target: <2 minutes to first analysis)

```
Screen 1: Value Hook
  Headline: "Never wonder if your pet needs the vet again."
  Sub: "AI triage in 10 seconds. 24/7. Less than $0.33/day."
  CTA: "Get Started" (primary) | "Sign In" (secondary text)
  [No login required yet — zero friction]

Screen 2: Pet Setup (45 seconds)
  Fields: Name (required), Species (tap grid: 🐶🐱🐰🦜🦎), Breed (typeahead), Age, Photo (optional)
  Microcopy: "Add more pets later. Edit anytime."

Screen 3: Trust Signal (10 seconds)
  Show: Vet advisor photo + credentials
  Show: "4.8★ Trusted by 47,000+ pet parents"
  CTA: "Continue"

Screen 4: Push Permission
  Context: "Get alerts when we notice concerning trends in [Pet Name]'s health."
  [System prompt shown here — context raises accept rate to 55%+]

Screen 5: Activation
  "Ready to check on [Pet Name]?"
  Sub: "Your first 3 analyses are free — no card needed."
  CTA: "Check [Pet Name] Now" → routes directly to camera

[Paywall shown AFTER first successful analysis, not here]
```

## Retention Loop Design

```
Activation event: first analysis completed
       ↓
Post-analysis: "Save to health log" CTA (creates ownership)
       ↓
48h follow-up push: "How is [Pet] doing?" → drives D2 return
       ↓
Weekly breed tip on home screen → passive engagement
       ↓
Monthly health summary email → reminds value even without events
       ↓
Vaccination reminder: "Luna's rabies vaccine is due" → utility touchpoint
       ↓
Next symptom event → repeat
```

## D1/D7/D30 Retention Targets and Tactics

| Metric | Target | Primary Tactic | Backup Tactic |
|--------|--------|---------------|--------------|
| D1 | 55% | Quality first analysis + save-to-log CTA | 8h follow-up notification |
| D7 | 35% | Breed tip cards + Day 4 follow-up push | Free query scarcity alert (Day 6) |
| D30 | 25% (free) / 60% (paid) | Monthly summary email + vaccination reminders | Seasonal alert (tick season, heatstroke, etc.) |
| D90 (paid) | 55% | Health history emotional ownership | Annual plan default (reduces cancel friction) |

## Referral System

```
Mechanic: Give 1 free month → get 1 free month when friend subscribes

Trigger moments (ranked by conversion probability):
1. After LIKELY NORMAL result (relief → generosity)
2. 30 days after subscription start (loyalty peak)
3. After monthly summary email
4. After positive outcome confirmation

Flow:
User → shares personal deep link
Friend → installs, uses referral code, gets 3 bonus free analyses
Friend subscribes → referrer gets RevenueCat entitlement extension (1 month)
```

## Viral Mechanics

1. **Share result button** — "Luna's all good! 🐾" — LIKELY NORMAL result shareable with PawDoc watermark (builds brand awareness via organic social)
2. **Breed community seeding** — Authentic posts in r/goldenretrievers, r/cats, r/puppy101 by founder
3. **TikTok screen-share format** — "Watch me use AI to check if my dog needs the vet" is proven content
4. **New puppy checklist** — Shareable onboarding artifact for new pet owners (high-frequency social moment)

## Gamification Elements (Light)

| Element | Mechanic | Retention Impact |
|---------|---------|-----------------|
| Health score | Weekly 1-10 pet wellness score | Weekly return motivation |
| Check-in acknowledgment | "Luna has been monitored for 3 weeks straight" | Habit reinforcement |
| Pet level | "Level 3 Well-Monitored Dog" after 10 analyses | Identity + milestone |
| Breed expert badge | After viewing 5 breed-specific insights | Community identity |

---

# 7. MONETIZATION STRATEGY

## Pricing Architecture

| Tier | Monthly | Annual | Core Features |
|------|---------|--------|--------------|
| **Free** | $0 | $0 | 3 analyses/month, photo only, 1 pet, no history |
| **Premium** | $9.99 | $59.99 (~$5/mo) | Unlimited analyses, history, reminders, 2 pets, video |
| **Family** | $14.99 | $89.99 (~$7.50/mo) | Unlimited pets, always Tier 4 on EMERGENCY, sitter mode |

**Critical rule:** Emergency analyses are NEVER paywalled. Any user can always submit EMERGENCY-level analysis. Paywalling safety is both unethical and catastrophically trust-damaging.

**Annual-first display:** Show annual plan as the primary option on all paywall screens. Annual subscribers have 2.5x higher LTV than monthly (22% vs. 48% annual churn rate).

## Paywall Placement Strategy

| Trigger | Copy | Priority |
|---------|------|----------|
| After first successful analysis | "Glad [Pet] seems okay. Protect them with unlimited checks — less than 1/10th the cost of an emergency visit." | P0 |
| At free limit (4th analysis attempt) | "You've used your 3 free analyses this month. Unlock unlimited." | P0 |
| On locked feature tap (history, video) | Feature-specific unlock message | P1 |
| Trial end | Standard RevenueCat expiry flow | P1 |

**Never show paywall:** during emergency flow, during onboarding, or more than once per day.

## Subscription Psychology

**Key anchors to use in copy:**
- "Less than 1/10th the cost of an emergency vet visit"
- "47,000+ pet parents trust PawDoc"
- "Cancel anytime"
- Show annual price ($4.99/mo equivalent) as the featured option

## Revenue Streams by Phase

| Stream | Phase | Year 1 | Year 2 |
|--------|-------|--------|--------|
| Premium subscriptions | Phase 1 (MVP) | $50-120K ARR | $200-600K ARR |
| Family subscriptions | Phase 1 (MVP) | $15-40K ARR | $80-200K ARR |
| Airvet/Vetster referrals | Phase 3 (V1) | $5-15K ARR | $30-80K ARR |
| Pet insurance affiliates | Phase 6 (V2) | $8-20K ARR | $40-100K ARR |
| B2B API licensing | Phase 7 (V3) | $0 | $100-500K ARR |

## Unit Economics

| Metric | Conservative | Realistic | Optimistic |
|--------|-------------|----------|-----------|
| ARPU (blended monthly) | $4.50 | $6.80 | $8.50 |
| LTV (18-month subscriber) | $81 | $122 | $153 |
| CAC (blended paid + organic) | $12 | $8 | $5 |
| LTV:CAC | 6.7x | 15.3x | 30.6x |
| Gross margin | 72% | 80% | 85% |
| Monthly subscriber churn | 6% | 4% | 2.5% |

---

# 8. AI & INFRASTRUCTURE COST ANALYSIS

## API Cost at Scale

| MAU | Queries/Month | Gemini Cost | Claude Cost (40%) | Total AI | Revenue (15% paid @ $8/mo) | AI as % Revenue |
|-----|-------------|-------------|------------------|---------|--------------------------|----------------|
| 1K | 3K | $4 | $50 | $54 | $1,200 | 4.5% |
| 10K | 30K | $40 | $500 | $540 | $12,000 | 4.5% |
| 100K | 300K | $400 | $4,500 | $4,900 | $120,000 | 4.1% |
| 500K | 1.5M | $1,800 | $20,000 | $21,800 | $600,000 | 3.6% |

**Key insight:** AI costs are 3-5% of subscription revenue — an extraordinary gross margin profile comparable to the best SaaS businesses.

## Infrastructure Costs

| Stage | MAU | Supabase | Fly.io | R2 | Redis | Other | Total/Month |
|-------|-----|---------|---------|-----|-------|-------|------------|
| Pre-launch | 0 | $25 | $5 | $1 | $3 | $10 | ~$44 |
| Launch | 1K | $25 | $15 | $5 | $3 | $15 | ~$63 |
| Early | 10K | $25 | $40 | $20 | $5 | $30 | ~$120 |
| Growing | 100K | $200 | $150 | $80 | $20 | $80 | ~$530 |
| Scale | 500K | $599 | $600 | $300 | $80 | $300 | ~$1,879 |

## Cost Optimization Levers

1. **Client-side compression** — Compress images to <2MB before upload; reduces R2 storage + API token count
2. **On-device pre-filter** — Reject non-animal images before any API call; saves ~15-20% of API costs
3. **Tier 2 gating** — 60% of queries resolved by Gemini Flash alone (confidence > 0.85)
4. **Semantic cache** — 10-15% API cost reduction at scale via pgvector similarity matching
5. **Anthropic prompt caching** — 50-70% reduction in system prompt token costs (large system prompt)
6. **Storage lifecycle** — Archive raw images after 90 days

---

# 9. SECURITY & COMPLIANCE

## Security Architecture

| Layer | Control | Implementation |
|-------|---------|---------------|
| Authentication | JWT with RLS | Supabase Auth; all DB queries require valid JWT |
| Data isolation | Row Level Security | Every table; users can only access their own rows |
| API abuse | Server-side rate limiting | Supabase Edge Function: max 10 analyses/day/user |
| AI cost abuse | Daily cap enforced in DB | `free_analyses_used_this_month` counter + server validation |
| Input validation | File type + size check | Only JPEG/PNG/HEIC/MP4/MOV; max 50MB video |
| Prompt injection | Structured output enforcement | JSON schema validation; free-text responses rejected |
| Secrets management | Doppler | All API keys in Doppler; never in code or logs |
| DDoS | Cloudflare WAF | Free tier handles most attacks |

## Emergency Override System (Hardcoded — Never AI-Dependent)

```python
EMERGENCY_KEYWORDS = [
    "not breathing", "stopped breathing", "can't breathe", "labored breathing",
    "blue gums", "grey gums", "pale gums",
    "seizure", "seizing", "convulsing",
    "collapse", "collapsed", "can't stand",
    "grapes", "xylitol", "rat poison", "antifreeze",
    "suspected poisoning", "ate something toxic",
    "hit by car", "severe bleeding",
    "broken bone", "compound fracture"
]

def check_emergency_override(text: str) -> bool:
    text_lower = text.lower()
    return any(keyword in text_lower for keyword in EMERGENCY_KEYWORDS)
```

**Rule:** Emergency override runs BEFORE any AI call. If triggered, classification is immediately EMERGENCY regardless of AI output.

## GDPR/CCPA Compliance

- **Explicit consent** at signup for data processing
- **Right to deletion** — user-facing "Delete my account and all data" option; 30-day purge
- **Data minimization** — only collect what's needed for analysis
- **Data residency** — Supabase EU project for EU users; Cloudflare R2 EU bucket
- **DPA agreements** with Supabase, Cloudflare, Anthropic, Google

## Legal Safeguards

- **E&O Insurance:** $100-300K annual premium — purchase BEFORE public launch
- **Terms of Service:** "Information and guidance, not veterinary diagnosis" — must be affirmatively accepted
- **Privacy Policy:** GDPR-compliant; live at pawdoc.app/privacy before launch
- **Disclaimer injection:** All analysis results include disclaimer at API level (not UI level — cannot be removed)
- **Analysis logging:** Every analysis stored permanently for legal record (input, output, timestamp, user)

---

# 10. PHASE PLAN

---

## MVP PHASES

---

### 📍 Phase 0: Foundation & Infrastructure
**Duration:** Days 1-7

**Objective:** All infrastructure deployed and verified before writing a single line of app code. Eliminate deployment unknowns early.

**Business Goal:** Engineering time is worth more when the deployment pipeline works reliably from day one. Zero infrastructure surprises during development.

**Dependencies:** None

**Deliverables:**
- Supabase projects (dev + prod) configured
- Cloudflare R2 buckets (dev + prod) with CORS
- Fly.io account + AI service placeholder deployed
- GitHub repo + branch protection + CI pipeline
- Doppler secrets configured
- PostHog self-hosted deployed
- Sentry project configured
- Apple Developer ($99/year) + Google Play ($25) accounts created

**Tasks:**

#### Infrastructure
- [ ] Create Supabase projects (dev + prod); enable pgvector, uuid-ossp extensions
- [ ] Configure Supabase Auth providers: email, Apple Sign In, Google
- [ ] Create Cloudflare R2 buckets with CORS policy (allow Flutter app origins)
- [ ] Deploy Fly.io placeholder FastAPI service (GET /health only)
- [ ] Configure Doppler: Supabase keys, Anthropic API key, Google AI key, R2 credentials
- [ ] Register pawdoc.app domain; configure Cloudflare DNS
- [ ] Deploy PostHog (self-hosted) on Fly.io
- [ ] Set up Better Uptime monitoring for all endpoints
- [ ] Create Sentry project; configure Flutter DSN
- [ ] Create RevenueCat project; configure iOS + Android app identifiers

#### CI/CD
- [ ] Initialize GitHub repo; configure branch protection (require PR review for main)
- [ ] GitHub Actions: Flutter analyze + test on every PR
- [ ] GitHub Actions: Fly.io deploy on merge to main
- [ ] Install Fastlane; configure Matchfile for iOS certificate management
- [ ] Fastlane lane: TestFlight upload triggered by git tag
- [ ] Fastlane lane: Google Play internal testing upload

**Success Metrics:**
- All services deployed and passing health checks
- CI pipeline completes in under 5 minutes
- Flutter app compiles to TestFlight build within 24 hours
- Zero secrets in git history (automated secret scanning enabled)

**Risk Analysis:**
- Apple developer enrollment takes 24-48h — initiate on Day 1
- Fly.io min_machines_running = 1 required to eliminate cold starts for AI service
- Create Supabase EU project immediately for future GDPR compliance

---

### 📍 Phase 1: MVP Core Product
**Duration:** Weeks 2-4

**Objective:** Working Flutter app — photo + pet context → AI triage result — with auth and paywall.

**Business Goal:** Prove the core value proposition works technically and experientially. A product that creates a genuine "wow" moment for a beta user.

**Dependencies:** Phase 0 complete

**Deliverables:**
- Complete analysis flow: camera → R2 upload → AI orchestration → structured result
- Onboarding flow (5 screens per design above)
- Home screen with pet card + primary CTA
- Result screen: EMERGENCY/MONITOR/NORMAL with recommended actions
- Supabase Auth (email + Apple Sign In)
- RevenueCat paywall (free: 3/month; premium: unlimited)
- Emergency override system (hardcoded keyword detection pre-AI)
- Safety layer: confidence thresholds, graceful degradation, disclaimer injection
- AI service: Gemini 2.0 Flash (Tier 2) + Claude 3.5 Sonnet (Tier 3)
- Sentry + PostHog integrated

**Tasks:**

#### Frontend
- [ ] Flutter project: Riverpod, go_router, Material 3 theme (teal #00897B / amber #FFB300)
- [ ] Supabase Flutter client; auth state Riverpod provider
- [ ] Onboarding 5-screen wizard with pet setup (name, species grid, breed typeahead, age picker, optional photo)
- [ ] In-app camera module: real-time quality overlay (blur, lighting, framing hints)
- [ ] Image capture: compress to <2MB → upload to R2 → return storage key
- [ ] Text symptom input screen with character guidance
- [ ] Analysis loading screen: animated "AI analyzing..." with 4 rotating contextual messages
- [ ] Result screen: triage badge (color-coded green/amber/red), what-we-noticed list, what-to-do numbered list, escalation triggers, disclaimer
- [ ] EMERGENCY result screen: warm red, urgent copy, vet finder deep link, acknowledgment gate before dismissal
- [ ] Home screen: pet card (photo, name, last check summary), "Check [Pet]" primary CTA, query counter
- [ ] Pet profile CRUD screen
- [ ] Apple Sign In + email auth flows
- [ ] RevenueCat paywall: shown after first successful analysis; annual-first layout
- [ ] PostHog event tracking on all key user actions
- [ ] Sentry crash reporting initialization

#### Backend
- [ ] Supabase migration v1: all tables with indexes and RLS policies
- [ ] Edge Function `/analyze`: validate input, load pet profile, check free tier limit, call AI service, store result
- [ ] Edge Function `/auth-webhook`: create users row on new Supabase Auth signup
- [ ] Edge Function `/revenuecat-webhook`: update subscription_status on entitlement change
- [ ] Free tier enforcement: check `free_analyses_used_this_month` before AI call; increment after

#### AI Service (Python FastAPI on Fly.io)
- [ ] FastAPI app with `/analyze` endpoint; Pydantic request/response models
- [ ] Emergency keyword detection (hardcoded list, runs BEFORE any API call)
- [ ] Gemini 2.0 Flash integration with JSON schema enforcement
- [ ] Claude Sonnet integration with structured output (tool_use JSON pattern)
- [ ] Tier routing: confidence > 0.85 → Tier 2 result; else → Tier 3
- [ ] EMERGENCY cross-verification: second Claude Sonnet call confirms any EMERGENCY
- [ ] Confidence gating: < 0.60 → "insufficient information" graceful response
- [ ] System prompt v1: includes species, breed context, triage schema, tone instructions, anti-hallucination guards
- [ ] Structured output schema: `AnalysisResult` {triage_level, confidence, primary_concern, visible_symptoms[], differential[], recommended_actions[], urgency_timeframe, disclaimer_required}
- [ ] Anthropic prompt caching on system prompt (reduces token cost 50-70%)
- [ ] Upstash Redis: basic result caching
- [ ] Retry logic: 1 retry on timeout; graceful degradation on repeated failure
- [ ] Structured JSON logging (mask API keys)

#### Analytics
- [ ] PostHog events: `onboarding_step_completed`, `onboarding_completed`, `analysis_submitted`, `analysis_completed`, `result_viewed`, `emergency_triggered`, `paywall_shown`, `trial_started`, `subscription_converted`
- [ ] RevenueCat → PostHog revenue sync via webhook

#### Testing
- [ ] Unit tests: AI output parser (valid, invalid, malformed JSON responses)
- [ ] Unit tests: Emergency override (all hardcoded keywords)
- [ ] Unit tests: Free tier rate limiting (3 allowed, 4th blocked)
- [ ] Integration tests: Full analysis flow with mocked AI responses
- [ ] Widget tests: Onboarding flow, result screen all three triage levels
- [ ] Manual QA: Happy path on physical iPhone + Android device
- [ ] Manual QA: EMERGENCY flow (acknowledgment gate, vet finder CTA)
- [ ] Manual QA: Paywall (3 free, 4th blocked, RevenueCat flow)

#### Growth Systems
- [ ] Share button on LIKELY NORMAL results (copy + PawDoc watermark image)
- [ ] Referral code field on users table; referral deep link generation

**Critical Considerations:**
- EMERGENCY analyses must NEVER be blocked by paywall — add explicit check in Edge Function
- All disclaimers injected at API level, not UI level — ensures they cannot be removed by UI changes
- RLS policies must be tested with actual user JWTs (not service role)
- Temperature 0.1 for ALL health analysis calls — consistency over creativity

**Success Metrics:**
- End-to-end analysis flow working on physical devices (iOS + Android)
- P95 latency < 10 seconds on WiFi
- Emergency override catches all 14 hardcoded trigger scenarios
- CI/CD deploys to TestFlight on every main branch merge

**Risk Analysis:**
- Claude JSON mode occasionally produces malformed output — implement robust fallback + retry
- Camera permissions differ between iOS/Android — test on both platforms early
- Gemini confidence scores need calibration — may require prompt tuning to get reliable 0.85 threshold

**Execution Prompt (FOR AI AGENT):**

```
TASK: Build Phase 1 of PawDoc — the core MVP analysis flow.

STACK:
- Flutter 3.x + Riverpod 2.x + go_router + Material 3
- Supabase (PostgreSQL + Auth + Edge Functions Deno/TypeScript)
- Python FastAPI on Fly.io (AI orchestration)
- Cloudflare R2 (image storage)
- RevenueCat (subscriptions)
- PostHog (analytics)
- Sentry (errors)

FOLDER STRUCTURE: Follow the structure defined in Section 4 of the roadmap.

ARCHITECTURE CONSTRAINTS:
- RLS on every Supabase table — NEVER use service_role for user data reads
- AI calls MUST use structured output/JSON mode — never parse free text
- Free tier limit enforced server-side (Edge Function) — NEVER trust client
- EMERGENCY override runs BEFORE any AI call (not after)
- All emergency hardcoded keywords checked in Python safety.py
- Images compressed to <2MB client-side before upload
- System prompt includes: species, breed, age, prior history, tone guidelines, anti-hallucination rules
- Anthropic prompt caching enabled on system prompt

CODING STANDARDS:
- Dart: strong mode; no dynamic types; const constructors where possible
- Python: type hints on all functions; Pydantic models for all I/O; no bare except clauses
- No hardcoded strings — use constants files
- API keys via Doppler env vars only — never in source
- PostHog event on every measurable user action

TESTING REQUIREMENTS:
- Emergency override: all 14 keywords trigger EMERGENCY
- Rate limiting: 4th analysis blocked for free user
- RLS: verify cross-user data access is impossible with user JWT
- Parser: valid, invalid, and empty AI responses all handled gracefully

SECURITY REQUIREMENTS:
- Input validation on all endpoints (file type, file size, user_id ownership)
- Rate limiting at Edge Function level (10 analyses/day/user)
- SQL injection impossible — parameterized queries only
- No PII in logs — mask user emails in logs

PERFORMANCE TARGETS:
- Image upload to R2: < 2s on 4G
- AI Tier 2 analysis: < 3s P50
- AI Tier 3 analysis: < 6s P50
- App cold start: < 2s on iPhone 12 / Pixel 6

ANTI-HALLUCINATION:
- Temperature: 0.1 for all health analysis calls
- Confidence < 0.60 → return "insufficient information" — never fabricate
- EMERGENCY results always cross-verified with second Claude call
- System prompt explicitly instructs: say "I cannot determine" rather than guessing
- JSON schema validation — off-schema responses rejected and logged

DEPLOYMENT:
- Fly.io: Docker container; min_machines_running = 1 (no cold starts)
- Supabase: deploy functions via Supabase CLI in CI pipeline
- Flutter: TestFlight (iOS) + Internal Testing (Android) via GitHub Actions on merge to main
```

---

### 📍 Phase 2: MVP Polish & App Store Launch
**Duration:** Weeks 5-6

**Objective:** App Store approved, production-quality UX, first public users.

**Business Goal:** First paying users. Establish App Store presence. Collect real user feedback for V1 iteration.

**Dependencies:** Phase 1 complete + beta tested on 20+ users

**Deliverables:**
- App Store Connect submission (iOS) + Google Play Console submission (Android)
- App Store metadata: title `PawDoc: AI Pet Health`, subtitle `Know When to Call the Vet`, optimized keywords
- Production infrastructure fully configured and verified
- E&O insurance purchased (before public launch)
- Terms of Service + Privacy Policy live at pawdoc.app
- Push notification permission flow in onboarding
- Final app icon (all required sizes)
- 50-user beta via TestFlight; feedback incorporated
- Customer support email: support@pawdoc.app

**Tasks:**

#### Frontend
- [ ] Final design polish: all loading, error, and empty states
- [ ] Offline graceful degradation messaging
- [ ] OneSignal SDK integration + permission request on Onboarding Screen 4
- [ ] App icon: all required sizes for iOS + Android; splash screen
- [ ] Deep link handling: referral codes; result share links
- [ ] Accessibility: minimum contrast ratios; VoiceOver labels; dynamic type support
- [ ] Dark mode (follow system setting)
- [ ] Performance profiling: cold start < 2s; analysis memory usage < 150MB

#### App Store
- [ ] iOS App Store: binary + metadata (title, subtitle, description, keywords, screenshots x10, preview video if possible)
- [ ] App Store review notes: "AI-assisted information tool, not veterinary service. All results include clear disclaimers."
- [ ] Google Play: AAB bundle + store listing
- [ ] Soft launch: 50 beta users via TestFlight; minimum 4.0 avg rating before public

**ASO Keywords (Apple — 100 char limit for keyword field):**
```
symptom,checker,dog,cat,sick,emergency,vet,triage,diagnosis,rabbit,puppy,monitor
```

**Screenshots order:**
1. "Know exactly what your pet needs." + result screen
2. How it works: camera → AI → result
3. "No more 2am anxiety spirals." + NORMAL result
4. Trust: "Reviewed by veterinary experts"
5. Feature breadth: multi-pet, history, reminders

#### Legal
- [ ] E&O Insurance policy: $100K minimum coverage; purchase before public launch
- [ ] Terms of Service: live at pawdoc.app/terms; GDPR-compliant
- [ ] Privacy Policy: live at pawdoc.app/privacy; covers US + EU users

**Success Metrics:**
- App Store approval without P0 rejection
- 50 beta users with average rating > 4.0
- Analysis flow P95 < 10s on 4G mobile
- Zero P0 bugs in beta

**Risk Analysis:**
- Apple health app reviews take 2-3 weeks and often require 2-3 rejections — build review notes carefully; avoid "diagnosis" language in any metadata
- Google Play is faster but also scrutinizes health apps — same caution applies

---

## GROWTH PHASES

---

### 📍 Phase 3: V1 Core Growth Features
**Duration:** Weeks 7-12

**Objective:** Video analysis, multi-pet management, health history, vet finder, referral program.

**Business Goal:** Reach $5K MRR. Build the retention features that create stickiness beyond the acute symptom event.

**Dependencies:** Phase 2 launched; 100+ active users providing real data

**Deliverables:**
- Video analysis (keyframe extraction + Gemini video path)
- Multi-pet management (up to 2 pets on Premium, unlimited on Family)
- Health history timeline (analyses + manual health events)
- Vaccination/medication reminder system
- Vet finder (Google Places API; nearest 5; emergency filter)
- Airvet/Vetster deep links on EMERGENCY results
- OneSignal notification campaigns (48h follow-up, seasonal alerts)
- Android parity (full feature match with iOS)
- iOS Widget (pet status at-a-glance)
- Breed-specific insight cards on home screen

**Tasks:**

#### Frontend
- [ ] Video capture: in-app camera video mode (max 30s); quality guidance
- [ ] Client-side keyframe extraction (flutter_ffmpeg): 4-6 frames from video
- [ ] Health history screen: timeline view; analyses + manual events
- [ ] Manual health event quick-add: type, date, notes
- [ ] Multi-pet switcher: pet selector on home screen
- [ ] Vaccination reminder setup: species-based schedule pre-fill; custom additions
- [ ] Vet finder: location-based Google Places results; emergency filter; call + directions CTA
- [ ] Airvet deep link: shown on EMERGENCY result + low-confidence result
- [ ] iOS Widget (WidgetKit): pet name, last check status, "Check [Pet]" button
- [ ] Android Widget (AppWidgetProvider): equivalent iOS widget
- [ ] Breed insight cards: rotating contextual content on home screen
- [ ] Android notification channels: health alerts, reminders, follow-ups

#### Backend
- [ ] Video analysis path: Edge Function handles video input; sends to Gemini 1.5 Pro video API
- [ ] Reminder cron job: daily Edge Function; check reminders due in 7 days; push via OneSignal
- [ ] 48h follow-up system: if last analysis = MONITOR, send follow-up push after 48h
- [ ] Seasonal alert system: monthly cron; breed-specific seasonal content to relevant segments
- [ ] Breed data table: static breed health characteristics; cached in Supabase
- [ ] Google Places proxy: Edge Function proxies vet finder queries (hides API key)

#### Analytics
- [ ] Track: `video_analysis_submitted`, `multi_pet_added`, `health_event_logged`, `reminder_set`, `vet_finder_opened`, `airvet_clicked`, `widget_installed`
- [ ] D7/D30 cohort retention analysis by feature usage
- [ ] Airvet referral tracking via UTM parameters

#### Growth Systems
- [ ] Referral program live: personal links, conversion tracking, RevenueCat entitlement extension
- [ ] Review request v2: after 3rd health history event logged
- [ ] First 5 SEO articles published at pawdoc.app/blog

**Success Metrics:**
- $5K MRR by end of Phase 3
- D7 retention ≥ 32%
- 25% of Premium subscribers use health history at least once
- Airvet referral revenue: first $500
- Video analysis P95 latency < 15s

---

### 📍 Phase 4: V1 Monetization & Retention Optimization
**Duration:** Weeks 13-16

**Objective:** $10K MRR. A/B test the conversion funnel. Launch paid acquisition.

**Business Goal:** Achieve LTV:CAC > 3:1 on paid acquisition. Establish content/SEO flywheel.

**Dependencies:** Phase 3 complete; real retention data from 500+ users

**Deliverables:**
- Onboarding A/B tests (3 variants via PostHog feature flags)
- Paywall A/B tests (annual-first vs. monthly-first; price anchoring)
- Push notification optimization (timing, copy, frequency)
- Android parity complete (video, widget, notification channels)
- Web landing page (pawdoc.app): SEO-optimized, social proof, App Store badges
- 10 SEO articles live with proper metadata
- First paid campaigns: Apple Search Ads (5 exact match keywords) + TikTok ($500 test)

**Tasks:**

#### Frontend
- [ ] PostHog feature flags for A/B variant assignment
- [ ] Onboarding Variant B: paywall on Screen 2 (aggressive)
- [ ] Onboarding Variant C: no paywall in onboarding (late paywall)
- [ ] Paywall Variant B: monthly price featured, annual as "best value" badge
- [ ] Paywall Variant C: add testimonial + vet advisor photo to paywall
- [ ] In-app feedback: thumbs up/down on result screen; optional comment
- [ ] Analysis follow-up: 72h prompt "Was this assessment helpful?"

#### Web (Next.js on Cloudflare Pages)
- [ ] Landing page: value prop above fold; screenshots; App Store badges; social proof
- [ ] Blog infrastructure: MDX articles with SEO metadata
- [ ] 10 SEO articles: see target keywords in Growth Strategy report

#### Analytics
- [ ] A/B test dashboards: variant completion + conversion rates
- [ ] Paid acquisition ROI: cost per install, trial, subscriber by channel
- [ ] Google Search Console integration for SEO tracking

**Success Metrics:**
- $10K MRR by end of Phase 4
- Winning onboarding and paywall variants identified
- CAC from paid acquisition < $15
- 5 SEO articles in top-20 Google for target keywords
- D30 retention ≥ 25%

---

## SCALE PHASES

---

### 📍 Phase 5: V2 — Platform Expansion
**Duration:** Months 5-7

**Objective:** Exotic species, web symptom checker, AI health journal, embedded telehealth.

**Business Goal:** $25K MRR. Open exotic species niche (40-60% higher WTP). Content-driven organic growth.

**Dependencies:** Phase 4 complete; stable $10K+ MRR; 4.5+ App Store rating

**Deliverables:**
- Exotic species: rabbits, guinea pigs, birds, reptiles (separate AI prompts per species)
- Web symptom checker: free, no-account-required at pawdoc.app/check
- AI health journal: weekly GPT-4o synthesized health narrative per pet
- Embedded Airvet: in-app video consultations (revenue share)
- German localization (App Store submission)
- B2B lite: dog walker / pet sitter multi-client plan ($19.99/month)

**Success Metrics:**
- $25K MRR
- 5% of users are exotic species owners
- Web checker: 5K unique uses/month
- Airvet: $2K/month referral revenue

---

### 📍 Phase 6: V2 — Revenue Optimization
**Duration:** Months 7-9

**Objective:** $50K MRR. Personalization engine. Insurance affiliates. Data moat begins.

**Deliverables:**
- Personalization engine: breed + age + history injected into every analysis prompt
- Pet insurance affiliate: Trupanion + Healthy Paws deep links with attribution
- Branded health reports: exportable PDF for vet visits ($4.99 add-on)
- Outcome feedback loop: "What happened?" 72h follow-up (model accuracy signal)
- Family sharing: invite family members to shared pet access

**Success Metrics:**
- $50K MRR
- Insurance affiliate: $3K/month
- Health reports: 500+/month
- 10K+ outcome data points (model training dataset begins)

---

### 📍 Phase 7: V3 — Infrastructure & B2B Foundation
**Duration:** Months 10-14

**Objective:** 100K+ MAU infrastructure hardening. B2B API v1. Community features.

**Deliverables:**
- Infrastructure upgrade: read replicas, pgBouncer, Fly.io autoscaling, DB partitioning
- B2B API v1: REST API with API keys, usage billing (Stripe), self-service signup
- Community features: breed-specific Q&A; vet-verified answers
- Longitudinal monitoring: AI baseline detection for chronic condition drift
- Proprietary dataset v1: 50K+ labeled analyses prepared for fine-tuning

**Success Metrics:**
- $75K MRR
- B2B API: 3+ paying customers at $500-2K/month
- System uptime: 99.9%+ rolling 30 days

---

### 📍 Phase 8: V3 — Proprietary AI & Acquisition Readiness
**Duration:** Months 15-18

**Objective:** Fine-tuned proprietary model. $100K MRR. Acquisition conversations begin.

**Deliverables:**
- Fine-tuned vision model v1 trained on PawDoc's pet health dataset
- Model A/B test infrastructure: traffic routing to proprietary model
- Pet insurance FNOL integration: emergency analyses notify insurance partner
- German + Australian App Store launches
- Acquisition readiness materials: data room, metrics deck

**Success Metrics:**
- $100K MRR
- Proprietary model accuracy ≥ Claude Sonnet baseline
- Insurance FNOL integration: first revenue
- 2+ strategic buyer conversations initiated

---

# 11. EXPERIMENTATION SYSTEM

## A/B Testing Framework

**Platform:** PostHog feature flags (unified with analytics)
**Minimum sample size:** 500 users per variant for 80% statistical power

## Experiment Backlog

### Onboarding Experiments

| Experiment | Hypothesis | Success Metric | Risk |
|------------|-----------|---------------|------|
| Paywall position (Screen 3 vs. post-first-analysis) | Post-analysis +30% trial conversion because user has experienced value | Trial start rate | Medium |
| Onboarding length (3-screen vs. 5-screen) | Shorter +15% completion rate | Onboarding completion | Low |
| Trust screen (vet advisor shown vs. skipped) | Vet photo +10% trial conversion | Trial start rate | Low |

### Pricing Experiments

| Experiment | Hypothesis | Success Metric | Risk |
|------------|-----------|---------------|------|
| Annual vs. monthly featured | Annual-first increases annual share by 20%, boosting LTV | Annual plan conversion | Low |
| Price point ($9.99 vs. $7.99 vs. $12.99) | $9.99 is optimal — lower doesn't convert better | Revenue × conversion | High |
| Free tier limit (2 vs. 3 vs. 5 per month) | 2/month creates more pressure; 5/month improves trust | Trial conversion rate | High |
| Trial length (7-day vs. 14-day) | 14-day +15% conversion via two health event opportunities | Trial-to-paid conversion | Medium |

### Retention Experiments

| Experiment | Hypothesis | Success Metric | Risk |
|------------|-----------|---------------|------|
| 48h follow-up push (on vs. off) | Follow-up +12% D7 retention | D7 retention | Low |
| Monthly summary email (on vs. off) | Summary email +8% D30 retention | D30 retention | Low |
| Streak visibility (shown vs. hidden) | Visible streak +15% weekly return | WAU | Low |

---

# 12. IMPLEMENTATION ROADMAP

## Phase Summary

| Phase | Duration | Key Deliverable | Effort | Confidence |
|-------|---------|-----------------|--------|-----------|
| 0: Foundation | 1 week | Infrastructure + CI/CD | 40h | High |
| 1: MVP Core | 3 weeks | Analysis flow + auth + paywall | 120h | High |
| 2: App Store Launch | 2 weeks | Submission + beta + legal | 80h | Medium |
| 3: V1 Growth | 6 weeks | Video, multi-pet, history, vet finder | 180h | Medium |
| 4: Monetization | 4 weeks | A/B tests + paid acquisition + SEO | 120h | Medium |
| 5: V2 Expansion | 8 weeks | Exotic species + web tool + journal | 240h | Low-Medium |
| 6: Revenue Opt. | 8 weeks | Personalization + insurance + B2B | 240h | Low-Medium |
| 7: Infrastructure | 16 weeks | B2B API + community + hardening | 400h | Low |
| 8: Proprietary AI | 16 weeks | Fine-tuned model + international | 480h | Low |

## Solo Founder Feasibility

| Phase | Feasibility | Bottleneck |
|-------|------------|-----------|
| 0-2 (MVP) | High | Prompt engineering quality |
| 3-4 (V1) | Medium | Android parity + content marketing |
| 5-6 (V2) | Low-Medium | Content work competes with engineering |
| 7-8 (V3) | Not solo-friendly | ML engineering + B2B sales require a second person |

**Recommended first hire:** Full-stack mobile developer (Flutter) OR content/growth specialist, depending on bottleneck at Month 8-10.

## Execution Bottlenecks

1. **Apple App Store Review** — Health apps often rejected 2-3 times; budget 4-6 weeks for review process
2. **System Prompt Quality** — 2-3 weeks of prompt iteration needed for consistent, safe outputs
3. **Android Parity** — Camera, video, widgets, notifications are platform-specific; budget 30% extra time
4. **Content Marketing** — Writing quality SEO articles competes with engineering; consider freelance vet writer
5. **B2B Sales** — B2B API customers need custom conversations and contracts; 3-6 month sales cycles

---

# 13. POST-LAUNCH STRATEGY

## Analytics Review Cadence

**Weekly (first 3 months):**
- DAU/MAU, analyses submitted, paywall conversions, MRR
- Top 3 crash sources (Sentry)
- Push notification open rates + opt-out rates
- App Store rating + new reviews (AppFollow)

**Monthly:**
- D1/D7/D30 cohort retention by acquisition cohort
- MRR + subscriber count + churn rate + trial-to-paid conversion
- AI quality review: sample 50 random analyses for quality and accuracy
- Churn reason analysis from cancellation data

**Quarterly:**
- Full P&L: revenue vs. AI + infra costs
- Competitive landscape: any new entrants?
- SEO performance: article rankings + organic traffic
- Paid acquisition ROI by channel

## Incident Response Protocol

**P0 (service down / data breach):**
1. Alert within 5 minutes (Better Uptime → Slack/SMS)
2. Status page acknowledgment within 15 minutes
3. Fix + deploy within 2 hours target
4. Post-incident report within 24 hours

**P1 (AI quality incident — false negative or wrong EMERGENCY):**
1. Log the analysis ID with full input/output
2. Respond to user within 4 hours — empathy first
3. If systematic: pause affected path; investigate prompt; resume with fix
4. Internal forensic review of what was shown

**P0 nightmare scenario (pet death complaint):**
1. Respond personally within 2 hours — empathy, never defensiveness
2. Pull the exact analysis record immediately
3. Do NOT admit legal liability in initial response
4. Contact E&O insurance provider immediately
5. Prepare press statement in advance

## User Feedback Systems

| Channel | Cadence | Action Threshold |
|---------|---------|-----------------|
| In-app thumbs up/down | Continuous | Negative rate > 20% → investigate prompt quality |
| App Store reviews | Monitor daily | All 1-3 star reviews responded to within 24h |
| Support email | Respond within 24h | Volume > 10/day → add FAQ |
| 72h outcome follow-up | Continuous | False negative detection |
| Reddit monitoring | Weekly | Engage authentically with organic mentions |

---

# 14. FINAL VALIDATION REPORT

## System Completeness Check

| System | Status | Notes |
|--------|--------|-------|
| Authentication | ✅ | Supabase Auth + RLS on all tables |
| Infrastructure | ✅ | Fly.io + Supabase + Cloudflare; costs documented |
| Observability | ✅ | Sentry + Better Uptime + PostHog |
| Security | ✅ | RLS + rate limiting + input validation + prompt injection guards |
| Testing | ✅ | Unit + integration + widget + manual QA defined per phase |
| CI/CD | ✅ | GitHub Actions + Fastlane for both platforms |
| Analytics | ✅ | PostHog + RevenueCat + AppFollow |
| Legal compliance | ✅ | E&O insurance, ToS, Privacy Policy, GDPR, disclaimers |
| Content moderation | ✅ | NSFW pre-filter on all uploads |
| Monetization | ✅ | Freemium + referral + affiliate + B2B; emergency never paywalled |

## Issues Found and Fixed

| Issue | Fix Applied |
|-------|------------|
| Rate limiting was client-side | Moved to Supabase Edge Function (server-side enforcement) |
| Emergency override was post-AI | Moved to pre-AI call with hardcoded keyword detection |
| No content moderation on uploads | NSFW pre-filter added to Phase 1 backend tasks |
| No outcome data collection | 72h follow-up + `analysis_feedback` table added in Phase 6 |
| E&O insurance not sequenced | Added as Phase 2 deliverable (before public launch) |
| Semantic cache not sequenced | pgvector schema in Phase 1; semantic cache logic in Phase 3 |
| No AI quality monitoring | `analysis_feedback` tracking + monthly quality review added |
| Prompt caching missing | Anthropic prompt caching added to Phase 1 AI service tasks |

## Optimization Opportunities

1. **Prompt caching** — Anthropic prompt caching on system prompt reduces token costs 50-70% from day one
2. **Content flywheel** — Each SEO article drives installs → analyses → data → better model → better reviews → more installs; start early
3. **Vet advisor network** — 5-10 credentialed advisors provide trust signals + content review + B2B referrals
4. **Outcome feedback loop** — 72h follow-up data is the foundation of the proprietary model training dataset

## Scaling Milestones

| ARR | Key Milestones | Strategic Priority |
|-----|---------------|-------------------|
| $120K | 1,000 subscribers | Data collection volume; content flywheel established |
| $600K | 5,000 subscribers | Paid acquisition profitable; B2B API launched |
| $1.2M | 10,000 subscribers | Proprietary dataset size meaningful for fine-tuning |
| $3M+ | 25,000 subscribers | Acquisition-attractive; data moat building; B2B revenue |

**Most likely exit pathway:** $5-10M ARR with growing data moat → strategic acquisition by Chewy ($100-300M), Trupanion ($50-150M), or Mars Petcare ($50-200M).

---

*Document version: 1.0 | Generated: May 2026 | PawDoc Execution Roadmap*
*Review cadence: Competitive analysis every 6 months; infrastructure costs quarterly; phase durations updated based on actual velocity post-Phase 2*
