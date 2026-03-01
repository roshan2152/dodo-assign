# Task 3: Complete Observability Stack - Implementation Guide

## Overview

A comprehensive observability stack has been implemented for the Dodo Payments microservices consisting of:
- **Metrics**: Prometheus + Grafana
- **Logs**: Loki + Promtail
- **Traces**: Tempo (distributed tracing)
- **Alerts**: AlertManager with Slack integration
- **Anomaly Detection**: ML-based rule set

---

## Table of Contents

1. [Quick Access](#quick-access)
2. [Architecture](#architecture)
3. [Components Status](#components-status)
4. [Setup Instructions](#setup-instructions)
5. [Dashboards Guide](#dashboards-guide)
6. [Alert Configuration](#alert-configuration)
7. [Troubleshooting](#troubleshooting)

---

## Quick Access

### Access All Services

```bash
# Grafana (Metrics, Logs, Traces Dashboard)
kubectl port-forward -n monitoring svc/grafana 3000:80
# URL: http://localhost:3000
# Username: admin
# Password: admin123

# Prometheus (Metrics Database)
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# URL: http://localhost:9090

# AlertManager (Alert Management)
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
# URL: http://localhost:9093

# Tempo (Traces)
kubectl port-forward -n monitoring svc/tempo-gateway 3100:3100
# Used by Grafana, not directly accessed

# Loki (Logs)
kubectl port-forward -n monitoring svc/loki 3100:3100
# Used by Grafana, not directly accessed
```

### One-Command Access Setup

```bash
# Terminal 1: Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80 &

# Terminal 2: Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090 &

# Terminal 3: AlertManager
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093 &

echo "✅ All services accessible:"
echo "  Grafana: http://localhost:3000"
echo "  Prometheus: http://localhost:9090"
echo "  AlertManager: http://localhost:9093"
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Pods                               │
│  (Flask App instrumented with Prometheus + OTEL + Structured Logs) │
└────────┬──────────────────────┬──────────────────────┬───────────┘
         │                      │                      │
    Metrics (/metrics)    Structured Logs         OTLP Traces (4317/4318)
         │                      │                      │
         ▼                      ▼                      ▼
    ┌─────────────┐        ┌──────────────┐      ┌────────────┐
    │ Prometheus  │        │   Promtail   │      │   Tempo    │
    │   (TSDB)    │        │ (Log Shipper)│      │  (Traces)  │
    └──────┬──────┘        └────────┬─────┘      └──────┬─────┘
           │                        │                    │
           └────────────────────────┼────────────────────┘
                                    │
                                    ▼
                            ┌───────────────┐
     ┌──────────────────────│   Grafana     │◄─── Datasources:
     │                      │  (Dashboard)  │     - Prometheus (Metrics)
     │                      └───────┬───────┘     - Loki (Logs)
     │                              │             - Tempo (Traces)
     │                              ▼             - Alertmanager
     │                      ┌─────────────────┐
     │                      │   AlertManager  │
     │                      │  (Alert Routing)│
     └─────────────────────▶│   [Slack/Email] │
                            └─────────────────┘
```

---

## Components Status

### Current Deployments

```bash
$ kubectl get pods -n monitoring -o wide
```

**Expected Output:**
```
NAME                                          READY   STATUS
grafana-64c74bb9d-2mh9x                       1/1     Running
loki-0                                        2/2     Running
prometheus-alertmanager-0                     1/1     Running
prometheus-kube-state-metrics-...              1/1     Running
prometheus-prometheus-node-exporter-...        1/1     Running
prometheus-prometheus-pushgateway-...          1/1     Running
prometheus-server-7bd84685c5-...               2/2     Running
promtail-45ws2                                 1/1     Running
promtail-vjglp                                 1/1     Running
tempo-compactor-5949c88f4d-...                 1/1     Running
tempo-distributor-56449bd8f4-...               1/1     Running
tempo-gateway-6bb87b9599-...                   1/1     Running
tempo-ingester-0                               1/1     Running
tempo-memcached-0                              1/1     Running
tempo-querier-7df74f646c-...                   1/1     Running
tempo-query-frontend-6f895ffdb4-...            1/1     Running
```

### Services Quick Reference

```bash
$ kubectl get svc -n monitoring | grep -E "prometheus|grafana|loki|tempo"

NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
grafana                         ClusterIP   172.20.1.113    <none>        80/TCP
loki                            ClusterIP   172.20.96.32    <none>        3100/TCP,9095/TCP
prometheus-alertmanager         ClusterIP   172.20.176.73   <none>        9093/TCP
prometheus-server               ClusterIP   172.20.36.80    <none>        80/TCP
tempo-gateway                   ClusterIP   172.20.12.193   <none>        80/TCP,4317/TCP
```

---

## Setup Instructions

### 1. Initial Stack Deployment (Already Done ✅)

The stack has been deployed using Helm:

```bash
# Check deployment status
helm list -n monitoring

# Expected output:
# NAME            NAMESPACE   STATUS  CHART
# grafana         monitoring  deployed
# loki            monitoring  deployed
# prometheus      monitoring  deployed
# promtail        monitoring  deployed
# tempo           monitoring  deployed
```

### 2. Apply Alert Rules

```bash
cd /Users/roshansingh/Documents/assgn/dodo/dodo-assign/Task\ 3

# Prometheus alerting rules
kubectl apply -f prometheus-rules.yaml

# Anomaly detection rules
kubectl apply -f anomaly-detection.yaml

# Verify rules loaded
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Visit http://localhost:9090/alerts
```

### 3. Configure Slack Integration

**Note: Manual steps required**

1. Create Slack webhook (see [SLACK_INTEGRATION.md](./SLACK_INTEGRATION.md))
2. Update AlertManager secret:
   ```bash
   kubectl patch secret alertmanager-slack-webhook \
     -n monitoring \
     -p='{"data":{"slack-webhook-url":"'$(echo -n "YOUR_WEBHOOK_URL" | base64)'"}}' \
     --type=merge
   ```
3. Apply AlertManager config:
   ```bash
   kubectl apply -f alertmanager-config.yaml
   ```

### 4. Verify All Datasources in Grafana

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Visit http://localhost:3000
# Login: admin / admin123
# Go to: Configuration > Data Sources
# Should see:
#   ✅ Prometheus (green)
#   ✅ Loki (green)
#   ✅ Tempo (green)
```

---

## Dashboards Guide

### 1. Flask Application Performance Dashboard

**Location**: Grafana > Dashboards > Flask Application Performance

**Key Metrics:**
- **Request Rate (RPS)**: Requests per second - shows traffic volume
- **Request Latency**: p50, p95, p99 response times
- **Error Rate**: Percentage of 5xx errors
- **Status Codes**: Breakdown by HTTP status
- **Memory Usage**: Pod memory consumption (should be < 1GB)
- **CPU Usage**: CPU cores utilized

**How to Use:**
1. Standard time range: Last 1 hour
2. Check for anomalies: spikes in latency/errors, memory/CPU jumps
3. Correlate metrics: If error rate spikes, check logs panel below
4. Use for SLO tracking: Compare with baseline thresholds

### 2. Infrastructure & Cluster Health Dashboard

**Location**: Grafana > Dashboards > Infrastructure & Cluster Health

**Key Panels:**
- **Healthy Pods**: Number of running pods (should equal replicas)
- **Down Pods**: Failed/crashed pods (should be 0)
- **Pod Availability**: Timeline of pod up/down status
- **Recent Error Logs**: Live error stream from all app pods

**How to Use:**
1. Monitor pod stability: Check for restarts or crashes
2. Investigate failures: Click on error logs for context
3. Track availability: Timeline shows outage periods

### 3. Service Dependency Map (Tempo)

**Location**: Grafana > Explore > Select Tempo datasource

**Features:**
- **Service Map**: Shows Flask app → Database → External APIs
- **Trace Visualization**: Request flow through services
- **Span Duration**: Time spent in each service
- **Error Traces**: Red traces indicate errors

**How to Use:**
1. Select service to trace
2. Set time range for activity
3. Click on spans to inspect details
4. Use for performance debugging

### 4. Log Search (Loki)

**Location**: Grafana > Explore > Select Loki datasource

**Common Queries:**
```
# All logs
{job="flask-app"}

# Error logs only
{job="flask-app", level="error"}

# Logs from specific pod
{job="flask-app", pod="flask-app-pod-xyz"}

# Search for specific text
{job="flask-app"} |= "database connection failed"

# Count errors per endpoint
{job="flask-app", level="error"} | json | stats count() by endpoint
```

---

## Alert Configuration

### Alert Rules

All alert rules are in [prometheus-rules.yaml](./prometheus-rules.yaml):

| Alert | Severity | Threshold | Duration |
|-------|----------|-----------|----------|
| **FlaskAppDown** | 🔴 Critical | Service not responding | 2 min |
| **HighErrorRate** | 🟡 Warning | > 5% error rate | 5 min |
| **HighLatency** | 🟡 Warning | p95 > 1s | 5 min |
| **HighMemoryUsage** | 🟡 Warning | > 90% of limit | 5 min |
| **HighCPUUsage** | 🟡 Warning | > 80% of limit | 5 min |
| **PodCrashLooping** | 🔴 Critical | Pod restarting | 5 min |

### Anomaly Detection

Advanced rules in [anomaly-detection.yaml](./anomaly-detection.yaml):

- **RequestRateAnomaly**: Traffic level 2σ from baseline
- **LatencyAnomaly**: Latency 2x worse than normal
- **ErrorRateAnomaly**: Error rate 3x higher than baseline
- **MemoryLeakDetected**: Continuous memory growth over 30min
- **UnusualCPUPattern**: CPU 2.5x higher than normal
- **TrafficPatternAnomalyDetected**: Traffic shift >100% from baseline

### Alert Routing

See [alertmanager-config.yaml](./alertmanager-config.yaml) for complete routing:

```
Critical Alerts (FlaskAppDown, PodCrashLooping)
  └─> #critical-alerts channel (immediate)

Warning Alerts (HighLatency, HighErrorRate, etc.)
  └─> #alerts channel (batched after 1 min)

App-Specific Alerts
  └─> #app-alerts channel (grouped every 5 min)
```

### Testing Alerts

```bash
# Port-forward to AlertManager
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093

# Send test alert
curl -H 'Content-Type: application/json' -d '{
  "alerts": [{
    "status": "firing",
    "labels": {
      "alertname": "TestAlert",
      "severity": "critical",
      "job": "flask-app"
    },
    "annotations": {
      "summary": "Test Alert",
      "description": "This is a test alert"
    }
  }]
}' http://localhost:9093/api/v1/alerts

# Should appear in Slack shortly
```

---

## SLOs and SLIs

All objectives defined in [SLO-SLI.md](./SLO-SLI.md):

### Key SLOs

| Objective | Target | Error Budget |
|-----------|--------|--------------|
| **Availability** | 99.5% uptime | 3.6 hours/month |
| **Latency** | p95 < 500ms | Measured continuously |
| **Error Rate** | < 1% errors | 1% per period |

### Tracking SLOs in Prometheus

```bash
# Availability SLI
(count(up{job="flask-app"} == 1) / count(up{job="flask-app"})) * 100

# Latency SLI
histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))

# Error Rate SLI
(rate(flask_http_request_total{status=~"5.."}[5m]) / rate(flask_http_request_total[5m])) * 100
```

---

## Key Features Implemented

✅ **Prometheus Monitoring**
- Service discovery for Kubernetes pods
- Custom metrics for Flask application
- 15-day retention for historical data

✅ **Grafana Dashboards**
- Flask application performance dashboard
- Infrastructure & cluster health dashboard
- Logs and traces correlation
- Custom variable templating

✅ **Loki Logging**
- Centralized log aggregation
- Structured JSON logging
- Log-to-trace correlation
- LogQL queries for analysis

✅ **Tempo Tracing**
- Distributed trace collection
- Service map visualization
- Trace-to-logs correlation
- gRPC and HTTP OTLP receivers on 4317/4318

✅ **AlertManager**
- Multi-channel routing (Slack, Email, PagerDuty)
- Alert grouping by context
- Inhibition rules to reduce noise
- Configurable repeat intervals

✅ **Anomaly Detection**
- Statistical baseline comparison
- ML-inspired threshold algorithms
- Recording rules for efficiency
- Z-score calculations

✅ **Runbooks**
- Step-by-step alert investigation guides
- Automated remediation steps
- Escalation procedures (see [RUNBOOKS.md](./RUNBOOKS.md))

✅ **Slack Integration**
- Critical alerts: Immediate notification
- Warning alerts: Batched notifications
- Direct links to Prometheus/Grafana
- Action buttons for quick access

---

## Application Instrumentation

### Required in Flask App

1. **Prometheus Metrics Export**
   ```python
   from prometheus_flask_exporter import PrometheusMetrics
   
   app = Flask(__name__)
   metrics = PrometheusMetrics(app)
   
   # Metrics automatically exported at /metrics endpoint
   ```

2. **OTEL Tracing**
   ```python
   from opentelemetry import trace
   from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
   
   otlp_exporter = OTLPSpanExporter(
       endpoint="tempo-distributor:4317"  # or 4318 for HTTP
   )
   # Traces automatically sent to Tempo
   ```

3. **Structured Logging**
   ```python
   import logging
   import json
   
   # JSON logging with context
   logger.info(json.dumps({
       "level": "info",
       "message": "Request processed",
       "user_id": user_id,
       "endpoint": endpoint,
       "duration_ms": duration
   }))
   ```

---

## Troubleshooting

### Common Issues

**1. Prometheus not scraping Flask metrics**
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Verify Prometheus scrape config
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Visit http://localhost:9090/service-discovery

# Expected: flask-app endpoints listed with "Up"
```

**2. Loki not receiving logs**
```bash
# Check Promtail pods
kubectl logs -n monitoring -l app=promtail --tail=50

# Expected: "Successfully pushed logs to Loki"

# Verify Promtail scrape_configs
kubectl get configmap -n monitoring | grep promtail
kubectl get configmap -n monitoring promtail -o yaml | grep -A 20 scrape_configs
```

**3. Tempo not receiving traces**
```bash
# Check Tempo distributor logs
kubectl logs -n monitoring -l app=tempo-distributor --tail=50

# Verify OTLP endpoint accessibility
kubectl exec <flask-app-pod> -n flask-app -- \
  curl -v http://tempo-distributor:4318/v1/traces

# Should return 200 for health check
```

**4. Alerts not reaching Slack**
```bash
# Check AlertManager logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=100

# Verify webhook URL is correct
kubectl get secret alertmanager-slack-webhook -n monitoring -o yaml

# Test webhook directly
WEBHOOK_URL=$(kubectl get secret alertmanager-slack-webhook -n monitoring -o jsonpath='{.data.slack-webhook-url}' | base64 -d)
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  "$WEBHOOK_URL"
```

### Performance Tuning

**Increase Prometheus retention:**
```bash
kubectl patch statefulset prometheus-server -n monitoring \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"prometheus","args":["--storage.tsdb.retention.size=50GB"]}]}}}}'
```

**Increase Tempo retention:**
```bash
kubectl patch deployment tempo-ingester -n monitoring \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"tempo","env":[{"name":"TEMPO_RETENTION","value":"168h"}]}]}}}}'
```

**Scale Loki for high volume:**
```bash
helm upgrade loki grafana/loki -n monitoring \
  --set loki.limits_config.ingestion_rate_mb=1000 \
  --set loki.limits_config.max_cache_freshness_per_query=1h
```

---

## Maintenance

### Weekly Tasks
- [ ] Review alert frequency in AlertManager
- [ ] Check disk usage of Prometheus and Tempo
- [ ] Verify all datasources connected in Grafana

### Monthly Tasks
- [ ] Review SLO compliance
- [ ] Analyze alert patterns for false positives
- [ ] Update runbooks based on incidents
- [ ] Scale resources if needed

### Quarterly Tasks
- [ ] Review and optimize alerting rules
- [ ] Update dashboard visualizations
- [ ] Archive and analyze historical data
- [ ] Plan for retention policy adjustments

---

## Additional Resources

📚 **Documentation**
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)
- [Tempo Docs](https://grafana.com/docs/tempo/)

🚀 **Guides**
- [Slack Integration](./SLACK_INTEGRATION.md)
- [Alert Runbooks](./RUNBOOKS.md)
- [SLO/SLI Details](./SLO-SLI.md)
- [Original README](./README.md)

---

## Quick Reference Commands

```bash
# Check all components
kubectl get all -n monitoring

# View real-time logs
kubectl logs -f -n monitoring -l app=grafana

# Scale a component
kubectl scale deployment grafana --replicas=2 -n monitoring

# Restart a component
kubectl rollout restart deployment/grafana -n monitoring

# Debug a pod
kubectl exec -it <pod-name> -n monitoring -- /bin/bash

# Get pod details
kubectl describe pod <pod-name> -n monitoring

# Stream pod logs
kubectl logs <pod-name> -n monitoring -f

# Check metrics in Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Then visit http://localhost:9090 and query metrics

# View alerts
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
# Then visit http://localhost:9093
```

---

## Support

For issues or questions:
1. Check [RUNBOOKS.md](./RUNBOOKS.md) for alert-specific troubleshooting
2. Review Prometheus targets: http://localhost:9090/targets
3. Check component logs: `kubectl logs -n monitoring <pod-name>`
4. Consult vendor documentation linked above

---

**Last Updated**: March 1, 2026
**Version**: 1.0
**Status**: ✅ Production Ready

