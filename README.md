# DevOps & Kubernetes Assignment

A comprehensive DevOps project demonstrating production-grade Kubernetes deployment, GitOps CI/CD, observability, and security hardening across 5 tasks.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AWS EKS Cluster                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐      │
│  │   Task 1    │   │   Task 2    │   │   Task 3    │   │   Task 4    │      │
│  │  Voting App │   │  Flask App  │   │ Observability│   │  Security   │      │
│  │  (5 svcs)   │   │  Blue-Green │   │    Stack    │   │  Hardening  │      │
│  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘      │
│         │                 │                 │                 │              │
│         └────────────────┼─────────────────┼─────────────────┘              │
│                          │                 │                                 │
│                          ▼                 ▼                                 │
│  ┌───────────────────────────────────────────────────────────────────┐      │
│  │  ArgoCD (GitOps)  │  Prometheus + Grafana  │  Vault + Falco       │      │
│  │  Argo Rollouts    │  Loki + Tempo          │  cert-manager (mTLS) │      │
│  └───────────────────────────────────────────────────────────────────┘      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
dodo-assign/
├── Task-1/              # Kubernetes Cluster Setup & Multi-Service Deployment
├── Task-2/              # Flask App with Blue-Green Production Deployment
├── Task-3/              # Monitoring, Logging & Observability
├── Task-4/              # Kubernetes Security Hardening
├── Task-5/              # Istio Service Mesh (Interview Q&A)
└── README.md            # This file
```

---

## Task 1: Kubernetes Cluster Setup & Multi-Service Deployment

Deploys the **Docker Samples Voting App** on **Amazon EKS** with production-grade configuration.

### Architecture

```
                              AWS ALB (k8s-alb)
                              ┌─────────────────┐
                 /vote ──────▶│  nginx-proxy    │
                 /result ────▶│  (path rewrite) │
                              └────────┬────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │            Namespace: prod                       │
              │                        │                         │
              │  ┌──────────┐   ┌──────┴─────┐   ┌──────────┐   │
              │  │   Vote   │   │   Result   │   │  Worker  │   │
              │  │ (Python) │   │  (Node.js) │   │   (Go)   │   │
              │  └────┬─────┘   └────────────┘   └────┬─────┘   │
              │       │                               │         │
              │       ▼                               │         │
              │  ┌──────────┐                         │         │
              │  │  Redis   │◀────────────────────────┘         │
              │  └──────────┘                                   │
              └────────────────────────────────────────────────┬┘
                                                               │
              ┌────────────────────────────────────────────────┴┐
              │           Namespace: postgres                    │
              │     ┌─────────────────────────────┐             │
              │     │   PostgreSQL (StatefulSet)  │             │
              │     │   Headless Service + PVC    │             │
              │     └─────────────────────────────┘             │
              └─────────────────────────────────────────────────┘
```

### Microservices

| Service | Role | Image | Type |
|---------|------|-------|------|
| Vote | Frontend (voting UI) | `dockersamples/examplevotingapp_vote` | Deployment |
| Result | Frontend (results) | `dockersamples/examplevotingapp_result` | Deployment |
| Worker | Backend processor | `dockersamples/examplevotingapp_worker` | Deployment |
| Redis | In-memory cache | `redis:alpine` | Deployment |
| Postgres | Persistent database | `postgres:15-alpine` | StatefulSet |
| nginx-proxy | Reverse proxy | `nginx:alpine` | Deployment |

### Features Implemented

| Feature | Implementation |
|---------|---------------|
| ALB Ingress | Path-based routing (`/vote`, `/result`) via AWS ALB |
| HPA | Vote: 2-10 replicas, CPU target 50% |
| Resource Limits | All containers have CPU/memory requests and limits |
| Health Checks | Liveness + readiness probes on all services |
| StatefulSet | PostgreSQL with 1Gi PVC via EBS CSI |
| Network Policies | DB restricted to worker+result; Redis to vote+worker |
| PDBs | minAvailable: 1 for vote, result, worker |

### Files

```
Task-1/
├── app-config/           # ConfigMaps & Secrets
├── applications/         # Vote, Result, Worker Deployments
├── cache/                # Redis Deployment
├── database/             # PostgreSQL StatefulSet + Services
├── networking/           # Ingress, nginx-proxy, Network Policies
├── ha/                   # HPA, PDBs
└── Readme.md
```

---

## Task 2: Flask App with Blue-Green Production Deployment

Production-ready Flask application with GitOps (ArgoCD) and Argo Rollouts blue-green deployment strategy.

### CI/CD Pipeline

```
Developer Push → GitHub Actions CI/CD
                    ├─ Lint + Test (pytest)
                    ├─ Docker Build → Push to ECR
                    └─ Update image tag in kustomization.yaml (auto-commit)
                                    ↓
                              ArgoCD (GitOps)
                         ┌──────────┴──────────┐
                    Staging                Production
                 (Rolling Update)       (Blue-Green Rollout)
```

### Blue-Green Strategy

```
BEFORE:                     DURING DEPLOY:               AFTER PROMOTION:
┌─────────────────┐        ┌─────────────────┐          ┌─────────────────┐
│  ACTIVE (v1)    │        │  ACTIVE (v1)    │          │  ACTIVE (v2)    │
│  flask-app-     │        │  flask-app-     │          │  flask-app-     │
│  active service │        │  active service │          │  active service │
└─────────────────┘        └─────────────────┘          └─────────────────┘
                           ┌─────────────────┐          ┌─────────────────┐
                           │  PREVIEW (v2)   │          │  OLD (v1)       │
                           │  flask-app-     │          │  scales down    │
                           │  preview service│          │  after 30s      │
                           └─────────────────┘          └─────────────────┘
```

### Environments

| Environment | Strategy | Replicas | ArgoCD App |
|-------------|----------|----------|------------|
| Staging | Rolling update | 2 | `flask-app-staging` |
| Production | Blue-green (Argo Rollout) | 1 (HPA: max 3) | `flask-app-production` |

### Analysis Template

Pre/post-promotion checks run 2 checks at 5-second intervals:

| Metric | Condition | Source |
|--------|-----------|--------|
| Success Rate | >= 95% | Prometheus (`http_requests_total`) |
| Latency (p95) | <= 500ms | Prometheus (`http_request_duration_seconds`) |

### Application Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Greeting message |
| `/health` | Health status with version |
| `/metrics` | Prometheus metrics |

### Files

```
Task-2/
├── app.py                  # Flask app with Prometheus + OpenTelemetry
├── Dockerfile              # python:3.11-slim, non-root (UID 1000)
├── tests/                  # pytest unit tests
└── k8s/
    ├── base/               # Shared Deployment, Service, ServiceMonitor
    ├── overlays/
    │   ├── staging/        # Rolling update
    │   └── production/     # Blue-green Rollout + Analysis
    └── argocd/             # ArgoCD Application manifests
```

---

## Task 3: Monitoring, Logging & Observability

Comprehensive observability stack for the Flask application microservice.

### Stack Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Grafana Dashboards                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Metrics    │  │    Logs      │  │   Traces     │       │
│  │  (Prometheus)│  │   (Loki)     │  │   (Tempo)    │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          │                 │                 │
    ┌─────▼─────┐     ┌─────▼─────┐     ┌─────▼─────┐
    │Prometheus │     │  Promtail │     │   OTLP    │
    │  Scrape   │     │  Collect  │     │  Export   │
    └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                    ┌───────▼───────┐
                    │  Flask App    │
                    │  /metrics     │
                    │  JSON logs    │
                    │  OTLP traces  │
                    └───────────────┘
```

### Features

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Metrics collection from `/metrics` endpoint every 30s |
| **Grafana** | Pre-built dashboards (cluster health, latency, traces) |
| **Loki** | Log aggregation with LogQL queries |
| **Promtail** | Log collection from all pods |
| **Tempo** | Distributed tracing via OpenTelemetry (OTLP) |
| **Alertmanager** | Alert routing for critical conditions |

### Alerting Rules

- High error rate (> 5%)
- High latency (p95 > 1 second)
- Pod crashes / CrashLoopBackOff
- Memory usage > 90%
- CPU usage > 80%
- Application down

### Files

```
Task-3/
├── alertmanager-config.yaml         # Alert routing
├── prometheus-rules.yaml            # Alert conditions
├── anomaly-detection.yaml           # Anomaly policies
├── grafana-datasources.yaml         # Prometheus, Loki, Tempo sources
├── grafana-dashboard-*.yaml         # Pre-built dashboards (5 total)
├── values/
│   ├── grafana-values.yaml
│   ├── loki-values.yaml
│   ├── promtail-values.yaml
│   └── tempo-values.yaml
└── README.md
```

---

## Task 4: Kubernetes Security Hardening

Zero-trust security architecture with 8 layers of defense.

### Security Layers

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    LAYER 8: Mutual TLS (cert-manager)                    │
├─────────────────────────────────────────────────────────────────────────┤
│              LAYER 7: Image Security (Trivy + Cosign)                    │
├─────────────────────────────────────────────────────────────────────────┤
│               LAYER 6: Audit Logging (API Server)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                LAYER 5: Runtime Security (Falco)                         │
├─────────────────────────────────────────────────────────────────────────┤
│            LAYER 4: Network Policies (Microsegmentation)                 │
├─────────────────────────────────────────────────────────────────────────┤
│               LAYER 3: Secret Management (Vault)                         │
├─────────────────────────────────────────────────────────────────────────┤
│           LAYER 2: Pod Security Standards (PSS/PSA)                      │
├─────────────────────────────────────────────────────────────────────────┤
│              LAYER 1: RBAC (Least Privilege Access)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

### Layer Details

| Layer | Component | Purpose |
|-------|-----------|---------|
| **1. RBAC** | 3 Roles (admin, operator, developer) | Least privilege access control |
| **2. PSS** | Pod Security Standards - Restricted | Block privileged, root, host access |
| **3. Vault** | HashiCorp Vault + ESO | Secrets never in Git; auto-rotation |
| **4. Network Policies** | Default-deny + explicit allow | Zero-trust networking |
| **5. Falco** | DaemonSet with eBPF | Runtime syscall monitoring |
| **6. Audit** | Kubernetes API logging | Compliance (HIPAA, PCI-DSS) |
| **7. Trivy** | Container scanning | Block CVEs before deployment |
| **8. mTLS** | cert-manager certificates | Encrypted service-to-service |

### RBAC Roles

| Role | Permissions |
|------|-------------|
| Admin | Full cluster management |
| Operator | View/manage deployments (no delete) |
| Developer | Logs and exec access only |

### Files

```
Task-4/
├── rbac/                   # ServiceAccounts, Roles, RoleBindings
├── pod-security/           # PSS enforcement, secure pod example
├── vault/                  # Vault + External Secrets Operator
├── network-policies/       # Default-deny + explicit allow rules
├── falco/                  # Falco DaemonSet + Helm values
├── audit/                  # Kubernetes API audit policy
├── image-security/         # Trivy server + CI/CD integration
├── mtls/                   # cert-manager certificates
├── test-task4.sh           # Security verification script
└── README.md
```

### Verification

```bash
# Run security verification script
chmod +x Task-4/test-task4.sh
./Task-4/test-task4.sh
```

---

## Task 5: Istio Service Mesh (Interview Q&A)

Istio service mesh concepts and implementation patterns.

### Topics Covered

1. **Istio Architecture** — Sidecar proxy model, Envoy injection
2. **Security** — PeerAuthentication vs AuthorizationPolicy, strict mTLS
3. **Traffic Management** — VirtualService + DestinationRule for canary
4. **Ingress** — Istio Gateway vs Kubernetes Ingress
5. **Observability** — Prometheus, Grafana, Jaeger, Kiali integration

### Example: Canary Deployment

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

### Files

```
Task-5/
└── istio.md      # Interview Q&A document
```

---

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl configured for EKS cluster
- Helm 3.x
- ArgoCD CLI (optional)

### Deploy All Tasks

```bash
# Task 1: Voting App
kubectl create namespace prod
kubectl create namespace postgres
kubectl apply -f Task-1/app-config/
kubectl apply -f Task-1/database/
kubectl apply -f Task-1/cache/
kubectl apply -f Task-1/applications/
kubectl apply -f Task-1/networking/
kubectl apply -f Task-1/ha/

# Task 2: ArgoCD Applications
kubectl apply -f Task-2/k8s/argocd/

# Task 3: Observability (via Helm)
# See Task-3/README.md for detailed instructions

# Task 4: Security
kubectl apply -f Task-4/rbac/
kubectl apply -f Task-4/pod-security/
kubectl apply -f Task-4/network-policies/
kubectl apply -f Task-4/audit/
# See README for Vault, Falco, cert-manager setup
```

### Verification

```bash
# Check all pods across namespaces
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Run security tests
./Task-4/test-task4.sh
```

---

## Technologies Used

| Category | Tools |
|----------|-------|
| **Container Orchestration** | Kubernetes, Amazon EKS |
| **CI/CD** | GitHub Actions, ArgoCD, Argo Rollouts |
| **Container Registry** | Amazon ECR |
| **Ingress** | AWS ALB, nginx |
| **Observability** | Prometheus, Grafana, Loki, Tempo |
| **Security** | Vault, Falco, Trivy, cert-manager |
| **Service Mesh** | Istio (concepts) |
| **IaC** | Kustomize, Helm |

---

## Author

Roshan Singh

## License

MIT
