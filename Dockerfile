# ═══════════════════════════════════════════════════════════════════
# Stage 1: Builder - install dependencies
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy dependency definition first for caching
COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ═══════════════════════════════════════════════════════════════════
# Stage 2: Runtime - lean production image
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY app ./app
COPY utils ./utils

# Run as non-root user
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

EXPOSE 8000

# Listen on dynamic PORT if provided by cloud platforms
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
