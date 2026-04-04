
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


FROM python:3.12-alpine
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin/flask /usr/local/bin/flask
COPY app.py .
ENV APP_VERSION=2.0

RUN adduser -D appuser
USER appuser
EXPOSE 5000
CMD ["python", "app.py"]