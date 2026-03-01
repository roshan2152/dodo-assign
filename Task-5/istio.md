# Istio Interview Questions & Answers

---

**Q1. What is Istio's role in Kubernetes and how does the sidecar proxy model work?**

Istio is a service mesh that handles service-to-service communication — security, traffic control, observability — without touching application code. It injects an Envoy proxy sidecar into every pod via mutating webhook. All traffic flows through the sidecar; Istiod pushes config centrally. Solves: no per-language SDK needed for retries, mTLS, circuit breaking, or metrics.

---

**Q2. PeerAuthentication vs AuthorizationPolicy — how do you enforce strict mTLS namespace-wide?**

- `PeerAuthentication` — controls *how* services authenticate (mTLS mode: STRICT/PERMISSIVE/DISABLE). Transport layer (L4).
- `AuthorizationPolicy` — controls *who* can access *what* (ALLOW/DENY by identity, method, path). L4–L7.

Enforce strict mTLS:
```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: your-namespace  # use istio-system for mesh-wide
spec:
  mtls:
    mode: STRICT
```

---

**Q3. How does Istio traffic management work? Canary with VirtualService + DestinationRule?**

`DestinationRule` defines subsets (versions). `VirtualService` routes traffic to those subsets by weight.

```yaml
# DestinationRule — define versions
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-service
spec:
  host: my-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
# VirtualService — 90/10 canary split
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
        subset: v1
      weight: 90
    - destination:
        host: my-service
        subset: v2
      weight: 10
```
Shift weight gradually. Rollback = set v2 weight to 0.

---

**Q4. Istio Ingress Gateway vs Kubernetes Ingress?**

| | K8s Ingress | Istio Gateway |
|---|---|---|
| Layer | L7 only | L4 + L7 |
| mTLS | Controller-dependent | Native |
| Traffic policies | Basic routing | Retries, fault injection, circuit breaking |
| Observability | Controller-dependent | Full Istio telemetry |
| Config | `Ingress` object | `Gateway` + `VirtualService` |

K8s Ingress behavior depends on the controller (nginx, ALB). Istio Gateway is a full mesh participant — all Istio policies apply to ingress traffic.

---

**Q5. How does Istio improve observability? Prometheus, Grafana, Jaeger integration?**

Envoy sidecars emit telemetry automatically — no app instrumentation needed.

- **Prometheus** — Envoy exposes `/stats/prometheus`; metrics include RPS, error rate, latency per service
- **Grafana** — Istio ships pre-built dashboards (Mesh Overview, Service, Workload) fed from Prometheus
- **Jaeger/Zipkin** — Istio propagates B3/W3C trace headers between sidecars; apps only need to forward incoming headers
- **Kiali** — Service graph UI; visualizes traffic flow, mTLS status, health, config validation

Stack: `Envoy → Prometheus → Grafana` for metrics. `Envoy → Jaeger collector → Jaeger UI` for traces.
