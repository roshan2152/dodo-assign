# Task-2: Flask App with Advanced Deployment Strategies

A production-ready Flask application with comprehensive Kubernetes deployment, GitOps automation, and advanced deployment strategies including blue-green rollouts and multi-environment support.

## 📋 Project Overview

This project demonstrates a complete DevOps setup for deploying a Flask application to Kubernetes using modern tools and best practices:
- **Framework**: Flask 3.0.0 with Gunicorn
- **Observability**: Prometheus metrics + OpenTelemetry tracing
- **Containerization**: Secure Docker builds with non-root user
- **Deployment**: Kustomize + ArgoCD + Argo Rollouts
- **Testing**: pytest with coverage reporting
- **Environments**: Staging and Production with different deployment strategies

## 🏗️ Architecture

```
Code Push → Docker Build → ECR Push
                             ↓
                      Kustomize Manifests
                             ↓
                         ArgoCD (GitOps)
                             ↓
                       EKS Cluster Deployment
                             ↓
                   Argo Rollouts (Blue-Green/Rolling)
```

## 🎯 Key Features

### Application Layer
- ✅ **Flask API**: Home endpoint (`/`) and health check (`/health`)
- ✅ **Prometheus Metrics**: Integrated Flask exporter for monitoring
- ✅ **Distributed Tracing**: OpenTelemetry with Tempo backend support
- ✅ **Structured Logging**: JSON-formatted logs for log aggregation
- ✅ **Health Checks**: Liveness and readiness probes for Kubernetes

### Containerization
- ✅ **Multi-stage Optimized**: Minimal final image size
- ✅ **Non-root User**: Security hardening (appuser:1000)
- ✅ **Slim Base Image**: `python:3.11-slim-bookworm` (~125MB)
- ✅ **Production Server**: Gunicorn with 2 workers and 4 threads

### Testing & Quality
- ✅ **Unit Tests**: pytest with basic endpoint testing
- ✅ **Test Configuration**: pytest.ini with coverage tracking
- ✅ **Code Formatting**: Black (line-length: 120)
- ✅ **Project Configuration**: Centralized pyproject.toml

### Kubernetes Deployment
- ✅ **Kustomize Templates**: Base + environment overlays
- ✅ **Multiple Environments**: Staging and production configurations
- ✅ **Deployment Strategies**: Rolling update and Argo Rollouts
- ✅ **Blue-Green Rollouts**: Zero-downtime deployments with quick rollback
- ✅ **GitOps with ArgoCD**: Automated synchronization from Git
- ✅ **Auto-sync & Self-healing**: ArgoCD policies for consistency
- ✅ **ServiceMonitor**: Prometheus scraping configuration

## 📁 Project Structure

```
Task-2/
├── app.py                          # Flask application with observability
├── Dockerfile                      # Production-ready Docker image
├── requirements.txt                # Python dependencies
├── pyproject.toml                  # Project configuration & tool settings
├── README.md                       # This file
├── tests/
│   ├── __init__.py
│   └── test_app.py                 # Unit tests for Flask app
└── k8s/                            # Kubernetes manifests
    ├── base/                       # Kustomize base configuration
    │   ├── deployment.yaml         # Flask app deployment
    │   ├── service.yaml            # Kubernetes service
    │   ├── servicemonitor.yaml     # Prometheus scraping config
    │   └── kustomization.yaml      # Kustomize configuration
    ├── overlays/                   # Environment-specific configs
    │   ├── staging/
    │   └── production/
    ├── argocd/                     # ArgoCD applications
    │   ├── appproject.yaml         # ArgoCD project definition
    │   ├── staging-app.yaml        # Staging deployment config
    │   ├── production-app.yaml     # Production deployment config
    │   └── bluegreen-app.yaml      # Blue-green deployment config
    └── rollouts/                   # Argo Rollouts configurations
        ├── bluegreen-rollout.yaml  # Blue-green rollout strategy
        ├── analysis-template.yaml  # Rollout analysis metrics
        ├── services.yaml           # Rollout-specific services
        └── kustomization.yaml      # Rollouts kustomization
```

## 🚀 Getting Started

### Prerequisites

- Docker & Docker Compose
- Python 3.11+
- kubectl
- git
- ArgoCD CLI (optional, for manual ArgoCD operations)
- Argo Rollouts kubectl plugin (optional, for manual rollout management)

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/roshan2152/dodo-assign.git
   cd dodo-assign/Task-2
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the application:**
   ```bash
   python app.py
   ```
   - Home endpoint: `http://localhost:8080/`
   - Health check: `http://localhost:8080/health`
   - Metrics: `http://localhost:8080/metrics`

4. **Run tests:**
   ```bash
   pytest tests/ -v
   ```

### Docker Build

```bash
# Build image
docker build -t flask-app:v1.0.0 .

# Run container
docker run -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317 \
  flask-app:v1.0.0

# Test container
curl http://localhost:8080/health
```

## 📊 Application Details

### Flask Endpoints

| Endpoint | Method | Description | Status Code |
|----------|--------|-------------|------------|
| `/` | GET | Returns greeting message | 200 |
| `/health` | GET | Returns health status with version | 200 |
| `/metrics` | GET | Prometheus metrics endpoint (auto-exposed) | 200 |

### Observability Stack

#### Prometheus Metrics
- Flask app info metrics
- Request/response metrics
- HTTP status codes
- Latency histograms

**Example query:** `rate(flask_http_request_duration_seconds[5m])`

#### OpenTelemetry Tracing
- Distributed tracing support
- Integration with Tempo backend
- Auto-instrumentation of Flask requests
- Span context propagation

**Configuration:**
```python
OTEL_EXPORTER_OTLP_ENDPOINT: tempo.monitoring.svc.cluster.local:4317
```

#### Structured Logging
- JSON-formatted logs for log aggregation
- Compatible with: ELK Stack, Loki, DataDog
- Example log format:
  ```json
  {"time":"2024-03-01 10:30:45,123", "level":"INFO", "message":"Home endpoint accessed", "name":"__main__"}
  ```

### Docker Image Features

- **Base**: `python:3.11-slim-bookworm` (minimal, ~125MB)
- **Non-root user**: `appuser:1000` for security
- **Production server**: Gunicorn with 2 workers, 4 threads
- **Health checks**: Built-in liveness and readiness probes
- **Layer caching**: Optimized for fast rebuilds

## 🎯 Kubernetes Deployment

### Base Configuration (`k8s/base`)

Standard Flask app deployment with:
- 2 replicas for high availability
- Rolling update strategy (maxSurge: 1, maxUnavailable: 0)
- Container port: 8080
- Resource requests: 128Mi memory
- Liveness probe: HTTP GET to "/" every 10 seconds
- Readiness probe: HTTP GET to "/" every 5 seconds

### Environment Overlays

#### Staging (`k8s/overlays/staging`)
- Uses rolling deployment strategy
- Lower resource quotas
- Auto-sync enabled in ArgoCD
- For development and testing

#### Production (`k8s/overlays/production`)
- Uses Argo Rollouts for advanced deployments
- Higher resource quotas
- Manual sync for controlled releases
- Multi-phase rollout strategy

### ArgoCD GitOps Setup

#### Applications Configured

| App | Path | Strategy | Sync |
|-----|------|----------|------|
| `flask-app-staging` | `Task-2/k8s/overlays/staging` | RollingUpdate | Auto |
| `flask-app-production` | `Task-2/k8s/overlays/production` | Argo Rollouts | Manual |
| `flask-app-bluegreen` | `Task-2/k8s/rollouts` | Blue-Green | Manual |

#### ArgoCD Sync Policies
- **Auto-sync enabled**: For staging and test environments
- **Manual sync enabled**: For production deployments
- **Prune enabled**: Remove resources not in Git
- **Self-heal enabled**: Revert manual kubectl changes
- **Retry limit**: 5 attempts before marking as failed

### Argo Rollouts Deployment

#### Blue-Green Strategy Overview

Blue-Green deployment is a **zero-downtime deployment strategy** where two identical production environments run simultaneously:

```
BEFORE DEPLOYMENT:
┌──────────────────────┐
│   ACTIVE (GREEN)     │ ← All users here
│  Flask v1.0 (3 pods) │
└──────────────────────┘

NEW VERSION ARRIVES:
┌──────────────────────┐        ┌──────────────────────┐
│   ACTIVE (GREEN)     │        │   IDLE (BLUE)        │
│  Flask v1.0 (3 pods) │  ←→    │  Flask v2.0 (3 pods) │
└──────────────────────┘        └──────────────────────┘
   ↑                                    ↑
   Active (production)            Testing/Warm-up

AFTER PROMOTION:
┌──────────────────────┐        ┌──────────────────────┐
│   IDLE (GREEN)       │        │   ACTIVE (BLUE)      │
│  Flask v1.0 (3 pods) │  ←→    │  Flask v2.0 (3 pods) │
└──────────────────────┘        └──────────────────────┘
   Scales down                      ↑ All users switched here
                                    (instant switchover!)
```

#### Deployment Workflow

**Step 1: Deploy New Version**
```bash
# New v2.0 deployed alongside v1.0
kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml -n production

# Monitor deployment
kubectl argo rollouts get rollout flask-app-bluegreen -n production --watch
```
- GREEN (v1.0): Still serves all production traffic
- BLUE (v2.0): Running but receives zero traffic (safe to test!)

**Step 2: Test New Version**
```bash
# Access the new version (BLUE) for testing
kubectl port-forward svc/flask-app-preview 8080:8080

# Test endpoints without affecting production users
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

**Step 3: Automated Analysis (Happens Automatically)**
The rollout runs pre-promotion analysis checks:
- ✅ Success rate >= 95% (checked 10 times, every 30 seconds)
- ✅ Response latency <= 500ms (checked 10 times, every 30 seconds)

If checks pass → Ready to promote  
If checks fail → Rollout aborts automatically, v1.0 stays active

**Step 4: Switch Traffic (One Command)**
```bash
# Instant traffic switch from v1.0 to v2.0
kubectl argo rollouts promote flask-app-bluegreen -n production
```

In **milliseconds**, the Kubernetes service switches to point to BLUE pods. All new requests go to v2.0!

**Step 5: Cleanup**
After 30 seconds, the old GREEN pods (v1.0) are scaled down and deleted.

#### Emergency Rollback

If v2.0 has issues **before promotion**:
```bash
# Abort immediately (anytime before 5 minutes)
kubectl argo rollouts abort flask-app-bluegreen -n production

# Result: v1.0 continues, v2.0 deleted, zero impact to users
```

If v2.0 has issues **after promotion**:
```bash
# Rollback to previous version
kubectl argo rollouts undo flask-app-bluegreen -n production

# Or use Git to revert
git revert <commit-hash>
git push origin main
# ArgoCD automatically syncs the change
```

#### Key Configuration in Your Setup

From `k8s/rollouts/bluegreen-rollout.yaml`:
```yaml
strategy:
  blueGreen:
    activeService: flask-app-active      # Service used by users
    previewService: flask-app-preview    # Service for testing
    autoPromotionEnabled: false          # Manual control
    scaleDownDelaySeconds: 30            # Keep old version 30 seconds

prePromotionAnalysis:                    # Auto-check before switching
  templates:
  - templateName: flask-app-success-rate
    
postPromotionAnalysis:                   # Safety check after switching
  templates:
  - templateName: flask-app-success-rate
```

#### Benefits

- ✅ **Zero downtime** - Users never see errors
- ✅ **Full testing** - Validate v2.0 before users see it
- ✅ **Instant rollback** - One command to revert
- ✅ **No traffic loss** - Atomic traffic switch
- ✅ **Automatic rollback** - If metrics are bad, abort automatically
- ✅ **Better than rolling updates** - No half-deployed state

#### Resource Usage

**Trade-off:** During deployment, you temporarily use 2x resources (3 GREEN + 3 BLUE = 6 pods)
- Before: 3 pods
- During: 6 pods (temporary)
- After: 3 pods

#### Deployment Workflow Timeline

Here's **exactly what happens step-by-step** when you deploy a new version:

```
TIME 0:00 → You run: kubectl apply -f bluegreen-rollout.yaml
            ├─ New v2.0 pods start (BLUE environment)
            └─ v1.0 pods still running (GREEN environment)
            
TIME 0:30 → v2.0 pods are ready and healthy
            ├─ Users: Still on v1.0 (100% traffic)
            ├─ You can now test: kubectl port-forward svc/flask-app-preview 8080:8080
            └─ Zero impact - users don't see v2.0 yet
            
TIME 1:00 → Pre-promotion analysis starts running automatically
            ├─ Check 1: v2.0 success rate >= 95%? ✅
            ├─ Check 2: v2.0 latency <= 500ms? ✅
            └─ (If any check fails, rollout aborts - v2.0 deleted)
            
TIME 3:00 → (Approx 5 minutes) Analysis checks complete
            ├─ Result: All checks PASSED ✅
            └─ Status: "Pending Promotion" (waiting for your approval)
            
TIME 3:30 → You run: kubectl argo rollouts promote flask-app-bluegreen
            ├─ Kubernetes switches service from GREEN → BLUE
            ├─ **IN MILLISECONDS**: All traffic switches to v2.0
            ├─ Users see v2.0 now (instant, atomic switch!)
            └─ Post-promotion analysis starts (double-check v2.0 is good)
            
TIME 4:00 → Post-promotion analysis completes
            └─ Status: "Healthy" (v2.0 verified after switching)
            
TIME 4:30 → Cleanup: OLD v1.0 pods scale down (30 second delay)
            ├─ v1.0 pods deleted
            └─ Only v2.0 pod running now (3 pods)

Total time: ~4.5 minutes from deploy to complete cleanup
```

#### Common Deployment Scenarios

**Scenario 1: Normal Successful Deployment**
```bash
# 1. Deploy new version
$ kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml -n production

# 2. Wait a few seconds for pods to start
$ kubectl argo rollouts get rollout flask-app-bluegreen -n production --watch

# 3. (Optional) Test the new version before switching
$ kubectl port-forward svc/flask-app-preview 8080:8080
$ curl http://localhost:8080/health  # ✅ Works great!

# 4. Automatic analysis runs (5 min), then promote
$ kubectl argo rollouts promote flask-app-bluegreen -n production

# 5. Done! Users are on v2.0, v1.0 cleaned up
```

**Scenario 2: v2.0 Has Bugs (Before Promotion)**
```bash
# 1. Deploy v2.0
$ kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml -n production

# 2. Test and find a bug 😞
$ kubectl port-forward svc/flask-app-preview 8080:8080
$ curl http://localhost:8080/  # ❌ 500 error

# 3. Abort immediately (no users affected!)
$ kubectl argo rollouts abort flask-app-bluegreen -n production

# 4. v2.0 deleted, v1.0 still running
$ kubectl get pods -n production  # Only v1.0 pods

# 5. Fix the bug, redeploy
$ # ... fix code ...
$ kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml -n production
```

**Scenario 3: v2.0 Works, But Metrics Say Otherwise**
```bash
# 1. Deploy v2.0
$ kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml -n production

# 2. Wait for automatic analysis...
# 3. Analysis FAILS: Success rate = 80% (need >= 95%) ❌

# 4. Rollout automatically aborts (no promotion!)
$ kubectl argo rollouts get rollout flask-app-bluegreen
> Status: Degraded/Failed
> Reason: Pre-promotion analysis failed

# 5. v1.0 continues serving (users never knew!)
# 6. Developer investigates and fixes the issue
```

**Scenario 4: v2.0 Good, But Issues Found After Switching**
```bash
# 1-4. Deploy, test, analysis passes, promote ✅

# 5. Uh oh! Users report slow performance 😱
$ kubectl argo rollouts undo flask-app-bluegreen -n production

# 6. Instantly rolls back to v1.0!
$ kubectl get pods -n production  # Back to v1.0

# 7. Root cause investigation
# 8. Fix and redeploy v2.0
```

#### Deployment Checklists

**Before Deploying to Production:**
- [ ] Code changes tested locally
- [ ] Docker image built and tested
- [ ] Unit tests pass: `pytest tests/ -v`
- [ ] Git commit with clear message
- [ ] Image pushed to ECR
- [ ] Updated deployment manifests in Git

**During Deployment:**
- [ ] Watch rollout progress: `kubectl argo rollouts get rollout flask-app-bluegreen -n production --watch`
- [ ] Test BLUE version: `kubectl port-forward svc/flask-app-preview 8080:8080`
- [ ] Check endpoints are working
- [ ] Monitor logs: `kubectl logs -f -l app=flask-app -n production`

**After Promotion:**
- [ ] Monitor application metrics
- [ ] Check error rates: `rate(http_requests_total{status=~"5.."}[5m])`
- [ ] Watch latency: `histogram_quantile(0.95, http_request_duration_seconds)`
- [ ] No sudden uptick in errors = success!

## 🧪 Testing

### Unit Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=. --cov-report=term-missing

# Run specific test
pytest tests/test_app.py::test_home -v
```

### Test Structure

Tests are located in `tests/test_app.py`:
- `test_home`: Validates home endpoint returns 200 OK
- All tests use Flask test client
- Can be extended with integration and load tests

### Local Docker Testing

```bash
# Build test image
docker build -t flask-app:test .

# Run container
docker run -d -p 8080:8080 --name flask-test flask-app:test

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health

# View logs
docker logs flask-test

# Cleanup
docker stop flask-test
docker rm flask-test
```

## 📝 Code Quality

### Configuration Files

#### `pyproject.toml`
Centralized configuration for development tools:
- **Black**: Code formatter (line-length: 120)
- **Pytest**: Test runner with coverage
- **Coverage**: Code coverage tracking

#### Running Tools

```bash
# Format code
black .

# Run tests with coverage
pytest

# Check formatting without changes
black --check .
```

## 🔧 Deployment Instructions

### Prerequisites for Kubernetes

1. **EKS Cluster** with kubectl access configured
2. **ArgoCD** installed in `argocd` namespace
3. **Argo Rollouts** installed in `argo-rollouts` namespace
4. **ECR Repository** for storing images
5. **ImagePullSecret** configured if using private ECR

### Deploy to Staging

```bash
# Create staging namespace
kubectl create namespace staging

# Deploy via ArgoCD
kubectl apply -f k8s/argocd/staging-app.yaml -n argocd

# Monitor deployment
kubectl get deployment -n staging -w
kubectl logs -f deployment/flask-app -n staging
```

### Deploy to Production

```bash
# Create production namespace
kubectl create namespace production

# Deploy via ArgoCD
kubectl apply -f k8s/argocd/production-app.yaml -n argocd

# Monitor with Argo Rollouts
kubectl argo rollouts get rollout flask-app -n production --watch
```

## 🔄 Rollback Procedures

### Using Argo Rollouts

```bash
# Undo to previous version
kubectl argo rollouts undo flask-app -n production

# Undo to specific revision
kubectl argo rollouts undo flask-app -n production --to-revision=3

# Abort current rollout
kubectl argo rollouts abort flask-app -n production
```

### Using kubectl

```bash
# Rollback deployment
kubectl rollout undo deployment/flask-app -n production

# Check status
kubectl rollout status deployment/flask-app -n production
```

### Using ArgoCD

```bash
# List history
argocd app history flask-app-production

# Rollback to specific revision
argocd app rollback flask-app-production <revision-id>

# Sync to rollback
argocd app sync flask-app-production
```

## 🔒 Security Features

- ✅ **Non-root container user** (UID 1000)
- ✅ **Minimal base image** (slim Python variant)
- ✅ **Health checks** (liveness & readiness)
- ✅ **CPU/Memory limits** (requests defined)
- ✅ **Prometheus metrics integration**
- ✅ **OpenTelemetry tracing support**
- ✅ **Structured logging** (JSON format)

## 📈 Scaling

The deployment is configured to handle:
- Multiple replicas (currently 2 in base, 3 in rollouts)
- Rolling updates without downtime
- Blue-green deployments for instant cutover
- Ready for HPA configuration via ArgoCD overlays

## Troubleshooting

### Application won't start locally

```bash
# Check Python version
python --version  # Should be 3.11+

# Install dependencies
pip install -r requirements.txt

# Run with verbose output
python -u app.py
```

### Docker build fails

```bash
# Clear cache
docker system prune -a

# Build with no-cache
docker build --no-cache -t flask-app:v1.0.0 .
```

### Kubernetes deployment fails

```bash
# Check pod status
kubectl get pods -n staging
kubectl describe pod <pod-name> -n staging

# Check logs
kubectl logs deployment/flask-app -n staging --all-containers

# Check events
kubectl get events -n staging --sort-by='.lastTimestamp'
```

### ArgoCD sync issues

```bash
# Check app status
argocd app get flask-app-staging

# Force sync
argocd app sync flask-app-staging --force

# Check application details
kubectl describe application flask-app-staging -n argocd
```

## Dependencies

### Python Packages
- **flask** (3.0.0): Web framework
- **werkzeug** (3.0.1): WSGI utilities
- **gunicorn** (21.2.0): Production WSGI server
- **prometheus-flask-exporter** (0.23.0): Prometheus metrics
- **opentelemetry-api** (1.21.0): Tracing API
- **opentelemetry-sdk** (1.21.0): Tracing SDK
- **opentelemetry-instrumentation-flask** (0.42b0): Flask instrumentation
- **opentelemetry-exporter-otlp-proto-grpc** (1.21.0): Tempo exporter

## 🏗️ Future Enhancements

Potential improvements:
- Add CI/CD pipeline (GitHub Actions)
- Implement canary deployments with analysis
- Add comprehensive monitoring dashboards
- Implement pod autoscaling (HPA)
- Add network policies
- Add pod security standards
- Implement sealed secrets for credential management

## 📚 Documentation References

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Prometheus Flask Exporter](https://github.com/prometheus-community/prometheus_flask_exporter)
- [OpenTelemetry Python](https://opentelemetry.io/docs/instrumentation/python/)

## 📄 License

This project is part of the dodo-assign assignment series.
