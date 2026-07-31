import logging
import os
import socket
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

    @app.get("/api/info")
    def info():
        REQUESTS.labels(endpoint="/api/info").inc()
        return jsonify(
            app=app_name,
            version=app_version,
            hostname=socket.gethostname(),
        )

    @app.get("/metrics")
    def metrics():
        REQUESTS.labels(endpoint="/metrics").inc()
        return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

    @app.errorhandler(Exception)
    def handle_error(exc: Exception):
        logger.exception("Unhandled application error")
        return jsonify(error="internal_server_error"), 500

    return app


app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", "3000"))
    logger.info("Starting application on 0.0.0.0:%s", port)
    app.run(host="0.0.0.0", port=port)
