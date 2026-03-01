import logging
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='{"time":"%(asctime)s", "level":"%(levelname)s", "message":"%(message)s", "name":"%(name)s"}',
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Prometheus metrics
metrics = PrometheusMetrics(app)
metrics.info("flask_app_info", "Flask App Info", version="1.0.0")

# OpenTelemetry tracing setup
resource = Resource(attributes={"service.name": "flask-app"})

# Configure OTLP exporter (Tempo endpoint)
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "tempo.monitoring.svc.cluster.local:4317"),
    insecure=True,
)

# Set up tracer provider
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(tracer_provider)

# Instrument Flask
FlaskInstrumentor().instrument_app(app)

tracer = trace.get_tracer(__name__)


@app.route("/")
def home():
    logger.info("Home endpoint accessed")
    with tracer.start_as_current_span("home-handler"):
        return "Hello from CI/CD Pipeline!", 200


@app.route("/health")
def health():
    logger.info("Health check")
    return jsonify({"status": "healthy", "version": "1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)  # nosec B104
