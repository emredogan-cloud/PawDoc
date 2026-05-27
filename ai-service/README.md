# PawDoc AI Service

FastAPI compute surface deployed on Fly.io. **Phase 0.3** ships only a `GET /health`
placeholder to prove the always-warm deploy; the real `/analyze` pipeline arrives in Phase 1.3.

## Run locally

```bash
cd ai-service
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload --port 8080
curl localhost:8080/health     # {"status":"ok","service":"pawdoc-ai","version":"0.3.0"}
```

## Test

```bash
cd ai-service && pytest -q     # health contract + "/health only" guard
```

## Deploy (Fly.io)

Founder-gated (needs a Fly account). See `docs/runbooks/08-fly-ai-service.md`. In short:

```bash
fly auth login
fly launch --no-deploy --copy-config --name pawdoc-ai   # first time; keeps this fly.toml
fly deploy
curl https://pawdoc-ai.fly.dev/health
fly status                      # expect exactly one always-on machine
```

## Why `min_machines_running = 1`

A cold start on the first analysis of the day would blow the P95 < 10s latency budget.
`fly.toml` pins one always-warm machine (`auto_stop_machines = "off"`). Autoscaling/redundancy
is a later concern (Phase 7; see Critical Review #5).
