#!/bin/bash
set -e

echo "🚀 Setting up Complete Observability Stack"
echo "==========================================="
echo ""

# Add Helm repos
echo "📦 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# Create namespace
echo ""
echo "📁 Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus + Grafana (kube-prometheus-stack)
echo ""
echo "📊 Installing Prometheus + Grafana..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123 \
  --set grafana.service.type=LoadBalancer \
  --wait \
  --timeout 10m

# Install Loki (logging)
echo ""
echo "📝 Installing Loki for logging..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --wait

# Install Jaeger (tracing)
echo ""
echo "🔍 Installing Jaeger for distributed tracing..."
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --set provisionDataStore.cassandra=false \
  --set allInOne.enabled=true \
  --set storage.type=memory \
  --set allInOne.service.type=LoadBalancer \
  --wait

echo ""
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=grafana" -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=prometheus" -n monitoring --timeout=300s

echo ""
echo "✅ Observability Stack Installed!"
echo "=================================="
echo ""

# Get access URLs
GRAFANA_URL=$(kubectl get svc kube-prometheus-stack-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

PROMETHEUS_URL=$(kubectl get svc kube-prometheus-stack-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

JAEGER_URL=$(kubectl get svc jaeger-query -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo "📊 Grafana:"
if [ "$GRAFANA_URL" != "pending" ]; then
  echo "   URL: http://$GRAFANA_URL"
else
  echo "   URL: (LoadBalancer provisioning...)"
  echo "   Port-forward: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
fi
echo "   Username: admin"
echo "   Password: admin123"
echo ""

echo "📈 Prometheus:"
if [ "$PROMETHEUS_URL" != "pending" ]; then
  echo "   URL: http://$PROMETHEUS_URL:9090"
else
  echo "   Port-forward: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
fi
echo ""

echo "🔍 Jaeger:"
if [ "$JAEGER_URL" != "pending" ]; then
  echo "   URL: http://$JAEGER_URL"
else
  echo "   Port-forward: kubectl port-forward svc/jaeger-query -n monitoring 16686:16686"
fi
echo ""

# Save info to file
cat > /tmp/observability-stack.txt <<EOF
Observability Stack Access
==========================

Grafana:
  URL: http://$GRAFANA_URL (or use port-forward)
  Username: admin
  Password: admin123
  Port-forward: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

Prometheus:
  URL: http://$PROMETHEUS_URL:9090 (or use port-forward)
  Port-forward: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

Jaeger:
  URL: http://$JAEGER_URL (or use port-forward)
  Port-forward: kubectl port-forward svc/jaeger-query -n monitoring 16686:16686

Loki:
  Integrated with Grafana (no separate UI)

Useful Commands:
  # View all monitoring resources
  kubectl get all -n monitoring

  # Check Prometheus targets
  kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
  # Then visit: http://localhost:9090/targets

  # Access Grafana
  kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
  # Then visit: http://localhost:3000

  # View logs
  kubectl logs -f -l app.kubernetes.io/name=prometheus -n monitoring
EOF

echo "💾 Access information saved to: /tmp/observability-stack.txt"
echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Access Grafana and explore pre-built dashboards"
echo "2. Configure application metrics (ServiceMonitor)"
echo "3. Set up alerting rules"
echo "4. Integrate Slack notifications"
