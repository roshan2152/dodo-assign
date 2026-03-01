# Modern Observability Stack - Deployed

## ✅ Components Deployed (All using Deployments - Modern Way!)

### 1. **Grafana** (Deployment)
- **Chart**: `grafana/grafana`
- **Version**: Latest
- **Type**: Deployment (1 replica)
- **Access**:
  ```bash
  kubectl port-forward -n monitoring svc/grafana 3000:80
  ```
  - URL: http://localhost:3000
  - Username: `admin`
  - Password: `admin123`

### 2. **Prometheus** (Deployment)
- **Chart**: `prometheus-community/prometheus`
- **Components**:
  - `prometheus-server` - Deployment
  - `prometheus-alertmanager` - StatefulSet (1 replica)
  - `prometheus-node-exporter` - DaemonSet
  - `prometheus-kube-state-metrics` - Deployment
  - `prometheus-pushgateway` - Deployment
- **Access**:
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-server 9090:80
  ```
  - URL: http://localhost:9090

### 3. **Loki** (Single Binary Mode)
- **Chart**: `grafana/loki`
- **Mode**: SingleBinary
- **Type**: StatefulSet (1 replica) - necessary for persistence
- **Storage**: EmptyDir (ephemeral)
- **URL**: `http://loki:3100`

### 4. **Promtail** (DaemonSet)
- **Chart**: `grafana/promtail`
- **Type**: DaemonSet (runs on every node)
- **Sends logs to**: `http://loki:3100/loki/api/v1/push`

### 5. **Tempo** (Distributed Mode)
- **Chart**: `grafana/tempo-distributed`
- **Components** (All Deployments):
  - `tempo-distributor` - Deployment (receives traces)
  - `tempo-ingester` - StatefulSet (1 replica - writes traces)
  - `tempo-querier` - Deployment (queries traces)
  - `tempo-query-frontend` - Deployment (query optimization)
  - `tempo-compactor` - Deployment (compaction)
  - `tempo-gateway` - Deployment (gateway/router)
  - `tempo-memcached` - StatefulSet (caching)
- **OTLP Endpoints**:
  - gRPC: `tempo-distributor:4317`
  - HTTP: `tempo-distributor:4318`
- **Query URL**: `http://tempo-query-frontend:3100`

## 📊 Grafana Data Sources (Auto-configured)

All data sources are automatically provisioned in Grafana:

1. **Prometheus** (Default)
   - URL: `http://prometheus-server`
   - Type: Metrics

2. **Loki**
   - URL: `http://loki:3100`
   - Type: Logs

3. **Tempo**
   - URL: `http://tempo-query-frontend:3100`
   - Type: Traces
   - Features:
     - Traces-to-Logs correlation (with Loki)
     - Service Map (with Prometheus)
     - Node Graph
     - Loki Search integration

## 🚀 Quick Start Commands

### Access Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000
# Login: admin / admin123
```

### Access Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Open http://localhost:9090
```

### Access Alertmanager
```bash
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
# Open http://localhost:9093
```

### Check All Pods
```bash
kubectl get pods -n monitoring
```

### Check All Services
```bash
kubectl get svc -n monitoring
```

## 📝 Application Instrumentation

To send data to this stack, configure your application:

### Metrics (Prometheus)
Expose metrics at `/metrics` endpoint. Prometheus will auto-discover via ServiceMonitor.

### Logs (Loki via Promtail)
Logs are automatically collected from all pods by Promtail DaemonSet. Use structured JSON logging:
```json
{"time":"2026-02-27T20:00:00Z", "level":"info", "message":"Request processed"}
```

### Traces (Tempo)
Configure OpenTelemetry to send traces:
```bash
# Environment variables for Flask app
OTEL_EXPORTER_OTLP_ENDPOINT=tempo-distributor.monitoring.svc.cluster.local:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

## 🛠️ Helm Values Files

All configuration is managed via values files in `values/` directory:

- `grafana-values.yaml` - Grafana configuration
- `loki-values.yaml` - Loki configuration
- `promtail-values.yaml` - Promtail configuration
- `tempo-values.yaml` - Tempo configuration

## 🔄 Update/Reinstall Commands

### Upgrade Grafana
```bash
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values values/grafana-values.yaml
```

### Upgrade Loki
```bash
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values values/loki-values.yaml
```

### Upgrade Promtail
```bash
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --values values/promtail-values.yaml
```

### Upgrade Tempo
```bash
helm upgrade --install tempo grafana/tempo-distributed \
  --namespace monitoring \
  --values values/tempo-values.yaml
```

## 📦 Installed Helm Releases

```bash
helm list -n monitoring
```

Expected output:
- `grafana` - Grafana dashboard
- `prometheus` - Prometheus monitoring
- `loki` - Loki log aggregation
- `promtail` - Promtail log collector
- `tempo` - Tempo distributed tracing

## 🗑️ Uninstall

To remove the entire stack:
```bash
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring
helm uninstall promtail -n monitoring
helm uninstall tempo -n monitoring

# Optional: delete namespace
kubectl delete namespace monitoring
```

## ✅ Modern Stack Benefits

1. **Grafana (Deployment)**: Stateless, easy to scale horizontally
2. **Prometheus Server (Deployment)**: Modern architecture, no StatefulSet needed
3. **Loki (SingleBinary)**: Simplified deployment, single StatefulSet for storage
4. **Tempo (Distributed)**: Each component as Deployment/StatefulSet where needed
5. **Promtail (DaemonSet)**: Automatic log collection from all nodes

## 🎯 Next Steps

1. ✅ Modern stack deployed
2. 🔄 Update Flask app deployment to use these endpoints
3. 📊 Create custom Grafana dashboards
4. 🔔 Configure alerting rules
5. 📈 Monitor SLOs/SLIs
