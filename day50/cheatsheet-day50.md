# Rollback Strategy - Recovery Procedures

# Rollback git commit
git revert HEAD                                       # revert last commit
git revert abc123                                     # revert specific commit
git push origin main

# Rollback Docker container
docker ps                                             # check running version
docker stop myapp
docker rm myapp
docker run -d --name myapp myapp:v1.2.2               # previous version

# Rollback Kubernetes deployment
kubectl rollout undo deployment/myapp                 # rollback to previous
kubectl rollout undo deployment/myapp --to-revision=3 # specific revision
kubectl rollout history deployment/myapp              # view history

# Automated rollback workflow
cat << 'EOF' > .github/workflows/rollback.yml
name: Rollback Deployment

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
        required: true
      environment:
        type: choice
        options:
          - staging
          - production

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - name: Rollback to ${{ inputs.version }}
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            docker pull myapp:${{ inputs.version }}
            docker stop myapp || true
            docker rm myapp || true
            docker run -d --name myapp myapp:${{ inputs.version }}

      - name: Health check after rollback
        run: |
          sleep 10
          curl -f https://myapp.com/health || exit 1
          echo "✅ Rollback successful"
EOF

# Rollback database migration
# migrations/rollback.sql
ALTER TABLE users DROP COLUMN email_verified;

npm run migrate:rollback                              # run rollback script
npm run migrate:rollback --steps=1                    # rollback 1 migration

# Health check script
cat << 'EOF' > health-check.sh
#!/bin/bash
URL=$1
MAX_ATTEMPTS=30

for i in $(seq 1 $MAX_ATTEMPTS); do
  if curl -f -s $URL/health > /dev/null; then
    echo "✅ Health check passed"
    exit 0
  fi
  echo "⏳ Attempt $i/$MAX_ATTEMPTS failed, retrying..."
  sleep 2
done

echo "❌ Health check failed after $MAX_ATTEMPTS attempts"
exit 1
EOF

# Blue/Green rollback (instant)
# Switch load balancer back to blue environment
aws elbv2 modify-listener --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN

# Rollback with backup restore
cat << 'EOF' > rollback-with-backup.sh
#!/bin/bash
BACKUP_DIR="/var/backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR/app_*.tar.gz | head -1)

echo "🔙 Rolling back to $LATEST_BACKUP"

# Stop current version
pm2 stop myapp

# Restore backup
tar -xzf $LATEST_BACKUP -C /var/www/myapp

# Restart
pm2 restart myapp

# Health check
sleep 5
curl -f http://localhost:3000/health || {
  echo "❌ Rollback failed"
  exit 1
}
EOF

# Automatic rollback on health check failure
cat << 'EOF' > .github/workflows/deploy-safe.yml
name: Deploy with Auto-Rollback

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Backup current version
        run: |
          CURRENT_VERSION=$(docker inspect myapp --format '{{.Config.Image}}')
          echo "PREVIOUS_VERSION=$CURRENT_VERSION" >> $GITHUB_ENV

      - name: Deploy new version
        run: ./deploy.sh

      - name: Health check
        id: health
        run: |
          sleep 10
          if ! curl -f https://myapp.com/health; then
            echo "failed=true" >> $GITHUB_OUTPUT
            exit 1
          fi

      - name: Auto-rollback on failure
        if: failure() && steps.health.outputs.failed == 'true'
        run: |
          echo "🚨 Health check failed, rolling back..."
          docker stop myapp
          docker rm myapp
          docker run -d --name myapp ${{ env.PREVIOUS_VERSION }}

          # Verify rollback
          sleep 5
          curl -f https://myapp.com/health
          echo "✅ Rollback completed"
EOF

# Rollback checklist
cat << 'EOF' > rollback-checklist.md
## Rollback Checklist

### Pre-rollback
- [ ] Identify target version to rollback to
- [ ] Check rollback will fix the issue
- [ ] Notify team in Slack
- [ ] Check database compatibility

### During rollback
- [ ] Execute rollback procedure
- [ ] Monitor error logs
- [ ] Verify health checks pass
- [ ] Test critical user flows

### Post-rollback
- [ ] Confirm metrics returned to normal
- [ ] Notify customers if needed
- [ ] Create incident postmortem
- [ ] Fix root cause before re-deploying
EOF

# Canary rollback
kubectl scale deployment/myapp-canary --replicas=0    # stop canary
kubectl scale deployment/myapp-stable --replicas=10   # back to 100% stable

# Terraform rollback
terraform plan                                        # review changes
terraform apply -target=aws_instance.web              # rollback specific resource
terraform state mv aws_instance.old aws_instance.new  # rename resource

# Feature flag rollback (instant)
curl -X PATCH https://api.myapp.com/admin/features/new_ui \
  -d '{"enabled": false}'                             # disable feature

# Rollback monitoring
cat << 'EOF' > monitor-rollback.sh
#!/bin/bash

echo "📊 Monitoring rollback..."

# Check error rate
ERROR_RATE=$(curl -s http://prometheus/api/v1/query?query=error_rate | jq '.data.result[0].value[1]')
echo "Error rate: $ERROR_RATE%"

# Check latency
LATENCY=$(curl -s http://prometheus/api/v1/query?query=latency_p99 | jq '.data.result[0].value[1]')
echo "P99 latency: ${LATENCY}ms"

# Check active users
USERS=$(curl -s http://myapp.com/api/metrics/active-users | jq '.count')
echo "Active users: $USERS"

if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
  echo "❌ Error rate still high after rollback"
  exit 1
fi

echo "✅ Metrics look healthy after rollback"
EOF

# Progressive rollback (gradual)
# Roll back 10% → 50% → 100%
kubectl scale deployment/myapp-new --replicas=9       # reduce new to 90%
kubectl scale deployment/myapp-old --replicas=1       # increase old to 10%

sleep 300                                             # monitor 5 minutes

kubectl scale deployment/myapp-new --replicas=5       # 50% new
kubectl scale deployment/myapp-old --replicas=5       # 50% old

sleep 300

kubectl scale deployment/myapp-new --replicas=0       # 0% new
kubectl scale deployment/myapp-old --replicas=10      # 100% old (fully rolled back)

# Rollback notification
curl -X POST $SLACK_WEBHOOK \
  -d '{
    "text": "🔙 Rollback initiated",
    "blocks": [{
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "Rollback from v1.2.3 → v1.2.2\nReason: High error rate\nStatus: In progress"
      }
    }]
  }'

# Database rollback with backup
pg_dump mydb > backup_before_rollback.sql             # backup first
psql mydb < migrations/down_001.sql                   # rollback migration
