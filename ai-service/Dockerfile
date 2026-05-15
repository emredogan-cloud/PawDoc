# syntax=docker/dockerfile:1.7
#
# Multi-stage build for PawDoc AI service.
# Stage 1 (builder) installs deps with uv into a virtualenv we copy forward.
# Stage 2 (runtime) is a slim image with only what's needed to serve.

ARG PYTHON_VERSION=3.12.5
ARG UV_VERSION=0.4.18

# =============================================================================
# Stage 1 — builder
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

ARG UV_VERSION
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "uv==${UV_VERSION}"

WORKDIR /app

# Copy only metadata first so the dep layer caches when source changes.
COPY pyproject.toml README.md ./
COPY uv.lock* ./

# Sync production deps only — no dev tooling in the runtime image.
RUN uv sync --frozen --no-install-project --no-dev || uv sync --no-install-project --no-dev

# Now copy source and install the project itself.
COPY app ./app
RUN uv sync --frozen --no-dev || uv sync --no-dev

# =============================================================================
# Stage 2 — runtime
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    APP_ENV=prod \
    PORT=8080

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 app \
    && useradd --system --uid 1001 --gid app --home-dir /home/app --create-home app

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app ./app

USER app

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT}/health" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-server-header", "--proxy-headers"]
