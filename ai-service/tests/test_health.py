"""Phase 0.3 — health endpoint contract test.

Runtime verification that the placeholder service answers /health with 200 and
the expected body. This is the unit gate the Phase 0.4 CI workflow will run.
"""
from fastapi.testclient import TestClient

from app.main import SERVICE_NAME, VERSION, app

client = TestClient(app)


def test_health_returns_200_ok():
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body == {"status": "ok", "service": SERVICE_NAME, "version": VERSION}


def test_core_routes_exist():
    # /health from Phase 0.3; /analyze added in Phase 1.3.
    paths = {route.path for route in app.routes if getattr(route, "methods", None)}
    assert "/health" in paths
    assert "/analyze" in paths
