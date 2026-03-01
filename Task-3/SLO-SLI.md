# Service Level Objectives (SLOs) and Service Level Indicators (SLIs)

## Flask Application SLOs

### 1. Availability SLO
- **Objective**: 99.5% uptime
- **SLI**: Percentage of successful health check probes
- **Measurement**: `(count(up{job="flask-app"} == 1) / count(up{job="flask-app"})) * 100`
- **Error Budget**: 0.5% (approximately 3.6 hours per month)

### 2. Latency SLO
- **Objective**: 95% of requests complete within 500ms
- **SLI**: 95th percentile response time
- **Measurement**: `histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))`
- **Threshold**: < 0.5 seconds

### 3. Error Rate SLO
- **Objective**: < 1% error rate
- **SLI**: Percentage of HTTP 5xx errors
- **Measurement**: `(rate(flask_http_request_total{status=~"5.."}[5m]) / rate(flask_http_request_total[5m])) * 100`
- **Threshold**: < 1%

### 4. Throughput SLI
- **Metric**: Requests per second
- **Measurement**: `rate(flask_http_request_total[5m])`
- **Baseline**: Track normal operating range

### 5. Resource Utilization SLIs
- **CPU SLI**: Average CPU usage should be < 70%
- **Memory SLI**: Average memory usage should be < 80%
- **Measurements**:
  - CPU: `rate(container_cpu_usage_seconds_total{container="flask-app"}[5m])`
  - Memory: `container_memory_usage_bytes{container="flask-app"} / container_spec_memory_limit_bytes{container="flask-app"}`

## Monitoring Windows

- **Short-term**: 5-minute rolling window for real-time alerts
- **Medium-term**: 1-hour window for trend analysis
- **Long-term**: 30-day window for SLO compliance reporting

## Alert Thresholds

| Alert | Severity | Threshold | Duration |
|-------|----------|-----------|----------|
| Service Down | Critical | 0% availability | 2 minutes |
| High Error Rate | Warning | > 5% errors | 5 minutes |
| High Latency | Warning | p95 > 1s | 5 minutes |
| High Memory | Warning | > 90% usage | 5 minutes |
| High CPU | Warning | > 80% usage | 5 minutes |
| Pod Crash Loop | Critical | Restarts > 0 | 5 minutes |

## Dashboards

### Main Application Dashboard
1. **Availability Panel**: Uptime percentage over time
2. **Latency Panel**: p50, p95, p99 response times
3. **Error Rate Panel**: HTTP status code distribution
4. **Throughput Panel**: Requests per second
5. **Resource Usage Panel**: CPU and memory utilization

### Distributed Tracing Dashboard (Tempo)
1. Service map showing request flows
2. Trace timeline view
3. Span duration analysis

### Logs Dashboard (Loki)
1. Log volume over time
2. Error log search
3. Logs correlated with traces
