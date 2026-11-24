"""Sample workload deployed by the platform: a small Flask API with
health checks, structured JSON logs (for CloudWatch) and Prometheus metrics."""
import json
import logging
import os
import sys
import time

from flask import Flask, Response, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

VERSION = os.getenv("APP_VERSION", "dev")


class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "message": record.getMessage(),
            "version": VERSION,
        }
        payload.update(getattr(record, "extra_fields", {}))
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logger = logging.getLogger("app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)
logger.propagate = False

REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["endpoint"])

ITEMS = []


def create_app():
    app = Flask(__name__)

    @app.before_request
    def start_timer():
        g.start = time.perf_counter()

    @app.after_request
    def record(resp):
        endpoint = request.url_rule.rule if request.url_rule else "unmatched"
        elapsed = time.perf_counter() - g.get("start", time.perf_counter())
        REQUESTS.labels(request.method, endpoint, resp.status_code).inc()
        LATENCY.labels(endpoint).observe(elapsed)
        if endpoint != "/health":
            logger.info(
                "request",
                extra={"extra_fields": {
                    "method": request.method, "path": request.path,
                    "status": resp.status_code, "duration_ms": round(elapsed * 1000, 2),
                }},
            )
        return resp

    @app.get("/")
    def index():
        return jsonify(service="cloud-deploy-demo", version=VERSION)

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/version")
    def version():
        return jsonify(version=VERSION)

    @app.get("/api/items")
    def list_items():
        return jsonify(items=ITEMS)

    @app.post("/api/items")
    def add_item():
        data = request.get_json(silent=True) or {}
        name = str(data.get("name", "")).strip()
        if not name or len(name) > 100:
            return jsonify(error="name is required (max 100 chars)"), 400
        item = {"id": len(ITEMS) + 1, "name": name}
        ITEMS.append(item)
        return jsonify(item), 201

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    @app.errorhandler(Exception)
    def on_error(exc):
        logger.error("unhandled exception", exc_info=exc)
        return jsonify(error="internal server error"), 500

    return app


app = create_app()
