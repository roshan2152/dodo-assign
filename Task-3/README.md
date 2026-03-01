# Task-3: Monitoring, Logging & Observability

## Overview

Implemented comprehensive observability stack for the Flask application microservice with:
- Metrics collection and visualization (Prometheus + Grafana)
- Centralized logging (Loki + Grafana)
- Distributed tracing (Tempo + OpenTelemetry)
- Alerting rules for critical metrics
- Log-based anomaly detection
- SLOs and SLIs tracking

## How It Works

### Metrics Collection (Prometheus)
The Flask application exports metrics on the `/metrics` endpoint (port 8080) every 30 seconds:
- HTTP request counts and duration
- Application info and custom metrics
- Prometheus scrapes via ServiceMonitor configuration
- Alertmanager triggers rules when thresholds are breached (high error rate, resource exhaustion, pod crashes)

### Visualization (Grafana)
Multiple pre-configured dashboards display:
- **Prometheus dashboard** — Cluster health, node resources, request rates
- **Node exporter dashboard** — CPU, memory, disk, network metrics
- **Request latency dashboard** — p95/p99 latency histograms
- **Tempo tracing dashboard** — Distributed trace visualization with service maps
- Data sources configured for Prometheus, Loki, and Tempo

### Log Aggregation (Loki + Grafana)
Flask application outputs JSON-formatted logs:
- Promtail collects logs from all pods
- Stored in Loki for queryable log aggregation
- Queried via Grafana with LogQL language
- Correlated with traces for end-to-end debugging

### Distributed Tracing (Tempo)
OpenTelemetry instrumentation in Flask app:
- Auto-traces all HTTP requests
- Sends OTLP traces to Tempo (port 4317, gRPC)
- Service name: `flask-app`
- Tempo stores traces and provides service maps
- Grafana can query and correlate traces with logs

### Alerting Rules
Critical conditions monitored:
- High error rate (> 5%)
- High latency (p95 > 1 second)
- Pod crashes / CrashLoopBackOff
- Memory usage > 90%
- CPU usage > 80%
- Application down

### Anomaly Detection
Log-based anomaly detection policies identify:
- Unusual error patterns
- Performance degradation trends
- Resource usage spikes

## Files

**Manifests (YAML):**
- `alertmanager-config.yaml` — Alert routing
- `prometheus-rules.yaml` — Alert conditions
- `anomaly-detection.yaml` — Anomaly policies
- `grafana-datasources.yaml` — Prometheus, Loki, Tempo sources
- `grafana-dashboards.yaml` — Dashboard inventory
- `grafana-dashboards-provisioning.yaml` — Auto-provision dashboards
- `grafana-dashboard-*.yaml` — Pre-built dashboards (5 total)
- `grafana-container-patch.yaml` — Container security
- `grafana-patch.yaml` — Deployment updates

**Helm Values:**
- `values/grafana-values.yaml` — Grafana settings
- `values/loki-values.yaml` — Loki configuration
- `values/promtail-values.yaml` — Log collector config
- `values/tempo-values.yaml` — Tracing backend config
