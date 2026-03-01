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
echo "📁 Creating monitoring namespace..."
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

# Install Grafana
echo ""
echo "📈 Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values values/grafana-values.yaml \
  --wait \
  --timeout 10m

# Install Loki
echo ""
echo "📝 Installing Loki (SingleBinary mode)..."
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values values/loki-values.yaml \
  --wait \
  --timeout 10m

# Install Promtail
echo ""
echo "📋 Installing Promtail..."
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --values values/promtail-values.yaml \
  --wait \
  --timeout 5m

# Install Tempo
echo ""
echo "🔍 Installing Tempo (Distributed mode)..."
helm upgrade --install tempo grafana/tempo-distributed \
  --namespace monitoring \
  --values values/tempo-values.yaml \
  --wait \
  --timeout 10m

# Apply Grafana datasources
echo ""
echo "🔧 Configuring Grafana data sources..."
kubectl apply -f grafana-datasources.yaml

# Restart Grafana to pick up datasources
echo ""
echo "🔄 Restarting Grafana..."
kubectl rollout restart deployment grafana -n monitoring
kubectl rollout status deployment grafana -n monitoring --timeout=5m

echo ""
echo "✅ Modern Observability Stack Installed!"
echo "========================================"
echo ""
echo "📊 Deployed Components:"
echo "  ✅ Grafana (Deployment)"
echo "  ✅ Prometheus (Deployment)"
echo "  ✅ Loki (StatefulSet - SingleBinary)"
echo "  ✅ Promtail (DaemonSet)"
echo "  ✅ Tempo Distributed (Multiple Deployments)"
echo ""
echo "🔧 Access Grafana:"
echo "  kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "📊 Access Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
echo "  URL: http://localhost:9090"
echo ""
echo "🎉 Installation Complete!"
echo ""
echo "📖 Read MODERN-STACK-README.md for full documentation"
