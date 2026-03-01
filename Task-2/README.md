# Task-2: Flask App with Blue-Green Production Deployment

A production-ready Flask application deployed on EKS using GitOps (ArgoCD) with Argo Rollouts blue-green strategy for production, CI/CD via GitHub Actions, and Kustomize-based multi-environment configuration.

## Architecture

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
                    Deployment         Argo Rollout + Analysis
```

## Project Structure

```
Task-2/
├── app.py                      # Flask app (Prometheus + OpenTelemetry)
├── Dockerfile                  # python:3.11-slim-bookworm, non-root (UID 1000)
├── requirements.txt            # Python dependencies
├── pyproject.toml              # Black, pytest, coverage config
├── tests/
│   └── test_app.py             # Unit tests
└── k8s/
    ├── base/                   # Shared base (Deployment, Service, ServiceMonitor)
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── servicemonitor.yaml
    │   └── kustomization.yaml
    ├── overlays/
    │   ├── staging/            # Rolling update via base Deployment
    │   │   ├── kustomization.yaml
    │   │   ├── namespace.yaml
    │   │   ├── ingress.yaml
    │   │   └── hpa.yaml
    │   └── production/         # Blue-green via Argo Rollout (standalone, no base)
    │       ├── kustomization.yaml
    │       ├── namespace.yaml
    │       ├── rollout.yaml          # Argo Rollout (replaces Deployment)
    │       ├── services.yaml         # flask-app-active + flask-app-preview
    │       ├── analysis-template.yaml # Pre/post promotion checks
    │       ├── servicemonitor.yaml
    │       ├── ingress.yaml          # Routes to flask-app-active
    │       ├── hpa.yaml              # Targets Rollout (min: 1, max: 3)
    │       └── pdb.yaml
    └── argocd/
        ├── appproject.yaml
        ├── staging-app.yaml    # Auto-sync, rolling update
        └── production-app.yaml # Auto-sync + self-heal, blue-green rollout
```

## Application

| Endpoint | Description |
|----------|-------------|
| `/` | Greeting message |
| `/health` | Health status with version |
| `/metrics` | Prometheus metrics (auto-exposed) |

**Stack:** Flask 3.0.0, Gunicorn (2 workers, 4 threads), Prometheus Flask Exporter, OpenTelemetry tracing (Tempo backend).

**Docker:** `python:3.11-slim-bookworm`, non-root user (`appuser:1000`), port 8080.

## CI/CD Pipeline (GitHub Actions)

The pipeline (`.github/workflows/build_deploy.yaml`) triggers on pushes to `main` and `develop`:

1. **Lint & Test** — runs `pytest`
2. **Docker Build** — builds image, pushes to ECR (`818604465858.dkr.ecr.ap-south-1.amazonaws.com/flask-app`)
3. **Update Manifests** — auto-commits new image tag to the appropriate overlay's `kustomization.yaml`
4. **ArgoCD Auto-Sync** — detects the Git change and deploys automatically

Image tags are sequential build numbers. Kustomize's `images` transformer maps `REGISTRY_PLACEHOLDER/myapp` to the real ECR image with the correct tag.

## Environments

### Staging

- **Strategy:** Rolling update (standard Kubernetes Deployment from `k8s/base`)
- **ArgoCD App:** `flask-app-staging`
- **Source:** `Task-2/k8s/overlays/staging` (inherits from `../../base`)
- **Sync:** Auto-sync + self-heal + prune
- **Replicas:** 2

### Production

- **Strategy:** Blue-green via Argo Rollout (no base dependency — standalone manifests)
- **ArgoCD App:** `flask-app-production`
- **Source:** `Task-2/k8s/overlays/production`
- **Sync:** Auto-sync + self-heal + prune
- **Replicas:** 1 (HPA scales to max 3)

#### Why Production Doesn't Use Base

The production overlay defines its own `Rollout` resource instead of inheriting the base `Deployment`. Kustomize doesn't natively understand the Argo Rollout CRD schema (e.g., `commonLabels` won't inject into `selector.matchLabels` on a Rollout), so production manages all resources independently to avoid label mismatches.

## Blue-Green Deployment (Production)

### How It Works

```
BEFORE:                          DURING DEPLOY:                    AFTER PROMOTION:
┌─────────────────┐             ┌─────────────────┐              ┌─────────────────┐
│  ACTIVE (v1)    │             │  ACTIVE (v1)    │              │  ACTIVE (v2)    │
│  flask-app-     │             │  flask-app-     │              │  flask-app-     │
│  active service │             │  active service │              │  active service │
└─────────────────┘             └─────────────────┘              └─────────────────┘
                                ┌─────────────────┐              ┌─────────────────┐
                                │  PREVIEW (v2)   │              │  OLD (v1)       │
                                │  flask-app-     │              │  scales down    │
                                │  preview service│              │  after 30s      │
                                └─────────────────┘              └─────────────────┘
```

### Key Configuration

From `k8s/overlays/production/rollout.yaml`:
```yaml
strategy:
  blueGreen:
    activeService: flask-app-active       # Production traffic
    previewService: flask-app-preview     # Testing new version
    autoPromotionEnabled: false           # Requires manual promote
    scaleDownDelaySeconds: 30             # Keep old pods 30s after switch
    scaleDownDelayRevisionLimit: 2        # Keep 2 old revisions
    prePromotionAnalysis:                 # Automated checks before switch
      templates:
      - templateName: flask-app-success-rate
    postPromotionAnalysis:                # Automated checks after switch
      templates:
      - templateName: flask-app-success-rate
```

### Analysis Template

Runs 2 checks at 5-second intervals (~10 seconds total) before and after promotion:

| Metric | Condition | Source |
|--------|-----------|--------|
| Success Rate | >= 95% | Prometheus (`http_requests_total`) |
| Latency (p95) | <= 500ms | Prometheus (`http_request_duration_seconds`) |

If pre-promotion analysis fails, the rollout aborts automatically. If post-promotion analysis fails, it triggers a rollback.

### Deployment Workflow

```bash
# 1. Push code → CI/CD builds image & updates tag → ArgoCD deploys

# 2. Monitor rollout
kubectl argo rollouts get rollout flask-app -n production --watch

# 3. Test preview version
kubectl port-forward svc/flask-app-preview -n production 8080:80
curl http://localhost:8080/health

# 4. Promote (after analysis passes)
kubectl argo rollouts promote flask-app -n production

# 5. Rollback if needed
kubectl argo rollouts abort flask-app -n production    # Before promotion
kubectl argo rollouts undo flask-app -n production     # After promotion
```

### Deployment Timeline

```
T+0s   → New image detected, preview pods start
T+10s  → Pods ready, pre-promotion analysis begins
T+20s  → Analysis passes (2 checks × 5s interval)
T+20s  → Status: Paused (waiting for manual promote)
         Promote: kubectl argo rollouts promote flask-app -n production
T+21s  → Traffic switches to new version (instant)
T+21s  → Post-promotion analysis begins
T+31s  → Post-promotion passes → Status: Healthy
T+51s  → Old pods scale down (30s delay)
```

## Production Resources

| Resource | Kind | Purpose |
|----------|------|---------|
| `flask-app` | Rollout | Blue-green deployment of Flask app |
| `flask-app-active` | Service | Routes production traffic |
| `flask-app-preview` | Service | Routes to preview/test version |
| `flask-app-success-rate` | AnalysisTemplate | Pre/post promotion metrics checks |
| `flask-app` | HPA | Auto-scales Rollout (1-3 replicas, CPU 60%, memory 75%) |
| `flask-app` | PDB | Disruption budget (minAvailable: 2) |
| `flask-app` | ServiceMonitor | Prometheus scrape config (/metrics, 30s) |
| `flask-app` | Ingress | TLS ingress via nginx with rate limiting |

## Security

- Non-root container (UID 1000)
- `allowPrivilegeEscalation: false`
- All Linux capabilities dropped
- Slim base image (minimal attack surface)
- Resource limits enforced (256Mi memory, 200m CPU)

## Local Development

```bash
# Clone and setup
git clone https://github.com/roshan2152/dodo-assign.git
cd dodo-assign/Task-2
pip install -r requirements.txt

# Run locally
python app.py
# → http://localhost:8080/

# Run tests
pytest tests/ -v

# Docker
docker build -t flask-app:test .
docker run -p 8080:8080 flask-app:test
```

## Troubleshooting

### Rollout Degraded
```bash
kubectl argo rollouts get rollout flask-app -n production
kubectl describe rollout flask-app -n production | grep -A5 "Message"
```

### ArgoCD Sync Issues
```bash
# Check app status
kubectl get application flask-app-production -n argocd -o wide

# Force hard refresh
kubectl patch application flask-app-production -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check repo-server (generates manifests)
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server
kubectl logs -l app.kubernetes.io/name=argocd-repo-server -n argocd --tail=20
```

### IP Exhaustion (aws-cni)
```bash
# Check pod count across cluster
kubectl get pods --all-namespaces --no-headers | wc -l

# Scale down replicas
kubectl patch rollout flask-app -n production --type merge -p '{"spec":{"replicas":1}}'
```

### Label Mismatch Errors
Kustomize `commonLabels` injects labels into service selectors but NOT into Rollout CRD's `selector.matchLabels`. If you see "unmatch label" errors, ensure the rollout's `selector.matchLabels` includes all labels that services select on. The rollout may need to be deleted and recreated since `matchLabels` is immutable.

## References

- [Argo Rollouts — Blue-Green](https://argoproj.github.io/argo-rollouts/features/bluegreen/)
- [ArgoCD — Auto Sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Kustomize](https://kustomize.io/)
- [Flask](https://flask.palletsprojects.com/)
- [Prometheus Flask Exporter](https://github.com/prometheus-community/prometheus_flask_exporter)
