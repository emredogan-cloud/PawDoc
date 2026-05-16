# Event Catalog

Canonical structured-log event names used across the PawDoc stack. Phase
4 PostHog A/B testing will use this list as the canonical names for
funnel + retention analytics; Phase 2 may add `category` + `expected
metadata` columns.

Conventions:
- snake_case, lowercase
- past-tense verbs for completed actions (`analyze_completed`)
- imperative for transient signals (`emergency_keyword_match`)
- prefixes (`auth_`, `analyze_`, `purchase_`, `paywall_`) cluster by feature

| Event | Surface | Meaning |
|-------|---------|---------|
| `service_starting` | ai-service / main.py | Process boot |
| `service_shutdown` | ai-service / main.py | Lifespan teardown |
| `sentry_initialized` | ai-service + mobile | SDK active |
| `sentry_disabled` | ai-service | DSN missing → no-op |
| `analyze_request_received` | edge function | New analyze POST |
| `analyze_completed` | ai-service router | Analysis finished |
| `analyze_received` | ai-service router | Body validated, orchestrator about to run |
| `emergency_keyword_match` | edge function | Override triggered (advisory) |
| `emergency_override_triggered` | ai-service orchestrator | Canonical override fired |
| `tier_2_response` | ai-service | Gemini Flash returned |
| `tier_3_response` | ai-service | Claude Sonnet returned |
| `tier2_failed_escalating_to_tier3` | ai-service orchestrator | Gemini failed |
| `tier3_failed_graceful` | ai-service orchestrator | Both providers failed |
| `cross_verify_disagreement` | ai-service orchestrator | Two Sonnet calls disagreed |
| `parser_validation_failed` | ai-service | Model output didn't validate |
| `graceful_degradation` | ai-service | Returning fallback MONITOR |
| `rate_limit_check` | edge function | Daily limit evaluated |
| `rate_limit_upstash_error` | edge function | Upstash unreachable (fail-open) |
| `free_tier_consume` | edge function | Quota decremented |
| `ai_service_call_start` | edge function | Forwarding to ai-service |
| `ai_service_call_end` | edge function | Response received |
| `ai_service_transport_error` | edge function | Transient transport failure (will retry once) |
| `ai_service_timeout` | edge function | 30s ceiling hit |
| `ai_service_unreachable_after_retry` | edge function | Final failure → 502 |
| `analysis_persisted` | edge function | Row inserted into analyses |
| `revenuecat_event_received` | revenuecat-webhook | Inbound webhook event |
| `revenuecat_state_applied` | revenuecat-webhook | DB updated |
| `revenuecat_event_acknowledged` | revenuecat-webhook | Event ack'd but no DB change |
| `revenuecat_no_matching_user` | revenuecat-webhook | app_user_id not found |
| `revenuecat_db_update_failed` | revenuecat-webhook | DB error during state apply |
| `user_provisioned` | auth-webhook | Row inserted into public.users |
| `user_delete_observed` | auth-webhook | auth.users delete (DB cascade handles) |
| `auth_token_rejected` | _shared/auth.ts | JWT didn't validate |
| `webhook_secret_mismatch` | _shared/auth.ts | Wrong bearer token |
| `webhook_secret_unconfigured` | _shared/auth.ts | Env var missing |
| `purchase_flow_started` | mobile (Phase 1D+ — pending) | User tapped Continue on paywall |
| `purchase_completed` | mobile | Store API confirmed |
| `purchase_restored` | mobile | restorePurchases returned an entitlement |
| `paywall_shown` | mobile (Phase 1D+ — pending) | Paywall route entered |
| `paywall_dismissed` | mobile (Phase 1D+ — pending) | User backed out |
| `onesignal_initialized` | mobile | SDK active |
| `onesignal_player_id_persisted` | mobile | player_id stored on users row |
| `revenuecat_initialized` | mobile | SDK active |
| `revenuecat_identified` | mobile | Purchases.logIn(userId) returned |
| `apple_sign_in_success` | mobile | Supabase signInWithIdToken succeeded |
| `apple_auth_exception` | mobile | SignInWithApple plugin error |
| `image_pick_failed` | mobile | image_picker threw |
| `image_ready_*` | mobile | Compression complete (size suffixed) |
| `upload_start` | mobile | Begin storage upload |
| `upload_complete` | mobile | Storage upload returned key |
| `analyze_done` | mobile | AnalysisResult parsed |
| `analyze_failed` | mobile | Typed failure (kind in payload) |
| `resume_after_idle_*Nm*` | mobile | App resumed from background (suffix = idle minutes) |

Phase 4 PostHog mapping convention: copy event names verbatim, add a
`pawdoc_` prefix when ingesting (e.g., `pawdoc_analyze_completed`).
