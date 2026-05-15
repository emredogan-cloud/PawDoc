# analyze

POST /functions/v1/analyze — submit a pet health analysis request.

## Phase 1A status

**Scaffold only.** The endpoint validates authentication, body, and pet ownership, then returns
`501 not_implemented`. Phase 1B wires the ai-service call + free-tier consume + persistence.

## Contract

Request:

```http
POST /functions/v1/analyze HTTP/1.1
Authorization: Bearer <user_jwt>
Content-Type: application/json

{
  "pet_id": "uuid",
  "input_type": "photo" | "video" | "text",
  "input_storage_key": "string",     // required for photo|video
  "text_description": "string"       // required for text
}
```

Responses:

| Status | Body                            | When                                       |
| ------ | ------------------------------- | ------------------------------------------ |
| 200    | `{ triage_level, ... }`         | (Phase 1B only)                            |
| 401    | `{ error: "unauthorized" }`     | Missing / bad JWT                          |
| 404    | `{ error: "not_found" }`        | Pet doesn't exist OR isn't owned by caller |
| 422    | `{ error: "validation_error" }` | Body shape wrong                           |
| 501    | `{ error: "not_implemented" }`  | Phase 1A response                          |

## Notes

- Ownership is verified by selecting the pet under the **user's** JWT (RLS applies). A cross-user
  `pet_id` returns 404, not 403 — we don't want to leak that the id exists.
- `text_description` (Phase 1B) is forwarded to the ai-service for Tier-3 reasoning.
- `input_storage_key` is the Cloudflare R2 key the mobile app got back from its presigned upload.

## Local invocation

```bash
supabase functions serve analyze --no-verify-jwt
# In another terminal:
curl -X POST http://127.0.0.1:54321/functions/v1/analyze \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"pet_id":"...","input_type":"text","text_description":"limping"}'
```
