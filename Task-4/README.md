## Test Result : 

# Task-4: Kubernetes Security Hardening

## Overview

Implemented comprehensive zero-trust security architecture with 8 layers of defense:
1. Role-Based Access Control (RBAC) — Least privilege service accounts
2. Pod Security Standards (PSS) — Prevent privilege escalation
3. Secret Management — HashiCorp Vault integration
4. Network Policies — Microsegmentation and lateral movement prevention
5. Runtime Security — Falco threat detection
6. Audit Logging — API server compliance logging
7. Image Security — Vulnerability scanning and signature verification
8. Mutual TLS — Encrypted service-to-service communication

## How It Works

### Layer 1: RBAC — Least Privilege Access (3 Roles)
**Files:** `rbac/01-namespaces-and-serviceaccounts.yaml`, `rbac/02-roles.yaml`, `rbac/03-rolebindings.yaml`

Implemented three distinct roles per role-based function:
- **Admin Role** — Full cluster management (create, update, delete all resources)
- **Operator Role** — View and manage deployments/statefulsets/pods (monitoring/scaling, no deletion)
- **Developer Role** — Logs and exec access only (debugging without infrastructure changes)

ServiceAccounts in each role cannot exceed their defined permissions, preventing privilege escalation attacks.
Tested via RBAC evaluation: Only appropriate role can perform its operations.

### Layer 2: Pod Security Standards (PSS)
**Files:** `pod-security/pod-security-standards.yaml`, `pod-security/secure-pod-example.yaml`

Enforces constraints on pod creation:
- `runAsNonRoot: true` — Prevents running as root (pid 0), eliminating container escape → host root compromise
- `allowPrivilegeEscalation: false` — Blocks `setuid` binaries from elevating pod user
- `readOnlyRootFilesystem: true` — Prevents malware from persisting on filesystem
- `securityContext.capabilities.drop: ALL` — Blocks dangerous Linux capabilities (CAP_NET_RAW, CAP_SYS_ADMIN)
- `securityContext.capabilities.add: [NET_BIND_SERVICE]` — Only adds explicitly needed capabilities

Violations are detected and prevents pod scheduling when constraints are violated.

### Layer 3: Secret Management (Vault + Kubernetes Auth)
**Files:** `vault/vault-deployment.yaml`, `vault/vault-auth-kubernetes.yaml`, `vault/external-secrets-operator.yaml`

Secrets never stored in Git or ConfigMaps:
- HashiCorp Vault runs in cluster
- Kubernetes auth method — Pod RBAC token authenticates to Vault
- External Secrets Operator syncs secrets from Vault → Kubernetes Secrets
- Application reads from Kubernetes Secrets (synced from Vault)
- Automatic secret rotation via ESO reconciliation
- Audit trail in Vault for all secret access

### Layer 4: Network Policies (Microsegmentation)
**Files:** `network-policies/network-policies.yaml`

Implements zero-trust networking:
- Default-deny ingress: All pods deny incoming traffic by default
- Default-deny egress: All pods deny outgoing traffic by default
- Explicit allow rules create trusted paths:
  - Flask app accepts traffic only from ingress controller
  - Worker accepts traffic only from message queue
  - Database accepts traffic only from app pods (label selector `app: flask-app`)
- Prevents lateral movement after pod compromise
- Blocks data exfiltration to external IPs

### Layer 5: Runtime Security (Falco)
**Files:** `falco/falco-deployment.yaml`, `falco/falco-helm-values.yaml`

Detects threats at container runtime:
- Monitors syscalls for:
  - Privilege escalation attempts (`setuid` calls, capability add)
  - Unauthorized file access (write to system files, read from sensitive paths)
  - Process execution anomalies (unexpected binaries, shell spawned in container)
  - Network anomalies (unauthorized connections)
- Falco rules trigger alerts when suspicious patterns detected
- Supports Kubernetes events integration for pod killing

### Layer 6: Audit Logging (Kubernetes API Server)
**Files:** `audit/audit-policy.yaml`

Logs all API server activity:
- **Who**: User/ServiceAccount making the request
- **What**: API endpoint and operation (create/update/delete/watch)
- **When**: Timestamp
- **Where**: Namespace and resource name
- **Why**: Request reason field

Logs captured for:
- Secret/ConfigMap access (secrets management audit trail)
- RBAC changes (detect unauthorized role/rolebinding modifications)
- Pod creation/deletion (container lifecycle tracking)
- Failures (failed authentication, authorization denials)

Essential for compliance (HIPAA, PCI-DSS) and incident forensics.

### Layer 7: Image Security (Vulnerability Scanning + Signing)
**Files:** `image-security/image-security-policies.yaml`, `image-security/ci-cd-integration.sh`

Prevents vulnerable and tampered container images:
- CI/CD pipeline scans images with Trivy for CVEs
- Failed scan blocks image push to ECR
- Image signing via Cosign — proves image built by trusted CI/CD
- Admission controller verifies image signature before pod scheduling
- Blocks unsigned or tampered images from running
- Protects against supply chain attacks

### Layer 8: Mutual TLS (mTLS)
**Files:** `mtls/mtls-cert-manager.yaml`

Encrypts all service-to-service communication:
- cert-manager auto-issues X.509 certificates for each pod
- Sidecar proxy (Istio/Linkerd) intercepts connections
- Mutual authentication: Client verifies server cert, server verifies client cert
- TLS encryption: All traffic encrypted with AES-256-GCM
- Certificate rotation: Automatic renewal before expiry
- Protects against man-in-the-middle attacks and network sniffing

## Files

**RBAC (3 files):**
- `rbac/01-namespaces-and-serviceaccounts.yaml` — Namespaces and service accounts
- `rbac/02-roles.yaml` — Admin, Operator, Developer roles
- `rbac/03-rolebindings.yaml` — Bind roles to service accounts

**Pod Security (2 files):**
- `pod-security/pod-security-standards.yaml` — Cluster-wide PSS enforcement
- `pod-security/secure-pod-example.yaml` — Example secure pod

**Vault (3 files):**
- `vault/vault-deployment.yaml` — Vault server
- `vault/vault-auth-kubernetes.yaml` — Kubernetes auth method
- `vault/external-secrets-operator.yaml` — Secret syncing to K8s

**Network Policies (1 file):**
- `network-policies/network-policies.yaml` — Ingress/egress rules

**Falco (2 files):**
- `falco/falco-deployment.yaml` — Falco DaemonSet
- `falco/falco-helm-values.yaml` — Configuration

**Audit (1 file):**
- `audit/audit-policy.yaml` — Audit logging rules

**Image Security (1 file):**
- `image-security/image-security-policies.yaml` — Scanning and signing

**mTLS (1 file):**
- `mtls/mtls-cert-manager.yaml` — cert-manager configuration


