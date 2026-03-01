# Task 1 — Kubernetes Cluster Setup & Multi-Service Deployment

## Overview

This task deploys the **Docker Samples Voting App** on an **Amazon EKS** cluster. The application consists of five microservices spread across two namespaces, configured with production-grade Kubernetes primitives including health checks, resource governance, autoscaling, and network segmentation. External access is provided via an **AWS Application Load Balancer (ALB)** with path-based routing.

---

## Application Architecture

```
kubectl get all,pvc,ingress,hpa,pdb,networkpolicy -n prod && kubectl get all,pvc -n postgres
```

```
                                                    AWS ALB (k8s-alb)
                                                    ┌─────────────────┐
                                       /vote ──────▶│  nginx-proxy    │
                                       /result ────▶│  (path rewrite) │
                                                    └────────┬────────┘
                                                             │
                                ┌────────────────────────────┼────────────────────────────┐
                                │                   Namespace: prod                        │
                                │                            │                             │
                                │                   ┌────────┴────────┐                    │
                                │                   │                 │                    │
                                │  ┌──────────┐     ▼       ┌─────────▼──┐   ┌──────────┐ │
                                │  │   Vote   │◀────────    │   Result    │   │  Worker  │ │
                                │  │ (Python) │             │  (Node.js)  │   │   (Go)   │ │
                                │  └────┬─────┘             └─────────────┘   └────┬─────┘ │
                                │       │                                          │       │
                                │       ▼                                          │       │
                                │  ┌──────────┐                                    │       │
                                │  │  Redis   │◀───────────────────────────────────┘       │
                                │  │ (Cache)  │                                            │
                                │  └──────────┘                                            │
                                │       ClusterIP:6379                                     │
                                │                                                          │
                                │  ┌──────────────┐                                        │
                                │  │ ExternalName │────────────────────────────────────┐   │
                                │  │   svc: db    │                                    │   │
                                │  └──────────────┘                                    │   │
                                └──────────────────────────────────────────────────────│───┘
                                                                                       │
                                ┌──────────────────────────────────────────────────────│───┐
                                │                Namespace: postgres                    │   │
                                │                                                      ▼   │
                                │               ┌─────────────────────────────┐            │
                                │               │   PostgreSQL (StatefulSet)  │            │
                                │               │   Headless Service + PVC    │            │
                                │               └─────────────────────────────┘            │
                                └──────────────────────────────────────────────────────────┘
```

**Access URLs:**
| Path | Application |
|------|-------------|
| `http://<ALB-DNS>/vote` | Vote UI |
| `http://<ALB-DNS>/result` | Result UI |
| `http://<ALB-DNS>/` | Vote UI (default) |

**Microservices:**

| Service      | Role                | Image                                        | Type        |
| ------------ | ------------------- | -------------------------------------------- | ----------- |
| **Vote**     | Frontend (voting UI) | `dockersamples/examplevotingapp_vote`        | Deployment  |
| **Result**   | Frontend (results)   | `dockersamples/examplevotingapp_result`      | Deployment  |
| **Worker**   | Backend processor    | `dockersamples/examplevotingapp_worker`      | Deployment  |
| **Redis**    | In-memory cache      | `redis:alpine`                               | Deployment  |
| **Postgres** | Persistent database  | `postgres:15-alpine`                         | StatefulSet |
| **nginx-proxy** | Reverse proxy (path rewrite) | `nginx:alpine`                      | Deployment  |

---

## Folder Structure

Manifests are organized by component for clarity:

```
Task-1/
├── app-config/            # Configuration & credentials
│   ├── app-configmap.yaml     # ConfigMap with Redis/DB connection details
│   └── postgres-secret.yaml   # Secret for PostgreSQL credentials
├── applications/          # Application workloads
│   ├── vote-deployment.yaml   # Vote frontend + NodePort Service
│   ├── result-deployment.yaml # Result frontend + NodePort Service
│   └── worker-deployment.yaml # Background worker (no Service)
├── cache/                 # Caching layer
│   └── redis-deployment.yaml  # Redis + ClusterIP Service
├── database/              # Database layer
│   ├── postgres.yaml          # Headless Service + StatefulSet + PVC
│   └── db-svc.yaml            # ExternalName Service (cross-namespace DNS)
├── networking/            # Traffic routing & segmentation
│   ├── ingress.yaml           # AWS ALB Ingress (path-based: /vote, /result)
│   ├── nginx-proxy.yaml       # Nginx reverse proxy for path rewriting
│   └── network-policy.yaml    # NetworkPolicies for DB & Redis
├── ha/                    # High availability & autoscaling
│   ├── hpa-vote.yaml          # HPA for Vote service
│   └── pdb.yaml               # PDBs for Vote, Result, Worker
└── Readme.md
```

---

## How Each Requirement Was Fulfilled

### 1. Kubernetes Cluster Setup

Provisioned an **Amazon EKS** cluster in `ap-south-1`. Additional cluster-level components installed:

- **AWS Load Balancer Controller** — for ALB-based HTTP routing with path-based listener rules
- **EBS CSI Driver** — for dynamic persistent volume provisioning
- **Metrics Server** — required by HPA for CPU-based autoscaling

### 2. Multi-Service Application (3+ Microservices)

Deployed the Docker Voting App which has **5 microservices** plus an **nginx-proxy** for path rewriting:

1. **Vote** — Python web app where users cast votes
2. **Result** — Node.js web app that displays live results
3. **Worker** — Go service that reads votes from Redis and writes tallies to PostgreSQL
4. **Redis** — In-memory store, acts as the vote queue
5. **PostgreSQL** — Persistent relational database storing aggregated results
6. **nginx-proxy** — Reverse proxy that rewrites `/vote` → `/` and `/result` → `/` for the apps

The application spans **two namespaces**: `prod` (application services) and `postgres` (database), connected via an **ExternalName** service that creates a DNS alias (`db` in `prod` → `db.postgres.svc.cluster.local`).

### 3. Kubernetes Resources Configured

#### Deployments

Four Deployments manage the stateless services:

| Deployment  | Replicas | Namespace |
| ----------- | -------- | --------- |
| vote        | 2        | prod      |
| result      | 1        | prod      |
| worker      | 1        | prod      |
| redis       | 1        | prod      |
| nginx-proxy | 2        | prod      |

**Manifest files:** `applications/vote-deployment.yaml`, `applications/result-deployment.yaml`, `applications/worker-deployment.yaml`, `cache/redis-deployment.yaml`, `networking/nginx-proxy.yaml`

#### Services

| Service     | Type         | Port/NodePort | Purpose                                     |
| ----------- | ------------ | ------------- | ------------------------------------------- |
| vote        | NodePort     | 80 / 31000    | Expose voting UI                            |
| result      | NodePort     | 80 / 31001    | Expose results UI                           |
| nginx-proxy | ClusterIP    | 80            | Reverse proxy for path rewriting            |
| redis       | ClusterIP    | 6379          | Internal access for vote & worker           |
| db          | Headless     | 5432          | Stable DNS for StatefulSet pods             |
| db          | ExternalName | 5432          | Cross-namespace alias (`prod` → `postgres`) |

#### ConfigMap

`app-config` in the `prod` namespace stores non-sensitive configuration:

```yaml
data:
  REDIS_HOST: redis
  DB_HOST: db
  DB_PORT: "5432"
  DB_NAME: postgres
  DB_USER: postgres
  DB_PASSWORD: postgres
```

Referenced by the Result deployment via `envFrom: configMapRef`.

**Manifest file:** `app-config/app-configmap.yaml`

#### Secret

`postgres-secret` in the `postgres` namespace stores database credentials:

```yaml
stringData:
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres
  POSTGRES_DB: postgres
```

Referenced by the PostgreSQL StatefulSet via `secretKeyRef` for each environment variable.

**Manifest file:** `app-config/postgres-secret.yaml`

#### Ingress

An **AWS Application Load Balancer (ALB)** routes external HTTP traffic using path-based routing:

| Path      | Backend Service | Port | Description                    |
| --------- | --------------- | ---- | ------------------------------ |
| `/vote`   | nginx-proxy     | 80   | Rewritten to `/` for Vote app  |
| `/result` | nginx-proxy     | 80   | Rewritten to `/` for Result app|
| `/`       | nginx-proxy     | 80   | Default to Vote app            |

**ALB Configuration:**
- **Load Balancer Name:** `k8s-alb`
- **Scheme:** `internet-facing`
- **Target Type:** `ip` (direct pod targeting)
- **Ingress Class:** `alb`

The **nginx-proxy** deployment handles path rewriting because the Vote and Result apps only serve from root `/`. It also routes static assets (`/stylesheets`, `/socket.io`, `/angular.min.js`, etc.) to the correct backend services.

**Manifest files:** `networking/ingress.yaml`, `networking/nginx-proxy.yaml`

### 4. Horizontal Pod Autoscaler (HPA)

HPA is configured for the **Vote** deployment — the most user-facing, traffic-heavy service:

| Parameter          | Value               |
| ------------------ | ------------------- |
| Target Deployment  | vote                |
| Min Replicas       | 2                   |
| Max Replicas       | 10                  |
| Scaling Metric     | CPU Utilization     |
| Target Utilization | 50%                 |
| API Version        | `autoscaling/v2`    |

This ensures the voting frontend scales up automatically during traffic spikes and scales back down during quiet periods. The Metrics Server running in the cluster supplies the CPU usage data.

**Manifest file:** `ha/hpa-vote.yaml`

### 5. Resource Requests & Limits

Every container in the cluster has explicit resource requests and limits defined:

| Container  | CPU Request | CPU Limit | Memory Request | Memory Limit |
| ---------- | ----------- | --------- | -------------- | ------------ |
| vote       | 100m        | 250m      | 64Mi           | 128Mi        |
| result     | 100m        | 250m      | 64Mi           | 128Mi        |
| worker     | 100m        | 300m      | 128Mi          | 256Mi        |
| redis      | 50m         | 200m      | 64Mi           | 128Mi        |
| postgres   | 250m        | 500m      | 256Mi          | 512Mi        |
| nginx-proxy| 50m         | 100m      | 64Mi           | 128Mi        |

This prevents any single pod from starving the node of resources and enables the scheduler to make informed placement decisions.

### 6. Health Checks (Liveness & Readiness Probes)

All services have **liveness probes** configured; the frontend and infrastructure services also have **readiness probes**:

| Service    | Probe Type        | Method                        | Initial Delay |
| ---------- | ----------------- | ----------------------------- | ------------- |
| vote       | Liveness + Readiness | HTTP GET `/` on port 80    | 15s / 5s      |
| result     | Liveness + Readiness | HTTP GET `/` on port 80    | 15s / 5s      |
| redis      | Liveness + Readiness | `redis-cli ping`           | 15s / 5s      |
| postgres   | Liveness + Readiness | `pg_isready -U postgres`  | 30s / 5s      |
| worker     | Liveness             | `cat /proc/1/status`       | 30s           |

- **Liveness probes** restart containers that become unresponsive.
- **Readiness probes** remove pods from Service endpoints until they are ready to accept traffic.
- The Worker uses an exec-based liveness probe (process check) since it has no HTTP endpoint and runs as a background processor.

---

## Bonus Implementations

### Bonus 1 — StatefulSet with Persistent Volumes

PostgreSQL is deployed as a **StatefulSet** (not a Deployment) to ensure:

- **Stable network identity** — the pod always gets the same DNS name (`db-0.db.postgres.svc.cluster.local`)
- **Persistent storage** — data survives pod restarts and rescheduling

Configuration:

```yaml
volumeClaimTemplates:
- metadata:
    name: postgres-data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: auto-ebs-sc
    resources:
      requests:
        storage: 1Gi
```

A **Headless Service** (`clusterIP: None`) is used alongside the StatefulSet for stable per-pod DNS resolution. The EBS CSI Driver dynamically provisions the underlying AWS EBS volume.

**Manifest file:** `database/postgres.yaml`

### Bonus 2 — Network Policies

Two **NetworkPolicies** enforce least-privilege network access:

**1. `db-network-policy`** (namespace: `postgres`)
- Restricts ingress to the PostgreSQL pod on port 5432
- Only allows traffic from pods labelled `app: worker` or `app: result` in the `prod` namespace
- Blocks all other pods (including `vote` and `redis`) from reaching the database

**2. `redis-network-policy`** (namespace: `prod`)
- Restricts ingress to the Redis pod on port 6379
- Only allows traffic from pods labelled `app: vote` or `app: worker`
- Blocks the result service and any other pods from accessing Redis

This ensures each service can only communicate with the backends it actually needs.

**Manifest file:** `networking/network-policy.yaml`

### Bonus 3 — Pod Disruption Budgets (PDBs)

Three PDBs protect application availability during voluntary disruptions (node drains, cluster upgrades):

| PDB          | Target   | minAvailable |
| ------------ | -------- | ------------ |
| vote-pdb     | vote     | 1            |
| result-pdb   | result   | 1            |
| worker-pdb   | worker   | 1            |

This guarantees that at least one pod of each service remains running at all times, preventing accidental full outages during maintenance.

**Manifest file:** `ha/pdb.yaml`

---

## Deployment Steps

```bash
# 1. Create namespaces
kubectl create namespace prod
kubectl create namespace postgres

# 2. Apply configuration & secrets
kubectl apply -f app-config/

# 3. Deploy the database layer
kubectl apply -f database/

# 4. Deploy the caching layer
kubectl apply -f cache/

# 5. Deploy application services
kubectl apply -f applications/

# 6. Configure networking (Ingress + Network Policies)
kubectl apply -f networking/

# 7. Apply HA policies (HPA + PDBs)
kubectl apply -f ha/
```

## Verification

```bash
# Check all pods are running
kubectl get pods -n prod
kubectl get pods -n postgres

# Verify HPA is active
kubectl get hpa -n prod

# Verify PDBs
kubectl get pdb -n prod

# Verify Network Policies
kubectl get networkpolicy -n prod
kubectl get networkpolicy -n postgres

# Check ALB Ingress
kubectl get ingress -n prod
kubectl describe ingress app-ingress -n prod

# Test endpoints (replace ALB_DNS with actual DNS)
curl http://<ALB_DNS>/vote
curl http://<ALB_DNS>/result
```

---

## Requirements Checklist

| # | Requirement                                        | Status | Implementation                                                        |
|---|----------------------------------------------------|--------|-----------------------------------------------------------------------|
| 1 | Set up Kubernetes cluster                          | ✅     | Amazon EKS cluster with EBS CSI, Metrics Server, AWS LB Controller   |
| 2 | Deploy multi-service app (3+ microservices)        | ✅     | 6 services: Vote, Result, Worker, Redis, PostgreSQL, nginx-proxy     |
| 3 | Deployments, Services, ConfigMaps, Secrets, Ingress| ✅     | 5 Deployments + 6 Services + 1 ConfigMap + 1 Secret + 1 ALB Ingress  |
| 4 | HPA for at least one service                       | ✅     | Vote HPA: 2–10 replicas, CPU target 50%                              |
| 5 | Resource requests/limits for all containers        | ✅     | All containers have CPU & memory requests and limits                  |
| 6 | Health checks for all services                     | ✅     | Liveness probes on all; readiness probes on vote, result, redis, db   |
| 7 | **Bonus:** StatefulSet with persistent volumes     | ✅     | PostgreSQL StatefulSet with 1Gi PVC via EBS CSI                       |
| 8 | **Bonus:** Network Policies                        | ✅     | DB restricted to worker+result; Redis restricted to vote+worker       |
| 9 | **Bonus:** Pod Disruption Budgets                  | ✅     | PDBs on vote, result, worker (minAvailable: 1)                       |