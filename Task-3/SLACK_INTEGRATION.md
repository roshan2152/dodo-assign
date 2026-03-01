# Slack & AlertManager Integration Guide

## Setting Up Slack Webhook

### Step 1: Create Slack Webhook URL

1. Go to your Slack workspace
2. Navigate to **Apps** → **Manage Apps** or go to https://api.slack.com/apps
3. Click **Create New App** → **From scratch**
4. Name: `Dodo Payments Alerts`
5. Select your workspace
6. Go to **Incoming Webhooks** in the left menu
7. Toggle **Activate Incoming Webhooks** ON
8. Click **Add New Webhook to Workspace**
9. Select the channels where you want alerts posted:
   - `#alerts` (general alerts)
   - `#critical-alerts` (critical only)
   - `#app-alerts` (app-specific)
10. Copy the webhook URL

### Step 2: Create Slack Channels

Before deploying AlertManager, create the following channels in Slack:
```
#alerts
#critical-alerts
#app-alerts
```

### Step 3: Deploy AlertManager with Slack Integration

1. **Update the Secret with your webhook URL:**
```bash
# Replace with your actual webhook URL
kubectl patch secret alertmanager-slack-webhook \
  -n monitoring \
  -p='{"data":{"slack-webhook-url":"'$(echo -n "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" | base64)'"}}' \
  --type=merge
```

2. **Apply the config:**
```bash
kubectl apply -f alertmanager-config.yaml
```

3. **Verify the AlertManager is running:**
```bash
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
# Visit http://localhost:9093
```

## AlertManager Configuration Details

### Alert Routing

| Alert Severity | Channel | Timing |
|---|---|---|
| Critical | #critical-alerts | Immediate (0s wait) |
| Warning | #alerts | Batched (1min wait) |
| App Alerts | #app-alerts | Batched (5min interval) |

### Alert Grouping

Alerts are grouped by:
- Alert name
- Cluster name
- Service name

This reduces noise by combining related alerts.

### Inhibition Rules

- If `FlaskAppDown` fires, suppress all other alerts for that job
- If the entire app is down, we don't send warnings about latency or errors

## Testing Slack Integration

### Test Critical Alert

```bash
# Port-forward to Alertmanager
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093

# Send test alert via curl
curl -H 'Content-Type: application/json' \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "severity": "critical",
        "job": "flask-app"
      },
      "annotations": {
        "summary": "Test Critical Alert",
        "description": "This is a test alert from AlertManager"
      }
    }]
  }' \
  http://localhost:9093/api/v1/alerts
```

## Environment Variables for AlertManager

When deploying, set these environment variables:

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export SLACK_CHANNEL_CRITICAL="#critical-alerts"
export SLACK_CHANNEL_WARNINGS="#alerts"
export SLACK_CHANNEL_APP="#app-alerts"
```

## Optional: PagerDuty Integration

To add PagerDuty in addition to Slack:

```yaml
- name: 'slack-critical'
  slack_configs:
    - channel: '#critical-alerts'
      # ... slack config ...
  pagerduty_configs:
    - service_key: '${PAGERDUTY_SERVICE_KEY}'
      description: '{{ .GroupLabels.alertname }}'
      details:
        severity: '{{ .GroupLabels.severity }}'
        instance: '{{ .Labels.instance }}'
```

## Optional: Email Integration

For email notifications:

```yaml
receivers:
  - name: 'email'
    email_configs:
      - to: 'alerts@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'username'
        auth_password: 'password'
        headers:
          Subject: 'Alert: {{ .GroupLabels.alertname }}'
```

## Troubleshooting

### Alerts not reaching Slack

1. Check AlertManager logs:
```bash
kubectl logs -n monitoring <alertmanager-pod> -f
```

2. Verify webhook URL is correct:
```bash
kubectl get secret alertmanager-slack-webhook -n monitoring -o yaml
```

3. Check AlertManager config:
```bash
kubectl get configmap alertmanager-config -n monitoring -o yaml
```

4. Test webhook directly:
```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_WEBHOOK_URL
```

### Too many/too few alerts

- Adjust `group_wait` and `group_interval` in routeconfig
- Modify `repeat_interval` to control resend frequency
- Update `inhibit_rules` to suppress less important alerts

