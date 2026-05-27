# 08 — Fly.io AI service (always-warm `/health`)

Deploys the `ai-service/` FastAPI placeholder to Fly.io with **one always-on machine** (no cold starts). Code, Dockerfile, and `fly.toml` are already written and locally verified — this is just the account + deploy.

**Cost:** Fly has a small pay-as-you-go free allowance; one `shared-cpu-1x` 512MB machine is cheap.

## 1. Account + CLI

`flyctl` is installed. Authenticate (interactive — run it yourself):
```bash
fly auth login
```
(Or, for CI later: `fly tokens create deploy` → store as `FLY_API_TOKEN` in Doppler.)

## 2. First deploy

```bash
cd ai-service
# Create the app but keep THIS fly.toml (don't let launch overwrite it):
fly launch --no-deploy --copy-config --name pawdoc-ai --region iad
fly deploy
```
- If `pawdoc-ai` is taken, pick another name and update `app =` in `fly.toml`.
- Set `--region` near your prod Supabase region (0.2).

## 3. Verify (the DoD)

```bash
curl https://pawdoc-ai.fly.dev/health
# {"status":"ok","service":"pawdoc-ai","version":"0.3.0"}

fly status          # MUST show exactly ONE machine, started, not auto-stopped
```
Then run the harness with the live URL:
```bash
FLY_APP_URL=https://pawdoc-ai.fly.dev ./scripts/verify-phase-0.3.sh
```
The `/health` response should be instant (machine already warm) — that is the whole point of this phase.

## 4. Confirm always-warm

`fly.toml` pins `min_machines_running = 1` and `auto_stop_machines = "off"`. Double-check after deploy:
```bash
fly scale show     # count 1, not 0
```

## Notes / boundaries

- **No secrets needed yet** — the placeholder reaches no external service. Supabase/R2/AI keys are wired in Phase 1.3 (via Doppler → `fly secrets` or the Doppler-Fly integration).
- **Single machine is intentional now.** Redundancy/autoscaling (so the AI service isn't a single point of failure) is Phase 7 — flagged as Critical Review #5; revisit before any viral push.
- Rollback = `fly releases` then `fly deploy --image <previous>` (or revert the PR and redeploy via CI from 0.4).
