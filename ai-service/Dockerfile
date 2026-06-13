# PawDoc AI service — Phase 0.3 placeholder image.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080

WORKDIR /app

# Install deps first for better layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Run as a non-root user (least privilege).
RUN useradd --create-home --uid 1000 appuser
USER appuser

EXPOSE 8080

# GAP-A4: --limit-concurrency sheds load (503) past the cap instead of letting
# the thread pool pin under a burst, keeping /health answerable.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--limit-concurrency", "32"]
