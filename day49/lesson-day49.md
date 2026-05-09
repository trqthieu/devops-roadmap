# 📘 Ngày 49: Notifications & Monitoring

## 🎯 Mục Tiêu Ngày Hôm Nay

Integrate notifications (Slack, Discord, Email, PagerDuty) vào CI/CD pipelines và setup deployment monitoring để track metrics và alert on issues.

---

## Tại Sao Cần Notifications?

### Vấn Đề: Silent Failures

```
❌ Without notifications:

Deployment fails at 2 AM
    ↓
No one knows
    ↓
Customers complain next morning
    ↓
Team checks logs → see failure from 6 hours ago
    ↓
Lost revenue, damaged reputation
```

**Real incident:**
- Database migration failed during deploy
- No alerts sent
- Production down for 4 hours overnight
- Cost: $50,000 in lost revenue + customer churn

---

### Giải Pháp: Real-time Notifications

```
✅ With notifications:

Deployment fails
    ↓
Instant Slack/PagerDuty alert  ← 5 seconds
    ↓
On-call engineer notified
    ↓
Rollback within 2 minutes
    ↓
Minimal downtime, quick recovery
```

---

## Slack Integration

### Setup Slack Webhook

**1. Create Incoming Webhook:**

```
Slack workspace → Apps → Search "Incoming Webhooks"
    → Add to Slack
    → Choose channel (#deployments)
    → Add Incoming Webhooks Integration
    → Copy Webhook URL

Example URL:
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
```

**2. Add to GitHub Secrets:**

```bash
# GitHub repo → Settings → Secrets
# Name: SLACK_WEBHOOK
# Value: https://hooks.slack.com/services/...
```

---

### Basic Slack Notification

```yaml
# .github/workflows/slack-notify.yml
name: Slack Notifications

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy application
        run: ./deploy.sh

      - name: Notify Slack on success
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Deployment successful\nCommit: ${{ github.sha }}\nBy: ${{ github.actor }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Notify Slack on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "❌ Deployment FAILED\nCommit: ${{ github.sha }}\nPlease check: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

### Rich Slack Messages (Blocks API)

```yaml
- name: Rich Slack notification
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "blocks": [
          {
            "type": "header",
            "text": {
              "type": "plain_text",
              "text": "🚀 Production Deployment"
            }
          },
          {
            "type": "section",
            "fields": [
              {
                "type": "mrkdwn",
                "text": "*Status:*\n✅ Success"
              },
              {
                "type": "mrkdwn",
                "text": "*Duration:*\n5m 32s"
              },
              {
                "type": "mrkdwn",
                "text": "*Commit:*\n<https://github.com/${{ github.repository }}/commit/${{ github.sha }}|${{ github.sha }}>"
              },
              {
                "type": "mrkdwn",
                "text": "*Deployer:*\n${{ github.actor }}"
              }
            ]
          },
          {
            "type": "actions",
            "elements": [
              {
                "type": "button",
                "text": {
                  "type": "plain_text",
                  "text": "View Logs"
                },
                "url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
              },
              {
                "type": "button",
                "text": {
                  "type": "plain_text",
                  "text": "Visit App"
                },
                "url": "https://myapp.com"
              }
            ]
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

**Result in Slack:**
```
┌─────────────────────────────────────┐
│ 🚀 Production Deployment            │
├─────────────────────────────────────┤
│ Status: ✅ Success                  │
│ Duration: 5m 32s                    │
│ Commit: abc1234                     │
│ Deployer: john-doe                  │
├─────────────────────────────────────┤
│ [View Logs] [Visit App]             │
└─────────────────────────────────────┘
```

---

## Discord Integration

```yaml
- name: Discord notification
  run: |
    curl -X POST ${{ secrets.DISCORD_WEBHOOK }} \
      -H "Content-Type: application/json" \
      -d '{
        "content": "**Deployment Status**",
        "embeds": [{
          "title": "Production Deployment",
          "description": "Deployment completed successfully ✅",
          "color": 65280,
          "fields": [
            {
              "name": "Commit",
              "value": "${{ github.sha }}",
              "inline": true
            },
            {
              "name": "Branch",
              "value": "${{ github.ref_name }}",
              "inline": true
            },
            {
              "name": "Actor",
              "value": "${{ github.actor }}",
              "inline": true
            }
          ],
          "timestamp": "${{ github.event.head_commit.timestamp }}"
        }]
      }'
```

---

## Critical Alerts: PagerDuty

### When to Use PagerDuty

```
Slack/Discord: Normal deployments, FYI notifications
PagerDuty: CRITICAL failures requiring immediate action

Examples:
  - Production deployment failed
  - Database migration rollback
  - Service health check failing
  - Security incident detected
```

---

### PagerDuty Integration

```yaml
- name: PagerDuty alert on critical failure
  if: failure()
  run: |
    curl -X POST https://events.pagerduty.com/v2/enqueue \
      -H "Content-Type: application/json" \
      -d '{
        "routing_key": "${{ secrets.PAGERDUTY_INTEGRATION_KEY }}",
        "event_action": "trigger",
        "payload": {
          "summary": "CRITICAL: Production deployment failed",
          "severity": "critical",
          "source": "GitHub Actions",
          "component": "deployment-pipeline",
          "custom_details": {
            "commit": "${{ github.sha }}",
            "actor": "${{ github.actor }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}"
          }
        },
        "links": [{
          "href": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}",
          "text": "View GitHub Actions logs"
        }]
      }'
```

**PagerDuty behavior:**
- Sends push notification to on-call engineer
- Calls phone if not acknowledged in 5 minutes
- Escalates to manager if still not acked
- Creates incident timeline

---

## Deployment Metrics Tracking

### Send Metrics to Monitoring Systems

**Datadog:**

```yaml
- name: Send deployment event to Datadog
  run: |
    curl -X POST "https://api.datadoghq.com/api/v1/events" \
      -H "Content-Type: application/json" \
      -H "DD-API-KEY: ${{ secrets.DATADOG_API_KEY }}" \
      -d '{
        "title": "Production Deployment",
        "text": "Deployed commit ${{ github.sha }} by ${{ github.actor }}",
        "priority": "normal",
        "tags": [
          "environment:production",
          "service:api",
          "deployment:${{ github.sha }}"
        ],
        "alert_type": "info"
      }'
```

**New Relic:**

```yaml
- name: Create deployment marker in New Relic
  run: |
    curl -X POST "https://api.newrelic.com/v2/applications/${{ secrets.NEW_RELIC_APP_ID }}/deployments.json" \
      -H "X-Api-Key: ${{ secrets.NEW_RELIC_API_KEY }}" \
      -H "Content-Type: application/json" \
      -d '{
        "deployment": {
          "revision": "${{ github.sha }}",
          "changelog": "See GitHub commit",
          "description": "Production deployment via GitHub Actions",
          "user": "${{ github.actor }}"
        }
      }'
```

---

## Comprehensive Notification Strategy

```yaml
name: Full Notification Pipeline

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Notify deployment start
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Notify start
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"🚀 Production deployment started by ${{ github.actor }}"}'

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Deploy
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Deploy application
        id: deploy
        run: |
          START_TIME=$(date +%s)
          ./deploy.sh
          END_TIME=$(date +%s)
          DURATION=$((END_TIME - START_TIME))
          echo "duration=$DURATION" >> $GITHUB_OUTPUT

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Success notifications
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Notify success (Slack)
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Production deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Duration:* ${{ steps.deploy.outputs.duration }}s\n*Commit:* ${{ github.sha }}\n*By:* ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Record deployment (Datadog)
        if: success()
        run: |
          curl -X POST "https://api.datadoghq.com/api/v1/events" \
            -H "DD-API-KEY: ${{ secrets.DATADOG_API_KEY }}" \
            -d '{
              "title": "Production Deployment",
              "text": "Success",
              "tags": ["environment:production"]
            }'

      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      # Failure notifications (CRITICAL)
      # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      - name: Notify failure (Slack)
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "❌ PRODUCTION DEPLOYMENT FAILED",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "<!channel> Production deployment failed\n*Commit:* ${{ github.sha }}\n*By:* ${{ github.actor }}\n<https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Logs>"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Page on-call engineer
        if: failure()
        run: |
          curl -X POST https://events.pagerduty.com/v2/enqueue \
            -d '{
              "routing_key": "${{ secrets.PAGERDUTY_KEY }}",
              "event_action": "trigger",
              "payload": {
                "summary": "Production deployment failed",
                "severity": "critical"
              }
            }'
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Slack webhook không hoạt động

**Dấu hiệu:**
```
Error: 404 not found
```

**Giải pháp:**
```bash
# Test webhook manually
curl -X POST $SLACK_WEBHOOK \
  -H "Content-Type: application/json" \
  -d '{"text":"Test message"}'

# If 404 → webhook URL sai hoặc đã bị revoke
# → Tạo webhook mới trong Slack
```

---

## 🎓 Tóm Tắt Ngày 49

✅ **Slack**: Real-time deployment notifications với rich formatting
✅ **Discord**: Alternative notification channel
✅ **PagerDuty**: Critical alerts với escalation policies
✅ **Datadog/New Relic**: Deployment markers cho monitoring
✅ **Conditional notifications**: Success vs failure handling
✅ **Rich messages**: Blocks API với buttons và links

**Best practices:**
- ✅ Different channels for different severities (Slack vs PagerDuty)
- ✅ Include actionable info (links to logs, rollback procedures)
- ✅ Notify on START and END of deployments
- ✅ Track deployment metrics (duration, frequency, success rate)
- ✅ Test webhooks before production use

**Next:** Ngày 50 - Rollback Strategy (automated rollback, health checks, recovery procedures)
