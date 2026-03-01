#!/bin/bash
set -e

echo "🔍 Adding Grafana Tempo to existing stack..."
echo ""

# Install Tempo
echo "📦 Installing Tempo..."
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --set tempo.auth_enabled=false \
  --set tempo.storage.trace.backend=local \
  --set tempo.receivers.jaeger.protocols.thrift_http.endpoint=0.0.0.0:14268 \
  --set tempo.receivers.jaeger.protocols.grpc.endpoint=0.0.0.0:14250 \
  --set tempo.receivers.otlp.protocols.grpc.endpoint=0.0.0.0:4317 \
  --set tempo.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318 \
  --set tempo.receivers.zipkin.endpoint=0.0.0.0:9411 \
  --wait

echo "✅ Tempo installed!"
echo ""
echo "🔧 Adding Tempo data source to Grafana..."

# Get Grafana pod
GRAFANA_POD=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" -o jsonpath="{.items[0].metadata.name}")

# Add Tempo datasource via Grafana API
kubectl exec -n monitoring $GRAFANA_POD -- sh -c '
curl -X POST -H "Content-Type: application/json" -d '\''
{
  "name": "Tempo",
  "type": "tempo",
  "access": "proxy",
  "url": "http://tempo:3100",
  "jsonData": {
    "tracesToLogs": {
      "datasourceUid": "loki",
      "tags": ["job", "instance", "pod", "namespace"],
      "mappedTags": [{"key": "service.name", "value": "service"}],
      "mapTagNamesEnabled": false,
      "spanStartTimeShift": "1h",
      "spanEndTimeShift": "-1h",
      "filterByTraceID": false,
      "filterBySpanID": false
    },
    "serviceMap": {
      "datasourceUid": "prometheus"
    },
    "nodeGraph": {
      "enabled": true
    },
    "search": {
      "hide": false
    },
    "lokiSearch": {
      "datasourceUid": "loki"
    }
  }
}'\'' http://localhost:3000/api/datasources -u admin:admin123
'

echo "✅ Tempo data source added to Grafana!"
echo ""
echo "📊 Tempo Endpoints:"
echo "  - Jaeger Thrift HTTP: tempo.monitoring.svc.cluster.local:14268"
echo "  - Jaeger gRPC: tempo.monitoring.svc.cluster.local:14250"
echo "  - OTLP gRPC: tempo.monitoring.svc.cluster.local:4317"
echo "  - OTLP HTTP: tempo.monitoring.svc.cluster.local:4318"
echo "  - Zipkin: tempo.monitoring.svc.cluster.local:9411"
echo ""
echo "🎉 Tempo setup complete!"
echo "Access via Grafana > Explore > Select Tempo"
