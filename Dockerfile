FROM python:3.12 AS builder

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/ .

RUN useradd -m appuser
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 3000

CMD ["python", "main.py"]

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:3000/api/health')"