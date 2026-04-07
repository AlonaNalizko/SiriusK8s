# Stage 1: builder
FROM python:3.12-slim AS builder
WORKDIR /build

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: final image
FROM python:3.12-slim
WORKDIR /app

RUN useradd -m appuser

COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
ENV APP_VERSION=2.0

COPY --chown=appuser:appuser app.py .
USER appuser
EXPOSE 5000
CMD ["python", "app.py"]