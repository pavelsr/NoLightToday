# syntax=docker/dockerfile:1

# --- Build: resolve deps with uv (discarded from final image) ---
FROM ghcr.io/astral-sh/uv:0.9.5-python3.12-bookworm-slim AS build

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Manifests are bind-mounted so they never enter a layer; cache mount keeps
# uv's download cache out of the image. Rebuilds only when requirements change.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=requirements.txt,target=requirements.txt \
    uv venv /opt/venv \
    && uv pip install --python /opt/venv/bin/python -r requirements.txt

# --- Runtime: slim Python, no uv, non-root ---
FROM python:3.12-slim-bookworm AS runtime

WORKDIR /app

# UID/GID 1000 matches the typical host user so bind-mounted ./data is writable.
RUN groupadd --system --gid 1000 appgroup \
    && useradd --system --uid 1000 --gid appgroup --home-dir /app --no-create-home appuser \
    && mkdir -p /app/data /app/logs \
    && chown appuser:appgroup /app/data /app/logs

COPY --from=build --link --chown=1000:1000 /opt/venv /opt/venv
# Source is a separate layer: code edits without new deps skip the install stage.
COPY --link --chown=1000:1000 src ./src

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/app/src \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER appuser

LABEL org.opencontainers.image.source="https://github.com/pavelsr/NoLightToday" \
      org.opencontainers.image.title="NoLightToday" \
      org.opencontainers.image.description="Telegram bot for Rosseti Lenenergo planned outage alerts"

CMD ["python", "-m", "src"]
