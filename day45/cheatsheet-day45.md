# Deploy Strategies - Deployment Patterns

# Rolling Update deployment
cat << 'EOF' > .github/workflows/rolling-update.yml
name: Rolling Update Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy với rolling update
        run: |
          # Update từng instance một, chờ health check pass
          for instance in server1 server2 server3; do
            echo "Deploying to $instance"
            ssh $instance "docker pull myapp:latest"
            ssh $instance "docker-compose up -d"

            # Health check
            for i in {1..30}; do
              if curl -f http://$instance/health; then
                echo "$instance healthy"
                break
              fi
              sleep 2
            done
          done
EOF

# Blue/Green deployment
cat << 'EOF' > .github/workflows/blue-green.yml
name: Blue/Green Deploy

jobs:
  deploy:
    steps:
      - name: Deploy to green environment
        run: |
          # Deploy version mới lên green
          ssh green.myapp.com "docker-compose up -d"

      - name: Smoke test green
        run: |
          curl -f http://green.myapp.com/health
          curl -f http://green.myapp.com/api/status

      - name: Switch traffic to green
        run: |
          # Update load balancer để point tới green
          aws elbv2 modify-rule --target-group green-tg

      - name: Monitor for issues
        run: |
          sleep 300  # 5 phút monitoring
          # Nếu có lỗi → rollback bằng cách point lại blue
EOF

# Canary deployment
cat << 'EOF' > .github/workflows/canary.yml
name: Canary Deploy

jobs:
  deploy:
    steps:
      - name: Deploy canary (10% traffic)
        run: |
          # Deploy version mới, route 10% traffic
          kubectl set image deployment/app app=myapp:v2
          kubectl scale deployment/app-canary --replicas=1
          kubectl scale deployment/app-stable --replicas=9

      - name: Monitor metrics
        run: |
          # Watch error rate, latency trong 10 phút
          sleep 600

      - name: Promote canary to 50%
        run: |
          kubectl scale deployment/app-canary --replicas=5
          kubectl scale deployment/app-stable --replicas=5

      - name: Promote canary to 100%
        run: |
          kubectl scale deployment/app-canary --replicas=10
          kubectl scale deployment/app-stable --replicas=0
EOF

# Feature flags
cat << 'EOF' > deploy-with-feature-flags.sh
#!/bin/bash

# Deploy with feature flag disabled
docker run -e FEATURE_NEW_UI=false myapp:latest

# Sau khi test OK, enable via config (không cần redeploy)
# Update environment variable hoặc config file
curl -X POST https://api.myapp.com/admin/features \
  -d '{"new_ui": true, "rollout_percentage": 10}'

# Gradually increase
curl -X PATCH https://api.myapp.com/admin/features/new_ui \
  -d '{"rollout_percentage": 50}'
EOF

# So sánh strategies
cat << 'EOF' > deployment-comparison.txt
┌─────────────────┬──────────────┬──────────────┬─────────────┬──────────────┐
│ Strategy        │ Downtime     │ Rollback     │ Cost        │ Complexity   │
├─────────────────┼──────────────┼──────────────┼─────────────┼──────────────┤
│ Rolling Update  │ No downtime  │ Slow (phút)  │ Low         │ Simple       │
│ Blue/Green      │ No downtime  │ Fast (giây)  │ High (2x)   │ Medium       │
│ Canary          │ No downtime  │ Fast         │ Medium      │ Complex      │
│ Feature Flags   │ No downtime  │ Instant      │ Low         │ Medium       │
│ Recreate        │ Có downtime  │ Slow         │ Low         │ Very Simple  │
└─────────────────┴──────────────┴──────────────┴─────────────┴──────────────┘
EOF

# Rolling update với Docker Compose
cat << 'EOF' > docker-compose.rolling.yml
version: '3.8'

services:
  app:
    image: myapp:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1                # update 1 container 1 lúc
        delay: 10s                    # chờ 10s giữa mỗi update
        failure_action: rollback      # tự động rollback nếu fail
        order: start-first            # start new trước khi stop old
      rollback_config:
        parallelism: 0                # rollback all cùng lúc
        order: stop-first
EOF

# Blue/Green với Nginx
cat << 'EOF' > nginx-blue-green.conf
upstream backend {
    # Ban đầu: 100% traffic đến blue
    server blue.myapp.com:3000 weight=100;
    server green.myapp.com:3000 weight=0;
}

# Khi muốn switch:
# 1. Test green: curl http://green.myapp.com:3000/health
# 2. Update config:
upstream backend {
    server blue.myapp.com:3000 weight=0;
    server green.myapp.com:3000 weight=100;
}
# 3. Reload: nginx -s reload
EOF

# Canary với Kubernetes
kubectl set image deployment/app app=myapp:v2                  # deploy v2
kubectl scale deployment/app --replicas=10                     # 10 pods total

# Canary: 1 pod v2, 9 pods v1 → 10% traffic
kubectl scale deployment/app-canary --replicas=1
kubectl scale deployment/app-stable --replicas=9

# Promote: 5 pods v2, 5 pods v1 → 50%
kubectl scale deployment/app-canary --replicas=5
kubectl scale deployment/app-stable --replicas=5

# Full deploy: 10 pods v2
kubectl scale deployment/app-canary --replicas=10
kubectl scale deployment/app-stable --replicas=0

# Feature flags trong code
# app.js
const features = {
  newUI: process.env.FEATURE_NEW_UI === 'true',
  betaAPI: process.env.FEATURE_BETA_API === 'true'
}

if (features.newUI) {
  app.use('/ui', newUIRouter)
} else {
  app.use('/ui', oldUIRouter)
}

# Feature flags với percentage rollout
function isFeatureEnabled(featureName, userId) {
  const rolloutPercentage = getFeatureRollout(featureName)  // e.g., 10
  const userHash = hashUserId(userId) % 100
  return userHash < rolloutPercentage
}

# Rollback strategies
# 1. Rollback Docker container
docker ps                                                      # xem container running
docker stop myapp-new
docker start myapp-old
docker rm myapp-new

# 2. Rollback Docker Compose
docker-compose down
docker-compose up -d --no-deps --build app                    # rebuild specific service

# 3. Rollback với git tag
git tag                                                        # list tags
docker pull myapp:v1.2.3                                       # pull old version
docker-compose up -d

# 4. Rollback Blue/Green (instant)
# Chỉ cần switch load balancer lại blue
aws elbv2 modify-target-groups --target-group blue-tg

# Health check script
cat << 'EOF' > health-check.sh
#!/bin/bash
HOST=$1
MAX_RETRIES=30
RETRY_INTERVAL=2

for i in $(seq 1 $MAX_RETRIES); do
  if curl -f -s http://$HOST/health > /dev/null; then
    echo "✅ $HOST is healthy"
    exit 0
  fi
  echo "⏳ Waiting for $HOST... ($i/$MAX_RETRIES)"
  sleep $RETRY_INTERVAL
done

echo "❌ $HOST health check failed"
exit 1
EOF

# Smoke test script
cat << 'EOF' > smoke-test.sh
#!/bin/bash
BASE_URL=$1

# Test critical endpoints
echo "Testing $BASE_URL"

curl -f $BASE_URL/health || exit 1
curl -f $BASE_URL/api/status || exit 1
curl -f $BASE_URL/api/users/1 || exit 1

# Test latency
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' $BASE_URL)
if (( $(echo "$RESPONSE_TIME > 1.0" | bc -l) )); then
  echo "❌ Response time too slow: ${RESPONSE_TIME}s"
  exit 1
fi

echo "✅ All smoke tests passed"
EOF

# Traffic split với nginx
upstream backend {
    # 90% traffic blue, 10% green (canary)
    server blue.myapp.com:3000 weight=9;
    server green.myapp.com:3000 weight=1;
}

# Deploy workflow với rollback capability
cat << 'EOF' > .github/workflows/deploy-safe.yml
name: Safe Deploy

on:
  workflow_dispatch:
    inputs:
      strategy:
        description: 'Deployment strategy'
        required: true
        type: choice
        options:
          - rolling
          - blue-green
          - canary

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy
        id: deploy
        run: |
          if [ "${{ inputs.strategy }}" == "rolling" ]; then
            ./scripts/deploy-rolling.sh
          elif [ "${{ inputs.strategy }}" == "blue-green" ]; then
            ./scripts/deploy-blue-green.sh
          else
            ./scripts/deploy-canary.sh
          fi

      - name: Health check
        run: ./scripts/health-check.sh production.myapp.com

      - name: Rollback on failure
        if: failure()
        run: ./scripts/rollback.sh
EOF

# Gradual rollout example
# Day 1: Deploy to 1% users
ROLLOUT_PERCENTAGE=1 ./deploy.sh

# Day 2: Monitor metrics, increase to 10%
ROLLOUT_PERCENTAGE=10 ./deploy.sh

# Day 3: 50%
ROLLOUT_PERCENTAGE=50 ./deploy.sh

# Day 4: 100% (full deployment)
ROLLOUT_PERCENTAGE=100 ./deploy.sh
