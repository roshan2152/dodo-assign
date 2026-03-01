# Flask App CI/CD Pipeline

This repository contains a complete CI/CD pipeline for deploying a Flask application to Amazon EKS using GitHub Actions, ArgoCD, and Argo Rollouts.

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────┐
│   GitHub    │────▶│   GitHub     │────▶│   Amazon    │────▶│   EKS    │
│   Push      │     │   Actions    │     │     ECR     │     │  Cluster │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────┘
                            │                                        ▲
                            │                                        │
                            ▼                                        │
                    ┌──────────────┐                                 │
                    │   Kustomize  │                                 │
                    │   Manifests  │                                 │
                    └──────────────┘                                 │
                            │                                        │
                            ▼                                        │
                    ┌──────────────┐                                 │
                    │   ArgoCD     │─────────────────────────────────┘
                    │   GitOps     │
                    └──────────────┘
```

## Features

- ✅ **Automated Linting**: Flake8, Bandit, Pylint, Black
- ✅ **Testing**: Pytest with coverage reporting
- ✅ **Security Scanning**: Trivy and Snyk
- ✅ **Container Building**: Multi-arch Docker builds
- ✅ **GitOps Deployment**: ArgoCD with auto-sync
- ✅ **Canary Deployments**: Argo Rollouts with progressive delivery
- ✅ **Blue-Green Deployments**: Zero-downtime releases
- ✅ **Auto-scaling**: HPA with CPU and memory metrics
- ✅ **Rollback Mechanisms**: Automated rollback on failure
- ✅ **Changelog Generation**: Conventional commits with git-cliff

## Prerequisites

### AWS Setup

1. **EKS Cluster**: Create an EKS cluster
   ```bash
   eksctl create cluster \
     --name flask-app-cluster \
     --region us-east-1 \
     --nodegroup-name standard-workers \
     --node-type t3.medium \
     --nodes 3 \
     --nodes-min 2 \
     --nodes-max 4 \
     --managed
   ```

2. **ECR Repository**: Create an ECR repository
   ```bash
   aws ecr create-repository \
     --repository-name flask-app \
     --region us-east-1
   ```

3. **OIDC Provider**: Set up OIDC for GitHub Actions
   ```bash
   eksctl utils associate-iam-oidc-provider \
     --cluster flask-app-cluster \
     --region us-east-1 \
     --approve
   ```

4. **IAM Role**: Create IAM role for GitHub Actions
   ```bash
   aws iam create-role \
     --role-name GitHubActionsECRRole \
     --assume-role-policy-document file://trust-policy.json

   aws iam attach-role-policy \
     --role-name GitHubActionsECRRole \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
   ```

### Kubernetes Setup

1. **Install ArgoCD**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

   # Access ArgoCD UI
   kubectl port-forward svc/argocd-server -n argocd 8080:443

   # Get initial password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Install Argo Rollouts**
   ```bash
   kubectl create namespace argo-rollouts
   kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

   # Install Argo Rollouts kubectl plugin
   brew install argoproj/tap/kubectl-argo-rollouts
   ```

3. **Install Nginx Ingress Controller**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
   ```

4. **Install cert-manager** (for TLS)
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

5. **Install Metrics Server** (for HPA)
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

## GitHub Configuration

### Required Secrets

Configure the following secrets in GitHub Settings → Secrets and variables → Actions:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::123456789012:role/GitHubActionsECRRole` |
| `ECR_REGISTRY` | ECR registry URL | `123456789012.dkr.ecr.us-east-1.amazonaws.com` |
| `ARGOCD_SERVER` | ArgoCD server URL | `https://argocd.example.com` |
| `ARGOCD_TOKEN` | ArgoCD API token | `eyJhbGciOiJIUzI1...` |
| `SNYK_TOKEN` | Snyk API token (optional) | `abc123...` |
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications (optional) | `https://hooks.slack.com/...` |

### Branch Protection Rules

Configure branch protection for `main` and `develop`:

1. **Navigate to**: Settings → Branches → Add rule

2. **Configure for `main` branch**:
   - ✅ Require a pull request before merging
   - ✅ Require approvals: 2
   - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require review from Code Owners
   - ✅ Require status checks to pass before merging
     - `lint`
     - `test`
     - `build-and-push`
   - ✅ Require branches to be up to date before merging
   - ✅ Require conversation resolution before merging
   - ✅ Require signed commits
   - ✅ Include administrators
   - ✅ Restrict who can push to matching branches
   - ✅ Allow force pushes: ❌
   - ✅ Allow deletions: ❌

3. **Configure for `develop` branch**:
   - Same as above but with 1 approval required

## Deployment Process

### Staging Deployment (develop branch)

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature develop
   ```

2. Make changes and commit:
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

3. Push and create PR:
   ```bash
   git push origin feature/my-feature
   ```

4. Once merged to `develop`:
   - CI/CD pipeline runs automatically
   - Image is built and pushed to ECR
   - Kustomize manifests are updated
   - ArgoCD syncs to staging namespace

### Production Deployment (main branch)

1. Create PR from `develop` to `main`

2. After approval and merge:
   - Full CI/CD pipeline runs
   - Changelog is automatically generated
   - Image is built with production tag
   - Kustomize production manifests are updated
   - ArgoCD syncs to production namespace
   - Canary deployment starts (if using Argo Rollouts)

## Deployment Strategies

### Standard Rolling Update

Default strategy for staging environment. Configured in `k8s/overlays/staging/kustomization.yaml`.

### Canary Deployment

Progressive traffic shifting for production:

```bash
# Monitor rollout
kubectl argo rollouts get rollout flask-app -n production --watch

# Promote to next step
kubectl argo rollouts promote flask-app -n production

# Abort rollout
kubectl argo rollouts abort flask-app -n production

# Retry rollout
kubectl argo rollouts retry flask-app -n production
```

Canary progression:
- 10% traffic for 2 minutes
- 20% traffic for 2 minutes
- 40% traffic for 3 minutes
- 60% traffic for 3 minutes
- 80% traffic for 2 minutes
- 100% traffic (full rollout)

### Blue-Green Deployment

Alternative zero-downtime strategy:

```bash
# Use blue-green rollout manifest
kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml

# Preview new version
kubectl argo rollouts get rollout flask-app-bluegreen --watch

# Promote to active
kubectl argo rollouts promote flask-app-bluegreen
```

## Rollback Procedures

### Automatic Rollback

The pipeline automatically rolls back on:
- Failed security scans (configurable)
- Failed health checks
- ArgoCD sync failures
- Argo Rollouts analysis failures

### Manual Rollback

#### Using ArgoCD

```bash
# List history
argocd app history flask-app-production

# Rollback to specific revision
argocd app rollback flask-app-production <revision-id>

# Sync to rollback
argocd app sync flask-app-production
```

#### Using Argo Rollouts

```bash
# Undo to previous version
kubectl argo rollouts undo flask-app -n production

# Undo to specific revision
kubectl argo rollouts undo flask-app -n production --to-revision=3
```

#### Using kubectl

```bash
# Rollback deployment
kubectl rollout undo deployment/flask-app -n production

# Check status
kubectl rollout status deployment/flask-app -n production
```

#### Using Git Revert

```bash
# Revert the commit
git revert <commit-hash>
git push origin main

# ArgoCD will automatically sync the previous state
```

## Monitoring and Observability

### ArgoCD Dashboard

Access ArgoCD UI to monitor deployment status:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit: https://localhost:8080
```

### Argo Rollouts Dashboard

Monitor canary deployments:
```bash
kubectl argo rollouts dashboard
# Visit: http://localhost:3100
```

### Application Logs

```bash
# View logs
kubectl logs -f deployment/flask-app -n production

# View previous logs
kubectl logs deployment/flask-app -n production --previous

# Tail logs from all pods
kubectl logs -f -l app=flask-app -n production --all-containers=true
```

### Metrics

```bash
# Check HPA status
kubectl get hpa -n production

# View pod metrics
kubectl top pods -n production

# View node metrics
kubectl top nodes
```

## Troubleshooting

### Pipeline Failures

#### Lint Job Fails
```bash
# Run locally
cd "Task 2"
flake8 . --max-line-length=120
black --check .
bandit -r . -ll
```

#### Test Job Fails
```bash
# Run tests locally
cd "Task 2"
pytest tests/ -v
```

#### Build Job Fails
```bash
# Test Docker build locally
cd "Task 2"
docker build -t flask-app:test .
docker run -p 8080:8080 flask-app:test
```

#### Security Scan Fails
```bash
# Run Trivy locally
trivy image --severity CRITICAL,HIGH flask-app:test
```

### Deployment Issues

#### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n production

# Describe pod
kubectl describe pod <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'
```

#### Image Pull Errors
```bash
# Verify ECR access
aws ecr describe-repositories --repository-names flask-app

# Check image exists
aws ecr describe-images --repository-name flask-app --region us-east-1
```

#### ArgoCD Sync Issues
```bash
# Check app status
argocd app get flask-app-production

# Force refresh
argocd app refresh flask-app-production

# Hard refresh (ignore cache)
argocd app refresh flask-app-production --hard
```

#### Canary Stuck
```bash
# Check rollout status
kubectl argo rollouts status flask-app -n production

# Check analysis
kubectl argo rollouts get rollout flask-app -n production

# Manually promote
kubectl argo rollouts promote flask-app -n production

# Abort and retry
kubectl argo rollouts abort flask-app -n production
kubectl argo rollouts retry flask-app -n production
```

## Testing the Pipeline

### Local Development

```bash
cd "Task 2"

# Run locally
python app.py

# Run tests
pytest tests/ -v

# Build and run Docker
docker build -t flask-app:local .
docker run -p 8080:8080 flask-app:local

# Test endpoint
curl http://localhost:8080
```

### Staging Testing

```bash
# Get staging URL
kubectl get ingress -n staging

# Test endpoint
curl https://staging.flask-app.example.com

# Load test
ab -n 1000 -c 10 https://staging.flask-app.example.com/
```

### Production Testing

```bash
# Test canary deployment
curl -H "X-Canary: always" https://flask-app.example.com

# Test active version
curl https://flask-app.example.com
```

## Changelog

Changelog is automatically generated using [git-cliff](https://git-cliff.org/) following [Conventional Commits](https://www.conventionalcommits.org/).

### Commit Message Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```bash
git commit -m "feat: add health check endpoint"
git commit -m "fix: resolve memory leak in request handler"
git commit -m "docs: update deployment instructions"
```

## Security Best Practices

1. **Never commit secrets** - Use GitHub Secrets for sensitive data
2. **Scan dependencies** - Trivy and Snyk run on every build
3. **Run as non-root** - Container uses non-root user (UID 1000)
4. **Read-only filesystem** - Security context configured
5. **Network policies** - Restrict pod-to-pod communication
6. **RBAC** - Minimal permissions for service accounts
7. **TLS everywhere** - All ingress traffic is encrypted
8. **Signed commits** - Branch protection requires signed commits

## Cost Optimization

1. **Use HPA** - Auto-scale based on load
2. **Node auto-scaling** - EKS cluster auto-scaler
3. **Spot instances** - Use for non-production workloads
4. **Image optimization** - Multi-stage builds, slim base images
5. **Resource limits** - Set appropriate CPU and memory limits
6. **ECR lifecycle policies** - Clean up old images

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Check ArgoCD application status
4. Review Kubernetes events and logs

## License

MIT License - See LICENSE file for details
