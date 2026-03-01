# Task 3: Monitoring, Logging & Observability

Complete observability stack with Prometheus, Grafana, Loki, and Tempo for the Flask application.

## Stack Components

### 1. **Prometheus** - Metrics Collection
- Collects metrics from Flask application
- Scrapes metrics every 30s via ServiceMonitor
- Stores time-series data

### 2. **Grafana** - Visualization Dashboard
- Unified dashboard for metrics, logs, and traces
- Pre-configured data sources:
  - Prometheus (metrics)
  - Loki (logs)
  - Tempo (traces)
- Login: `admin` / `admin123`

### 3. **Loki** - Log Aggregation
- Collects logs from all pods via Promtail
- Queryable via LogQL
- Integrated with Grafana

### 4. **Tempo** - Distributed Tracing
- Receives OTLP traces from Flask app
- Provides service maps and trace visualization
- Correlates traces with logs

## Access URLs

### Grafana
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```
Then visit: http://localhost:3000
- Username: `admin`
- Password: `admin123`

### Prometheus
```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
```
Then visit: http://localhost:9090

### Alertmanager
```bash
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
```
Then visit: http://localhost:9093

## Application Instrumentation

The Flask application is instrumented with:

1. **Prometheus Metrics** (prometheus-flask-exporter)
   - HTTP request count
   - Request duration histogram
   - In-progress requests
   - Available at `/metrics` endpoint

2. **OpenTelemetry Tracing**
   - Automatic Flask instrumentation
   - Traces exported to Tempo via OTLP (port 4317)
   - Service name: `flask-app`

3. **Structured Logging**
   - JSON format for easy parsing
   - Collected by Promtail
   - Stored in Loki

## Alerting Rules

The following alerts are configured:

| Alert | Severity | Condition | Duration |
|-------|----------|-----------|----------|
| FlaskAppDown | Critical | Service is down | 2 minutes |
| HighErrorRate | Warning | > 5% error rate | 5 minutes |
| HighLatency | Warning | p95 > 1s | 5 minutes |
| HighMemoryUsage | Warning | > 90% memory | 5 minutes |
| HighCPUUsage | Warning | > 80% CPU | 5 minutes |
| PodCrashLooping | Critical | Pod restarting | 5 minutes |

View alerts in:
- Prometheus: http://localhost:9090/alerts
- Alertmanager: http://localhost:9093

## SLOs and SLIs

See [SLO-SLI.md](./SLO-SLI.md) for detailed Service Level Objectives and Indicators:
- **Availability**: 99.5% uptime
- **Latency**: 95% of requests < 500ms
- **Error Rate**: < 1% errors
- **Resource Utilization**: CPU < 70%, Memory < 80%

## Grafana Dashboards

### Viewing Metrics
1. Open Grafana (http://localhost:3000)
2. Go to **Explore**
3. Select **Prometheus** data source
4. Query examples:
   ```promql
   rate(flask_http_request_total[5m])
   histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))
   up{job="flask-app"}
   ```

### Viewing Logs
1. Go to **Explore**
2. Select **Loki** data source
3. Query examples:
   ```logql
   {namespace="staging", app="flask-app"}
   {namespace="staging"} |= "error"
   {namespace="staging", app="flask-app"} | json
   ```

### Viewing Traces
1. Go to **Explore**
2. Select **Tempo** data source
3. Search by:
   - Service name: `flask-app`
   - Time range
   - Tag filters
4. Click on traces to see:
   - Service map
   - Span timeline
   - Correlated logs (click "Logs for this span")

## Useful Commands

### Check Observability Stack Status
```bash
# All monitoring pods
kubectl get pods -n monitoring

# Check Prometheus targets
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Visit: http://localhost:9090/targets

# Check ServiceMonitor
kubectl get servicemonitor -n staging

# Check PrometheusRule
kubectl get prometheusrule -n monitoring
```

### View Logs
```bash
# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100

# Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100

# Loki logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=100

# Tempo logs
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo --tail=100
```

### Test Application Metrics
```bash
# Port-forward to staging app
kubectl port-forward -n staging svc/flask-app 8080:8080

# Generate traffic
for i in {1..100}; do curl http://localhost:8080/; done

# View metrics
curl http://localhost:8080/metrics
```

## Data Flow

```
Application
    ├─> Prometheus (metrics via /metrics endpoint)
    │   └─> Grafana (visualization)
    │
    ├─> Loki (logs via Promtail)
    │   └─> Grafana (log queries)
    │
    └─> Tempo (traces via OTLP gRPC:4317)
        └─> Grafana (trace visualization + logs correlation)
```

## Troubleshooting

### Metrics not appearing
1. Check ServiceMonitor: `kubectl get servicemonitor -n staging`
2. Check Prometheus targets: http://localhost:9090/targets
3. Verify app has `/metrics` endpoint: `kubectl exec -n staging <pod> -- curl localhost:8080/metrics`

### Traces not appearing
1. Check Tempo is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo`
2. Check OTLP endpoint env var in deployment
3. Verify Tempo logs: `kubectl logs -n monitoring tempo-0`

### Logs not appearing
1. Check Promtail is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail`
2. Check Loki: `kubectl get pods -n monitoring -l app.kubernetes.io/name=loki`
3. Verify Promtail config: `kubectl get configmap -n monitoring loki-promtail -o yaml`

## Helm Releases

```bash
helm list -n monitoring
```

Expected releases:
- `kube-prometheus-stack` (Prometheus + Grafana + Alertmanager)
- `loki` (Loki + Promtail)
- `tempo` (Tempo for distributed tracing)

## Next Steps

1. ✅ Install observability stack
2. ✅ Instrument Flask application
3. ✅ Configure data sources in Grafana
4. ✅ Set up alerting rules
5. ✅ Define SLOs and SLIs
6. 🔄 Deploy instrumented application
7. 📊 Create custom Grafana dashboards
8. 🔔 (Bonus) Set up Slack notifications
9. 📖 (Bonus) Create runbooks for alerts
10. 🤖 (Bonus) Implement anomaly detection

## Files Created

- `setup-observability-tempo.sh` - Complete stack installation script
- `add-tempo.sh` - Add Tempo to existing Grafana
- `prometheus-rules.yaml` - Alerting rules
- `SLO-SLI.md` - Service level objectives documentation
- `../Task 2/k8s/base/servicemonitor.yaml` - Prometheus ServiceMonitor
- `../Task 2/app.py` - Instrumented Flask app
- `../Task 2/requirements.txt` - Updated with observability libraries
