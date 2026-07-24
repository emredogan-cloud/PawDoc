# PawDoc — Next Evolution Program: Master Roadmap

**Date:** 2026-07-24 · **Branch:** `feat/next-evolution` (off `main` @ `2e8d11f`, post-PR #86)
**Mission:** Evolve PawDoc into a significantly more valuable product while preserving the core
philosophy — **Safety first. Trust first. Memory over diagnosis.**
**Working mode:** Autonomous execution per the founder's mission brief (same mode as the
Final Evolution Program, PR #80): one program branch, one commit per phase, full local test
suite + CI verification after every phase, single PR at the end for founder squash-merge.
This mission brief supersedes the per-sub-PR stop gate for the duration of the program.

---

## 0. Non-negotiables carried into every phase

These are the existing safety/security gates and pinned decisions (`memory/PAST_DECISIONS.md`)
that every phase below was designed around. Nothing in this program touches them:

1. **Emergency surfaces stay frozen.** Nothing is added to `EmergencyHelpScreen` /
   `EmergencyResultScreen`. The red path stays offline-capable and model-free.
2. **GET_HELP_NOW is never paywalled, metered, or blocked** — including by any new quota
   introduced here (AI Assistant daily limits explicitly bypass on emergency keyword match).
3. **RLS on every new user table** with explicit per-operation policies, `USING` **and**
   `WITH CHECK`, using the `(select auth.uid())` pattern; every new table gets assertions in
   `supabase/tests/rls_isolation.sql` + the account-deletion cascade test.
4. **No R2 credentials in the client.** All object access via short-lived presigned URLs
   minted by JWT-verified Edge Functions; EXIF/GPS stripped client-side before upload.
5. **No `service_role` for user-data reads.** Reads are user-JWT + RLS; service role only for
   server writes (same split `analyze` uses today).
6. **AI output remains structured/guarded.** The assistant never diagnoses, never names
   conditions as findings, never gives medication doses, and always defers symptom concerns
   to the triage flow; emergency keyword override runs before any model call.
7. **Deleted features stay deleted.** OneSignal (→ local notifications), Google Places
   (→ keyless OSM), family sharing, referrals, journals, video capture are not re-added.
   Where a new phase overlaps a deletion, the design below explicitly avoids the revert:
   - *Walk notifications* → `flutter_local_notifications` scheduled on-device (no push vendor).
   - *Walk places* → OpenStreetMap Overpass API, keyless (not Google Places).
   - *Community chat* → new opt-in social system (not a family-sharing revert; different
     tables, different purpose, opt-in only).
8. **Model IDs only** (`claude-sonnet-4-6`, `gemini-2.0-flash`); temperature 0.1 for anything
   health-triage; new assistant calls use a pinned low temperature and structured guardrails.
9. **No secrets in git**; new config lands as `--dart-define` / Doppler env placeholders and
   is documented in `ENVIRONMENT_VARS.md`.
10. **Copy discipline:** no overclaims; `scripts/verify-no-placeholders.sh` (CI job
    "No placeholders / overclaims") must stay green — new marketing copy (premium modal,
    encyclopedia, assistant) is written within those constraints.

---

## 1. Shared foundations (built once, reused across phases)

To minimise technical debt, the following are built exactly once, in the earliest phase that
needs them, and reused afterwards:

| ID | Foundation | Built in | Reused by |
|----|------------|----------|-----------|
| F1 | **Scoped storage keys + signed GET**: extend `_shared/upload_key.mjs` with a `memories` scope; new Edge Function `sign-media-url` (JWT-verified, batch presigned GETs for the caller's own keys only); Flutter `SignedMediaImage` widget + TTL-aware URL cache (`cached_network_image`, cache key = storage key, not URL) | Phase 2 | Phase 4 (chat image history), future avatars |
| F2 | **Gallery/camera picking + compression**: `image_picker` (Android photo-picker backed) feeding the existing `compressForUpload` (2 MB / 1600 px / EXIF-strip) + `UploadService` retry path, parameterised by scope | Phase 2 | Phase 4 (chat attachments) |
| F3 | **Location service**: `geolocator` wrapper (foreground-only, "while in use"), contextual permission flow, pure-Dart geohash encode/neighbors util (unit-tested; no plugin) | Phase 5 | Phase 6 (nearby discovery) |
| F4 | **SSE client**: minimal `http`-based Server-Sent-Events consumer (POST + streamed response, line-delimited event parser) with cancellation | Phase 4 | any future streaming feature |
| F5 | **Premium gating**: existing `userProfileProvider.isPremium` (`account/user_profile.dart`) reused as the single premium source of truth for Memories caps, Assistant limits, and the Premium Welcome trigger | — | Phases 2, 4, 8 |

**New Flutter dependencies (pinned at implementation):** `image_picker`, `cached_network_image ^3.4.1`,
`gpt_markdown ^1.1.8` (successor for discontinued `flutter_markdown`), `geolocator ^14.x`,
`google_sign_in ^7.2.0`. `flutter_launcher_icons ^0.14.4` is already a dev dependency.
No new native build config beyond manifest permissions (location) and, later, Google OAuth client IDs.

**External services (all keyless / no new secrets):**
- **Weather:** MET Norway Locationforecast 2.0 — free including commercial use, CC-BY 4.0,
  requires identifying `User-Agent` + attribution ([met.no licensing](https://docs.api.met.no/doc/License.html)).
  Open-Meteo was rejected: its free tier is non-commercial only ([terms](https://open-meteo.com/en/terms)).
- **Walk places:** OpenStreetMap Overpass API (public instances, fair-use), attribution
  "© OpenStreetMap contributors" rendered in-UI.
- **Breed images:** Wikimedia Commons, PD/CC0/CC-BY/CC-BY-SA only, per-image credit rendered
  in-app + `CREDITS` manifest committed.

---

## 2. Phase plan

Phases run in mission order. Each phase ends with: `flutter analyze` + `flutter test` green,
`ruff` + `pytest` green when ai-service changed, `node --test` green when Edge Functions
changed, `./scripts/test-rls.sh` green when migrations changed, commit + push, CI green.

---

### PHASE 1 — Brand Refresh (launcher icon)

**Objective.** Replace the launcher icon with `ASO-image/PlayStore-ASO/007-app-logo.png`
(navy + neon-mint puppy/kitten/stethoscope art) across every required Android density,
with correct adaptive-icon behaviour and Play compatibility.

- **Architecture changes.** None (asset-level).
- **UI work.** None beyond icon rendering; verify launcher, settings, recents appearance
  via masked previews (circle / squircle / rounded-square composites generated locally).
- **Backend / DB / API / AI work.** None.
- **Assets.**
  - `mobile/assets/icon/app_icon.png` — full-bleed 1024² source (legacy icons + store use).
  - `mobile/assets/icon/app_icon_foreground.png` — adaptive foreground: artwork scaled so the
    subject sits inside the 66/108 safe zone, on the sampled navy so it blends seamlessly
    with the background layer under any mask.
  - `mobile/assets/icon/app_icon_monochrome.png` — Android 13+ themed icon: clean white paw
    glyph (generated vector-style, not a photo threshold).
  - Adaptive background = exact sampled corner navy of the artwork.
  - Regenerate all `mipmap-*` + `drawable-*` densities via `flutter_launcher_icons` 0.14.4
    (already a dev dep) with `adaptive_icon_*` + `adaptive_icon_monochrome` config.
  - `ASO-image/` (raw founder art, ~13 MB) is **gitignored**; only derived assets are committed.
- **Testing strategy.** `flutter_launcher_icons` run output; inspect generated res tree
  (all 5 densities + anydpi-v26 XML); compose masked previews and visually verify; debug APK
  build; confirm `AndroidManifest` still references `@mipmap/ic_launcher`.
- **Migration requirements.** None. Play accepts icon changes with any new AAB
  (version already bumped to `1.0.0+2` in the working tree — kept).
- **Risks.** Adaptive masks cropping the art (mitigated by safe-zone scaling + preview
  verification); legacy launchers showing the square source (acceptable, it is full-bleed art).
- **Dependencies.** None.
- **Estimated effort.** 0.5 day.

---

### PHASE 2 — Pet Memories

**Objective.** A beautiful personal pet journal: photo memories with title/note/date —
create (camera or gallery), edit, delete, search, and a timeline gallery — cloud-stored,
premium-quality UI. This directly serves the product thesis: **paid = memory**.

- **Architecture changes.** New feature module `mobile/lib/src/memories/` (model, repository,
  providers, screens, widgets) following the established Repository +
  `FutureProvider.autoDispose` pattern. Foundations F1 + F2 built here.
- **UI work.**
  - `MemoriesScreen` — per-pet gallery: staggered photo grid + month-grouped timeline toggle,
    search field (title/note), premium empty state, `PawBackground` dark world, hero
    transition into the viewer.
  - `MemoryViewerScreen` — full-bleed photo, title/note/date overlay, edit + delete +
    (existing `share_plus`) share.
  - `MemoryEditorSheet` — frosted bottom sheet: photo (camera / gallery / keep), title
    (required, ≤80), note (optional, ≤600), date picker (defaults today).
  - Entry points: Home quick-action "Memories" + a `PawCard` section in the pet's world;
    tasteful, consistent with `_CaptureSheet` frosted styling.
- **Backend work.**
  - `generate-upload-url`: accept optional `scope: "memories"` → keys `memories/<uid>/<uuid>.<ext>`
    (`buildStorageKey` gains a validated scope arg; `analyze`'s `isOwnUploadKey` gate is
    untouched, so memory keys can never enter the analysis path).
  - New Edge Function `sign-media-url` (F1): POST `{keys: [...]}` (≤24/req) → verifies JWT,
    validates every key is under the caller's own `uploads/` or `memories/` namespace,
    returns `{key, url, expires_in: 3600}` presigned GETs.
  - New Edge Function `delete-media`: POST `{key}` → ownership-validated R2 object delete
    (used after RLS row delete; best-effort, logged).
  - `delete-account`: extend R2 purge to the `memories/<uid>/` prefix (GDPR-complete).
- **Database changes.** Migration `pet_memories`:
  `id uuid PK, user_id uuid → auth.users ON DELETE CASCADE, pet_id uuid → pets ON DELETE CASCADE,
  title text ≤80, note text ≤600 nullable, storage_key text, taken_on date, created_at, updated_at`
  + per-op RLS (own-only, USING + WITH CHECK) + `(user_id, pet_id, taken_on desc)` index +
  RLS isolation assertions + account-deletion cascade assertions.
- **API work.** Client repository: RLS-scoped CRUD via PostgREST; search via `ilike` on
  title/note; signed URL hydration through F1 with in-memory TTL cache.
- **AI work.** None (deliberately: memories are human, not AI content).
- **Assets.** Reuse existing empty-state illustration style (`assets/illustrations/`);
  no new bundled art required.
- **Testing strategy.** Unit: repository mapping, search filter, month grouping, quota cap
  logic. Widget: gallery renders memories (provider overrides), editor validation, delete
  confirmation flow, empty state. Edge: `node --test` for scoped `upload_key`,
  `sign-media-url` key-validation pure logic. RLS: isolation + cascade suites extended.
- **Migration requirements.** One additive migration; `supabase db push` is a founder deploy
  step (headless env has no live infra) — listed in the final report.
- **Risks.** Orphaned R2 objects if row-delete succeeds and object-delete fails (accepted:
  best-effort delete + delete-account prefix purge as backstop); free-tier storage growth
  (mitigated: free tier capped at 20 memories client-side with upsell — cost surface is
  storage-only, no AI; cap constant server-mirrorable later).
- **Dependencies.** None on other phases.
- **Estimated effort.** 2.5 days.

---

### PHASE 3 — Breed Encyclopedia

**Objective.** A premium, scalable breed encyclopedia — launch content: 10 dog + 10 cat
breeds, each with licensed photography, origin, life expectancy, physical traits,
temperament, personality, exercise, grooming, health notes, and facts.

- **Architecture changes.** New module `mobile/lib/src/encyclopedia/`. Content-as-data:
  `assets/breeds/breeds_v1.json` (versioned schema `schema_version: 1`) + WebP images.
  `BreedRepository` reads assets today; the interface (id-addressed, versioned, lazy) is
  remote-swappable later (CDN/Supabase) without UI changes — the path to "hundreds of breeds".
- **UI work.**
  - `EncyclopediaScreen` — species segmented control (Dogs/Cats), search-as-you-type,
    premium breed cards (photo, name, origin flag-line, temperament chips).
  - `BreedDetailScreen` — hero image with parallax-lite scroll, stat band (life expectancy,
    size, weight), sectioned content: About, Personality & Temperament (chips + prose),
    Exercise & Grooming (1–5 level meters), Health notes (educational tone + vet-consult
    line), Interesting facts, photo credit footer (license attribution).
  - Entry points: Home `PawCard` ("Breed Encyclopedia") + deep link from the existing
    `BreedInsightCard` when the active pet's breed matches an entry.
- **Backend / DB / API work.** None (bundled assets v1 by design — offline-capable, zero
  latency; the repository seam is the future remote path).
- **AI work.** None. Content is human-authored/reviewed; health notes are educational
  ("this breed can be predisposed to…"), never diagnostic, always ending in a
  see-your-vet line — consistent with the no-diagnosis contract.
- **Assets.** 20 Wikimedia Commons photos (PD/CC0/CC-BY/CC-BY-SA only), recompressed to
  ~720 px WebP (~60–120 KB each, ~2 MB total bundle cost); `assets/breeds/credits.json`
  (author/license/source per image) rendered in-app; `docs/legal/BREED_IMAGE_CREDITS.md`.
- **Testing strategy.** Unit: JSON schema decode of all 20 entries (every field present,
  ranges sane, no banned overclaim phrases), search/filter logic, credit lookup. Widget:
  list renders + filters, detail renders all sections, attribution visible.
- **Migration requirements.** None.
- **Risks.** Image licensing (mitigated: allow-listed licenses only, per-image credit
  in-app + manifest); bundle size +~2 MB (accepted; AAB density splits unaffected);
  content accuracy (mitigated: conservative encyclopedic claims, ranges not absolutes).
- **Dependencies.** None.
- **Estimated effort.** 2 days (content authoring is the long pole).

---

### PHASE 4 — PawDoc AI Assistant

**Objective.** A premium conversational AI experience as a permanent bottom-nav destination —
streaming, markdown, conversation history/management, image support, pet-context awareness —
that is *additive to* and *never a bypass of* the safety triage system.

- **Architecture changes.**
  - Bottom nav grows to 5 tabs: Home · Pets · **Assistant** · Health · Settings
    (`root_shell.dart` `_pages` + destinations; center placement, distinctive icon).
  - New module `mobile/lib/src/assistant/` (models, repository, chat controller
    [`Notifier`-based streaming state], screens, widgets).
  - **ai-service** gains its first streaming endpoint; **Edge Function** gains its first
    SSE proxy. Trust boundary unchanged: model keys stay in ai-service; the client only
    ever talks to the JWT-verified Edge Function.
- **UI work.**
  - `AssistantScreen` — translucent pet-themed dark surface (PawBackground + subtle paw-mark
    painter overlay), greeting hero with the active pet, suggestion chips (safe, non-medical
    starters), conversation list access.
  - Chat view — user bubbles / assistant markdown (gpt_markdown: headings, lists, tables,
    code), token-streamed text with typing indicator, image attachments (thumbnail in
    bubble), graceful error + retry, day dividers, auto-scroll with "jump to latest".
  - Conversation management — history sheet (search, rename, delete, new chat), auto-titled
    conversations.
  - Emergency interstitial — if the emergency router matches user input, the send is
    intercepted client-side (same `emergency_keywords.dart` router) and the user is taken to
    the existing emergency flow; the server mirrors this check (defense in depth).
- **Backend work.** New Edge Function `assistant-chat` (JWT-verified):
  1. validates `{conversation_id?, pet_id?, message ≤2000, image_storage_key?}`;
  2. **emergency pre-check first** (shared `emergency_keywords.mjs`) → immediate `emergency`
     SSE event, no AI, no quota;
  3. quota: free tier **20 assistant messages/day** (count of today's user-role rows,
     service-role read), premium unlimited → 402 `assistant_limit_reached`;
  4. loads conversation history (RLS-scoped, last 20 turns) + pet context;
  5. ownership-validates + presigns any image key (same `isOwnUploadKey` gate as `analyze`);
  6. streams from ai-service `/assistant/chat`, piping SSE to the client through a
     TransformStream that accumulates the full reply;
  7. persists user + assistant messages, creates/titles the conversation, bumps `updated_at`.
- **Database changes.** Migration: `assistant_conversations`
  (`id, user_id → auth.users CASCADE, pet_id → pets SET NULL, title, created_at, updated_at`)
  and `assistant_messages`
  (`id, conversation_id → CASCADE, user_id → CASCADE, role ∈ user|assistant, content text,
  image_storage_key nullable, created_at`) + per-op RLS (own-only; client reads history
  directly via RLS; message inserts happen in the Edge Function) + indexes
  (`user_id, updated_at desc`; `conversation_id, created_at`) + RLS/cascade test assertions.
- **API work.** SSE protocol Edge→client: `delta` (text chunk), `emergency`, `limit`,
  `done {conversation_id, message_id}`, `error {code}`. Client consumes via F4 SSE client
  with the session JWT.
- **AI work.** ai-service `POST /assistant/chat` (service-token auth, same
  `require_service_auth`):
  - Claude streaming (`anthropic` 0.104.1 `messages.stream`), model env-configurable
    `ASSISTANT_MODEL` default `claude-sonnet-4-6`, `temperature 0.3`, `max_tokens 1500`;
  - system prompt: PawDoc companion persona; **hard guardrails** — no diagnosis, no
    medication/dosing, no "your pet is fine", symptom questions get general education plus
    an explicit hand-off to the in-app check flow; emergency-sounding content → advise
    immediate vet contact; pet context (species/breed/age/sex/weight) injected;
  - server-side emergency keyword re-check before the model call (reuses `safety.py`);
  - image support via existing `media.py` fetch guards (https, no-redirect, size cap,
    mime allowlist) — images arrive only as server-presigned own-upload URLs;
  - SSE out; refusal-safe fallback message on provider error.
- **Assets.** None new (background painted procedurally; typography from bundled fonts).
- **Testing strategy.** Python: endpoint auth, emergency short-circuit, prompt guardrail
  presence, stream assembly (mock SDK stream), image-URL gating. Node: quota gate pure
  logic, SSE event framing helpers, key validation. Flutter: SSE parser unit tests,
  chat controller state machine (streaming/cancel/error), widget tests for chat rendering
  (markdown, bubbles, typing indicator), conversation management, emergency interception,
  limit sheet. RLS suite for both tables.
- **Migration requirements.** One additive migration; founder deploys `assistant-chat` EF +
  ai-service (auto via `deploy.yml` on merge) + `supabase db push`.
- **Risks.** Cost exposure (mitigated: server-enforced daily free limit, premium unlimited,
  max_tokens cap, single-model calls, no retries on stream); long-lived SSE vs Fly
  concurrency limits (soft 20/machine — acceptable at beta scale, responses ≤ ~30 s;
  flagged for scale-up); safety drift in free-form chat (mitigated: layered keyword
  override client+edge+service, guardrailed prompt, no diagnosis contract, disclaimer
  line in assistant UI); streaming through two hops (mitigated: pure pass-through piping,
  25 s first-byte timeout, non-streaming fallback error event).
- **Dependencies.** F1/F2 from Phase 2 (attachments); nav change is standalone.
- **Estimated effort.** 4 days. **This is the program's largest phase.**

---

### PHASE 5 — Weather + Smart Walks

**Objective.** Weather-aware, location-aware walk recommendations —
"Today is a perfect day to walk Rex at Central Park." — with beautiful cards and
privacy-first delivery.

- **Architecture changes.** New module `mobile/lib/src/walks/`; F3 location foundation.
  **All computation on-device; PawDoc servers never receive or store coordinates** (the
  trust-first choice, and consistent with the deleted-Places decision).
- **UI work.**
  - Home: `WalkCard` — today's walk window (score ring, temp/precip/wind snapshot,
    pet-personalised copy using the active pet's name), tap → detail.
  - `WalksScreen` — hourly walk-quality timeline for today (+ tomorrow), best-window
    highlight, nearby walking places list (parks/dog parks/gardens from OSM with distance
    + open-in-maps deep link via existing `maps_links.dart` pattern), weather attribution
    footer ("Weather: MET Norway · Places: © OpenStreetMap contributors").
  - Permission flow: contextual pre-prompt explaining exactly what location is used for
    (foreground only, never stored server-side), graceful denied state with manual
    city-free fallback (generic weather-less walk tips).
- **Backend / DB / API work.** None server-side (keyless public APIs called from the
  client; no PawDoc endpoint involved).
  - MET Norway Locationforecast 2.0 compact: identifying `User-Agent`
    (`PawDoc/<version> (pawdoc.app)`), response cached 1 h on-device, coordinates rounded
    to 3 decimals per their ToS.
  - Overpass API: `leisure=park|dog_park|garden` within ~2.5 km, single query, cached
    24 h on-device, public instance with fair-use headers.
- **AI work.** None — the recommendation engine is a **deterministic, unit-tested pure
  function** (`WalkScorer`): temperature band (species/size-adjusted), precipitation,
  wind, UV; returns 0–100 score + reason strings + best hourly windows. Deterministic
  beats a model here (no cost, no latency, testable, no safety surface).
- **Database changes.** None (preferences in `shared_preferences`: notification opt-in,
  preferred walk hour).
- **Notifications.** On-device `flutter_local_notifications` daily walk reminder at a
  user-chosen hour with pet-personalised copy; **no push vendor** (pinned decision
  respected). Weather-conditional copy is refreshed whenever the app foregrounds
  (documented limitation: fully weather-conditional *background* delivery would need a
  background-fetch worker — listed under future ideas, not v1).
- **Assets.** None new (weather glyphs from Material icons; score ring painted).
- **Testing strategy.** Unit: `WalkScorer` matrix (hot/cold/rain/wind/UV × dog sizes/cat),
  MET response parsing (fixture JSON), Overpass parsing (fixture), geohash util, best-window
  selection. Widget: WalkCard states (loading/ready/denied/offline), WalksScreen render,
  permission pre-prompt.
- **Migration requirements.** Android `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION`
  manifest entries; Play **Data Safety form update** (location, not shared, ephemeral) —
  founder console step, documented in the final report. iOS plist keys added for parity.
- **Risks.** Public API availability (mitigated: cached responses, graceful degrade to
  tips-only card); OEM alarm throttling for reminders (existing inexact-alarm pattern);
  Play data-safety mismatch (mitigated: explicit founder checklist item).
- **Dependencies.** F3; benefits from Phase 2's Home layout polish but standalone.
- **Estimated effort.** 2.5 days.

---

### PHASE 6 — Paw Community (v1 of a long-term system)

**Objective.** An opt-in social layer: discover nearby pet owners, connect, chat 1-to-1,
and propose walks — designed so trust and privacy are structural, not bolted on.

- **Architecture changes.** New module `mobile/lib/src/community/`; first consumer of
  Supabase Realtime (postgres_changes over RLS-scoped streams, with pull-to-refresh
  fallback). Server-side logic stays in RLS policies (no new Edge Functions needed for v1).
- **UI work.**
  - `CommunityOnboardingScreen` — explicit opt-in: what is shared (display name, bio,
    species tags, approximate area — never exact location), what is not, how to leave;
    profile editor (display name, bio ≤160, species chips, discoverability toggle).
  - `CommunityHomeScreen` — nearby owners (approximate-distance cards), incoming/outgoing
    requests, connections list with unread hints.
  - `ChatScreen` — 1:1 messages (text, ≤2000 chars), day dividers, realtime updates,
    walk-proposal composer (time + place name + note) rendered as structured cards with
    accept/decline.
  - Safety surface on every profile/chat: **Report** and **Block** actions (Play UGC
    policy), plus community guidelines sheet.
  - Entry: Home card + Settings row; hidden entirely until opted in.
- **Backend work.** None beyond DB (v1); moderation runbook `docs/runbooks/COMMUNITY_MODERATION.md`
  (founder review cadence for reports, takedown steps).
- **Database changes.** One migration, four tables, all per-op RLS + tests:
  - `community_profiles` — `user_id PK → auth.users CASCADE, display_name ≤40, bio ≤160,
    species_tags text[], geohash text (5 chars, ~±2.4 km cell), is_discoverable bool,
    allow_requests bool, created_at, updated_at`. SELECT: own row OR
    (`is_discoverable` = true — coarse fields are the product); INSERT/UPDATE/DELETE: own.
  - `community_connections` — `id, requester_id, addressee_id, status ∈
    pending|accepted|declined|blocked, created_at, updated_at, UNIQUE(requester_id, addressee_id)`
    + FKs → `community_profiles ON DELETE CASCADE` (leaving the community dissolves your
    graph). SELECT: participant; INSERT: self as requester, status pending, addressee
    allows requests; UPDATE: addressee (accept/decline/block) or requester (cancel/block).
  - `community_messages` — `id, connection_id → CASCADE, sender_id, content ≤2000, created_at`.
    SELECT: participant of the parent connection; INSERT: sender is self AND parent
    connection `accepted` (blocked conversations go silent server-side). Realtime
    publication enabled for this table.
  - `community_reports` — `id, reporter_id, reported_user_id, connection_id?, reason enum,
    details ≤500, created_at`. INSERT: reporter is self; SELECT: own reports only
    (founder reads via service role).
  - RLS isolation assertions for all four (including the negative "non-participant cannot
    read messages" and "cannot message a non-accepted connection") + deletion-cascade
    assertions.
- **API work.** Client repositories over PostgREST + one Realtime stream per open chat;
  nearby query = geohash prefix-neighbor `IN` filter (client-computed neighbor set from F3
  util) ordered by approximate distance.
- **AI work.** None in v1 (deliberate: no AI moderation promises we can't keep; text-only
  chat, length-capped, report/block + founder runbook are the honest v1).
- **Assets.** None new.
- **Testing strategy.** Unit: geohash neighbors, distance approximation, connection state
  machine (pure Dart reducer), report reasons. Widget: opt-in flow gates everything,
  discovery cards, request accept/decline, chat send/receive (provider-injected stream),
  block hides content, report flow. RLS: the four-table suite is the heart of this phase's
  safety — written adversarially (cross-user reads, forged inserts, non-participant
  message reads, blocked-send).
- **Migration requirements.** One additive migration + realtime publication; founder
  `db push`. Play Console: UGC declarations (report/block present) — founder checklist.
- **Risks.** Social-graph abuse (mitigated: opt-in only, coarse location only, requests
  gated by `allow_requests`, block is one-tap, reports logged); realtime-over-RLS quirks
  (mitigated: stream + refresh fallback, integration-tested policies); scope creep
  (v1 is deliberately 1:1-chat + proposals; groups/feeds are future).
- **Dependencies.** F3 (geohash). Independent of Phases 2–5 otherwise.
- **Estimated effort.** 4 days.

---

### PHASE 7 — Google Sign-In

**Objective.** Google Sign-In on the Sign In / Create Account surface, in the existing
design language, with a complete operational runbook to make it live.

- **Architecture changes.** None structural — extends `AuthController` with
  `signInWithGoogle()` using `google_sign_in ^7.2.0` → `supabase.auth.signInWithIdToken`
  (mirrors the existing Apple flow with nonce handling per supabase-flutter docs).
- **UI work.** `SignInScreen`: a "Continue with Google" `PawSecondaryButton`-styled button
  (Google "G" mark per brand guidelines, cream-surface variant) placed with the Apple
  button in a social-auth group; shown on Android/all platforms; **hidden cleanly when
  `GOOGLE_WEB_CLIENT_ID` is not configured** (graceful degrade — no dead buttons); loading
  + error states via the existing inline error banner; works for both sign-in and sign-up
  (Supabase creates the account on first Google auth; LEG-03 terms acceptance is recorded
  the same way the Apple path does it).
- **Backend work.** None in-repo (Supabase Google provider is already enabled in
  `config.toml`; dashboard client-ID config is an ops step).
- **Database changes.** None (existing auth-user DB trigger provisions the profile row).
- **API / AI work.** None.
- **Assets.** Google mark drawn as a compliant vector widget (no binary asset).
- **Testing strategy.** Unit: controller logic with injected google-sign-in wrapper
  (token → Supabase call, cancel path, error mapping). Widget: button hidden without
  config, visible with config, disabled while in flight, error banner on failure.
  `flutter analyze` + full suite. On-device E2E is founder-side (needs real OAuth config)
  — marked MANUAL.
- **Migration requirements / ops runbook.** `docs/runbooks/GOOGLE_SIGN_IN_SETUP.md` —
  EVERY step to make it operational: Google Cloud project + OAuth consent screen
  (external, scopes, branding); Android OAuth client (package `app.pawdoc` + **SHA-1 of
  the upload key AND the Play App Signing key** — commands + where to find each);
  Web OAuth client (the `serverClientId` used by the app and the client ID + secret pasted
  into Supabase Auth → Google provider); Supabase dashboard config (authorized client IDs);
  `--dart-define=GOOGLE_WEB_CLIENT_ID=…` in the build command + Doppler; Play Console
  release implications; Firebase explicitly **not required** (documented why); test matrix.
- **Risks.** Misconfigured SHA/client IDs (mitigated: runbook with verification commands);
  `google_sign_in` v7 API differences from older guides (pinned version, implementation
  against current docs).
- **Dependencies.** None in-repo; operational steps are founder-gated.
- **Estimated effort.** 1 day (+ runbook).

---

### PHASE 8 — Premium Welcome Experience

**Objective.** A rewarding, elegant premium success moment after subscription — replacing
the current generic `showCelebration` toast on purchase.

- **Architecture changes.** New `mobile/lib/src/monetization/premium_welcome.dart`
  (self-contained modal route + controller-free API `showPremiumWelcome(context, {...})`).
- **UI work.** Full-screen frosted modal in the premium visual language: navy/mint
  gradient, animated paw-and-sparkle entrance (flutter_animate staged reveal; static
  layout under reduce-motion), "Welcome to PawDoc Premium" thank-you, unlocked-benefits
  list (unlimited photo checks, unlimited assistant conversations, unlimited memories —
  copy kept overclaim-free and consistent with `paywall_screen` claims), premium badge
  motif, single "Continue" `PawPrimaryButton`. Triggered from both purchase success
  (`paywall_screen.dart` `_purchase` success block) and restore success; fires once per
  transition (guard in `shared_preferences`).
- **Backend / DB / API / AI work.** None.
- **Assets.** None binary — the badge/sparkle art is painted (consistent with the
  no-placeholder rule and keeps the bundle lean).
- **Testing strategy.** Widget: modal renders all benefit rows + continue dismisses;
  reduce-motion path renders statically; shown on entitlement-active purchase result and
  not on cancelled purchase (provider/purchase-result injection); once-only guard unit test.
- **Migration requirements.** None.
- **Risks.** Copy overclaim (checked against `verify-no-placeholders.sh` + existing legal
  copy constraints); double-trigger via webhook + SDK (mitigated by the once-guard).
- **Dependencies.** Benefits copy references Phases 2 & 4 features → runs last.
- **Estimated effort.** 1 day.

---

## 3. Sequencing & dependency graph

```
P1 Brand ──────────────────────────────┐
P2 Memories (F1 media, F2 picker) ──┬──┼── P4 Assistant (uses F1/F2)
P3 Encyclopedia ────────────────────┤  │
P5 Walks (F3 location) ─────────────┼──┴── P6 Community (uses F3)
P7 Google Sign-In ──────────────────┤
P8 Premium Welcome (copy refs P2+P4) ┴── runs last
```

Execution order = mission order 1→8 (dependencies all point forward). Each phase is one
commit; CI (`CI` workflow: AI service ruff+pytest · ShellCheck · gitleaks · RLS full-migration
Docker suite · Edge node tests · no-placeholders guard · Flutter analyze+test+APK+AAB) must
be green after every push before the next phase begins.

## 4. Program risk register (top-level)

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Safety dilution via free-form AI chat | **Critical** | Triple emergency keyword layer (client router → edge check → ai-service `safety.py`), no-diagnosis system contract, assistant disclaimer, hand-off to triage flow; adversarial tests |
| New tables leak across users | **Critical** | Per-op RLS everywhere + adversarial `rls_isolation.sql` additions + full-migration CI job |
| AI cost blowout (assistant) | High | Server-enforced free daily cap, premium-only unlimited, max_tokens cap, one model call per message |
| Location privacy erosion | High | Foreground-only, on-device use; only 5-char geohash ever stored (community, opt-in); Play Data Safety checklist |
| Community abuse | High | Opt-in, coarse location, request gating, block/report, moderation runbook, text-only v1 |
| Icon rejected/ugly under launcher masks | Medium | Safe-zone composition + masked-preview verification before commit |
| Public API (met.no/Overpass) flakiness | Medium | On-device caching, graceful degraded cards, attribution + UA compliance |
| Image licensing challenge | Medium | Commons allow-listed licenses only, in-app credits + manifest |
| Bundle size growth | Low | WebP recompression (~2 MB total), AAB splits |
| CI regression mid-program | Medium | Full local suite before every push; fix-forward before next phase |

## 5. Founder-gated items this program will surface (not block on)

Deploy `sign-media-url`/`delete-media`/`assistant-chat` Edge Functions + `db push`
migrations to the hosted project · ai-service deploy (auto on merge via `deploy.yml`) ·
Google OAuth console setup per runbook · Play Data Safety update (location) + UGC
declaration · store listing refresh with the new icon. All enumerated with exact commands
in `PAWDOC_NEXT_EVOLUTION_REPORT.md` at the end.

## 6. Estimated total effort

~17.5 engineer-days compressed into this autonomous program; phases sized above.
Two reports only, per the mission: this roadmap + the final
`PAWDOC_NEXT_EVOLUTION_REPORT.md`.
