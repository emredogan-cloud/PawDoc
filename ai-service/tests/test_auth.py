"""Phase A — trust-boundary (service-token) auth on the AI service.

The AI service is internal: only the Supabase Edge Functions may reach the
analysis endpoints, presenting `Authorization: Bearer <AI_SERVICE_TOKEN>`.
/health stays open (Fly machine health checks). These tests pin:
  * /health is always reachable unauthenticated;
  * when a token is configured, missing/wrong creds are rejected (401) and the
    correct credential is accepted;
  * production fails CLOSED (503) if the token is unset;
  * dev/test (no token, not prod) stays open so the suite + local run work.

The dependency is exercised through a minimal probe app so the auth contract
is pinned independently of which product endpoints exist.
"""
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app import config
from app.main import app, require_service_auth

client = TestClient(app)

# Minimal app mounting ONLY the auth dependency — the unit under test.
probe = FastAPI()


@probe.post("/probe", dependencies=[Depends(require_service_auth)])
def _probe() -> dict:
    return {"ok": True}


probe_client = TestClient(probe)


def test_health_is_open_without_auth(monkeypatch):
    # Even with a token configured, /health must answer for Fly health checks.
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "tok-health")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    assert client.get("/health").status_code == 200


def test_missing_credentials_rejected_when_token_configured(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "tok-abc")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    assert probe_client.post("/probe").status_code == 401


def test_wrong_token_rejected(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "tok-abc")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    resp = probe_client.post("/probe", headers={"Authorization": "Bearer wrong"})
    assert resp.status_code == 401


def test_malformed_authorization_header_rejected(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "tok-abc")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    resp = probe_client.post("/probe", headers={"Authorization": "tok-abc"})  # no "Bearer "
    assert resp.status_code == 401


def test_correct_token_accepted(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "tok-abc")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    resp = probe_client.post("/probe", headers={"Authorization": "Bearer tok-abc"})
    assert resp.status_code == 200


def test_production_fails_closed_when_token_unset(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    assert probe_client.post("/probe").status_code == 503


def test_dev_stays_open_without_token(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "")
    monkeypatch.setattr(config, "IS_PRODUCTION", False)
    assert probe_client.post("/probe").status_code == 200
