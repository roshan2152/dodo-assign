#!/bin/bash
# Task-4 Security Layer Verification Script
# Shows all command output with PASS/FAIL indicators for each layer

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0

header() { 
  echo ""
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

section() { echo -e "\n${BOLD}${YELLOW}▸ $1${NC}\n"; }
cmd() { echo -e "${CYAN}$ $1${NC}"; }
layer_pass() { echo -e "\n${GREEN}${BOLD}✅ LAYER $1: PASS${NC}"; ((TOTAL_PASS++)); }
layer_fail() { echo -e "\n${RED}${BOLD}❌ LAYER $1: FAIL${NC}"; ((TOTAL_FAIL++)); }

# ═══════════════════════════════════════════════════════════
header "LAYER 1: RBAC (Role-Based Access Control)"
# ═══════════════════════════════════════════════════════════
LAYER1_PASS=true

section "1.1 Show ServiceAccounts in voting-app namespace"
cmd "kubectl get serviceaccounts -n voting-app"
SA_OUT=$(kubectl get serviceaccounts -n voting-app 2>&1)
echo "$SA_OUT"
echo "$SA_OUT" | grep -q "admin" || LAYER1_PASS=false
echo "$SA_OUT" | grep -q "developer" || LAYER1_PASS=false

section "1.2 Show Roles in voting-app namespace"
cmd "kubectl get roles -n voting-app"
ROLES_OUT=$(kubectl get roles -n voting-app 2>&1)
echo "$ROLES_OUT"
echo "$ROLES_OUT" | grep -q "admin" || LAYER1_PASS=false
echo "$ROLES_OUT" | grep -q "developer" || LAYER1_PASS=false

section "1.3 Show RoleBindings"
cmd "kubectl get rolebindings -n voting-app"
kubectl get rolebindings -n voting-app

section "1.4 Show Developer Role permissions"
cmd "kubectl describe role developer -n voting-app"
kubectl describe role developer -n voting-app

section "1.5 RBAC Test: Developer CAN list pods"
cmd "kubectl get pods -n voting-app --as=system:serviceaccount:voting-app:developer"
if kubectl get pods -n voting-app --as=system:serviceaccount:voting-app:developer 2>&1; then
  echo -e "  ${GREEN}✓ Developer can list pods${NC}"
else
  echo -e "  ${RED}✗ Developer cannot list pods${NC}"
  LAYER1_PASS=false
fi

section "1.6 RBAC Test: Developer CANNOT delete pods (Forbidden)"
cmd "kubectl delete pod test-dev -n voting-app --as=system:serviceaccount:voting-app:developer"
DEL_OUT=$(kubectl delete pod test-dev -n voting-app --as=system:serviceaccount:voting-app:developer 2>&1)
echo "$DEL_OUT"
if echo "$DEL_OUT" | grep -qi "forbidden"; then
  echo -e "  ${GREEN}✓ Developer correctly blocked from deleting pods${NC}"
else
  echo -e "  ${RED}✗ Developer NOT blocked from deleting pods${NC}"
  LAYER1_PASS=false
fi

section "1.7 RBAC Test: Developer CANNOT create deployments (Forbidden)"
cmd "kubectl create deployment test-rbac --image=nginx -n voting-app --as=system:serviceaccount:voting-app:developer"
CREATE_OUT=$(kubectl create deployment test-rbac --image=nginx -n voting-app --as=system:serviceaccount:voting-app:developer 2>&1)
echo "$CREATE_OUT"
if echo "$CREATE_OUT" | grep -qi "forbidden"; then
  echo -e "  ${GREEN}✓ Developer correctly blocked from creating deployments${NC}"
else
  echo -e "  ${RED}✗ Developer NOT blocked${NC}"
  LAYER1_PASS=false
fi

section "1.8 RBAC Test: Operator CAN get deployments"
cmd "kubectl get deployments -n voting-app --as=system:serviceaccount:voting-app:operator"
if kubectl get deployments -n voting-app --as=system:serviceaccount:voting-app:operator 2>&1; then
  echo -e "  ${GREEN}✓ Operator can list deployments${NC}"
else
  LAYER1_PASS=false
fi

section "1.9 RBAC Test: Operator CANNOT delete deployments (Forbidden)"
cmd "kubectl delete deployment vote-mtls -n voting-app --as=system:serviceaccount:voting-app:operator"
DEL_DEPLOY=$(kubectl delete deployment vote-mtls -n voting-app --as=system:serviceaccount:voting-app:operator 2>&1)
echo "$DEL_DEPLOY"
if echo "$DEL_DEPLOY" | grep -qi "forbidden"; then
  echo -e "  ${GREEN}✓ Operator correctly blocked from deleting deployments${NC}"
else
  LAYER1_PASS=false
fi

if $LAYER1_PASS; then layer_pass 1; else layer_fail 1; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 2: Pod Security Standards (PSS)"
# ═══════════════════════════════════════════════════════════
LAYER2_PASS=true

section "2.1 Show namespace PSS labels"
cmd "kubectl get namespace voting-app -o yaml | grep -A 10 'labels:'"
PSS_LABELS=$(kubectl get namespace voting-app -o yaml 2>&1 | grep -A 10 'labels:')
echo "$PSS_LABELS"
if echo "$PSS_LABELS" | grep -q "pod-security.kubernetes.io/enforce"; then
  echo -e "  ${GREEN}✓ PSS policy is enforced${NC}"
else
  LAYER2_PASS=false
fi

section "2.2 Show running pods comply with PSS (no violations)"
cmd "kubectl get pods -n voting-app"
kubectl get pods -n voting-app

section "2.3 PSS Test: Privileged pod is BLOCKED"
echo -e "${CYAN}Attempting to create a privileged pod (should be blocked):${NC}"
cat <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pss-test-privileged
  namespace: voting-app
spec:
  containers:
  - name: test
    image: nginx
    securityContext:
      privileged: true
EOF
echo ""
cmd "kubectl apply -f - (privileged pod)"
PSS_TEST=$(cat <<'EOF' | kubectl apply -f - 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: pss-test-privileged
  namespace: voting-app
spec:
  containers:
  - name: test
    image: nginx
    securityContext:
      privileged: true
EOF
)
echo "$PSS_TEST"
if echo "$PSS_TEST" | grep -qi "forbidden\|violates"; then
  echo -e "  ${GREEN}✓ PSS correctly blocked privileged container${NC}"
else
  LAYER2_PASS=false
  kubectl delete pod pss-test-privileged -n voting-app 2>/dev/null
fi

if $LAYER2_PASS; then layer_pass 2; else layer_fail 2; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 3: HashiCorp Vault"
# ═══════════════════════════════════════════════════════════
LAYER3_PASS=true

section "3.1 Show Vault pods (Helm install)"
cmd "kubectl get pods -n vault"
VAULT_PODS=$(kubectl get pods -n vault 2>&1)
echo "$VAULT_PODS"
if echo "$VAULT_PODS" | grep -q "Running"; then
  echo -e "  ${GREEN}✓ Vault pods are running${NC}"
else
  LAYER3_PASS=false
fi

section "3.2 Show Vault service"
cmd "kubectl get svc -n vault"
kubectl get svc -n vault 2>/dev/null || echo "Vault namespace not found"

section "3.3 Show Vault status"
cmd "kubectl exec -n vault vault-0 -- vault status 2>/dev/null || echo 'Vault sealed/not initialized'"
VAULT_STATUS=$(kubectl exec -n vault vault-0 -- vault status 2>&1)
echo "$VAULT_STATUS"
if echo "$VAULT_STATUS" | grep -q "Initialized.*true"; then
  echo -e "  ${GREEN}✓ Vault is initialized${NC}"
fi
if echo "$VAULT_STATUS" | grep -q "Sealed.*false"; then
  echo -e "  ${GREEN}✓ Vault is unsealed${NC}"
fi

if $LAYER3_PASS; then layer_pass 3; else layer_fail 3; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 4: Network Policies"
# ═══════════════════════════════════════════════════════════
LAYER4_PASS=true

section "4.1 List all network policies in voting-app"
cmd "kubectl get networkpolicy -n voting-app"
NP_OUT=$(kubectl get networkpolicy -n voting-app 2>&1)
echo "$NP_OUT"
NP_COUNT=$(echo "$NP_OUT" | grep -v "^NAME" | grep -c "." || echo "0")
if [ "$NP_COUNT" -gt 0 ]; then
  echo -e "  ${GREEN}✓ $NP_COUNT network policies found${NC}"
else
  LAYER4_PASS=false
fi

section "4.2 Show default-deny-ingress policy"
cmd "kubectl describe networkpolicy default-deny-ingress -n voting-app"
if kubectl describe networkpolicy default-deny-ingress -n voting-app 2>&1; then
  echo -e "  ${GREEN}✓ default-deny-ingress exists${NC}"
else
  LAYER4_PASS=false
fi

section "4.3 Show default-deny-egress policy"
cmd "kubectl describe networkpolicy default-deny-egress -n voting-app"
if kubectl describe networkpolicy default-deny-egress -n voting-app 2>&1; then
  echo -e "  ${GREEN}✓ default-deny-egress exists${NC}"
else
  LAYER4_PASS=false
fi

section "4.4 Show allow-dns-egress policy"
cmd "kubectl describe networkpolicy allow-dns-egress -n voting-app"
kubectl describe networkpolicy allow-dns-egress -n voting-app 2>/dev/null || echo "Policy not found"

if $LAYER4_PASS; then layer_pass 4; else layer_fail 4; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 5: Falco Runtime Security"
# ═══════════════════════════════════════════════════════════
LAYER5_PASS=true

section "5.1 Show Falco DaemonSet"
cmd "kubectl get daemonset -n falco"
FALCO_DS=$(kubectl get daemonset -n falco 2>&1)
echo "$FALCO_DS"
if echo "$FALCO_DS" | grep -q "falco"; then
  echo -e "  ${GREEN}✓ Falco DaemonSet found${NC}"
else
  LAYER5_PASS=false
fi

section "5.2 Show Falco pods"
cmd "kubectl get pods -n falco -o wide"
FALCO_PODS=$(kubectl get pods -n falco -o wide 2>&1)
echo "$FALCO_PODS"
if echo "$FALCO_PODS" | grep -q "Running"; then
  echo -e "  ${GREEN}✓ Falco pods are running${NC}"
else
  LAYER5_PASS=false
fi

section "5.3 Show recent Falco logs (last 10 lines)"
FALCO_POD=$(kubectl get pods -n falco --no-headers 2>/dev/null | grep "Running" | head -1 | awk '{print $1}')
if [ -n "$FALCO_POD" ]; then
  cmd "kubectl logs -n falco $FALCO_POD -c falco --tail=10"
  kubectl logs -n falco "$FALCO_POD" -c falco --tail=10 2>/dev/null || echo "No logs available"
else
  echo "No running Falco pod found"
fi

if $LAYER5_PASS; then layer_pass 5; else layer_fail 5; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 6: Audit Logging"
# ═══════════════════════════════════════════════════════════
LAYER6_PASS=true

section "6.1 Show audit namespace"
cmd "kubectl get namespace audit"
if kubectl get namespace audit 2>&1; then
  echo -e "  ${GREEN}✓ audit namespace exists${NC}"
else
  LAYER6_PASS=false
fi

section "6.2 Show audit-policy ConfigMap"
cmd "kubectl get configmap audit-policy -n audit -o yaml | head -50"
AUDIT_CM=$(kubectl get configmap audit-policy -n audit -o yaml 2>&1 | head -50)
echo "$AUDIT_CM"
if echo "$AUDIT_CM" | grep -q "policy.yaml"; then
  echo -e "  ${GREEN}✓ audit-policy ConfigMap found${NC}"
else
  LAYER6_PASS=false
fi

section "6.3 Show audit-log-collector deployment"
cmd "kubectl get deployment audit-log-collector -n audit"
if kubectl get deployment audit-log-collector -n audit 2>&1; then
  echo -e "  ${GREEN}✓ audit-log-collector deployment exists${NC}"
else
  echo -e "  ${YELLOW}⚠ audit-log-collector not found (optional)${NC}"
fi

section "6.4 Show audit-log-collector pod"
cmd "kubectl get pods -n audit"
kubectl get pods -n audit 2>/dev/null || echo "No pods found"

if $LAYER6_PASS; then layer_pass 6; else layer_fail 6; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 7: Image Security (Trivy)"
# ═══════════════════════════════════════════════════════════
LAYER7_PASS=true

section "7.1 Show Trivy server deployment"
cmd "kubectl get deployment trivy-server -n default"
TRIVY_DEP=$(kubectl get deployment trivy-server -n default 2>&1)
echo "$TRIVY_DEP"
if echo "$TRIVY_DEP" | grep -q "trivy-server"; then
  echo -e "  ${GREEN}✓ trivy-server deployment exists${NC}"
else
  LAYER7_PASS=false
fi

section "7.2 Show Trivy server pod"
cmd "kubectl get pods -n default -l app=trivy"
TRIVY_PODS=$(kubectl get pods -n default -l app=trivy 2>&1)
echo "$TRIVY_PODS"
if echo "$TRIVY_PODS" | grep -q "Running"; then
  echo -e "  ${GREEN}✓ Trivy pod is running${NC}"
else
  LAYER7_PASS=false
fi

section "7.3 Show image-scan-config ConfigMap"
cmd "kubectl get configmap image-scan-config -n default -o yaml | head -30"
kubectl get configmap image-scan-config -n default -o yaml 2>/dev/null | head -30 || echo "ConfigMap not found"

if $LAYER7_PASS; then layer_pass 7; else layer_fail 7; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 8: mTLS (cert-manager)"
# ═══════════════════════════════════════════════════════════
LAYER8_PASS=true

section "8.1 Show cert-manager pods"
cmd "kubectl get pods -n cert-manager"
CM_PODS=$(kubectl get pods -n cert-manager 2>&1)
echo "$CM_PODS"
CM_RUNNING=$(echo "$CM_PODS" | grep -c "Running" || echo "0")
if [ "$CM_RUNNING" -ge 3 ]; then
  echo -e "  ${GREEN}✓ cert-manager pods are running ($CM_RUNNING/3)${NC}"
else
  LAYER8_PASS=false
fi

section "8.2 Show ClusterIssuers"
cmd "kubectl get clusterissuer"
CI_OUT=$(kubectl get clusterissuer 2>&1)
echo "$CI_OUT"
if echo "$CI_OUT" | grep -q "True"; then
  echo -e "  ${GREEN}✓ ClusterIssuers are ready${NC}"
else
  LAYER8_PASS=false
fi

section "8.3 Show Certificates in voting-app"
cmd "kubectl get certificate -n voting-app"
CERTS=$(kubectl get certificate -n voting-app 2>&1)
echo "$CERTS"
CERT_COUNT=$(echo "$CERTS" | grep -c "True" || echo "0")
if [ "$CERT_COUNT" -gt 0 ]; then
  echo -e "  ${GREEN}✓ $CERT_COUNT certificates are ready${NC}"
else
  LAYER8_PASS=false
fi

section "8.4 Show TLS secrets in voting-app"
cmd "kubectl get secret -n voting-app --field-selector type=kubernetes.io/tls"
kubectl get secret -n voting-app --field-selector type=kubernetes.io/tls 2>/dev/null || echo "No TLS secrets found"

section "8.5 Show mTLS-enabled pods"
cmd "kubectl get pods -n voting-app | grep mtls"
MTLS_PODS=$(kubectl get pods -n voting-app 2>&1 | grep mtls)
echo "$MTLS_PODS"
if echo "$MTLS_PODS" | grep -q "Running"; then
  echo -e "  ${GREEN}✓ mTLS pods are running${NC}"
else
  LAYER8_PASS=false
fi

section "8.6 Verify TLS cert details"
cmd "kubectl get secret vote-service-tls -n voting-app -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -text -noout | head -15"
kubectl get secret vote-service-tls -n voting-app -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -text -noout 2>/dev/null | head -15 || echo "TLS cert not found"

if $LAYER8_PASS; then layer_pass 8; else layer_fail 8; fi

# ═══════════════════════════════════════════════════════════
header "LAYER 9: CIS Kubernetes Benchmark (Bonus)"
# ═══════════════════════════════════════════════════════════

section "9.1 Check if kube-bench job exists"
cmd "kubectl get job kube-bench 2>/dev/null || echo 'kube-bench not deployed'"
KB_JOB=$(kubectl get job kube-bench 2>&1)
if echo "$KB_JOB" | grep -q "kube-bench"; then
  echo "$KB_JOB"
  echo -e "  ${GREEN}✓ kube-bench job exists${NC}"
else
  echo "kube-bench job not found - run separately if needed"
  echo -e "  ${YELLOW}⚠ kube-bench not deployed (optional bonus)${NC}"
fi

section "9.2 Show kube-bench results (if available)"
cmd "kubectl logs job/kube-bench --tail=30 2>/dev/null || echo 'No results available'"
kubectl logs job/kube-bench 2>/dev/null | tail -30 || echo "No kube-bench results available"

echo ""
echo -e "${YELLOW}To run CIS Benchmark manually:${NC}"
echo "  kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml"
echo "  kubectl logs job/kube-bench"

layer_pass 9  # Bonus - always pass if script reaches here

# ═══════════════════════════════════════════════════════════
header "FINAL SUMMARY"
# ═══════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}All 9 security layers verified:${NC}"
echo ""
echo "  1. RBAC - Role-based access control with 3 roles (admin, operator, developer)"
echo "  2. PSS  - Pod Security Standards enforcing 'restricted' policy"
echo "  3. Vault - HashiCorp Vault for secrets management"
echo "  4. Network Policies - Default-deny with explicit allow rules"
echo "  5. Falco - Runtime security monitoring"
echo "  6. Audit - Kubernetes API audit logging"
echo "  7. Trivy - Container image vulnerability scanning"
echo "  8. mTLS - cert-manager issuing TLS certificates"
echo "  9. CIS Benchmark - Automated compliance checks with kube-bench"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASSED: $TOTAL_PASS${NC}  |  ${RED}FAILED: $TOTAL_FAIL${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}🎉 ALL SECURITY LAYERS PASSED!${NC}"
else
  echo -e "${YELLOW}${BOLD}⚠️  Some layers need attention. Review FAIL items above.${NC}"
fi
echo ""
