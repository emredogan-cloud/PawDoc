# 17 — Push, account deletion, accessibility & dark mode

## OneSignal push

1. Create an app at <https://onesignal.com>; copy the **App ID**.
2. Configure platform credentials in OneSignal: **APNs** key (iOS, from the Apple
   Developer account) and **FCM**/Firebase (Android).
3. Build with the App ID:
   ```bash
   flutter run --dart-define=ONESIGNAL_APP_ID=<app-id>  (+ the Supabase/PostHog defines)
   ```
4. **Test:** complete onboarding to **Screen 4 → "Enable alerts"** → the OS push
   prompt appears. Grant it, then confirm the player id synced:
   ```sql
   select id, one_signal_player_id from public.users where id = '<your uid>';
   ```
   Send a test notification from the OneSignal dashboard to verify delivery.

## Account deletion (CR #9)

1. Deploy: `supabase functions deploy delete-account --project-ref <ref>`.
2. **Test in-app:** Home → overflow menu (⋮) → **Delete account** → type `DELETE`
   → **Delete my account**.
3. Confirm removal:
   - Supabase **Authentication → Users**: the user is gone.
   - `select count(*) from public.users where id='<uid>';` → 0 (and pets/analyses
     for that user are gone — FK `ON DELETE CASCADE`).
   - The app returns to the sign-in screen.
4. **Local logic test (no device):** `./scripts/test-rls.sh` runs
   `supabase/tests/account_deletion.sql`, which deletes the auth user and asserts
   the cascade removed all their rows while another user's data is untouched.

## Image moderation (CR #8)

Submit a non-pet / explicit image → expect **"We couldn't process this image."** and
the uploaded object **removed from R2** (the analyze Edge Function calls `deleteR2Object`).
The moderation gate runs in the AI service *before* the Tier 2/3 analysis; verify the
unit gate with `cd ai-service && .venv/bin/python -m pytest -q -k cr8`.

## Accessibility (a gate)

- iOS: Settings → Accessibility → **VoiceOver** on; Android: **TalkBack** on. Navigate
  every screen — each interactive control announces a label (buttons/fields have Semantics).
- Increase system **text size** (Dynamic Type) — content scales without clipping.
- Contrast: the Material 3 `ColorScheme.fromSeed(teal)` meets WCAG AA for text on surfaces.

## Dark mode

Toggle the system appearance to Dark — every screen follows it (`ThemeMode.system`,
`AppTheme.dark()`), with the warm-red EMERGENCY screen still legible.
