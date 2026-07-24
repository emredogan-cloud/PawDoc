# Paw Community — Moderation Runbook (founder ops)

Next Evolution Phase 6 shipped an opt-in social layer. v1 moderation =
**structural prevention** (opt-in, coarse location only, request gating,
block-goes-silent at the database) + **report & block** in-app + **this
founder review loop**. There is no auto-moderation in v1 — do not promise any.

## What users can do themselves
- **Block** (chat → shield icon → Block): the connection flips to `blocked`;
  the RLS insert policy then rejects every new message server-side.
- **Report** (chat → shield icon → Report): writes a `community_reports` row
  (reason ∈ spam / harassment / inappropriate / other, optional details).
- **Leave** (community → leave): deletes their profile; connections, messages,
  and proposals cascade away in one statement.

## Founder review loop (run at least weekly at beta scale)
Reports are service-role-only (users see only their own). In the Supabase SQL
editor:

```sql
-- Open reports, newest first
select r.created_at, r.reason, r.details,
       r.reporter_id, r.reported_user_id, r.connection_id
from community_reports r
order by r.created_at desc
limit 50;

-- Context: the reported member's profile + recent messages on the reported
-- connection (only if a connection_id is present)
select * from community_profiles where user_id = '<reported_user_id>';
select created_at, sender_id, content
from community_messages
where connection_id = '<connection_id>'
order by created_at desc limit 30;
```

## Actions (proportionate ladder)
1. **No action** — note the report; most first reports are misunderstandings.
2. **Removal from discovery** — `update community_profiles set
   is_discoverable = false, allow_requests = false where user_id = '…';`
   (they keep existing accepted chats; nobody new can reach them).
3. **Ejection** — `delete from community_profiles where user_id = '…';`
   dissolves their community graph (profile FK cascade). Their PawDoc account
   and pet data are untouched — community ejection is not account deletion.
4. **Account-level action** (illegal content / repeated abuse): use the
   standard account tools; preserve evidence (copy the rows) before deleting.

Record every action taken as a comment on the report row era (keep a simple
log; a `handled_at` column can be added when volume justifies it).

## Play Console (UGC policy)
The app declares user-generated content. Keep these true:
- in-app report + block exist (shipped v1);
- this review loop actually runs;
- the community guidelines line is shown at opt-in ("Be kind. No spam, no
  harassment — you can report or block anyone, and reports are reviewed.").
