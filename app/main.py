import logging
import os
import socket

import psycopg
import redis
from flask import Flask, jsonify, render_template
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST


logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)

logger = logging.getLogger(__name__)


REQUESTS = Counter(
    "app_http_requests_total",
    "Total HTTP requests handled by the demo application",
    ["endpoint"],
)


def create_app() -> Flask:
    app = Flask(__name__)

    app_name = os.getenv("APP_NAME", "DevOps Pet Service")
    app_version = os.getenv("APP_VERSION", "0.1.0")
    instance_id = os.getenv("INSTANCE_ID", "default")

    database_url = os.getenv("DATABASE_URL")
    redis_url = os.getenv("REDIS_URL")

    @app.get("/")
    def index():
        REQUESTS.labels(endpoint="/").inc()

        return render_template(
            "index.html",
            app_name=app_name,
            app_version=app_version,
            hostname=socket.gethostname(),
        )

    @app.get("/api/health")
    def health():
        REQUESTS.labels(endpoint="/api/health").inc()

        return jsonify(status="ok"), 200

    @app.get("/api/ready")
    def ready():
        REQUESTS.labels(endpoint="/api/ready").inc()

        postgres_status = "ok"
        redis_status = "ok"

        try:
            if not database_url:
                raise RuntimeError("DATABASE_URL is not configured")

            with psycopg.connect(
                database_url,
                connect_timeout=2,
            ) as connection:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT 1")
                    cursor.fetchone()

        except Exception:
            logger.exception("PostgreSQL readiness check failed")
            postgres_status = "error"

        try:
            if not redis_url:
                raise RuntimeError("REDIS_URL is not configured")

            redis_client = redis.Redis.from_url(
                redis_url,
                socket_connect_timeout=2,
                socket_timeout=2,
            )

            redis_client.ping()

        except Exception:
            logger.exception("Redis readiness check failed")
            redis_status = "error"

        if postgres_status == "ok" and redis_status == "ok":
            return jsonify(
                status="ready",
                postgres=postgres_status,
                redis=redis_status,
            ), 200

        return jsonify(
            status="not_ready",
            postgres=postgres_status,
            redis=redis_status,
        ), 503

    @app.get("/api/info")
    def info():
        REQUESTS.labels(endpoint="/api/info").inc()

        return jsonify(
            app=app_name,
            version=app_version,
            hostname=socket.gethostname(),
            instance=instance_id,
        )

    @app.get("/metrics")
    def metrics():
        REQUESTS.labels(endpoint="/metrics").inc()

        return generate_latest(), 200, {
            "Content-Type": CONTENT_TYPE_LATEST,
        }

    @app.errorhandler(Exception)
    def handle_error(exc: Exception):
        logger.exception("Unhandled application error")

        return jsonify(error="internal_server_error"), 500

    return app


app = create_app()


if __name__ == "__main__":
    port = int(os.getenv("PORT", "3000"))

    logger.info(
        "Starting application on 0.0.0.0:%s",
        port,
    )

    app.run(
        host="0.0.0.0",
        port=port,
    )