# Backend Dockerfile - Using uv for fast dependency installation
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_CACHE_DIR=/tmp/uv-cache

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files first for better caching
# NOTE: run `uv lock` locally once to generate backend/uv.lock, then commit it
COPY backend/pyproject.toml backend/.python-version ./
COPY backend/uv.lock* ./

# Install dependencies with uv (uses cache, very fast)
# --frozen requires uv.lock to exist; falls back to resolving if missing
RUN uv sync --frozen --no-dev || uv sync --no-dev

# Copy backend code
COPY backend/ .
RUN rm -rf /tmp/uv-cache

# Create non-root user
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

# Expose port
EXPOSE 8080

# Run with gunicorn using uv's environment
CMD ["uv", "run", "--no-dev", "gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "app:create_app()"]