# PawDoc mobile — smoke checklist

Manual end-to-end run after a clean clone. Documented so a new contributor
can validate Phase 1C in ~15 minutes.

## Prerequisites

- Docker running
- Flutter 3.41+
- An iOS simulator (macOS) or Android emulator/device
- `supabase` CLI, `uv` (for the AI service)

## Start the backend

```bash
# Terminal 1
supabase start
supabase db reset --local

# Terminal 2 — AI service (the AI keys can be empty for graceful-degradation testing)
cd ai-service
cp .env.example .env   # set INTERNAL_API_TOKEN if you want real calls
INTERNAL_API_TOKEN=local-secret APP_ENV=local uv run uvicorn app.main:app --port 8080
```

## Configure the mobile env

```bash
cp env/dev.json.example env/dev.json
# Edit:
#   SUPABASE_URL=http://127.0.0.1:54321
#   SUPABASE_ANON_KEY=<copied from `supabase status`>
#   AI_SERVICE_URL=http://10.0.2.2:8080      (Android emulator)
#   AI_SERVICE_URL=http://127.0.0.1:8080     (iOS simulator)
```

## Run the app

```bash
flutter run --dart-define-from-file=env/dev.json
```

## Test path

1. **Splash → /auth.** Cold start with no session should show the splash
   logo briefly then push to the auth screen.
2. **Sign in.** Enter `test@example.test`, tap **Send code**. Open the
   Inbucket dashboard at http://127.0.0.1:54324 and copy the 6-digit OTP.
3. **Verify.** Paste the OTP. The app navigates through splash, then the
   onboarding welcome screen.
4. **Onboard.** Tap **Add your first pet** → fill in name "Luna",
   species **Dog**, pick a birth date. Save.
5. **Home.** You should see Luna's card with **Check Luna** as the
   primary CTA.
6. **Background + restore.** Background the app on the onboarding form,
   come back — the draft should still be there.
7. **Analyze (text-only emergency).** Tap **Check Luna**, type
   `"She just had a seizure"`, tap **Analyze**. Expect a red EMERGENCY
   result with the keyword-override callout. The **I understand** button
   acknowledges before dismissing.
8. **Analyze (graceful degradation).** Tap **Check Luna** again, type
   `"She seems sleepy today"`, tap **Analyze**. Expect a yellow MONITOR
   result with the "Limited analysis" callout (because the local
   ai-service has no real provider keys).
9. **Sign out.** Settings → Sign out. App pushes back to /auth.

## Failure-mode spot checks

- **Wrong OTP code.** Triggers an inline error; the auth state stays on
  the verify screen.
- **No internet.** Turn off the simulator's wifi between steps 6 and 7;
  the analyze submit should surface a friendly "no internet" message.
- **Quota exhausted.** Repeat step 7 four times (free-tier cap is 3).
  The fourth attempt should show the paywall stub (Phase 2 wires real
  RevenueCat).
