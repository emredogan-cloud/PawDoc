# 13 — Auth webhook (create the profile row on signup)

> **SUPERSEDED (GAP-D3 / BE-03):** the webhook was removed from the repo on 2026-07-17. User provisioning runs as an in-transaction DB trigger (`supabase/migrations/*auth_user_profile_trigger.sql`). Do not redeploy this function; `verify-phase-1.1.sh` now fails if the directory reappears.

The `/auth-webhook` Edge Function creates the `public.users` row when someone
signs up. It verifies a signature before doing anything (CR #21), so only your
Supabase project can trigger it.

## 1. Deploy the function

```bash
supabase functions deploy auth-webhook --project-ref <ref>
```
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically. Set the
hook secret:
```bash
supabase secrets set SUPABASE_AUTH_WEBHOOK_SECRET="v1,whsec_..." --project-ref <ref>
```

## 2. Register the Auth Hook

Supabase dashboard → **Authentication → Hooks** → add a hook on the signup event
pointing at the deployed function URL:
`https://<ref>.supabase.co/functions/v1/auth-webhook`.
Use the **same** signing secret you stored above (the dashboard generates one in
the `v1,whsec_...` format — copy it into `SUPABASE_AUTH_WEBHOOK_SECRET`).

## 3. Verify (Phase 1.1 DoD)

1. Sign up a brand-new email (and separately, an Apple account) in the app.
2. Confirm a matching row appears in `public.users` with the same `id` as the
   `auth.users` row:
   ```sql
   select u.id, u.email from public.users u
   join auth.users a on a.id = u.id order by u.created_at desc limit 5;
   ```
3. Tamper test: POST to the function URL with a bad/no signature → expect **401**.

## Notes

- The row `id` equals the `auth.users.id` (the schema FKs `public.users.id` to
  `auth.users(id)`), which is what makes the RLS policies (`auth.uid() = user_id`)
  work. Do not change that linkage.
- **Surfaced (not auto-added):** a Postgres `on auth.users` trigger
  (`handle_new_user`) is a more robust, unforgeable alternative that needs no
  network hop. The roadmap specifies this Edge Function, so it ships; consider
  the trigger as a belt-and-braces follow-up if webhook delivery ever flakes.
