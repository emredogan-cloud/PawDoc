# 04 — Doppler secrets backbone

**What Doppler is:** one place that stores all your API keys/secrets, separated per environment (`dev`, `prod`). Your apps and CI read from Doppler at runtime instead of from committed `.env` files — so secrets never touch git.

**Cost:** free tier is plenty for now.

## 1. Install (already installed in this environment)

```bash
doppler --version   # expect v3.x
```
If missing: <https://docs.doppler.com/docs/install-cli> (`brew install dopplerhq/cli/doppler`, or the Linux script).

## 2. Authenticate (interactive — you must run this)

```bash
doppler login
```
This opens a browser to authorize the CLI. If you don't have a Doppler account yet, sign up at <https://dashboard.doppler.com> first.

## 3. Create the project, configs, and secret slots

```bash
./scripts/doppler-bootstrap.sh
```
This creates:
- project **`pawdoc`**
- configs **`dev`** and **`prd`** (Doppler's name for production)
- every Phase 0.1 secret slot, filled with a **placeholder** (e.g. `SET_IN_PHASE_0.2`).

The script is **idempotent and non-destructive** — it never overwrites a slot that already holds a value, so it's safe to re-run after you start adding real keys.

## 4. Fill real values as services come online (Phase 0.2 / 0.3)

```bash
doppler secrets set SUPABASE_URL="https://xxxx.supabase.co" --project pawdoc --config dev
```
Which key comes from where is documented in [`/ENVIRONMENT_VARS.md`](../../ENVIRONMENT_VARS.md). Set **dev** and **prod** separately — they point at different Supabase projects and R2 buckets.

## 5. How the apps read secrets

```bash
# inject secrets as env vars for any command
doppler run --project pawdoc --config dev -- <command>
```
For CI and Fly.io (Phase 0.3/0.4), generate a **read-only service token** (Doppler → project → config → **Access → Service Tokens**) and store it as `DOPPLER_TOKEN` in that platform's secret store. Then those platforms pull secrets non-interactively.

## Rules

- ❌ Never commit a real value to git. Placeholders only in committed files.
- 🔒 `*_SERVICE_ROLE_KEY`, `*_SECRET_*`, and all API keys are **server-only** — they must never be bundled into the Flutter or web client.
- Enable 2FA on your Doppler account.

## Verify

```bash
doppler secrets --project pawdoc --config dev    # lists keys (placeholders OK)
./scripts/verify-phase-0.1.sh
```
