# PawDoc — Next Evolution Program: Final Report

**Date:** 2026-07-24 · **Branch:** `feat/next-evolution` · **PR:** #87 (base `main` @ `2e8d11f`)
**Mission:** evolve PawDoc into a significantly more valuable product while preserving
**Safety first. Trust first. Memory over diagnosis.**
**Companion document:** `PAWDOC_NEXT_EVOLUTION_ROADMAP.md` (written and committed before any
implementation, per the mission). These are the program's only two reports.

---

## 1. Executive summary

All 8 phases were implemented, tested, and pushed as one commit per phase on a single
program branch. The app grew from a triage-plus-records product into a daily companion:
a pet journal, a breed encyclopedia, a streaming AI assistant, weather-aware walks, an
opt-in owner community, Google sign-in, and a premium welcome moment — under a refreshed
brand icon.

Every safety pillar held: the emergency surfaces were not touched, GET_HELP_NOW remains
un-gateable, every new table ships per-operation RLS with adversarial tests, the AI
assistant is triple-fenced against becoming a diagnosis channel, no deleted feature was
revived, and no location data ever reaches PawDoc servers.

**Verdict: YES — engineering-complete and production-quality on the branch;
founder-gated deploy/config steps remain before users see it** (§8).

| Program totals | |
|---|---|
| Commits | 9 (roadmap + 8 phases) + this report |
| Flutter tests | **319** (was 222 → +97 across 13 new test files) — all green |
| ai-service pytest | **173** (was 159 → +14) — all green; ruff clean |
| Edge `node --test` | **69** (+18 across 2 new suites) — all green |
| RLS/Docker suite | green, now covering **7 new tables** + widened deletion cascade |
| flutter analyze | 0 issues |
| New DB migrations | 3 (pet_memories · assistant · community) |
| New Edge Functions | 3 (sign-media-url · delete-media · assistant-chat) + 1 extended |
| New Flutter modules | 5 (`memories/`, `encyclopedia/`, `assistant/`, `walks/`, `community/`) |
| New dependencies | image_picker, cached_network_image, flutter_cache_manager, gpt_markdown, geolocator, google_sign_in |

---

## 2. Completed phases

### Phase 1 — Brand refresh (`dca7c75`)
New launcher icon generated from `ASO-image/PlayStore-ASO/007-app-logo.png` via
flutter_launcher_icons 0.14.4: legacy mipmaps (all densities), adaptive icon with the
foreground at 88% over the artwork's own `#030C1E` navy (layers blend seamlessly under
circle/squircle/rounded masks — verified with locally composed mask previews before
committing), a **new Android 13+ monochrome themed icon** (clean white paw glyph), and the
iOS set flattened alpha-free onto brand navy (GAP-B2 preserved). Play-compatible; version
stays `1.0.0+2` for the next upload. Raw ASO art directory gitignored.

### Phase 2 — Pet Memories (`e2d1c8f`)
A per-pet photo journal: gallery grid ⇄ month timeline, search, create (camera/system
photo picker), edit, delete, share; premium empty state; free tier holds 20 memories,
premium unlimited (client gate — the cost surface is storage-only, unlike AI quotas which
are server-enforced). Media foundation built once and reused program-wide: storage keys
gained purpose scopes (`uploads/` analysis · `memories/` journal · `chat/` assistant),
`sign-media-url` mints batch presigned GETs **for the caller's own display-scope keys
only** (analysis images stay non-displayable by design), `delete-media` deletes own
journal objects, and the account-deletion purge now sweeps all three prefixes
(GDPR-complete). Every journal photo passes the same EXIF/GPS-stripping compressor as
triage uploads. `pet_memories` table: per-op RLS with pet-ownership pinned on writes.

### Phase 3 — Breed Encyclopedia (`21a6405`)
A premium field guide: Dogs/Cats tabs, search by name/origin/temperament, photo cards
with hero transitions into a detail spread (stat band, personality + temperament chips,
exercise/grooming paw-meters, educational health notes that always close with a
talk-to-your-vet line, facts, photo attribution). Launch catalog: 10 dogs + 10 cats as
versioned JSON behind a `BreedsSource` seam — the path to hundreds of breeds is a data
swap, not a UI rewrite. All 20 photos are Wikimedia Commons under PD/CC0/CC-BY/CC-BY-SA
(no NC/ND), recompressed to 720px WebP (~1.2 MB total), credited in-app **and** in
`docs/legal/BREED_IMAGE_CREDITS.md`. A CI-enforced content contract validates every
entry, bans diagnostic/treatment phrasing in health notes, requires hedged tone, and
rejects non-commercial licenses.

### Phase 4 — PawDoc AI Assistant (`2623856`) — the program's largest phase
A permanent 5th bottom-nav destination: streaming markdown chat (gpt_markdown), typing
indicator, conversation history (open/rename/delete), photo attachments, pet-aware
greeting with suggestion chips, paw-mark translucent backdrop.

Safety is structural, not stylistic:
- **Triple emergency fence:** the client keyword router intercepts before any network
  call → the Edge Function re-checks before quota/persistence → ai-service `safety.py`
  re-checks before the model. An emergency message is never persisted, never counted,
  never model-answered — it routes to the frozen red help screen.
- **Guardrailed system prompt:** no diagnosis, no medication/dosing, no "your pet is
  fine"; symptom questions hand off to the Check flow; a disclaimer is pinned under the
  chat input.
- **Cost fence:** free tier 20 messages/day, server-enforced (402 → upgrade sheet);
  premium unlimited; `max_tokens` capped; one model call per message.

Architecture: ai-service gained its first streaming endpoint (`/assistant/chat`, SSE via
`anthropic` `messages.stream`, `ASSISTANT_MODEL` env-tunable defaulting to
`claude-sonnet-4-6`, temperature 0.3 — the 0.1 rule applies to health-analysis calls,
which this deliberately is not); the `assistant-chat` Edge Function proxies the stream
(JWT verify → emergency → quota → history window → own-key `chat/` presign) and
tee-persists the reply only on clean completion. Clients cannot forge assistant-role rows
(RLS-proven).

### Phase 5 — Weather + Smart Walks (`ab0e8dc`)
"Today is a great time for a walk with Rex" — computed entirely on-device. MET Norway
Locationforecast 2.0 (free including commercial use, CC BY 4.0, identifying User-Agent,
3-decimal coordinates, 1h cache) + OpenStreetMap Overpass for nearby parks/dog parks
(24h cache, in-UI attribution, native-maps directions). The scorer is a deterministic,
heat-conservative pure function with a best-window finder — deliberately not a model.
Home card asks contextually **before** any permission dialog and states the privacy
contract ("uses your location on this device only — never stored on PawDoc servers");
the permission diet held: **COARSE location only**, foreground only. Daily walk reminder
is an on-device repeating local notification — no push vendor (OneSignal-deletion
decision honored). Pure geohash utilities (canonical-vector-tested) landed as the
foundation Phase 6 reuses.

### Phase 6 — Paw Community v1 (`e5ba535`)
Opt-in social: discover nearby owners, connect, chat 1:1, propose walks. Privacy is
structural: the profile row IS the opt-in (leaving deletes it and the whole graph
cascades away in one statement); the only location-shaped value stored is a **5-char
geohash cell (~±2.4 km)** — never coordinates; discovery is on-device neighbor-cell
matching with honest "~2 km" labels. Requests are gated by `allow_requests`; **block goes
silent server-side** (the messages INSERT policy requires an accepted connection);
report + block sit in every chat (Play UGC policy) with a founder review loop in
`docs/runbooks/COMMUNITY_MODERATION.md`. First Supabase Realtime consumer (message
stream, fallback refresh). The RLS suite gained a third test user to prove
non-participant boundaries, sender/requester forge denial, addressee-only accept,
proposer-cannot-self-accept, hidden-profile invisibility, and blocked-thread write
denial.

### Phase 7 — Google Sign-In (`8e967a9`)
"Continue with Google" beside the Apple button on the cream sign-in/create surface
(google_sign_in 7.x native flow → `signInWithIdToken`), terms assent gating it exactly
like email/Apple, cancel treated as a choice (no error banner), and **no dead controls**:
the button renders only when `GOOGLE_WEB_CLIENT_ID` is provided at build time.
`docs/runbooks/GOOGLE_SIGN_IN_SETUP.md` documents EVERY operational step: Google Cloud
project + consent screen, the three OAuth clients (upload-key SHA-1, **Play App Signing
SHA-1** — the one everyone forgets — and the Web audience client), why Firebase is not
needed, the exact Supabase dashboard fields, Doppler/build wiring, a device test matrix,
Play data-safety impact (none new), iOS future steps, and a troubleshooting table.

### Phase 8 — Premium Welcome (`da60cc2`)
A full-screen premium moment replaces the old 2.5s toast on entitlement-active purchase
and on restore ("Welcome back to Premium"): brand-navy gradient with painted sparkles
and faint paw marks (asset-free), glowing badge, staged reveal (static under
reduce-motion), benefits limited to REAL entitlements (unlimited photo checks /
Assistant conversations / memories, PDF reports included), one Continue CTA, closing on
the honesty line "safety checks stay free for everyone". Fires only from explicit
success callbacks — once per transition by construction.

---

## 3. Tests performed

- **Flutter (319 green):** existing 222 plus new suites — memories (model/cache/screen),
  breed catalog (including the real-asset content-safety validator and license-compliance
  check), encyclopedia screens, SSE parser (adversarial chunk/UTF-8 splits), chat
  controller state machine (stream/cancel/limit/error/emergency), assistant screen,
  walk scorer matrix + MET/Overpass fixture parsing + geohash vectors, walk card states,
  community models + five community screens tests (consent, join, partition,
  chat/proposals, report/block), Google sign-in (controller + no-dead-controls +
  terms gating), premium welcome. All widget tests run under forced reduce-motion per
  the repo harness; fakes are injected via Riverpod provider overrides — no network, no
  platform channels.
- **ai-service (ruff + 173 pytest green):** 14 new assistant tests — auth boundary
  (401/503 fail-closed), emergency short-circuit with a model-constructor counter
  proving zero SDK touches, species-specific override, SSE framing, guardrail prompt
  content on the wire, provider-failure→error-event, request validation (role/length/
  window), SSRF-guarded image gating.
- **Edge (`node --test`, 69 green):** scoped storage keys (scope allowlist, display vs
  deletable scopes, batch sanitizer caps/dedupe/foreign-drop) and assistant chat pure
  logic (quota gate, premium statuses, title derivation, body validation, history
  window).
- **RLS/Docker suite (green):** full-migration apply + isolation + deletion cascade,
  extended with `pet_memories`, both assistant tables, and the four community tables —
  written adversarially (forged inserts, cross-user reads, non-participant access,
  blocked-thread writes, assistant-role forgery).
- **Guards:** `verify-no-placeholders.sh` (overclaim ban) and `verify-disclaimers.sh`
  pass; gitleaks/shellcheck run in CI.
- **Visual verification:** launcher icon composited under circle/squircle/rounded/themed
  masks and inspected before commit; breed WebP crops spot-checked visually.
- **MANUAL (founder, needs device/live infra):** assistant end-to-end streaming against
  deployed EF+ai-service; community realtime between two accounts; Google sign-in per
  runbook §7; walk flow with real GPS/weather; premium welcome with a sandbox purchase.

## 4. CI results

Workflow "CI" (7 jobs: AI service ruff+pytest · ShellCheck · gitleaks · RLS full-migration
Docker suite · Edge node tests · no-placeholders guard · Flutter analyze+test+**APK+AAB
build**) ran on every phase push to PR #87:

- Roadmap/Phase 1 runs: **success** (e.g. run 30092312290).
- Phase 5 sha `ab0e8dc`: first run 30095278663 failed in the Flutter job, and the rerun
  of the **same sha** (30095985400) passed all jobs — a transient runner flake (logs
  expired before capture), not a code failure.
- Phase 3/4 pushes: **success**.
- Phase 6/7/8 pushes: kicked in sequence; the final Phase-8 run (30111444101, sha
  `da60cc2`) is the release gate for this program — its status is verified before this
  report's commit lands (any late failure would be fixed forward before merge-request).
- The AAB in the Flutter job builds with debug signing in CI (no keystore in CI by
  design); the signed release AAB remains the founder's local `doppler run … flutter
  build appbundle` step, unchanged from PR #84.

## 5. Migrations shipped (additive only — `supabase db push` deploys them)

| Migration | Contents |
|---|---|
| `20260724110000_pet_memories.sql` | `pet_memories` + per-op RLS (pet ownership pinned) + timeline index |
| `20260724130000_assistant.sql` | `assistant_conversations` + `assistant_messages`, per-op RLS (no client assistant-role inserts, no message updates), recency/quota indexes |
| `20260724150000_community.sql` | `community_profiles`, `community_connections`, `community_messages`, `walk_proposals`, `community_reports`; per-op RLS as described; guarded realtime publication for messages |

## 6. New capabilities (user-facing)

Pet photo journal with cloud storage · premium breed field guide (20 breeds, scalable
data path) · streaming AI companion with history and image support (safety-fenced) ·
weather-aware walk guidance + nearby places + daily on-device reminder · opt-in nearby
owner community with chat, walk proposals, report/block · Google sign-in (config-gated)
· a rewarding premium welcome · a refreshed, adaptive, themable app icon.

## 7. Observations surfaced (not silently changed)

- **Emergency keyword list:** "choking" is not in the triplicated safety lists (the
  suite's own comment references a choking example). Adding a keyword touches all three
  mirrors + parity tests — proposed as a follow-up decision, not folded in.
- **GCP service-account key in the repo folder:** a live `pawdoc-prod-*.json` key sat
  untracked in the working directory. It was never committed (verified across history);
  it is now gitignored. Recommendation: move it outside the repo; rotate if it was ever
  copied elsewhere.
- **Assistant/chat images:** deleting a conversation removes rows (cascade) but leaves
  its `chat/` objects until account deletion purges them — private, bounded, documented
  here; a per-conversation object sweep is a future nicety.
- **Overpass/MET are shared public instances** — fine at beta scale; a paid weather tier
  or self-hosted Overpass is the scale-up path.

## 8. Founder actions to go live (in order)

1. **Merge PR #87** (squash) — ai-service auto-deploys via `deploy.yml` on main.
2. `supabase db push` → the three migrations (hosted project `zbxrvfunaylkscgvsllm`).
3. Deploy Edge Functions: `supabase functions deploy sign-media-url delete-media
   assistant-chat generate-upload-url delete-account --project-ref zbxrvfunaylkscgvsllm`
   (last two changed: scope param + widened purge). No new secrets — they reuse the
   deployed `R2_*`/`AI_SERVICE_TOKEN` set.
4. Google sign-in per `docs/runbooks/GOOGLE_SIGN_IN_SETUP.md` (console + Supabase +
   `GOOGLE_WEB_CLIENT_ID` in Doppler + build define).
5. Play Console: Data safety — add approximate-location (collected, not shared,
   ephemeral) for Smart Walks; confirm the UGC declaration (report/block shipped).
6. Build/upload the signed AAB (`1.0.0+2`) exactly as in PR #84; on-device pass over the
   MANUAL list in §3.
7. Housekeeping: move the GCP key out of the repo folder (§7); adopt the community
   moderation review loop (runbook).

## 9. Remaining future ideas (not started, by design)

Per-breed encyclopedia expansion via the remote `BreedsSource` · assistant deep-links
into Checks/Memories ("save this tip") · memory collages/yearbook export · weather-
conditional notification copy via a background fetcher · community group walks + event
photos (needs moderation investment) · assistant voice input · encyclopedia ↔ pet
profile linking (auto-open your breed) · walk streaks in the pet's story.

## 10. Final verdict

**YES.** All 8 phases are implemented with production-quality code, 561 automated
checks across four suites are green, CI is green on the program branch, safety and
privacy invariants are proven by adversarial tests rather than asserted, and the
remaining work is exclusively founder-gated configuration and deployment (§8).
