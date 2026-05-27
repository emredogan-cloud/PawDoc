# SUB-PR Report — Phase 0.3: AI Service Shell & Compute

**Status:** Service code + container + Fly config built and **verified running locally**; live deploy + RevenueCat account are founder-gated.
**Branch:** `phase-0.3-ai-service-shell` (stacked on `phase-0.2-data-storage`)
**Date:** 2026-05-27

---

## 1. What was implemented

Unlike 0.1/0.2, most of this phase is real, runnable code — and it was executed, not just asserted.

- **FastAPI placeholder** (`ai-service/app/main.py`) — `GET /health` only, returning `{status, service, version}`. No AI logic (that's 1.3).
- **Container** (`ai-service/Dockerfile`) — `python:3.12-slim`, deps layer-cached, runs uvicorn as a **non-root** `appuser`, port 8080. `.dockerignore` excludes tests/venv/secrets.
- **Fly config** (`ai-service/fly.toml`) — **`min_machines_running = 1` + `auto_stop_machines = "off"`** for zero cold starts (the phase's whole point), `/health` HTTP check, `shared-cpu-1x`/512MB.
- **Tests** (`ai-service/tests/test_health.py`) — health contract + a guard that **only** `/health` exists (no scope creep).
- **Deps** — `requirements.txt` (fastapi, uvicorn) + `requirements-dev.txt` (pytest, httpx).
- **Verification harness** `scripts/verify-phase-0.3.sh` and runbooks `08-fly-ai-service.md`, `09-revenuecat-project.md`.
- **ENVIRONMENT_VARS.md** — `FLY_API_TOKEN`, RevenueCat keys (secret + public SDK + webhook secret), canonical bundle id `app.pawdoc`.

## 2. Files changed

```
A  ai-service/app/__init__.py
A  ai-service/app/main.py
A  ai-service/tests/__init__.py
A  ai-service/tests/test_health.py
A  ai-service/requirements.txt
A  ai-service/requirements-dev.txt
A  ai-service/Dockerfile
A  ai-service/.dockerignore
A  ai-service/fly.toml
A  ai-service/README.md
A  scripts/verify-phase-0.3.sh
A  docs/runbooks/08-fly-ai-service.md
A  docs/runbooks/09-revenuecat-project.md
A  sub-pr-report/SUBPR_PHASE_0.3.md
M  ENVIRONMENT_VARS.md
```

## 3. Tests executed

| Test | Command | Purpose |
|------|---------|---------|
| Unit / contract | `pytest -q` (in venv) | /health 200 + body; "/health only" guard |
| Live HTTP | `uvicorn …` + `curl /health` | proves the server binds and serves over HTTP |
| Fly schema | `fly config validate` | fly.toml is deployable |
| Always-warm assertion | `python3 tomllib` on fly.toml | min_machines_running=1, auto_stop=off |
| Full checklist | `./scripts/verify-phase-0.3.sh` | aggregate |

## 4. Test results

- **`pytest`: 2 passed** (0.29s) — TestClient exercises the real ASGI app.
- **Live HTTP:** `curl http://127.0.0.1:8090/health` → `{"status":"ok","service":"pawdoc-ai","version":"0.3.0"}`, **HTTP 200**; uvicorn log confirms `Application startup complete` + `GET /health 200`.
- **`fly config validate`: "Configuration is valid".**
- **fly.toml assertions:** min_machines_running=1, auto_stop=off, /health check present.
- **`verify-phase-0.3.sh`: exit 0** — 5 local PASS, deployed `/health` SKIP (no live URL yet), 2 MANUAL.
- Found + fixed a bug **in the verifier** (not the code): the Dockerfile grep expected space-separated `uvicorn app.main:app`, but the CMD is a JSON array (`["uvicorn","app.main:app"]`). Corrected the pattern; re-ran green.

## 5. Security checks

- Container runs as **non-root** (`USER appuser`, uid 1000) — least privilege.
- **No secrets** in the image or repo; `.dockerignore` excludes `.env*`, tests, venv. Verified no key-shapes in the tree.
- `/health` is **dependency-free** — it reflects process liveness, never leaks downstream state or credentials.
- RevenueCat **webhook secret** slotted now so `/revenuecat-webhook` is signature-verified in 1.4 (Critical Review #21).

## 6. Known issues

- **Live deploy + RevenueCat creation are founder-gated** (Fly account / RevenueCat account). Code + runbooks ready; deployed `/health` check SKIPs until `FLY_APP_URL` exists.
- RevenueCat Apple in-app-purchase key linkage depends on Apple Developer approval (Phase 0.1, in review).

## 7. Risks

- **Cold-start risk** if `min_machines_running`/`auto_stop` were ever changed — mitigated and now **test-enforced** by the verify harness.
- **Single Fly machine = single point of failure** for all triage (Critical Review #5). Intentional for the placeholder; redundancy/autoscaling is Phase 7 — flagged to revisit before any viral push. Not silently added.
- Free-tier Fly machines can be aggressively reclaimed; `auto_stop = off` + always-warm mitigates.

## 8. Git branch

`phase-0.3-ai-service-shell` (stacked on `phase-0.2-data-storage`).

## 9. Commit hash

Implementation commit: `__IMPL_COMMIT__` (finalized in report-finalization commit; see `git log`).

## 10. Push confirmation

`__PUSH_STATUS__`

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| AI service answers `/health` | ✅ DONE (local) | pytest + live curl 200; verify harness PASS |
| Zero cold-start config | ✅ DONE | fly.toml min_machines_running=1 + auto_stop=off; assertion-tested; `fly config validate` ✓ |
| Deployed & reachable on Fly | ⏳ READY | `fly deploy` per runbook 08; then `FLY_APP_URL=… ./scripts/verify-phase-0.3.sh` |
| Exactly one always-on machine | ⏳ MANUAL | `fly status` after deploy (runbook 08) |
| RevenueCat project + iOS/Android ids | ⏳ MANUAL | runbook 09 (identifiers only; products deferred to 1.4) |

**Verified now:** the service genuinely runs and serves `/health`; the always-warm config is valid and test-enforced. **Founder-gated:** the live Fly deploy and RevenueCat account.
