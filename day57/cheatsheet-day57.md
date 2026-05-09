# Alerting - Prometheus Alertmanager & Notification Channels

# Alerting workflow: Prometheus → Alertmanager → Notification channels
# Prometheus: Evaluate alert rules
# Alertmanager: Route, group, deduplicate, silence alerts
# Channels: Slack, PagerDuty, Email, Discord, etc.

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROMETHEUS ALERT RULES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Alert rules file
cat << 'EOF' > alerts.yml
groups:
  - name: instance_alerts
    interval: 30s
    rules:
      # Instance down
      - alert: InstanceDown
        expr: up == 0
        for: 5m                                  # pending for 5 min before firing
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes."

      # High CPU
      - alert: HighCPU
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}"
          description: "CPU usage is {{ $value }}% on {{ $labels.instance }}"

      # High memory
      - alert: HighMemory
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory on {{ $labels.instance }}"
          description: "Memory usage is {{ $value }}% on {{ $labels.instance }}"

      # Disk space low
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"}) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space low on {{ $labels.instance }}"
          description: "Disk {{ $labels.device }} on {{ $labels.instance }} has only {{ $value }}% free space"

  - name: application_alerts
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100 > 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate"
          description: "Error rate is {{ $value }}% (threshold: 5%)"

      # High latency
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "p95 latency is {{ $value }}s (threshold: 1s)"

      # Low request rate (service might be down)
      - alert: LowRequestRate
        expr: sum(rate(http_requests_total[5m])) < 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low request rate"
          description: "Request rate is {{ $value }} req/s (expected: >1 req/s)"

      # Database connection pool exhausted
      - alert: DBConnectionPoolExhausted
        expr: (db_connections_active / db_connections_max) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "DB connection pool exhausted"
          description: "Connection pool is {{ $value }}% full"

      # Container restarts
      - alert: ContainerRestarting
        expr: rate(container_last_seen{name!=""}[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} restarting"
          description: "Container has restarted {{ $value }} times in the last 5 minutes"
EOF

# Add alerts to prometheus.yml
cat << 'EOF' >> prometheus.yml
rule_files:
  - 'alerts.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
EOF

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload

# Check alert rules
curl http://localhost:9090/api/v1/rules | jq

# Check active alerts
curl http://localhost:9090/api/v1/alerts | jq

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALERTMANAGER CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Alertmanager config
cat << 'EOF' > alertmanager.yml
global:
  resolve_timeout: 5m                # auto-resolve after 5 min if no updates
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

# Route alerts to receivers
route:
  receiver: 'default'                # default receiver
  group_by: ['alertname', 'instance']
  group_wait: 10s                    # wait 10s to group alerts
  group_interval: 5m                 # send grouped alerts every 5 min
  repeat_interval: 4h                # resend alert every 4h if still firing

  routes:
    # Critical alerts → PagerDuty (wake up on-call)
    - match:
        severity: critical
      receiver: 'pagerduty'
      group_wait: 10s
      repeat_interval: 1h

    # Warnings → Slack (no PagerDuty)
    - match:
        severity: warning
      receiver: 'slack'
      group_wait: 30s
      repeat_interval: 4h

    # Database alerts → DBA team
    - match_re:
        alertname: '^DB.*'
      receiver: 'dba-team'

    # Production alerts → prod team
    - match:
        environment: production
      receiver: 'prod-team'
      group_wait: 5s
      repeat_interval: 2h

# Receivers (notification channels)
receivers:
  - name: 'default'
    email_configs:
      - to: 'team@example.com'

  - name: 'slack'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
        description: '{{ .GroupLabels.alertname }}'

  - name: 'dba-team'
    email_configs:
      - to: 'dba@example.com'
    slack_configs:
      - channel: '#database-alerts'

  - name: 'prod-team'
    slack_configs:
      - channel: '#production-alerts'
    pagerduty_configs:
      - service_key: 'PROD_PAGERDUTY_KEY'

# Inhibit rules (suppress alerts)
inhibit_rules:
  # If instance is down, don't alert on high CPU/memory
  - source_match:
      alertname: 'InstanceDown'
    target_match_re:
      alertname: '^(HighCPU|HighMemory|HighDisk)$'
    equal: ['instance']

  # If high error rate, don't alert on low request rate
  - source_match:
      alertname: 'HighErrorRate'
    target_match:
      alertname: 'LowRequestRate'
EOF

# Run Alertmanager
docker run -d \
  --name alertmanager \
  -p 9093:9093 \
  -v $(pwd)/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager

# Access Alertmanager UI: http://localhost:9093

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NOTIFICATION CHANNELS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Slack webhook
cat << 'EOF' >> alertmanager.yml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts'
        username: 'Alertmanager'
        icon_emoji: ':fire:'
        title: '{{ .GroupLabels.alertname }} - {{ .GroupLabels.severity }}'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Severity:* {{ .Labels.severity }}
          *Instance:* {{ .Labels.instance }}
          *Description:* {{ .Annotations.description }}
          {{ end }}
        send_resolved: true
EOF

# Email
cat << 'EOF' >> alertmanager.yml
receivers:
  - name: 'email'
    email_configs:
      - to: 'oncall@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@gmail.com'
        auth_password: 'your-app-password'
        headers:
          Subject: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
EOF

# PagerDuty
cat << 'EOF' >> alertmanager.yml
receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
        description: '{{ .GroupLabels.alertname }}: {{ .GroupLabels.instance }}'
        details:
          firing: '{{ .Alerts.Firing | len }}'
          resolved: '{{ .Alerts.Resolved | len }}'
EOF

# Discord webhook
cat << 'EOF' >> alertmanager.yml
receivers:
  - name: 'discord'
    webhook_configs:
      - url: 'https://discord.com/api/webhooks/YOUR/WEBHOOK'
        send_resolved: true
EOF

# Telegram
cat << 'EOF' >> alertmanager.yml
receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: YOUR_CHAT_ID
        message: |
          {{ range .Alerts }}
          🚨 *{{ .Labels.alertname }}*
          Severity: {{ .Labels.severity }}
          Instance: {{ .Labels.instance }}
          {{ .Annotations.description }}
          {{ end }}
        parse_mode: 'Markdown'
EOF

# Webhook (custom receiver)
cat << 'EOF' >> alertmanager.yml
receivers:
  - name: 'webhook'
    webhook_configs:
      - url: 'http://myapi.com/alerts'
        send_resolved: true
        http_config:
          basic_auth:
            username: 'api-user'
            password: 'api-pass'
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SILENCE ALERTS (Maintenance mode)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Silence alert via CLI
amtool silence add alertname=HighCPU instance=server1 --duration=2h --comment="Planned maintenance"

# Silence via API
curl -X POST http://localhost:9093/api/v1/silences \
  -H 'Content-Type: application/json' \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "HighCPU", "isRegex": false},
      {"name": "instance", "value": "server1", "isRegex": false}
    ],
    "startsAt": "2025-05-09T10:00:00Z",
    "endsAt": "2025-05-09T12:00:00Z",
    "comment": "Planned maintenance",
    "createdBy": "admin"
  }'

# List silences
amtool silence query
curl http://localhost:9093/api/v1/silences | jq

# Delete silence
amtool silence expire SILENCE_ID
curl -X DELETE http://localhost:9093/api/v1/silence/SILENCE_ID

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TESTING ALERTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Test alert rule (manual trigger)
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test-instance"
    },
    "annotations": {
      "summary": "This is a test alert",
      "description": "Testing notification channels"
    }
  }]'

# Check alert status in Prometheus
# Prometheus UI → Alerts → See firing alerts

# Check alert in Alertmanager
# Alertmanager UI → Alerts → See active alerts

# Check notification sent
# → Check Slack/Email/PagerDuty

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALERT SEVERITY LEVELS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Severity levels (standard practice)
cat << 'EOF' > severity-guide.md
CRITICAL (P1):
- Service down, data loss, security breach
- Action: Page on-call, immediate response
- Examples: InstanceDown, DBConnectionPoolExhausted, HighErrorRate
- SLA: Response < 15 minutes

WARNING (P2):
- Degraded performance, approaching limits
- Action: Slack notification, investigate during business hours
- Examples: HighCPU (>80%), HighMemory (>90%), HighLatency
- SLA: Response < 2 hours

INFO (P3):
- Non-urgent information, FYI
- Action: Email, no immediate action needed
- Examples: Deployment completed, backup finished
- SLA: Response < 1 day

DEBUG (P4):
- Development/debugging information
- Action: Log only, no notification
- Examples: Temporary spikes, expected behavior
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPLETE STACK (docker-compose)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cat << 'EOF' > docker-compose-alerting.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts.yml:/etc/prometheus/alerts.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'                    # enable reload via API

  alertmanager:
    image: prom/alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'

  node-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus

volumes:
  prometheus-data:
  alertmanager-data:
  grafana-data:
EOF

docker-compose -f docker-compose-alerting.yml up -d

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GRAFANA ALERTING (Alternative to Alertmanager)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Grafana can send alerts directly (without Alertmanager)
# Grafana UI → Alerting → Alert rules → New alert rule

# Configure notification channel in Grafana
# Alerting → Contact points → New contact point

# Slack contact point (via Grafana UI)
# Type: Slack
# Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK
# Channel: #alerts

# Email contact point
# Type: Email
# Addresses: oncall@example.com

# PagerDuty contact point
# Type: PagerDuty
# Integration Key: YOUR_KEY

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALERT BEST PRACTICES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Alert on symptoms, not causes
# ❌ BAD: Alert on "High CPU"
# ✅ GOOD: Alert on "High latency" (symptom), then investigate CPU (cause)

# 2. Use "for" duration to avoid flapping
# ❌ BAD: for: 30s (too sensitive, many false positives)
# ✅ GOOD: for: 5m (wait for sustained issue)

# 3. Make alerts actionable
# ❌ BAD: "Something is wrong"
# ✅ GOOD: "Error rate 10% on API service. Check logs: kubectl logs api-pod"

# 4. Include context in annotations
annotations:
  summary: "High error rate on {{ $labels.job }}"
  description: "Error rate is {{ $value }}%. Runbook: https://wiki.company.com/runbooks/high-error-rate"
  dashboard: "https://grafana.company.com/d/api-dashboard"

# 5. Use labels for routing
labels:
  severity: critical          # route to PagerDuty
  team: backend               # route to backend-team
  environment: production     # route to prod-alerts

# 6. Set appropriate repeat intervals
# Critical: 1 hour (keep paging until fixed)
# Warning: 4 hours (remind if not resolved)
# Info: 24 hours (daily digest)

# 7. Document runbooks
# Every alert should have a runbook
# Runbook = Step-by-step guide to investigate and fix

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TROUBLESHOOTING ALERTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Alert not firing
# 1. Check Prometheus rules: http://localhost:9090/rules
# 2. Check if query returns data: run expr in Prometheus UI
# 3. Check "for" duration: might be pending
# 4. Check Prometheus logs: docker logs prometheus

# Alert firing but no notification
# 1. Check Alertmanager: http://localhost:9093
# 2. Check routing config: Does alert match any route?
# 3. Check receiver config: Is Slack webhook correct?
# 4. Check Alertmanager logs: docker logs alertmanager
# 5. Test notification manually (send test alert via API)

# Too many alerts (alert fatigue)
# 1. Increase "for" duration (reduce flapping)
# 2. Adjust thresholds (too sensitive?)
# 3. Use inhibit rules (suppress related alerts)
# 4. Group alerts (don't send 100 separate alerts)

# Alerts not resolving
# 1. Check resolve_timeout in Alertmanager config
# 2. Check if Prometheus still evaluates alert as firing
# 3. Verify alert query returns to normal
