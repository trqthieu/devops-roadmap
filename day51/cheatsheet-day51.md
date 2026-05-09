# Project CD - Full CD Pipeline Implementation

# Complete CD workflow: CI → Staging → Approval → Production

cat << 'EOF' > .github/workflows/full-cd-pipeline.yml
name: Full CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Stage 1: CI (Build & Test)
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm test

      - name: Build
        run: npm run build

      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Scan image
        run: |
          docker run --rm aquasec/trivy image \
            --severity HIGH,CRITICAL myapp:${{ github.sha }}

      - name: Push image
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker tag myapp:${{ github.sha }} myapp:latest
          docker push myapp:${{ github.sha }}
          docker push myapp:latest

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Stage 2: Deploy to Staging
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-staging:
    needs: ci
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.myapp.com
    if: github.event_name == 'push'

    steps:
      - name: Deploy to staging
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            docker pull myapp:${{ github.sha }}
            docker stop myapp-staging || true
            docker rm myapp-staging || true
            docker run -d --name myapp-staging \
              -p 3000:3000 \
              -e NODE_ENV=staging \
              myapp:${{ github.sha }}

      - name: Health check
        run: |
          sleep 30
          for i in {1..30}; do
            if curl -f https://staging.myapp.com/health; then
              echo "✅ Staging deployment successful"
              exit 0
            fi
            sleep 2
          done
          exit 1

      - name: Run smoke tests
        run: |
          curl -f https://staging.myapp.com/api/users
          curl -f https://staging.myapp.com/api/status

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Deployed to staging: ${{ github.sha }}\nhttps://staging.myapp.com"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Stage 3: Manual Approval + Deploy Production
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.com
    if: github.event_name == 'push'

    steps:
      - name: Notify approval required
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "⏳ Production deployment waiting for approval\nhttps://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

      - name: Deploy to production
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            # Backup current version
            CURRENT_VERSION=$(docker inspect myapp --format '{{.Config.Image}}' 2>/dev/null || echo "none")
            echo $CURRENT_VERSION > /tmp/previous_version.txt

            # Deploy new version
            docker pull myapp:${{ github.sha }}
            docker stop myapp || true
            docker rm myapp || true
            docker run -d --name myapp \
              -p 3000:3000 \
              -e NODE_ENV=production \
              --restart unless-stopped \
              myapp:${{ github.sha }}

      - name: Health check with auto-rollback
        id: health
        run: |
          sleep 30
          for i in {1..30}; do
            if curl -f https://myapp.com/health; then
              echo "✅ Health check passed"
              exit 0
            fi
            sleep 2
          done
          echo "failed=true" >> $GITHUB_OUTPUT
          exit 1

      - name: Rollback on failure
        if: failure() && steps.health.outputs.failed == 'true'
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            PREVIOUS_VERSION=$(cat /tmp/previous_version.txt)
            echo "🚨 Rolling back to $PREVIOUS_VERSION"

            docker stop myapp || true
            docker rm myapp || true
            docker run -d --name myapp \
              -p 3000:3000 \
              -e NODE_ENV=production \
              --restart unless-stopped \
              $PREVIOUS_VERSION

            sleep 10
            curl -f https://myapp.com/health

      - name: Notify production deployment
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "${{ job.status == 'success' && '✅' || '❌' }} Production deployment ${{ job.status }}: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
EOF

# Rollback workflow for production emergencies
cat << 'EOF' > .github/workflows/emergency-rollback.yml
name: Emergency Rollback

on:
  workflow_dispatch:
    inputs:
      target_version:
        description: 'Version to rollback to'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Rollback production
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            docker pull myapp:${{ inputs.target_version }}
            docker stop myapp
            docker rm myapp
            docker run -d --name myapp \
              -p 3000:3000 \
              -e NODE_ENV=production \
              --restart unless-stopped \
              myapp:${{ inputs.target_version }}

      - name: Verify rollback
        run: |
          sleep 30
          curl -f https://myapp.com/health
          echo "✅ Rollback successful"
EOF

# Multi-environment configuration
cat << 'EOF' > docker-compose.staging.yml
version: '3.8'

services:
  app:
    image: myapp:${VERSION}
    environment:
      - NODE_ENV=staging
      - DATABASE_URL=postgresql://staging-db/myapp
      - REDIS_URL=redis://staging-redis:6379
    ports:
      - "3000:3000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - staging-db-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine

volumes:
  staging-db-data:
EOF

cat << 'EOF' > docker-compose.production.yml
version: '3.8'

services:
  app:
    image: myapp:${VERSION}
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://prod-db/myapp
      - REDIS_URL=redis://prod-redis:6379
    ports:
      - "3000:3000"
    restart: always
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - prod-db-data:/var/lib/postgresql/data
    restart: always

  redis:
    image: redis:7-alpine
    restart: always

volumes:
  prod-db-data:
EOF

# Environment secrets setup guide
cat << 'EOF' > setup-environments.sh
#!/bin/bash

# GitHub Repository Settings → Environments

# 1. Create staging environment
#    - No approval required
#    - Secrets: STAGING_HOST, SSH_USER, SSH_PRIVATE_KEY

# 2. Create production environment
#    - Required reviewers: 2 people
#    - Wait timer: 5 minutes
#    - Secrets: PRODUCTION_HOST, SSH_USER, SSH_PRIVATE_KEY

# Add secrets via GitHub UI or gh CLI
gh secret set STAGING_HOST -b "staging.myapp.com" --env staging
gh secret set PRODUCTION_HOST -b "myapp.com" --env production
gh secret set SSH_USER -b "deploy" --env staging
gh secret set SSH_USER -b "deploy" --env production
gh secret set SSH_PRIVATE_KEY < ~/.ssh/deploy_key --env staging
gh secret set SSH_PRIVATE_KEY < ~/.ssh/deploy_key --env production
EOF

# Blue/Green deployment script
cat << 'EOF' > scripts/deploy-blue-green.sh
#!/bin/bash
set -e

ENVIRONMENT=$1
VERSION=$2
CURRENT_COLOR=$(cat /tmp/current_color.txt 2>/dev/null || echo "blue")

# Determine target color
if [ "$CURRENT_COLOR" == "blue" ]; then
  TARGET_COLOR="green"
else
  TARGET_COLOR="blue"
fi

echo "🎨 Current: $CURRENT_COLOR, Target: $TARGET_COLOR"

# Deploy to target environment
docker pull myapp:$VERSION
docker stop myapp-$TARGET_COLOR || true
docker rm myapp-$TARGET_COLOR || true

docker run -d \
  --name myapp-$TARGET_COLOR \
  -p $([ "$TARGET_COLOR" == "blue" ] && echo "3000" || echo "3001"):3000 \
  -e NODE_ENV=$ENVIRONMENT \
  myapp:$VERSION

# Health check
sleep 30
HEALTH_URL="http://localhost:$([ "$TARGET_COLOR" == "blue" ] && echo "3000" || echo "3001")/health"

for i in {1..30}; do
  if curl -f $HEALTH_URL; then
    echo "✅ $TARGET_COLOR is healthy"
    break
  fi
  sleep 2
done

# Switch nginx upstream
sudo sed -i "s/myapp-$CURRENT_COLOR/myapp-$TARGET_COLOR/" /etc/nginx/sites-enabled/myapp.conf
sudo nginx -t
sudo nginx -s reload

echo "$TARGET_COLOR" > /tmp/current_color.txt
echo "✅ Switched traffic to $TARGET_COLOR"
EOF

# Canary deployment script
cat << 'EOF' > scripts/deploy-canary.sh
#!/bin/bash
set -e

VERSION=$1
CANARY_PERCENTAGE=${2:-10}

echo "🐤 Deploying canary: $CANARY_PERCENTAGE% traffic"

# Deploy canary
docker pull myapp:$VERSION
docker stop myapp-canary || true
docker rm myapp-canary || true

docker run -d \
  --name myapp-canary \
  -p 3002:3000 \
  -e NODE_ENV=production \
  myapp:$VERSION

# Update nginx weight
cat > /tmp/nginx-canary.conf << NGINX
upstream backend {
  server localhost:3000 weight=$((100 - CANARY_PERCENTAGE));
  server localhost:3002 weight=$CANARY_PERCENTAGE;
}
NGINX

sudo cp /tmp/nginx-canary.conf /etc/nginx/conf.d/backend.conf
sudo nginx -s reload

echo "✅ Canary deployed with $CANARY_PERCENTAGE% traffic"

# Monitor for 5 minutes
echo "📊 Monitoring canary..."
sleep 300

# If successful, promote canary
read -p "Promote canary to 100%? (y/n): " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  docker stop myapp
  docker rm myapp
  docker run -d --name myapp -p 3000:3000 -e NODE_ENV=production myapp:$VERSION
  docker stop myapp-canary
  echo "✅ Canary promoted to production"
fi
EOF

# Progressive deployment workflow
cat << 'EOF' > .github/workflows/progressive-deployment.yml
name: Progressive Deployment

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy-10-percent:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to 10% users
        run: ./scripts/deploy-canary.sh ${{ github.ref_name }} 10

      - name: Monitor metrics
        run: |
          sleep 600
          ERROR_RATE=$(curl -s http://prometheus/api/v1/query?query=error_rate)
          if [ "$ERROR_RATE" -gt "1" ]; then
            echo "❌ High error rate, stopping deployment"
            exit 1
          fi

  deploy-50-percent:
    needs: deploy-10-percent
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to 50% users
        run: ./scripts/deploy-canary.sh ${{ github.ref_name }} 50

      - name: Monitor metrics
        run: sleep 600

  deploy-100-percent:
    needs: deploy-50-percent
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy to 100% users
        run: ./scripts/deploy-canary.sh ${{ github.ref_name }} 100
EOF

# Deployment verification script
cat << 'EOF' > scripts/verify-deployment.sh
#!/bin/bash

ENVIRONMENT=$1
BASE_URL=$2

echo "🔍 Verifying deployment on $ENVIRONMENT"

# Health check
curl -f $BASE_URL/health || { echo "❌ Health check failed"; exit 1; }

# Version check
VERSION=$(curl -s $BASE_URL/version | jq -r '.version')
echo "Version: $VERSION"

# API smoke tests
curl -f $BASE_URL/api/users || { echo "❌ Users API failed"; exit 1; }
curl -f $BASE_URL/api/status || { echo "❌ Status API failed"; exit 1; }

# Performance test
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' $BASE_URL)
echo "Response time: ${RESPONSE_TIME}s"

if (( $(echo "$RESPONSE_TIME > 1.0" | bc -l) )); then
  echo "⚠️  Response time > 1s"
fi

# Database connectivity
curl -f $BASE_URL/api/db-health || { echo "❌ Database connection failed"; exit 1; }

echo "✅ All verification checks passed"
EOF

# Deployment runbook
cat << 'EOF' > docs/deployment-runbook.md
# Deployment Runbook

## Normal Deployment Flow

1. **Merge PR to main**
   → CI runs automatically
   → Build & test
   → Push Docker image

2. **Deploy to Staging**
   → Automatic after CI success
   → Health checks
   → Smoke tests

3. **Manual Approval**
   → Go to GitHub Actions
   → Review staging deployment
   → Approve production deployment

4. **Deploy to Production**
   → Automatic after approval
   → Health checks with auto-rollback
   → Slack notification

## Emergency Rollback

1. Go to GitHub Actions → Emergency Rollback workflow
2. Click "Run workflow"
3. Enter target version (e.g., v1.2.3)
4. Click "Run workflow"
5. Verify in Slack notification

## Monitoring Deployment

- **Staging:** https://staging.myapp.com
- **Production:** https://myapp.com
- **Metrics:** http://grafana.myapp.com
- **Logs:** `docker logs myapp`

## Troubleshooting

### Deployment fails on staging
1. Check logs: `ssh staging-server 'docker logs myapp-staging'`
2. Check health endpoint: `curl https://staging.myapp.com/health`
3. Rollback if needed: Use Emergency Rollback workflow

### Production approval blocked
1. Verify staging is stable (check for 10+ minutes)
2. Review metrics in Grafana
3. Get approval from 2 team members

### Post-deployment issues
1. Check error rate in Grafana
2. If > 1%, trigger rollback immediately
3. Investigate root cause in staging
EOF

chmod +x scripts/*.sh
