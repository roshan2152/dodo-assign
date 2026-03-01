#!/bin/bash
set -e

echo "🚀 Setting up Complete Observability Stack with Tempo"
echo "====================================================="
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

# Install Prometheus + Grafana (kube-prometheus-stack)
echo ""
echo "📊 Installing Prometheus + Grafana..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123 \
  --set grafana.service.type=ClusterIP \
  --wait \
  --timeout 10m

# Install Loki (logging)
echo ""
echo "📝 Installing Loki for logging..."
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1 \
  --wait

# Install Promtail (log collector)
echo ""
echo "📋 Installing Promtail..."
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --set config.clients[0].url=http://loki:3100/loki/api/v1/push \
  --wait

# Install Tempo (distributed tracing)
echo ""
echo "🔍 Installing Grafana Tempo for distributed tracing..."
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --set tempo.storage.trace.backend=local \
  --set tempo.receivers.jaeger.protocols.thrift_http.endpoint=0.0.0.0:14268 \
  --set tempo.receivers.otlp.protocols.grpc.endpoint=0.0.0.0:4317 \
  --set tempo.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318 \
  --wait

echo ""
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=grafana" -n monitoring --timeout=300s || true
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=prometheus" -n monitoring --timeout=300s || true

echo ""
echo "✅ Observability Stack Installed!"
echo "=================================="
echo ""

# Configure Grafana data sources
echo "🔧 Configuring Grafana data sources..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://kube-prometheus-stack-prometheus:9090
        isDefault: true
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
      - name: Tempo
        type: tempo
        access: proxy
        url: http://tempo:3100
        jsonData:
          tracesToLogs:
            datasourceUid: Loki
            tags: ['job', 'instance', 'pod', 'namespace']
          tracesToMetrics:
            datasourceUid: Prometheus
          serviceMap:
            datasourceUid: Prometheus
          nodeGraph:
            enabled: true
EOF

# Patch Grafana to use the data sources
kubectl patch deployment kube-prometheus-stack-grafana -n monitoring \
  --type strategic -p '
{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {
            "name": "datasources",
            "configMap": {
              "name": "grafana-datasources"
            }
          }
        ],
        "containers": [
          {
            "name": "grafana",
            "volumeMounts": [
              {
                "name": "datasources",
                "mountPath": "/etc/grafana/provisioning/datasources"
              }
            ]
          }
        ]
      }
    }
  }
}' || true

echo ""
echo "📊 Access Information:"
echo "====================="
echo ""
echo "Grafana:"
echo "  kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "  Then visit: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Prometheus:"
echo "  kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
echo "  Then visit: http://localhost:9090"
echo ""
echo "Tempo (integrated with Grafana, no separate UI)"
echo "  Access via Grafana > Explore > Select Tempo data source"
echo ""

# Save info to file
cat > /tmp/observability-stack-tempo.txt <<EOF
Observability Stack with Tempo
===============================

Grafana:
  Port-forward: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
  URL: http://localhost:3000
  Username: admin
  Password: admin123

Prometheus:
  Port-forward: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
  URL: http://localhost:9090

Loki (Logs):
  Integrated with Grafana - no separate UI
  Access via Grafana > Explore > Select Loki

Tempo (Traces):
  Integrated with Grafana - no separate UI
  Access via Grafana > Explore > Select Tempo

  Tempo endpoints:
  - Jaeger Thrift HTTP: tempo:14268
  - OTLP gRPC: tempo:4317
  - OTLP HTTP: tempo:4318

Data Flow:
  Application → Promtail → Loki → Grafana (Logs)
  Application → Prometheus → Grafana (Metrics)
  Application → Tempo → Grafana (Traces)

Useful Commands:
  # View all monitoring resources
  kubectl get all -n monitoring

  # Check Tempo status
  kubectl logs -l app.kubernetes.io/name=tempo -n monitoring

  # Check Loki status
  kubectl logs -l app.kubernetes.io/name=loki -n monitoring

  # View Promtail logs
  kubectl logs -l app.kubernetes.io/name=promtail -n monitoring
EOF

echo "💾 Access information saved to: /tmp/observability-stack-tempo.txt"
echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "2. Open http://localhost:3000 (admin/admin123)"
echo "3. Go to Explore and select Tempo to view traces"
echo "4. Configure your application to send traces to Tempo"
