# Task 4: Kubernetes Security Hardening

This directory contains comprehensive security measures for hardening the Kubernetes infrastructure and application layers. The implementation covers RBAC, Pod Security, Secrets Management, Network Policies, Runtime Security, and TLS encryption.

## 🏗️ Infrastructure Organization

All security components are deployed in **separate, dedicated namespaces** for isolation and management:

- **vault** - HashiCorp Vault (Helm-deployed, dev mode)
- **audit** - Kubernetes audit logging
- **falco** - Runtime security monitoring
- **cert-manager** - mTLS certificate management
- **voting-app** - Application layer (RBAC, network policies, security context)
- **monitoring** - Observability stack (existing)

## 📋 Overview

Security implementation across 8 layers:

```
Layer 1: Authentication & Authorization (RBAC)
Layer 2: Pod Security Standards (PSS)
Layer 3: Secrets Management (Vault)
Layer 4: Network Segmentation (Network Policies)
Layer 5: Runtime Security (Falco)
Layer 6: Audit Logging (API Server)
Layer 7: Image Security (Scanning & Signing)
Layer 8: Encrypted Communication (mTLS)
```

## 📁 Directory Structure & Namespace Organization

```
Task 4/
├── rbac/                          # RBAC - voting-app namespace
│   ├── 01-namespaces-and-serviceaccounts.yaml
│   ├── 02-roles.yaml
│   └── 03-rolebindings.yaml
├── pod-security/                  # PSS - voting-app namespace
│   ├── pod-security-standards.yaml
│   └── secure-pod-example.yaml
├── vault/                         # Vault - vault namespace (Helm deployed)
│   ├── vault-auth-kubernetes.yaml
│   └── external-secrets-operator.yaml
├── network-policies/              # NP - voting-app namespace
│   └── network-policies.yaml
├── falco/                         # Falco - falco namespace
│   └── falco-deployment.yaml
├── audit/                         # Audit - audit namespace
│   └── audit-policy.yaml
├── image-security/                # Image Security
│   └── ci-cd-integration.sh
├── mtls/                          # mTLS - voting-app & cert-manager namespaces
│   └── mtls-cert-manager.yaml
└── README.md                      # This file

NAMESPACE DISTRIBUTION:
- vault (default Helm deployment)
- audit (audit log collector)
- falco (runtime security)
- cert-manager (mTLS certificates)
- voting-app (application with RBAC, network policies, etc.)
- monitoring (existing observability stack)
```

---

## 🔐 Layer 1: RBAC (Role-Based Access Control)

**Purpose:** Enforce least-privilege access with three roles: Admin, Operator, Developer

**Location:** `voting-app` namespace

**Files:**
- `rbac/01-namespaces-and-serviceaccounts.yaml` - Service accounts
- `rbac/02-roles.yaml` - Role definitions
- `rbac/03-rolebindings.yaml` - Bind roles to service accounts

**Status:** ✅ Deployed

**Deployment:**
```bash
kubectl apply -f rbac/
```

**Roles:**
- **Admin:** Full access (all verbs on all resources)
- **Operator:** Can manage deployments, scale, view logs (no delete)
- **Developer:** Read-only access, no sensitive operations

**Testing RBAC:**
```bash
# Get token for developer service account
TOKEN=$(kubectl -n voting-app create token developer)

# Make request with token
kubectl --token=$TOKEN -n voting-app get pods        # ✅ Works
kubectl --token=$TOKEN -n voting-app delete pod xyz   # ❌ Denied
```

---

## 🛡️ Layer 2: Pod Security Standards (PSS)

**Purpose:** Enforce container security constraints at the pod level

**Files:**
- `pod-security/pod-security-standards.yaml` - Namespace PSS labels
- `pod-security/secure-pod-example.yaml` - Example compliant pod

**Deployment:**
```bash
kubectl apply -f pod-security/pod-security-standards.yaml
```

**Restrictions Enforced:**
- ✅ No privileged containers
- ✅ No privilege escalation
- ✅ Read-only root filesystem
- ✅ No host network/PID/IPC
- ✅ No root user (runAsNonRoot)
- ✅ Drop all Linux capabilities

**Verify:**
```bash
# Check namespace labels
kubectl get ns voting-app -o yaml | grep pod-security

# Try to deploy a non-compliant pod (should fail)
kubectl apply -f pod-security/secure-pod-example.yaml
```

---

## 🔑 Layer 3: Secrets Management (HashiCorp Vault)

**Purpose:** Centralized secret storage with encryption and access control

**Location:** `vault` namespace

**Status:** ✅ Running in Dev Mode

**Quick Start:**

Vault is already deployed via Helm in dev mode (auto-unsealed, single pod):

```bash
# Access Vault UI with port-forward
kubectl port-forward -n vault svc/vault 8200:8200

# Shell into Vault pod
kubectl exec -it -n vault vault-0 -- sh

# Inside pod, use Vault CLI
vault status                  # Check status
vault secrets list            # List secret engines
vault write secret/test-secret data=value
vault read secret/test-secret
```

**Dev Mode Advantages:**
- ✅ Automatic unsealing (no keys needed)
- ✅ In-memory storage (no persistence needed)
- ✅ Perfect for learning and testing
- ✅ Single pod deployment

**Reference Files:**
- `vault/vault-auth-kubernetes.yaml` - K8s authentication setup guide
- `vault/external-secrets-operator.yaml` - Secret syncing configuration (requires ESO installation)

---

## 🌐 Layer 4: Network Segmentation (Network Policies)

**Purpose:** Control traffic flow between pods using deny-by-default principle

**Location:** `voting-app` namespace

**Files:**
- `network-policies/network-policies.yaml` - All policies

**Status:** ✅ Deployed

**Deployment:**
```bash
kubectl apply -f network-policies/network-policies.yaml
```

**Policy Types:**
1. **Default Deny** - Block all traffic by default
2. **DNS Access** - Allow DNS for service discovery
3. **Kubernetes API** - Allow K8s API access
4. **Ingress Controller** - Allow external traffic
5. **Inter-pod Communication** - Allow specific pod-to-pod traffic
6. **Database Access** - Allow worker/result to DB
7. **Vault Access** - Allow K8s to Vault

**Test Network Policies:**
```bash
# Try to access blocked pod (should timeout)
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://vote:8080

# Enable communication
kubectl label pod vote-pod security=allow-nginx

# Try again (should work)
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://vote:8080
```

---

## 🚨 Layer 5: Runtime Security (Falco)

**Purpose:** Real-time detection of suspicious runtime behavior

**Location:** `falco` namespace

**Status:** ✅ Deployed (via Helm)

**Deployment Method:** HashiCorp Helm Chart with eBPF mode

Falco is deployed using the official Falco Helm chart following the [Falco Kubernetes Quickstart](https://falco.org/docs/getting-started/falco-kubernetes-quickstart/) documentation.

**Why eBPF Mode?**
- ✅ No kernel module compilation required
- ✅ Works on managed Kubernetes (EKS, GKE, AKS)
- ✅ Requires Linux kernel 4.14+ (available on most modern clusters)
- ✅ Better performance and isolation
- ✅ No kernel headers dependency

**Files:**
- `falco/falco-deployment.yaml` - Legacy deployment (replaced by Helm)
- `falco-helm-values.yaml` - Helm values configuration

**Deployment (via Helm):**
```bash
# 1. Add Falco Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# 2. Install Falco with eBPF enabled
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set ebpf.enabled=true \
  --set serviceAccount.create=true \
  --set rbac.create=true \
  --set falco.grpc.enabled=true
```

**Verify Deployment:**
```bash
# Check pods
kubectl get pods -n falco
# Expected: 2 pods running (2/2 ready) - one per node

# Check logs
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20
```

**View Falco Alerts:**
```bash
# Stream real-time alerts
kubectl -n falco logs -f -l app.kubernetes.io/name=falco | grep "CRITICAL\|WARNING"

# Search for specific rule triggers
kubectl -n falco logs -l app.kubernetes.io/name=falco | grep "Sensitive file opened"
```

**Built-in Rules Monitored:**
- Suspicious process execution (bash, wget, curl)
- Unauthorized privilege escalation (sudo misuse)
- Sensitive file access (/etc/passwd, /etc/shadow)
- Network reconnaissance (nc, nmap)
- Container escape attempts
- Package management tools execution
- Kernel module loading
- Unauthorized network connections

**Helm Chart Version:**
- Falco Chart: 8.0.1+
- Falco Runtime: 0.43.0+
- eBPF enabled by default

**Custom Rules (Optional):**
To add custom Falco rules, create a ConfigMap and mount it:
```bash
kubectl create configmap falco-custom-rules \
  --from-file=custom-rules.yaml \
  -n falco
```

---

## 📋 Layer 6: Audit Logging (Kubernetes API)

**Purpose:** Log all API server events for compliance and forensics

**Location:** `audit` namespace

**Status:** ✅ Deployed

**Files:**
- `audit/audit-policy.yaml` - Audit policy configuration and collector

**Deployment:**
```bash
kubectl apply -f audit/
```

**API Server Integration (Requires Manual Setup):**

To enable audit logging on your cluster's API server:

```bash
# 1. Copy audit policy to API server node
sudo cp audit/audit-policy-config.yaml /etc/kubernetes/audit/

# 2. Edit kube-apiserver manifest  
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

# 3. Add these flags:
# - --audit-policy-file=/etc/kubernetes/audit/audit-policy-config.yaml
# - --audit-log-path=/var/log/kubernetes/audit.log
# - --audit-log-maxage=30
# - --audit-log-maxbackup=5
```

**View Audit Logs:**
```bash
# From API server node
sudo tail -f /var/log/kubernetes/audit.log | jq .

# Filter by resource
sudo cat /var/log/kubernetes/audit.log | jq 'select(.objectRef.resource=="secrets")'
```

**Policy Coverage:**
- ✅ All secrets access
- ✅ Pod exec/attach
- ✅ Deployment changes
- ✅ Authentication events
- ✅ Resource deletions

---

## 🖼️ Layer 7: Image Security (Scanning & Signing)

**Purpose:** Prevent deployment of vulnerable or unsigned images

**Files:**
- `image-security/image-security-policies.yaml` - Kyverno policies & Trivy
- `image-security/ci-cd-integration.sh` - CI/CD integration script

**Deployment:**
```bash
# Install Kyverno for policy enforcement
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Deploy image security policies
kubectl apply -f image-security/image-security-policies.yaml

# Deploy Trivy vulnerability scanner
kubectl apply -f image-security/image-security-policies.yaml
```

**Policies Enforced:**
1. **Registry Whitelist** - Only approved registries (docker.io, gcr.io, quay.io)
2. **Image Scanning** - Require scan results annotation
3. **No Privileged Images** - Prevent privileged containers
4. **Image Digest** - Use @sha256 instead of tags

**CI/CD Integration:**
```bash
# Make script executable
chmod +x image-security/ci-cd-integration.sh

# Scan image
./image-security/ci-cd-integration.sh scan myapp:latest

# Sign image
./image-security/ci-cd-integration.sh sign myapp:latest

# Verify signature
./image-security/ci-cd-integration.sh verify myapp:latest cosign.pub

# Generate SBOM
./image-security/ci-cd-integration.sh sbom myapp:latest
```

**Generate Signing Keys:**
```bash
cosign generate-key-pair  # Creates cosign.key and cosign.pub

# Sign image with Cosign
cosign sign --key cosign.key docker.io/myapp:latest
```

---

## 🔗 Layer 8: mTLS (Mutual TLS)

**Purpose:** Encrypt all inter-service communication with mutual authentication

**Files:**
- `mtls/mtls-cert-manager.yaml` - Cert-manager setup with certificates

**Prerequisites:**
```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set installCRDs=true
```

**Deployment:**
```bash
kubectl apply -f mtls/mtls-cert-manager.yaml
```

**Certificate Types:**
- Self-signed CA (for lab)
- Service certificates signed by CA
- Namespace-scoped issuers
- Auto-renewal support

**Verify Certificates:**
```bash
# Check certificate status
kubectl get certificated -n voting-app
kubectl describe cert vote-service-cert -n voting-app

# View TLS secret
kubectl get secret vote-service-tls -n voting-app -o yaml

# Extract and inspect certificate
kubectl get secret vote-service-tls -n voting-app -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

**Application Integration:**
```bash
# Mount TLS certs in deployment
volumeMounts:
- name: tls-certs
  mountPath: /etc/tls/certs
  readOnly: true
volumes:
- name: tls-certs
  secret:
    secretName: vote-service-tls

# Set environment variables
- name: TLS_CERT_PATH
  value: "/etc/tls/certs/tls.crt"
- name: TLS_KEY_PATH
  value: "/etc/tls/certs/tls.key"
- name: CA_CERT_PATH
  value: "/etc/tls/certs/ca.crt"
```

---

## 🚀 Deployment Order (Recommended)

Deploy security layers in this order for foundation building:

```bash
# 1. Add Helm repositories (if not already added)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# 2. RBAC (foundation)
kubectl apply -f rbac/

# 3. Pod Security Standards
kubectl apply -f pod-security/

# 4. Network Policies (before Vault)
kubectl apply -f network-policies/

# 5. Vault (via Helm - dev mode)
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.dev.enabled=true"

# 6. Audit Logging
kubectl apply -f audit/

# 7. Falco Runtime Security (via Helm - eBPF enabled)
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set ebpf.enabled=true \
  --set serviceAccount.create=true \
  --set rbac.create=true

# 8. Image Security
kubectl apply -f image-security/

# 9. mTLS with Certificates (optional - requires cert-manager pre-installed)
# kubectl apply -f mtls/
```

**Complete Deployment Script:**
```bash
#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Adding Helm repositories..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

echo "1️⃣  Deploying RBAC..."
kubectl apply -f rbac/

echo "2️⃣  Deploying Pod Security Standards..."
kubectl apply -f pod-security/

echo "3️⃣  Deploying Network Policies..."
kubectl apply -f network-policies/

echo "4️⃣  Installing Vault via Helm..."
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.dev.enabled=true" \
  --wait

echo "5️⃣  Deploying Audit Logging..."
kubectl apply -f audit/

echo "6️⃣  Installing Falco via Helm..."
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set ebpf.enabled=true \
  --set serviceAccount.create=true \
  --set rbac.create=true \
  --wait

echo "7️⃣  Deploying Image Security..."
kubectl apply -f image-security/

echo "✅ Deployment complete!"
echo ""
echo "Verify deployments:"
echo "  VAULT:    kubectl get pods -n vault"
echo "  FALCO:    kubectl get pods -n falco"
echo "  AUDIT:    kubectl get pods -n audit"
echo "  RBAC:     kubectl get roles -n voting-app"
echo "  NETPOL:   kubectl get networkpolicies -n voting-app"
```

---

## ✅ Security Checklist

- [ ] RBAC configured with 3 roles (admin, operator, developer)
- [ ] Pod Security Standards enforced at namespace level
- [ ] Vault deployed and initialized
- [ ] External Secrets Operator syncing K8s secrets from Vault
- [ ] Network policies denying all traffic by default
- [ ] Falco DaemonSet running on all nodes
- [ ] Audit logging enabled on API server
- [ ] Image scanning policies enforced via Kyverno
- [ ] Image signing script integrated in CI/CD
- [ ] Certificates generated and mTLS enabled
- [ ] All pods running as non-root
- [ ] All containers with read-only root filesystem

---

## 🆘 Troubleshooting

**Vault Pod Stuck in Init:**
```bash
kubectl logs -n default <vault-pod> -c vault
# Usually needs more time - increase initialDelaySeconds
```

**Network Policies Too Restrictive:**
```bash
# Temporarily allow all traffic for debugging
kubectl delete networkpolicies --all -n voting-app
# Re-apply with refined rules
```

**Falco Alerts Not Appearing:**
```bash
# Check Falco logs
kubectl -n falco logs -f -l app=falco
# Ensure host mounts are correct
```

**Certificate Not Ready:**
```bash
# Check cert-manager controller logs
kubectl -n cert-manager logs -f -l app=cert-manager

# Check certificate status
kubectl describe cert <cert-name> -n voting-app
```

---

## 📚 Additional Resources

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Falco Documentation](https://falco.org/)
- [cert-manager](https://cert-manager.io/)
- [Kyverno Policies](https://kyverno.io/)

---

## 🎯 Bonus Tasks Status

✅ **Audit Logging** - Implemented in Layer 6  
✅ **Runtime Security (Falco)** - Implemented in Layer 5  
⏳ **CIS Benchmark Checks** - Manual: `kubectl-bench` or `kubesec`  
⏳ **Compliance Scanning** - Use tools like Polaris, Kubewarden

---

**Last Updated:** March 2026  
**Status:** Implementation Complete ✅
