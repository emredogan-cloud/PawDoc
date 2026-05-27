"""Structured JSON logging with API-key masking and end-to-end request-id (CR #23)."""
from __future__ import annotations

import json
import logging
import re
import sys
from contextvars import ContextVar
from datetime import datetime, timezone

_request_id: ContextVar[str] = ContextVar("request_id", default="-")

# Mask anything shaped like a provider key / JWT before it can hit a log sink.
_SECRET_RE = re.compile(
    r"sk-ant-[A-Za-z0-9_-]{6,}|AIza[A-Za-z0-9_-]{10,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+"
)


def set_request_id(request_id: str) -> None:
    _request_id.set(request_id)


def get_request_id() -> str:
    return _request_id.get()


def mask_secrets(text: str) -> str:
    return _SECRET_RE.sub("***MASKED***", text)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "request_id": get_request_id(),
            "msg": mask_secrets(record.getMessage()),
        }
        if record.exc_info:
            payload["exc"] = mask_secrets(self.formatException(record.exc_info))
        return json.dumps(payload)


def configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(logging.INFO)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
