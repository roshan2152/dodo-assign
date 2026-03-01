# Testing Tempo - Complete Guide

## Quick Overview

Tempo is **already running** and your Flask app pods are **already sending traces** to it. You don't need Task 1 - it's already deployed. Here are multiple ways to test:

---

## Method 1: Query Traces in Grafana (Easiest) 🌟

### Step 1: Set up Port Forwards

```bash
# Terminal 1: Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Terminal 2: Generate some traffic to Flask
kubectl port-forward -n production svc/flask-app 5000:5000
```

### Step 2: Generate Traffic to Flask App

```bash
# In another terminal, hit the Flask app endpoints
for i in {1..10}; do
  curl -s http://localhost:5000/
  curl -s http://localhost:5000/health
  curl -s http://localhost:5000/metrics
done
```

### Step 3: View Traces in Grafana

1. Open Grafana: http://localhost:3000 (admin/admin123)
2. Go to **Explore** (sidebar)
3. Select **Tempo** datasource (dropdown at top)
4. Click **Service Name** dropdown → Select `flask-app`
5. Click **Run Query**
6. You should see traces with request flows!

### What to Look For

```
✅ Traces with:
   • Timestamp of request
   • Total duration
   • Span count
   • Service: flask-app
   • Status: OK or error
```

---

## Method 2: Direct Tempo Query via kubectl

### Check if Tempo is Receiving Traces

```bash
# Look at Tempo distributor logs for incoming spans
kubectl logs -n monitoring -l app=tempo-distributor -f --tail=50

# Expected output:
# [distributor] trace received [trace_id=xxx duration=XXXms]
```

### Query API Directly

```bash
# Port-forward to Tempo query-frontend
kubectl port-forward -n monitoring svc/tempo-query-frontend 3100:3100

# Test the trace API (from another terminal)
curl -s http://localhost:3100/api/traces/search | jq .

# Or search by service
curl -s "http://localhost:3100/api/traces/search?service=flask-app" | jq .
```

---

## Method 3: Check Tempo Components

### Verify All Tempo Pods are Running

```bash
kubectl get pods -n monitoring | grep tempo

# Expected: All READY (1/1 or 2/2)
tempo-compactor-5949c88f4d-4sskc            1/1     Running
tempo-distributor-56449bd8f4-vghp9          1/1     Running     ← Receives traces
tempo-gateway-6bb87b9599-94bll              1/1     Running
tempo-ingester-0                            1/1     Running     ← Stores traces
tempo-memcached-0                           2/2     Running
tempo-querier-7df74f646c-f4rvr              1/1     Running     ← Queries traces
tempo-query-frontend-6f895ffdb4-jm5gw       1/1     Running
```

### Check Distributor Accepts Traces

```bash
# Test OTLP gRPC endpoint (4317)
kubectl exec -it -n production flask-app-6847795f47-hpp8n -- \
  nc -zv tempo-distributor.monitoring.svc.cluster.local 4317

# Expected: Connection successful

# Or check HTTP endpoint (4318)
kubectl exec -it -n production flask-app-6847795f47-hpp8n -- \
  curl -v http://tempo-distributor.monitoring.svc.cluster.local:4318/v1/traces
```

### Check Ingester Storage

```bash
# See what's in Tempo storage
kubectl exec -it -n monitoring tempo-ingester-0 -- \
  ls -lh /var/tempo/wal/

# Should have trace files
```

---

## Method 4: End-to-End Test (Complete Flow)

### Step 1: Start Port Forwards

```bash
# Terminal 1
kubectl port-forward -n monitoring svc/grafana 3000:80

# Terminal 2
kubectl port-forward -n production svc/flask-app 5000:5000

# Terminal 3 (optional monitoring)
kubectl logs -n monitoring -l app=tempo-distributor -f
```

### Step 2: Generate Request with Tracing

```bash
# Terminal 4: Generate load
for i in {1..20}; do
  echo "Request $i..."
  curl -s -X GET http://localhost:5000/vote/a
  curl -s -X GET http://localhost:5000/health
  sleep 1
done
```

### Step 3: Find Trace IDs

```bash
# Check distributor logs (Terminal 3)
# Look for lines like:
# [tempo] received trace id: abc123def456
```

### Step 4: Query Specific Trace

```bash
# Using trace ID from logs
TRACE_ID="abc123def456"

curl -s http://localhost:3100/api/traces/$TRACE_ID | jq .
```

### Step 5: View in Grafana

1. Open Grafana Explore (http://localhost:3000/explore)
2. Switch to **Tempo** datasource
3. Click **Select a trace**
4. Search by tag: `service.name = flask-app`
5. Find your trace and click it
6. See full span timeline!

---

## Method 5: Check Trace Data Exists

### Verify Traces in OTLP Format

```bash
# Connect to Tempo query API
kubectl port-forward -n monitoring svc/tempo-query-frontend 3100:3100

# Search all traces for flask-app
curl -s "http://localhost:3100/api/search?service=flask-app&limit=100" | jq '.traces | length'

# Expected: Number > 0 (e.g., "15")
```

### Export Trace Statistics

```bash
# Get summary of traces
curl -s http://localhost:3100/api/status/instrumentation \
  -H 'Accept: application/json' | jq .
```

---

## Visualizing Traces in Grafana

### Dashboard View

1. **Service Map**: Shows Flask app → Database → Cache dependencies
2. **Trace List**: Recent traces from flask-app
3. **Span Timeline**: Request flow through services
4. **Logs Correlation**: See logs emitted during trace

### Example Trace Screen

```
Trace ID: abc123def456
Duration: 245ms
Status: OK (200)

Spans:
├─ flask.request (100ms) - HTTP request handling
│  ├─ db.query (80ms) - Database query
│  │  └─ db.connect (10ms) - Connection time
│  └─ cache.get (5ms) - Redis lookup
└─ http.response (20ms) - Send response
```

---

## Troubleshooting

### No Traces Appearing?

#### 1. Check Flask App has OTEL Instrumentation

```bash
# Check Flask app environment variables
kubectl exec -n production flask-app-6847795f47-hpp8n -- env | grep -i otel

# Should contain:
# OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo-distributor:4317
# OTEL_SERVICE_NAME=flask-app
```

#### 2. Verify Trace Export is Working

```bash
# Check Flask app logs for trace errors
kubectl logs -n production flask-app-6847795f47-hpp8n | grep -i trace

# Should NOT have errors like "connection refused"
```

#### 3. Check Network Connectivity

```bash
# From Flask pod, can reach Tempo?
kubectl exec -n production flask-app-6847795f47-hpp8n -- \
  curl -v http://tempo-distributor.monitoring.svc.cluster.local:4318/healthcheck
```

#### 4. Monitor Distributor for Errors

```bash
# Watch for distributor errors
kubectl logs -n monitoring -l app=tempo-distributor -f | grep -i error
```

### Traces Appear But No Spans?

```bash
# Flask app might not be instrumented
# Check instrumentations in app code:
# from opentelemetry.instrumentation.flask import FlaskInstrumentor
# FlaskInstrumentor().instrument()
```

---

## Quick Commands Reference

```bash
# Test connectivity to Tempo
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://tempo-distributor.monitoring:4318/healthcheck

# View Distributor logs in real-time
kubectl logs -f -n monitoring -l app=tempo-distributor

# Get latest trace stats
kubectl exec -n monitoring tempo-ingester-0 -- \
  ls -lh /var/tempo/ | head -20

# Check Tempo config
kubectl get configmap -n monitoring | grep -i tempo

# Restart Tempo to clear old traces
kubectl rollout restart deployment/tempo-distributor -n monitoring
kubectl rollout restart statefulset/tempo-ingester -n monitoring
```

---

## Full Testing Workflow (Copy & Paste)

```bash
#!/bin/bash

# Setup
echo "📊 Setting up Tempo testing..."

# Terminal 1 (run in separate terminal)
# kubectl port-forward -n monitoring svc/grafana 3000:80 &
# kubectl port-forward -n production svc/flask-app 5000:5000 &

# Generate traffic
echo "🔄 Generating traces..."
for i in {1..50}; do
  curl -s http://localhost:5000/health > /dev/null
  curl -s http://localhost:5000/vote/a > /dev/null
  sleep 0.5
done

echo ""
echo "✅ Done! Check traces in Grafana:"
echo "   1. Open http://localhost:3000"
echo "   2. Go to Explore > Select Tempo"
echo "   3. Service Name: flask-app"
echo "   4. Run Query"
echo ""
echo "📊 Trace count:"
curl -s "http://localhost:3100/api/search?service=flask-app&limit=1" 2>/dev/null | \
  jq '.traces | length' 2>/dev/null || echo "  (port-forward svc/tempo-query-frontend 3100:3100 first)"
```

---

## Do You Need Task 1?

**NO!** Task 1 just contains Kubernetes manifests for basic deployments (ConfigMaps, StatefulSets, etc.).

**What you actually have:**
- ✅ Task 2: Flask App (deployed in production & staging)
- ✅ Task 3: Observability Stack (deployed, Tempo running)
- ✅ Flask App already instrumented with OpenTelemetry

**Next Step:** Just test by querying traces in Grafana!

---

## SummaryTo test Tempo right now:

1. **Keep it simple**: Use Grafana Explore with Tempo datasource
2. **No setup needed**: Tempo is already running and receiving traces
3. **Generate traffic**: `for i in {1..20}; do curl http://localhost:5000/; done`
4. **View traces**: Go to Grafana > Explore > Tempo > Select flask-app service

You're ready to go! 🚀
