"""GAP-E11: production hardening — no interactive docs/OpenAPI schema in prod."""
from app.main import _docs_kwargs, app


def test_docs_disabled_in_production():
    assert _docs_kwargs(True) == {
        "docs_url": None,
        "redoc_url": None,
        "openapi_url": None,
    }


def test_docs_enabled_in_dev():
    assert _docs_kwargs(False) == {}


def test_dev_app_keeps_docs_on():
    # The test runtime is not production, so the live app exposes the schema.
    assert app.openapi_url == "/openapi.json"
