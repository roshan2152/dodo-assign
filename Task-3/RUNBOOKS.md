# Alert Runbooks - Standard Operating Procedures

## Overview

Runbooks provide step-by-step instructions to investigate and resolve common alerts. Each runbook includes:
- **Alert Description**: What triggered the alert
- **Impact**: Business and technical impact if not resolved
- **Investigation Steps**: How to diagnose the issue
- **Resolution Steps**: How to fix the problem
- **Escalation**: When to involve other teams

---

## 1. FlaskAppDown - CRITICAL

### Description
The Flask application is not responding to health checks. The service is unavailable.

### Impact
- 🔴 **CRITICAL**: Service is completely down
- Users cannot access the application
- All business transactions are blocked
- Revenue impact if payment processing is affected

### Investigation Steps

1. **Check Pod Status:**
   ```bash
   kubectl get pods -n flask-app -o wide
   kubectl describe pod <flask-app-pod> -n flask-app
   ```
   - Look for `CrashLoopBackOff`, `ImagePullBackOff`, `Pending` status
   - Check recent events for clues

2. **View Application Logs:**
   ```bash
   kubectl logs <flask-app-pod> -n flask-app --tail=100
   kubectl logs <flask-app-pod> -n flask-app --previous  # If pod crashed
   ```
   - Look for stack traces, database connection errors, OOM errors
   - Check Loki for structured logs:
   ```bash
   kubectl port-forward -n monitoring svc/loki 3100:3100
   # Query in Grafana: {job="flask-app", level="error"}
   ```

3. **Check Resource Constraints:**
   ```bash
   kubectl top pod <flask-app-pod> -n flask-app
   kubectl describe node <node-name>
   ```
   - Verify CPU and memory availability
   - Check for disk space on node

4. **Verify Deployment:**
   ```bash
   kubectl get deployment flask-app -n flask-app -o yaml
   kubectl rollout status deployment/flask-app -n flask-app
   ```
   - Check if deployment has correct image
   - Verify replica count

### Resolution Steps

**Scenario A: Image Pull Error**
```bash
# Push correct image to registry
docker build -t your-registry/flask-app:latest .
docker push your-registry/flask-app:latest

# Update deployment
kubectl set image deployment/flask-app \
  flask-app=your-registry/flask-app:latest \
  -n flask-app
```

**Scenario B: Resource Constraints**
```bash
# Check available resources
kubectl top nodes

# Scale up node group or increase resource limits
# Edit deployment to request appropriate resources
kubectl edit deployment flask-app -n flask-app
```

**Scenario C: Database Connection Error**
```bash
# Check database pod
kubectl get pod -n database-ns

# Verify ConfigMap/Secrets
kubectl get configmap -n flask-app
kubectl get secret -n flask-app

# Restart database connection pool
kubectl exec <flask-app-pod> -n flask-app -- \
  curl -X POST http://localhost:5000/health
```

**Scenario D: Recent Deployment Issue**
```bash
# Rollback to previous version
kubectl rollout undo deployment/flask-app -n flask-app

# Verify
kubectl rollout status deployment/flask-app -n flask-app
```

### Verification
```bash
# Pod should be Running and Ready
kubectl get pods -n flask-app

# Health check should pass
kubectl exec <flask-app-pod> -n flask-app -- \
  curl -s http://localhost:5000/health | jq .

# Prometheus should show up=1
# Query: up{job="flask-app"}
```

### Escalation
- **5 minutes unresolved**: Contact Platform Team
- **15 minutes unresolved**: Page On-Call DevOps Engineer
- **30 minutes unresolved**: Declare incident, involve all stakeholders

---

## 2. HighErrorRate - WARNING

### Description
The Flask application is producing errors at a rate > 5% (more than 5 errors per 100 requests) over 5-minute period.

### Impact
- ⚠️  **WARNING**: Users experience failures
- Reduced user satisfaction
- Potential data losses if errors affect transactions
- System becoming unstable

### Investigation Steps

1. **Check Recent Error Logs:**
   ```bash
   # In Grafana Explore (Loki):
   {job="flask-app", level="error"} | json
   
   # Or via CLI:
   kubectl logs <flask-app-pod> -n flask-app --tail=500 | grep -i error
   ```

2. **Identify Error Type Distribution:**
   ```bash
   # Prometheus Query:
   rate(flask_http_request_total{status=~"5.."}[5m]) by (status)
   ```
   - 500 errors: Server-side application issue
   - 502/503: Upstream service unavailable
   - 504: Gateway timeout

3. **Check Application Metrics:**
   ```bash
   # View request duration
   histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))
   
   # Check database query time
   # (if instrumented)
   rate(app_db_query_duration_bucket[5m])
   ```

4. **Check Dependent Services:**
   ```bash
   # Check database connectivity
   kubectl exec <flask-app-pod> -n flask-app -- \
     curl <database-service>:5432 -v
   
   # Check external API availability
   curl https://external-api.example.com/health
   ```

### Resolution Steps

**Scenario A: Database Unavailable**
```bash
# Check database pod
kubectl get pod -n database-ns
kubectl logs <db-pod> -n database-ns

# Restart database if needed
kubectl rollout restart statefulset/postgres -n database-ns

# Clear connection pool cache
kubectl delete all -l app=postgres-cache -n database-ns
```

**Scenario B: Memory Leak or Resource Exhaustion**
```bash
# Check memory usage
kubectl top pod <flask-app-pod> -n flask-app

# Restart application
kubectl rollout restart deployment/flask-app -n flask-app

# Monitor memory over next 5 minutes
watch kubectl top pod <flask-app-pod> -n flask-app
```

**Scenario C: Invalid Configuration**
```bash
# Check environment variables
kubectl exec <flask-app-pod> -n flask-app -- env | grep -i config

# Check ConfigMap
kubectl get configmap flask-config -n flask-app -o yaml

# Update ConfigMap
kubectl patch configmap flask-config -n flask-app -p '{"data":{"KEY":"value"}}'

# Restart pods to pick up new config
kubectl rollout restart deployment/flask-app -n flask-app
```

**Scenario D: Dependency Version Mismatch**
```bash
# Check dependency versions in pod
kubectl exec <flask-app-pod> -n flask-app -- pip list

# Update requirements and rebuild image
docker build -t your-registry/flask-app:latest .
docker push your-registry/flask-app:latest
kubectl set image deployment/flask-app \
  flask-app=your-registry/flask-app:latest -n flask-app
```

### Resolution Priority
1. Stop error propagation (circuit breaker, rate limit)
2. Identify root cause
3. Fix underlying issue
4. Verify error rate drop below 5%

### Escalation
- **10 minutes unresolved**: Contact Application Team
- **20 minutes unresolved**: Page On-Call Engineer
- **30 minutes unresolved**: Begin incident response

---

## 3. HighLatency - WARNING

### Description
95th percentile response time is > 1 second. Users experiencing slow application.

### Impact
- ⚠️  **WARNING**: Poor user experience
- Potential timeouts on client side
- Cascading failures if retries overload system

### Investigation Steps

1. **Identify Slow Endpoints:**
   ```bash
   # Prometheus Query:
   histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket{endpoint=~".*"}[5m]))
   
   # By endpoint:
   histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m])) by (endpoint)
   ```

2. **Check Database Query Time:**
   ```bash
   # If instrumented:
   rate(app_db_query_duration_seconds_bucket[5m])
   
   # Slow query logs:
   kubectl logs <db-pod> -n database-ns | grep "slow"
   ```

3. **Review Network Latency:**
   ```bash
   # Between pods
   kubectl exec <flask-app-pod> -n flask-app -- \
     ping <database-service>
   
   # Query RTT
   kubectl top pod <flask-app-pod> --containers
   ```

4. **Check CPU and Memory:**
   ```bash
   kubectl top pod <flask-app-pod> -n flask-app
   
   # If CPU throttled, check resource limits
   kubectl describe pod <flask-app-pod> -n flask-app
   ```

### Resolution Steps

**Scenario A: Slow Database Queries**
```bash
# Enable query logging
kubectl exec <db-pod> -n database-ns -- \
  psql -U postgres -d app_db -c \
  "ALTER SYSTEM SET log_min_duration_statement = 1000;"

# Restart database to apply
kubectl rollout restart statefulset/postgres -n database-ns

# Check for missing indexes
kubectl exec <db-pod> -n database-ns -- \
  psql -U postgres -d app_db -c "EXPLAIN ANALYZE <SLOW_QUERY>;"

# Add indexes if needed
kubectl exec <db-pod> -n database-ns -- \
  psql -U postgres -d app_db -c \
  "CREATE INDEX idx_name ON table(column);"
```

**Scenario B: Insufficient Resources**
```bash
# Increase replicas
kubectl scale deployment flask-app --replicas=3 -n flask-app

# Increase resource requests
kubectl patch deployment flask-app -n flask-app -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"flask-app","resources":{"requests":{"memory":"512Mi","cpu":"500m"}}}]}}}}'
```

**Scenario C: Network Congestion**
```bash
# Check network policies
kubectl get networkpolicy -n flask-app

# Verify no traffic being blocked
kubectl describe networkpolicy <policy> -n flask-app

# Check node network
kubectl describe node <node-name> | grep -i network
```

**Scenario D: External Service Issue**
```bash
# Test connectivity to external services
kubectl exec <flask-app-pod> -n flask-app -- \
  timeout 5 curl -w "DNS: %{time_appconnect}s\n" https://external-api.com

# May need to increase timeout or add retry logic
# Update deployment environment
kubectl set env deployment/flask-app \
  EXTERNAL_API_TIMEOUT=30 -n flask-app
```

### Verification
```bash
# Query after resolution
histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))
# Should be < 1 second
```

### Escalation
- **Will clear on its own**: Monitor for 10 minutes
- **Persistent**: Page Database Team (if DB query issue)
- **Network issue**: Page Infrastructure Team

---

## 4. HighMemoryUsage - WARNING

### Description
Memory usage is > 90% of container limit for 5+ minutes.

### Impact
- ⚠️  **WARNING**: Pod may be OOMKilled (Out of Memory)
- Application performance degradation
- Risk of crash and restart loop

### Investigation Steps

1. **Check Current Memory:**
   ```bash
   kubectl top pod <flask-app-pod> -n flask-app
   
   # Check limits vs usage
   kubectl describe pod <flask-app-pod> -n flask-app | grep -A 5 "Limits:"
   ```

2. **Check for Memory Leaks:**
   ```bash
   # Monitor memory growth over time
   watch kubectl top pod <flask-app-pod> -n flask-app
   
   # Check in Prometheus
   container_memory_usage_bytes{pod="flask-app"} / 1024 / 1024
   ```

3. **List Top Memory Processes:**
   ```bash
   kubectl exec <flask-app-pod> -n flask-app -- ps aux --sort=-%mem
   
   # Check Python objects
   kubectl exec <flask-app-pod> -n flask-app -- \
     python -c "import gc; gc.collect(); print(len(gc.get_objects()))"
   ```

4. **Check Cache Size:**
   ```bash
   # Redis/Memcached usage
   kubectl exec <cache-pod> -n cache-ns -- \
     redis-cli info stats
   ```

### Resolution Steps

**Scenario A: Memory Leak**
```bash
# Quick fix: Restart pod
kubectl delete pod <flask-app-pod> -n flask-app
# Pod will auto-restart via controller

# Long-term: Add memory profiling to code
# Use memory_profiler or tracemalloc

# In code:
from memory_profiler import profile

@profile
def my_function():
    ...
```

**Scenario B: Low Memory Limit**
```bash
# Increase memory limit
kubectl patch deployment flask-app -n flask-app -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"flask-app","resources":{"limits":{"memory":"1Gi"}}}]}}}}'

# Verify new limit
kubectl describe deployment flask-app -n flask-app
```

**Scenario C: Unbounded Cache**
```bash
# Set cache size limit in code or config
kubectl set env deployment/flask-app \
  CACHE_MAX_SIZE=100 \
  CACHE_TTL=3600 \
  -n flask-app

# Clear existing cache
kubectl exec <flask-app-pod> -n flask-app -- \
  redis-cli FLUSHDB
```

**Scenario D: Large Data Loading**
```bash
# Implement pagination
# Update data loading logic to use generators instead of loading all in memory

# Set memory monitoring
export PYTHONUNBUFFERED=1
# Ensure logs capture memory issues
```

### Verification
```bash
# Memory should drop below 80%
kubectl top pod <flask-app-pod> -n flask-app

# Graph in Prometheus:
container_memory_usage_bytes{pod="flask-app"} / container_spec_memory_limit_bytes{pod="flask-app"}
# Should be < 0.8
```

### Escalation
- **Temporary spike**: Monitor for resolution
- **Persistent growth**: Contact Application Team (possible memory leak)
- **All remediation failed**: Scale up node or pod resources

---

## 5. HighCPUUsage - WARNING

### Description
CPU usage is > 80% of limit for 5+ minutes.

### Impact
- ⚠️  **WARNING**: Performance degradation
- Slow response times
- Risk of CPU throttling

### Investigation Steps

1. **Check Current CPU:**
   ```bash
   kubectl top pod <flask-app-pod> -n flask-app --containers
   ```

2. **Identify Hot Processes:**
   ```bash
   # Top CPU consumers
   kubectl exec <flask-app-pod> -n flask-app -- \
     ps aux --sort=-%cpu | head -20
   
   # Python thread/process info
   kubectl exec <flask-app-pod> -n flask-app -- \
     python -m py_spy top -p 1 -d 10  # 10 seconds profile
   ```

3. **Check for Busy Loops:**
   ```bash
   # Look for tight loops or inefficient code
   kubectl logs <flask-app-pod> -n flask-app --tail=200
   
   # Check application metrics
   rate(process_cpu_seconds_total[5m])
   ```

### Resolution Steps

**Scenario A: Inefficient Code**
```bash
# Profile application
kubectl exec <flask-app-pod> -n flask-app -- \
  python -m cProfile -o stats.prof app.py

# Analyze hotspots
# Optimize algorithms or queries

# Deploy optimization
docker build -t your-registry/flask-app:latest .
docker push your-registry/flask-app:latest
kubectl set image deployment/flask-app flask-app=your-registry/flask-app:latest -n flask-app
```

**Scenario B: Insufficient CPU Allocation**
```bash
# Increase CPU request/limit
kubectl patch deployment flask-app -n flask-app -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"flask-app","resources":{"requests":{"cpu":"500m"},"limits":{"cpu":"1000m"}}}]}}}}'

# Scale to more replicas
kubectl scale deployment flask-app --replicas=5 -n flask-app
```

**Scenario C: External Load**
```bash
# Check request rate
rate(flask_http_request_total[5m])

# Implement rate limiting
# Or auto-scale based on CPU
kubectl patch hpa flask-app-hpa -n flask-app -p \
  '{"spec":{"targetCPUUtilizationPercentage":70}}'
```

### Verification
```bash
# CPU should drop below 70%
kubectl top pod <flask-app-pod> -n flask-app

# CPU throttle metric (Prometheus):
increase(container_cpu_cfs_throttled_seconds_total[5m])
# Should be 0
```

---

## 6. PodCrashLooping - CRITICAL

### Description
Pod is restarting frequently (detected restarts in last 15 minutes).

### Impact
- 🔴 **CRITICAL**: Service is unstable and unreliable
- Users experience intermittent failures
- Data loss risk if restart loses in-flight transactions

### Investigation Steps

1. **Check Restart Count:**
   ```bash
   kubectl get pod <flask-app-pod> -n flask-app
   kubectl describe pod <flask-app-pod> -n flask-app
   ```
   - Look at `restartCount` and `lastState`

2. **View Previous Logs:**
   ```bash
   # Last execution crash logs
   kubectl logs <flask-app-pod> --previous -n flask-app --tail=200
   
   # All recent logs
   kubectl logs <flask-app-pod> -n flask-app --tail=500
   ```
   - Look for OOMKilled, segfault, exception

3. **Check Pod Events:**
   ```bash
   kubectl describe pod <flask-app-pod> -n flask-app | tail -20
   ```
   - Check `BackOff` messages
   - Look for `Liveness probe failed`

4. **Check Liveness/Readiness Probes:**
   ```bash
   kubectl get pod <flask-app-pod> -n flask-app -o yaml | grep -A 20 "livenessProbe:"
   ```

### Resolution Steps

**Scenario A: OOMKilled**
```bash
# Increase memory
kubectl patch deployment flask-app -n flask-app -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"flask-app","resources":{"limits":{"memory":"2Gi"}}}]}}}}'
```

**Scenario B: Liveness Probe Failing**
```bash
# Test the probe endpoint manually
kubectl exec <flask-app-pod> -n flask-app -- \
  curl -v http://localhost:5000/health

# If endpoint broken, fix in code and redeploy
# Or temporarily disable probe:
kubectl patch deployment flask-app -n flask-app -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"flask-app","livenessProbe":null}]}}}}'
```

**Scenario C: Corrupted Application State**
```bash
# Delete pod to let controller create fresh one
kubectl delete pod <flask-app-pod> -n flask-app

# Check if logs show data corruption
# May need to rebuild/restore database
```

**Scenario D: Infinite Loop in Startup**
```bash
# Check startup script
kubectl describe deployment flask-app -n flask-app | grep -i "command"

# Check logs early in startup
kubectl logs <flask-app-pod> -n flask-app -c <init-container-name>

# Fix startup issue and redeploy
```

### Verification
```bash
# Pod should be Running and Ready
kubectl get pods -n flask-app

# No restarts
kubectl get pods -n flask-app --watch

# Monitor for 15 minutes
watch -n 5 kubectl get pods -n flask-app
```

### Escalation
- **Immediate**: Page On-Call Engineer
- **App issue**: Contact Development Team
- **Infrastructure issue**: Page Platform Team

---

## Common Investigation Commands

```bash
# Overall app health
kubectl get deployment flask-app -n flask-app
kubectl get svc flask-app -n flask-app  
kubectl top pod -n flask-app

# Logs from all replicas
kubectl logs -n flask-app -l app=flask-app --tail=100 -f

# Prometheus queries (port-forward first)
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Visit http://localhost:9090/graph

# Grafana dashboards
kubectl port-forward -n monitoring svc/grafana 3000:80
# Visit http://localhost:3000

# Loki logs (via Grafana)
# Dashboard > Explore > Select Loki datasource
# Query: {job="flask-app"}

# Tempo traces
# Dashboard > Explore > Select Tempo datasource
# Service: flask-app

# AlertManager
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
# Visit http://localhost:9093
```

---

## Creating Custom Runbooks

For new alerts, follow this template:

```markdown
## [Alert Name]

### Description
What triggered? What does the metric mean?

### Impact
How does this affect users/business?

### Investigation Steps
1. Step 1
2. Step 2
...

### Resolution Steps
**Scenario A: Condition**
Solution

**Scenario B: Condition**
Solution

### Verification
How to confirm issue is fixed?

### Escalation
When to escalate to other teams?
```

