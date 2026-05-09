# Deploy lên VPS/EC2 - SSH Actions & Scripts

# Basic SSH deployment
ssh user@server.com "cd /app && git pull && docker-compose up -d"

# GitHub Actions workflow với SSH
cat << 'EOF' > .github/workflows/deploy-ssh.yml
name: Deploy to VPS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT }}
          script: |
            cd /var/www/myapp
            git pull origin main
            npm install --production
            pm2 restart myapp
EOF

# Setup SSH key cho GitHub Actions
ssh-keygen -t ed25519 -C "github-actions" -f deploy_key
# → Public key: deploy_key.pub (add vào server ~/.ssh/authorized_keys)
# → Private key: deploy_key (add vào GitHub Secrets: SSH_PRIVATE_KEY)

# Add SSH key vào server
ssh user@server.com
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test SSH connection
ssh -i deploy_key user@server.com "echo 'Connection successful'"

# Deploy với rsync (faster than git pull)
cat << 'EOF' > .github/workflows/deploy-rsync.yml
name: Deploy with rsync

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build application
        run: |
          npm ci
          npm run build

      - name: Deploy with rsync
        run: |
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > deploy_key
          chmod 600 deploy_key

          rsync -avz --delete \
            -e "ssh -i deploy_key -o StrictHostKeyChecking=no" \
            dist/ \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:/var/www/myapp/

          rm deploy_key
EOF

# Deploy script trên server
cat << 'EOF' > /var/www/myapp/deploy.sh
#!/bin/bash
set -e

APP_DIR="/var/www/myapp"
BACKUP_DIR="/var/www/backups"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Starting deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Backup current version
echo "📦 Creating backup..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/app_$TIMESTAMP.tar.gz -C $APP_DIR .

# 2. Pull latest code
echo "📥 Pulling latest code..."
cd $APP_DIR
git pull origin main

# 3. Install dependencies
echo "📚 Installing dependencies..."
npm ci --production

# 4. Run database migrations
echo "🗄️  Running migrations..."
npm run migrate

# 5. Build application
echo "🔨 Building application..."
npm run build

# 6. Restart application
echo "🔄 Restarting application..."
pm2 reload myapp

# 7. Health check
echo "🏥 Health check..."
sleep 5
if curl -f http://localhost:3000/health; then
  echo "✅ Deployment successful"
else
  echo "❌ Health check failed, rolling back..."
  tar -xzf $BACKUP_DIR/app_$TIMESTAMP.tar.gz -C $APP_DIR
  pm2 reload myapp
  exit 1
fi

# 8. Cleanup old backups (keep last 5)
echo "🧹 Cleaning up old backups..."
cd $BACKUP_DIR
ls -t | tail -n +6 | xargs -r rm

echo "✅ Deployment completed successfully"
EOF

chmod +x /var/www/myapp/deploy.sh

# Deploy với Docker
cat << 'EOF' > .github/workflows/deploy-docker.yml
name: Deploy Docker to VPS

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build -t myapp:latest .
          docker save myapp:latest | gzip > myapp.tar.gz

      - name: Copy image to server
        uses: appleboy/scp-action@v0.1.4
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          source: "myapp.tar.gz,docker-compose.yml"
          target: "/tmp"

      - name: Deploy on server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /tmp
            docker load < myapp.tar.gz
            docker-compose up -d
            docker system prune -f
EOF

# Multi-server deployment
cat << 'EOF' > .github/workflows/deploy-multi-server.yml
name: Deploy to Multiple Servers

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        server:
          - host: server1.myapp.com
            name: Production 1
          - host: server2.myapp.com
            name: Production 2
          - host: server3.myapp.com
            name: Production 3

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to ${{ matrix.server.name }}
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ matrix.server.host }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            /var/www/myapp/deploy.sh
EOF

# Deploy với environment variables
cat << 'EOF' > .github/workflows/deploy-env.yml
name: Deploy with Env

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Create .env file
        run: |
          cat > .env << 'ENVFILE'
          NODE_ENV=production
          DATABASE_URL=${{ secrets.DATABASE_URL }}
          API_KEY=${{ secrets.API_KEY }}
          REDIS_URL=${{ secrets.REDIS_URL }}
          ENVFILE

      - name: Copy .env to server
        uses: appleboy/scp-action@v0.1.4
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          source: ".env"
          target: "/var/www/myapp/"

      - name: Deploy
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /var/www/myapp
            docker-compose up -d
EOF

# Zero-downtime deployment script
cat << 'EOF' > /var/www/myapp/zero-downtime-deploy.sh
#!/bin/bash
set -e

APP_NAME="myapp"
APP_DIR="/var/www/myapp"
PORT=3000

echo "🚀 Zero-downtime deployment"

# 1. Pull latest code
cd $APP_DIR
git pull origin main

# 2. Install dependencies
npm ci --production

# 3. Build new version
npm run build

# 4. Start new process on different port
PORT=3001 pm2 start dist/index.js --name ${APP_NAME}-new

# 5. Wait for new process to be ready
sleep 10
if ! curl -f http://localhost:3001/health; then
  echo "❌ New version failed health check"
  pm2 delete ${APP_NAME}-new
  exit 1
fi

# 6. Update nginx to point to new port
cat > /etc/nginx/conf.d/myapp.conf << 'NGINX'
upstream backend {
    server localhost:3001;  # new version
}
NGINX

nginx -s reload

# 7. Stop old process
pm2 delete $APP_NAME || true

# 8. Rename new process
pm2 restart ${APP_NAME}-new --name $APP_NAME

echo "✅ Deployment completed"
EOF

# Rollback script
cat << 'EOF' > /var/www/myapp/rollback.sh
#!/bin/bash
set -e

BACKUP_DIR="/var/www/backups"

# Get latest backup
LATEST_BACKUP=$(ls -t $BACKUP_DIR/app_*.tar.gz | head -1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "❌ No backup found"
  exit 1
fi

echo "🔙 Rolling back to $LATEST_BACKUP"

# Extract backup
tar -xzf $LATEST_BACKUP -C /var/www/myapp

# Restart application
cd /var/www/myapp
pm2 reload myapp

echo "✅ Rollback completed"
EOF

# Deploy monitoring
cat << 'EOF' > .github/workflows/deploy-with-monitoring.yml
name: Deploy with Monitoring

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Notify deployment start
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"🚀 Deployment started"}'

      - name: Deploy
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: /var/www/myapp/deploy.sh

      - name: Health check
        run: |
          sleep 10
          curl -f https://myapp.com/health

      - name: Notify success
        if: success()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"✅ Deployment successful"}'

      - name: Notify failure
        if: failure()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text":"❌ Deployment failed"}'
EOF

# Deploy script với validation
cat << 'EOF' > deploy-validated.sh
#!/bin/bash
set -e

# Pre-deployment checks
echo "🔍 Pre-deployment validation"

# Check disk space
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
  echo "❌ Disk usage too high: ${DISK_USAGE}%"
  exit 1
fi

# Check database connection
if ! psql -h localhost -U user -d db -c "SELECT 1" > /dev/null; then
  echo "❌ Database connection failed"
  exit 1
fi

# Deploy
echo "🚀 Deploying..."
cd /var/www/myapp
git pull
npm ci
pm2 reload myapp

# Post-deployment validation
echo "🏥 Post-deployment validation"
sleep 5

# Health check
if ! curl -f http://localhost:3000/health; then
  echo "❌ Health check failed"
  exit 1
fi

# Smoke tests
curl -f http://localhost:3000/api/status
curl -f http://localhost:3000/api/version

echo "✅ Deployment successful"
EOF

# AWS EC2 deployment
aws ec2 describe-instances --filters "Name=tag:Name,Values=production"  # list instances
aws ssm send-command --instance-ids i-1234567890abcdef0 \
  --document-name "AWS-RunShellScript" \
  --parameters commands="/var/www/myapp/deploy.sh"

# Systemd service deployment
cat << 'EOF' > /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable myapp
systemctl restart myapp
systemctl status myapp

# Blue/Green deployment với SSH
cat << 'EOF' > blue-green-ssh-deploy.sh
#!/bin/bash

BLUE_HOST="blue.myapp.com"
GREEN_HOST="green.myapp.com"
LB_HOST="lb.myapp.com"

# Check current active
CURRENT=$(ssh $LB_HOST "cat /etc/nginx/active")

if [ "$CURRENT" == "blue" ]; then
  TARGET=$GREEN_HOST
  NEW_ACTIVE="green"
else
  TARGET=$BLUE_HOST
  NEW_ACTIVE="blue"
fi

echo "Deploying to $TARGET"

# Deploy to inactive environment
ssh $TARGET "cd /var/www/myapp && ./deploy.sh"

# Switch load balancer
ssh $LB_HOST "echo $NEW_ACTIVE > /etc/nginx/active && nginx -s reload"

echo "✅ Switched to $NEW_ACTIVE"
EOF
