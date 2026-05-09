# Notifications & Monitoring - CI/CD Alerts

# Slack notification
cat << 'EOF' > .github/workflows/slack-notify.yml
name: Slack Notifications

on: [push]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Notify deployment start
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚀 Deployment started by ${{ github.actor }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - run: ./deploy.sh

      - name: Notify success
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Commit:* <https://github.com/${{ github.repository}}/commit/${{ github.sha }}|${{ github.sha }}>\n*Branch:* ${{ github.ref_name }}\n*Deployer:* ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Notify failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "❌ Deployment failed"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
EOF

# Setup Slack webhook
# Slack → Apps → Incoming Webhooks → Add New Webhook to Workspace
# → Choose channel → Copy webhook URL
# GitHub → Settings → Secrets → SLACK_WEBHOOK

# Discord webhook
cat << 'EOF' > .github/workflows/discord-notify.yml
name: Discord Notifications

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Notify Discord
        run: |
          curl -X POST ${{ secrets.DISCORD_WEBHOOK }} \
            -H "Content-Type: application/json" \
            -d '{
              "content": "**Deployment Status**",
              "embeds": [{
                "title": "Production Deployment",
                "description": "Deployment completed successfully",
                "color": 65280,
                "fields": [
                  {"name": "Commit", "value": "${{ github.sha }}", "inline": true},
                  {"name": "Branch", "value": "${{ github.ref_name }}", "inline": true},
                  {"name": "Actor", "value": "${{ github.actor }}", "inline": true}
                ]
              }]
            }'
EOF

# Email notification (GitHub native)
# Settings → Notifications → Email notifications
# → Check "Send notifications for failed workflows"

# Microsoft Teams webhook
cat << 'EOF' > .github/workflows/teams-notify.yml
name: Teams Notifications

jobs:
  notify:
    steps:
      - name: Notify Teams
        run: |
          curl -X POST ${{ secrets.TEAMS_WEBHOOK }} \
            -H "Content-Type: application/json" \
            -d '{
              "@type": "MessageCard",
              "@context": "https://schema.org/extensions",
              "summary": "Deployment Status",
              "themeColor": "0078D4",
              "title": "Production Deployment",
              "sections": [{
                "facts": [
                  {"name": "Status", "value": "Success"},
                  {"name": "Commit", "value": "${{ github.sha }}"},
                  {"name": "Branch", "value": "${{ github.ref_name }}"}
                ]
              }]
            }'
EOF

# GitHub Actions script (advanced notifications)
cat << 'EOF' > .github/workflows/github-script-notify.yml
name: Advanced Notifications

jobs:
  notify:
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const message = `
            ## 🚀 Deployment Report

            **Status:** ✅ Successful
            **Environment:** Production
            **Commit:** ${context.sha}
            **Branch:** ${context.ref}
            **Deployer:** ${context.actor}
            **Duration:** 5m 32s

            [View Deployment](https://myapp.com)
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: message
            });
EOF

# Telegram notification
cat << 'EOF' > .github/workflows/telegram-notify.yml
name: Telegram Notifications

jobs:
  notify:
    steps:
      - name: Send Telegram message
        run: |
          curl -X POST "https://api.telegram.org/bot${{ secrets.TELEGRAM_BOT_TOKEN }}/sendMessage" \
            -d "chat_id=${{ secrets.TELEGRAM_CHAT_ID }}" \
            -d "text=✅ Deployment successful: ${{ github.sha }}" \
            -d "parse_mode=HTML"
EOF

# PagerDuty alert (critical failures)
cat << 'EOF' > .github/workflows/pagerduty-alert.yml
name: PagerDuty Alerts

jobs:
  deploy:
    steps:
      - run: ./deploy.sh

      - name: PagerDuty alert on failure
        if: failure()
        run: |
          curl -X POST https://events.pagerduty.com/v2/enqueue \
            -H "Content-Type: application/json" \
            -d '{
              "routing_key": "${{ secrets.PAGERDUTY_INTEGRATION_KEY }}",
              "event_action": "trigger",
              "payload": {
                "summary": "Production deployment failed",
                "severity": "critical",
                "source": "GitHub Actions",
                "custom_details": {
                  "commit": "${{ github.sha }}",
                  "actor": "${{ github.actor }}"
                }
              }
            }'
EOF

# Conditional notifications (only on main branch)
jobs:
  notify:
    if: github.ref == 'refs/heads/main'
    steps:
      - run: echo "Notifying production deployment"

# Notification only on failure
jobs:
  deploy:
    steps:
      - run: ./deploy.sh

      - name: Notify only on failure
        if: failure()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"❌ Deployment failed!"}'

# Job status summary
jobs:
  summary:
    if: always()
    needs: [build, test, deploy]
    steps:
      - name: Check all statuses
        run: |
          SUMMARY="📊 Pipeline Summary\n"
          SUMMARY+="Build: ${{ needs.build.result }}\n"
          SUMMARY+="Test: ${{ needs.test.result }}\n"
          SUMMARY+="Deploy: ${{ needs.deploy.result }}"

          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d "{\"text\":\"$SUMMARY\"}"

# Deployment metrics tracking
cat << 'EOF' > .github/workflows/metrics-tracking.yml
name: Deployment Metrics

jobs:
  deploy:
    steps:
      - name: Record deployment start
        run: echo "START_TIME=$(date +%s)" >> $GITHUB_ENV

      - run: ./deploy.sh

      - name: Calculate duration
        run: |
          END_TIME=$(date +%s)
          DURATION=$((END_TIME - START_TIME))
          echo "Deployment took ${DURATION}s"

          # Send to monitoring
          curl -X POST https://metrics.myapp.com/api/deployments \
            -d "duration=$DURATION" \
            -d "status=success" \
            -d "commit=${{ github.sha }}"
EOF

# Rich Slack message with buttons
cat << 'EOF' > .github/workflows/rich-slack-message.yml
name: Rich Notifications

jobs:
  notify:
    steps:
      - uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployment Status",
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
                    {"type": "mrkdwn", "text": "*Status:*\n✅ Success"},
                    {"type": "mrkdwn", "text": "*Duration:*\n5m 32s"},
                    {"type": "mrkdwn", "text": "*Commit:*\n${{ github.sha }}"},
                    {"type": "mrkdwn", "text": "*By:*\n${{ github.actor }}"}
                  ]
                },
                {
                  "type": "actions",
                  "elements": [
                    {
                      "type": "button",
                      "text": {"type": "plain_text", "text": "View Deployment"},
                      "url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                    },
                    {
                      "type": "button",
                      "text": {"type": "plain_text", "text": "View App"},
                      "url": "https://myapp.com"
                    }
                  ]
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
EOF

# Datadog event tracking
curl -X POST "https://api.datadoghq.com/api/v1/events" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -d '{
    "title": "Production Deployment",
    "text": "Deployed commit: '$COMMIT_SHA'",
    "tags": ["environment:production", "service:api"]
  }'

# New Relic deployment marker
curl -X POST "https://api.newrelic.com/v2/applications/$APP_ID/deployments.json" \
  -H "X-Api-Key: $NEW_RELIC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "deployment": {
      "revision": "'$COMMIT_SHA'",
      "changelog": "See GitHub",
      "description": "Production deployment",
      "user": "'$GITHUB_ACTOR'"
    }
  }'

# Webhook notification template
notify_webhook() {
  STATUS=$1
  MESSAGE=$2

  curl -X POST $WEBHOOK_URL \
    -H "Content-Type: application/json" \
    -d "{
      \"status\": \"$STATUS\",
      \"message\": \"$MESSAGE\",
      \"commit\": \"$GITHUB_SHA\",
      \"repository\": \"$GITHUB_REPOSITORY\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }"
}
