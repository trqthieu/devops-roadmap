# 📘 Ngày 45: Deploy Strategies - Deployment Patterns

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu sâu các deployment strategies (Rolling update, Blue/Green, Canary, Feature flags), biết khi nào dùng strategy nào, và implement zero-downtime deployments trong production.

---

## Tại Sao Deployment Strategy Quan Trọng?

### Vấn Đề: Naive Deployment

```
❌ BAD: Simple deployment (có downtime)

1. Stop old version
   → Application DOWN (downtime starts)
2. Deploy new version
3. Start new version
   → Application UP (downtime ends)

Downtime: 2-5 minutes
Impact: Lost revenue, bad UX, angry customers
```

**Real cost của downtime:**
- E-commerce: $5,000-$10,000 per minute
- SaaS platform: Customer churn, reputation damage
- Banking: Regulatory penalties, customer complaints

---

### Giải Pháp: Zero-Downtime Deployment

```
✅ GOOD: Modern deployment strategies

Deploy new version TRƯỚC khi stop old version
→ Zero downtime
→ Always có instance running
→ Có thể rollback nhanh
```

**Yêu cầu production deployment:**
- ✅ Zero downtime
- ✅ Fast rollback (< 30 giây)
- ✅ Gradual rollout (test với small traffic trước)
- ✅ Automated health checks
- ✅ Monitoring & alerting

---

## 1. Rolling Update Deployment

### Khái Niệm

```
Rolling update = Update từng instance một, giữ app luôn available

Initial state:      Update sequence:           Final state:
┌─────────┐        ┌─────────┐                ┌─────────┐
│ v1  v1  │   →    │ v2  v1  │           →    │ v2  v2  │
│ v1  v1  │        │ v1  v1  │                │ v2  v2  │
└─────────┘        └─────────┘                └─────────┘
                           ↓
                   ┌─────────┐
                   │ v2  v2  │
                   │ v1  v1  │
                   └─────────┘
                           ↓
                   ┌─────────┐
                   │ v2  v2  │
                   │ v2  v1  │
                   └─────────┘

Timeline: 0s  → 30s → 60s → 90s → 120s
```

**Process:**
1. Stop 1 instance running v1
2. Deploy v2 lên instance đó
3. Start v2, wait for health check pass
4. Repeat cho instance tiếp theo
5. Khi tất cả instances chạy v2 → done

---

### Rolling Update Workflow

```yaml
# .github/workflows/rolling-deploy.yml
name: Rolling Update Deploy

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Get list of servers
        id: servers
        run: |
          echo "list=server1,server2,server3,server4" >> $GITHUB_OUTPUT

      - name: Deploy to each server
        run: |
          IFS=',' read -ra SERVERS <<< "${{ steps.servers.outputs.list }}"

          for server in "${SERVERS[@]}"; do
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Deploying to $server"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            # Deploy
            ssh $server "docker pull myapp:latest"
            ssh $server "docker-compose up -d"

            # Health check
            for i in {1..30}; do
              if curl -f http://$server/health; then
                echo "✅ $server is healthy"
                break
              fi
              echo "⏳ Waiting for $server health check... ($i/30)"
              sleep 2
            done

            # Small delay trước khi deploy server tiếp theo
            sleep 10
          done
```

**Ưu điểm:**
- ✅ Zero downtime (luôn có instances running)
- ✅ Đơn giản, dễ implement
- ✅ Cost-effective (không cần double resources)
- ✅ Tự động rollback nếu health check fail

**Nhược điểm:**
- ❌ Rollback chậm (phải update lại từng instance)
- ❌ v1 và v2 chạy chung trong quá trình deploy (compatibility issues)
- ❌ Deploy lâu (tuần tự update từng instance)

**Khi nào dùng:**
- Stateless applications
- Backward-compatible changes
- Budget constraints (không thể double resources)
- Small-medium scale (< 50 instances)

---

## 2. Blue/Green Deployment

### Khái Niệm

```
Blue/Green = 2 môi trường identical, switch traffic instantly

┌──────────────────────────────────────────────────────────┐
│                     Load Balancer                        │
└────────────────────┬─────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼─────┐           ┌────▼─────┐
    │  BLUE    │           │  GREEN   │
    │  (v1)    │           │  (v2)    │
    │          │           │          │
    │ Active   │           │ Inactive │
    └──────────┘           └──────────┘

Before deploy: 100% traffic → Blue (v1)
After deploy:  100% traffic → Green (v2)

Switch = Change load balancer config (instant)
```

---

### Blue/Green Workflow

```
Phase 1: Pre-deployment
┌──────────────────────────────────┐
│ Blue (v1) - 100% traffic         │ ← Production
│ Green - idle                     │
└──────────────────────────────────┘

Phase 2: Deploy to Green
┌──────────────────────────────────┐
│ Blue (v1) - 100% traffic         │ ← Still production
│ Green (v2) - deploying...        │
└──────────────────────────────────┘

Phase 3: Test Green
┌──────────────────────────────────┐
│ Blue (v1) - 100% traffic         │ ← Still production
│ Green (v2) - smoke tests ✓       │
└──────────────────────────────────┘

Phase 4: Switch traffic
┌──────────────────────────────────┐
│ Blue (v1) - 0% traffic (standby) │
│ Green (v2) - 100% traffic ✓      │ ← Now production
└──────────────────────────────────┘

Phase 5: Monitor
- If OK: Keep Green as production
- If ERROR: Instant rollback to Blue (giây)
```

**Workflow Implementation:**

```yaml
name: Blue/Green Deploy

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Determine current environment
        id: env
        run: |
          CURRENT=$(aws elbv2 describe-target-health \
            --target-group-arn $TG_ARN \
            --query 'TargetHealthDescriptions[0].Target.Id' \
            --output text)

          if [[ $CURRENT == *"blue"* ]]; then
            echo "current=blue" >> $GITHUB_OUTPUT
            echo "target=green" >> $GITHUB_OUTPUT
          else
            echo "current=green" >> $GITHUB_OUTPUT
            echo "target=blue" >> $GITHUB_OUTPUT
          fi

      - name: Deploy to ${{ steps.env.outputs.target }}
        run: |
          TARGET=${{ steps.env.outputs.target }}

          # Deploy
          ssh $TARGET.myapp.com "docker pull myapp:latest"
          ssh $TARGET.myapp.com "docker-compose up -d"

      - name: Smoke test ${{ steps.env.outputs.target }}
        run: |
          TARGET=${{ steps.env.outputs.target }}

          # Wait for app to be ready
          sleep 30

          # Critical endpoints
          curl -f http://$TARGET.myapp.com/health
          curl -f http://$TARGET.myapp.com/api/status
          curl -f http://$TARGET.myapp.com/api/users/1

      - name: Switch traffic to ${{ steps.env.outputs.target }}
        run: |
          TARGET=${{ steps.env.outputs.target }}

          # Update load balancer
          aws elbv2 modify-listener --listener-arn $LISTENER_ARN \
            --default-actions Type=forward,TargetGroupArn=$TARGET_TG_ARN

          echo "✅ Traffic switched to $TARGET"

      - name: Monitor for 5 minutes
        run: |
          echo "Monitoring new deployment..."
          sleep 300

          # Check error rate
          ERROR_RATE=$(curl -s http://monitoring.myapp.com/api/error-rate)
          if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
            echo "❌ Error rate too high: $ERROR_RATE%"
            exit 1
          fi

      - name: Rollback on failure
        if: failure()
        run: |
          CURRENT=${{ steps.env.outputs.current }}

          echo "🚨 Rolling back to $CURRENT"
          aws elbv2 modify-listener --listener-arn $LISTENER_ARN \
            --default-actions Type=forward,TargetGroupArn=$CURRENT_TG_ARN

          echo "✅ Rollback complete"
```

**Ưu điểm:**
- ✅ Zero downtime
- ✅ Instant rollback (chỉ cần switch load balancer)
- ✅ Full testing trước khi go live
- ✅ Không có version mixing (không có v1 và v2 chạy cùng lúc)

**Nhược điểm:**
- ❌ Cost: Cần double resources (2 environments)
- ❌ Database migrations phức tạp (cả 2 envs dùng chung DB)
- ❌ Stateful applications khó implement

**Khi nào dùng:**
- Mission-critical applications
- Financial services, healthcare
- Khi cần instant rollback capability
- Large-scale production systems

---

## 3. Canary Deployment

### Khái Niệm

```
Canary = Deploy version mới cho small % traffic, gradually tăng lên

┌────────────────────────────────────────────────────────┐
│                    Load Balancer                       │
└──────────┬────────────────────────────────────────────┘
           │
           ├─── 90% traffic ───→ ┌──────────────┐
           │                      │   v1 (old)   │
           │                      │  9 instances │
           │                      └──────────────┘
           │
           └─── 10% traffic ───→ ┌──────────────┐
                                  │   v2 (new)   │
                                  │  1 instance  │ ← Canary
                                  └──────────────┘

Timeline:
  Day 1: 10% canary → monitor metrics
  Day 2: 50% canary → monitor metrics
  Day 3: 100% canary → full deployment
```

**Canary là gì?**
- Canary = "con chim vàng anh" - thợ mỏ xưa dùng để detect khí độc
- Trong deployment: Small % users test version mới trước
- Nếu có bug → chỉ ảnh hưởng small % users

---

### Canary Deployment Workflow

```
Phase 1: Deploy canary (10%)
┌────────────────────────────────────┐
│ 90% users → v1 (stable)            │
│ 10% users → v2 (canary)            │
└────────────────────────────────────┘
→ Monitor: error rate, latency, CPU

Phase 2: If metrics OK, increase to 50%
┌────────────────────────────────────┐
│ 50% users → v1                     │
│ 50% users → v2                     │
└────────────────────────────────────┘
→ Monitor more

Phase 3: If still OK, promote to 100%
┌────────────────────────────────────┐
│ 100% users → v2 (promoted)         │
│ v1 terminated                      │
└────────────────────────────────────┘

If ANY phase has issues → rollback immediately
```

**Implementation:**

```yaml
name: Canary Deployment

jobs:
  deploy-canary:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy canary (10% traffic)
        run: |
          # Kubernetes example
          kubectl set image deployment/app-canary app=myapp:v2
          kubectl scale deployment/app-stable --replicas=9
          kubectl scale deployment/app-canary --replicas=1

          echo "✅ Canary deployed: 10% traffic"

      - name: Monitor canary metrics (10 minutes)
        run: |
          echo "Monitoring canary for 10 minutes..."

          for i in {1..60}; do
            # Get metrics from monitoring system
            ERROR_RATE=$(curl -s http://prometheus/api/v1/query?query=error_rate)
            LATENCY=$(curl -s http://prometheus/api/v1/query?query=latency_p99)

            echo "[$i/60] Error rate: $ERROR_RATE%, Latency: ${LATENCY}ms"

            # Threshold checks
            if (( $(echo "$ERROR_RATE > 1.0" | bc -l) )); then
              echo "❌ Error rate too high!"
              exit 1
            fi

            sleep 10
          done

      - name: Promote to 50%
        run: |
          kubectl scale deployment/app-stable --replicas=5
          kubectl scale deployment/app-canary --replicas=5

          echo "✅ Canary promoted: 50% traffic"

      - name: Monitor 50% canary (10 minutes)
        run: |
          # Same monitoring as before
          sleep 600

      - name: Promote to 100%
        run: |
          kubectl scale deployment/app-stable --replicas=0
          kubectl scale deployment/app-canary --replicas=10

          # Rename canary to stable
          kubectl label deployment/app-canary version=stable

          echo "✅ Canary fully promoted: 100% traffic"

      - name: Rollback on failure
        if: failure()
        run: |
          echo "🚨 Rolling back canary"
          kubectl scale deployment/app-stable --replicas=10
          kubectl scale deployment/app-canary --replicas=0
```

**Ưu điểm:**
- ✅ Risk mitigation (chỉ small % users bị ảnh hưởng nếu có bug)
- ✅ Early detection of issues
- ✅ Gradual confidence building
- ✅ Real production traffic testing

**Nhược điểm:**
- ❌ Complex setup (cần monitoring, automated rollback)
- ❌ Slow deployment (phải monitor từng phase)
- ❌ Cần sophisticated monitoring system

**Khi nào dùng:**
- Large user base (millions of users)
- High-risk changes
- Major version upgrades
- Khi có good monitoring infrastructure

---

## 4. Feature Flags

### Khái Niệm

```
Feature flags = Deploy code nhưng tắt feature, enable sau via config

┌─────────────────────────────────────────────────────┐
│           Application v2 deployed                   │
│  ┌──────────────────────────────────────────────┐  │
│  │ if (featureFlags.newUI) {                    │  │
│  │   return <NewUI />      ← Feature TẮNG      │  │
│  │ } else {                                     │  │
│  │   return <OldUI />      ← Feature BẬT       │  │
│  │ }                                            │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

Deployment ≠ Release
- Deployment: Deploy code lên server
- Release: Enable feature cho users

→ Decouple deployment from release!
```

---

### Feature Flags Implementation

```javascript
// config/features.js
module.exports = {
  features: {
    newUI: process.env.FEATURE_NEW_UI === 'true',
    betaAPI: process.env.FEATURE_BETA_API === 'true',
    paymentV2: process.env.FEATURE_PAYMENT_V2 === 'true'
  }
}

// app.js
const { features } = require('./config/features')

app.get('/dashboard', (req, res) => {
  if (features.newUI) {
    res.render('dashboard-v2')
  } else {
    res.render('dashboard-v1')
  }
})

// Percentage rollout
function isFeatureEnabled(featureName, userId) {
  const config = {
    newUI: { enabled: true, percentage: 10 },    // 10% rollout
    betaAPI: { enabled: true, percentage: 100 }  // Full rollout
  }

  const feature = config[featureName]
  if (!feature.enabled) return false

  // Hash userId to determine if in rollout percentage
  const userHash = hashUserId(userId) % 100
  return userHash < feature.percentage
}

// Usage
app.get('/api/users', (req, res) => {
  if (isFeatureEnabled('betaAPI', req.user.id)) {
    return betaAPIController.getUsers(req, res)
  } else {
    return oldAPIController.getUsers(req, res)
  }
})
```

**Ưu điểm:**
- ✅ Instant rollback (tắt flag, không cần redeploy)
- ✅ A/B testing (enable cho specific users)
- ✅ Gradual rollout (10% → 50% → 100%)
- ✅ Kill switch (tắt feature nếu có incident)

**Nhược điểm:**
- ❌ Code complexity (if/else branches)
- ❌ Technical debt (phải cleanup old code)
- ❌ Testing complexity (test cả 2 branches)

**Khi nào dùng:**
- Experimental features
- A/B testing
- Phased rollouts
- High-risk features

---

## So Sánh Deployment Strategies

| Strategy | Downtime | Rollback Speed | Cost | Complexity | Best For |
|----------|----------|---------------|------|------------|----------|
| **Rolling** | ❌ None | 🐢 Slow (minutes) | 💰 Low | ⭐ Simple | Small-medium apps |
| **Blue/Green** | ❌ None | ⚡ Instant (seconds) | 💰💰 High (2x) | ⭐⭐ Medium | Mission-critical |
| **Canary** | ❌ None | ⚡ Fast | 💰 Medium | ⭐⭐⭐ Complex | Large scale |
| **Feature Flags** | ❌ None | ⚡ Instant | 💰 Low | ⭐⭐ Medium | Experiments |
| **Recreate** | ✅ Yes | 🐢 Slow | 💰 Lowest | ⭐ Very Simple | Dev/staging only |

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Rolling update stuck - một instance không healthy

**Nguyên nhân:**
- New version có bug
- Health check endpoint fail
- Database migration chưa xong

**Giải pháp:**
```bash
# Stop deployment
kubectl rollout pause deployment/app

# Check logs
kubectl logs -l app=myapp --tail=100

# Rollback
kubectl rollout undo deployment/app

# Resume sau khi fix
kubectl rollout resume deployment/app
```

---

### Problem 2: Blue/Green deployment - cả 2 environments dùng chung database

**Vấn đề:**
```
Blue (v1) và Green (v2) đều kết nối cùng DB
→ Nếu v2 có schema migration → v1 break
```

**Giải pháp:**
```
1. Backward-compatible migrations
   - Add new column (không xóa old column)
   - Deploy v2
   - Sau khi stable, deploy migration xóa old column

2. Database per environment
   - Blue có DB riêng
   - Green có DB riêng
   - Sync data trước khi switch

3. Feature flags cho DB changes
   - Deploy migration
   - Use feature flag để enable/disable new schema
```

---

### Problem 3: Canary deployment - làm sao biết canary có issue?

**Giải pháp: Automated canary analysis**

```yaml
- name: Analyze canary metrics
  run: |
    # Compare canary vs stable
    CANARY_ERROR_RATE=$(prometheus_query "error_rate{version=canary}")
    STABLE_ERROR_RATE=$(prometheus_query "error_rate{version=stable}")

    # Nếu canary error rate cao hơn 20% so với stable → fail
    if [ "$CANARY_ERROR_RATE" > "$((STABLE_ERROR_RATE * 1.2))" ]; then
      echo "❌ Canary has higher error rate"
      exit 1
    fi

    # Compare latency
    CANARY_P99=$(prometheus_query "latency_p99{version=canary}")
    STABLE_P99=$(prometheus_query "latency_p99{version=stable}")

    if [ "$CANARY_P99" > "$((STABLE_P99 * 1.5))" ]; then
      echo "❌ Canary latency is 50% slower"
      exit 1
    fi
```

---

## 🎓 Tóm Tắt Ngày 45

✅ **Rolling Update**: Update từng instance, zero downtime, simple
✅ **Blue/Green**: 2 environments, instant switch, instant rollback
✅ **Canary**: Gradual rollout (10% → 50% → 100%), risk mitigation
✅ **Feature Flags**: Deploy code, enable sau, instant rollback
✅ **Strategy selection**: Dựa vào scale, risk, budget, complexity

**Kỹ năng đạt được:**
- Hiểu pros/cons của từng deployment strategy
- Implement zero-downtime deployments
- Setup automated health checks
- Design rollback mechanisms
- Choose strategy phù hợp với use case

**Decision tree:**
```
Mission-critical app + budget OK → Blue/Green
Large scale + need gradual rollout → Canary
Budget constraints + simple app → Rolling Update
Experiments + A/B testing → Feature Flags
Dev/staging only → Recreate (OK to have downtime)
```

**Next:** Ngày 46 - Deploy lên VPS/EC2 (SSH actions, rsync, deploy scripts)
