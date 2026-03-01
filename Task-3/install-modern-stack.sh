#!/bin/bash
set -e

echo "🚀 Installing Modern Observability Stack"
echo "=========================================="
echo ""

# Add Helm repos
echo "📦 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create namespace
echo ""
echo "📁 Ensuring monitoring namespace exists..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus
echo ""
echo "📊 Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set alertmanager.enabled=true \
  --set server.persistentVolume.enabled=false \
  --set server.retention=15d \
  --wait \
  --timeout 10m

# Install Grafana with proper configuration
echo ""
echo "📈 Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=admin123 \
  --set persistence.enabled=false \
  --set service.type=ClusterIP \
  --set datasources."datasources\.yaml".apiVersion=1 \
  --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
  --set datasources."datasources\.yaml".datasources[0].type=prometheus \
  --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server \
  --set datasources."datasources\.yaml".datasources[0].access=proxy \
  --set datasources."datasources\.yaml".datasources[0].isDefault=true \
  --wait \
  --timeout 10m

# Install Loki (single binary mode)
echo ""
echo "📝 Installing Loki..."
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1 \
  --set singleBinary.persistence.enabled=false \
  --set monitoring.selfMonitoring.enabled=false \
  --set monitoring.selfMonitoring.grafanaAgent.installOperator=false \
  --set test.enabled=false \
  --set write.replicas=0 \
  --set read.replicas=0 \
  --set backend.replicas=0 \
  --wait \
  --timeout 10m

# Install Promtail
echo ""
echo "📋 Installing Promtail..."
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --set config.clients[0].url=http://loki:3100/loki/api/v1/push \
  --wait \
  --timeout 5m

# Install Tempo (distributed mode)
echo ""
echo "🔍 Installing Tempo..."
helm upgrade --install tempo grafana/tempo-distributed \
  --namespace monitoring \
  --set traces.otlp.grpc.enabled=true \
  --set traces.otlp.http.enabled=true \
  --set storage.trace.backend=local \
  --wait \
  --timeout 10m

echo ""
echo "⏳ Waiting for all pods to be ready..."
sleep 10

echo ""
echo "✅ Modern Observability Stack Installed!"
echo "========================================"
echo ""
echo "📊 Components Installed:"
echo "  - Prometheus (metrics)"
echo "  - Grafana (visualization)"
echo "  - Loki (logs)"
echo "  - Promtail (log collector)"
echo "  - Tempo (distributed tracing)"
echo ""
echo "🔧 Access URLs:"
echo ""
echo "Grafana:"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
echo "  URL: http://localhost:9090"
echo ""
echo "🎉 Installation Complete!"
