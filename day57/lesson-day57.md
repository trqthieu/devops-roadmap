# 📘 Ngày 57: Alerting - Notification & On-call Strategy

## 🎯 Mục Tiêu Ngày Hôm Nay

Setup alerting system hoàn chỉnh với Prometheus Alertmanager, configure notification routing cho các severity levels khác nhau, và hiểu on-call best practices để tránh alert fatigue.

---

## Tại Sao Cần Alerting?

### Vấn Đề: Reactive vs Proactive

```
Scenario: Production database running out of disk space

WITHOUT alerting:
❌ 2 AM: Disk full
❌ 2:15 AM: Database crashes
❌ 2:30 AM: Users report errors
❌ 3:00 AM: On-call wakes up, checks phone
❌ 3:30 AM: Finally fixes disk space
❌ 4:00 AM: Service restored

Impact:
- 2 hours downtime
- Angry customers
- Lost revenue: $20,000
- Reputation damage

WITH alerting:
✅ 1:00 AM: Alert "Disk 85% full" → Slack
✅ 1:05 AM: On-call sees alert, adds disk space
✅ 1:15 AM: Disk usage back to 60%
✅ Crisis averted, zero downtime

Impact:
- 0 downtime
- Happy customers
- $0 lost revenue
- Good night's sleep
```

---

### The Value of Alerting

```
Alerting = Proactive notification of problems

Benefits:
✅ Fix issues before users notice
✅ Reduce MTTR (Mean Time To Resolution)
✅ Sleep better (know you'll be notified)
✅ Prevent cascading failures
✅ Track SLA compliance

Cost of NOT alerting:
- Average downtime cost: $5,600/minute (Gartner)
- Median incident: 2-4 hours to detect + fix
- With alerting: 10-30 minutes
→ ROI: 10x faster resolution
```

---

## Alerting Architecture

### Alert Flow

```
┌──────────────────────────────────────────────────┐
│  Prometheus                                      │
│  ┌────────────────────────────────────────────┐ │
│  │  Alert Rules (alerts.yml)                  │ │
│  │  - Evaluate every 30s                      │ │
│  │  - Check: cpu > 80% for 5 minutes?        │ │
│  └────────────────┬───────────────────────────┘ │
└───────────────────┼──────────────────────────────┘
                    │
                    │ Alert FIRING
                    ↓
┌──────────────────────────────────────────────────┐
│  Alertmanager                                    │
│  ┌────────────────────────────────────────────┐ │
│  │  Routing (alertmanager.yml)                │ │
│  │  - Group alerts                            │ │
│  │  - Deduplicate                             │ │
│  │  - Route to receivers                      │ │
│  │  - Silence/inhibit                         │ │
│  └────────────────┬───────────────────────────┘ │
└───────────────────┼──────────────────────────────┘
                    │
       ┌────────────┼────────────┐
       ↓            ↓            ↓
┌──────────┐  ┌──────────┐  ┌──────────┐
│  Slack   │  │PagerDuty │  │  Email   │
└──────────┘  └──────────┘  └──────────┘
   WARNING      CRITICAL       INFO
```

---

### Alert States

```
Alert lifecycle:

INACTIVE → PENDING → FIRING → RESOLVED

1. INACTIVE:
   - Condition not met
   - expr: cpu > 80% → current: 50%

2. PENDING:
   - Condition met, waiting for "for" duration
   - expr: cpu > 80% → current: 85%
   - for: 5m → wait 5 minutes before firing
   - Purpose: Avoid flapping (transient spikes)

3. FIRING:
   - Condition met for > "for" duration
   - Send to Alertmanager
   - Alertmanager sends notification

4. RESOLVED:
   - Condition no longer met
   - Send resolve notification (optional)
   - "All clear" message
```

**Example timeline:**

```
10:00 → CPU 50% (INACTIVE)
10:05 → CPU 85% (PENDING, started timer)
10:06 → CPU 75% (back to INACTIVE, timer reset)
10:10 → CPU 90% (PENDING, started timer again)
10:15 → CPU 88% (still PENDING, 5 min not reached)
10:16 → CPU 91% (FIRING! 5+ min sustained, send alert)
10:30 → CPU 70% (RESOLVED, send "all clear")
```

---

## Alert Rules Best Practices

### Good Alert Rules

```
Characteristics of good alerts:

1. ACTIONABLE
   ❌ BAD: "Something is wrong"
   ✅ GOOD: "Error rate 10% on API. Check logs: kubectl logs api-pod"

2. SYMPTOM-BASED (not cause-based)
   ❌ BAD: Alert on "CPU high"
   ✅ GOOD: Alert on "Latency high" (symptom)
          → Then investigate CPU (possible cause)

3. INCLUDE CONTEXT
   ✅ Instance name
   ✅ Current value vs threshold
   ✅ Link to dashboard
   ✅ Link to runbook

4. APPROPRIATE THRESHOLD
   ❌ BAD: for: 30s (too sensitive, many false positives)
   ✅ GOOD: for: 5m (sustained issue)

5. SEVERITY LABELING
   ✅ Labels: severity: critical/warning/info
   → Routes to appropriate notification channel
```

---

### Alert Rule Examples

```
1. Service Availability (most important!)
   - SLO: 99.9% uptime
   - Alert if service down for >1 minute

   alert: ServiceDown
   expr: up{job="api"} == 0
   for: 1m
   severity: critical

2. Error Rate (SLO violation)
   - SLO: Error rate < 0.1%
   - Alert if error rate > 1% (10x SLO)

   alert: HighErrorRate
   expr: sum(rate(http_requests_total{status=~"5.."}[5m])) /
         sum(rate(http_requests_total[5m])) > 0.01
   for: 5m
   severity: critical

3. Latency (SLO violation)
   - SLO: p99 < 500ms
   - Alert if p99 > 1s (2x SLO)

   alert: HighLatency
   expr: histogram_quantile(0.99,
           rate(http_request_duration_seconds_bucket[5m])) > 1
   for: 10m
   severity: warning

4. Resource Saturation (preventive)
   - Disk usage > 90% (approaching full)
   - Memory > 90%
   - CPU sustained > 80%

   alert: DiskSpaceLow
   expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
   for: 5m
   severity: warning
```

---

## Severity Levels & Routing

### Severity Classification

```
CRITICAL (P1) - Page on-call immediately
├─ Service down (can't serve traffic)
├─ Data loss risk
├─ Security breach
├─ Revenue-impacting
└─ SLA violation

Action: PagerDuty page
Response SLA: 15 minutes
Example: InstanceDown, HighErrorRate (>5%)

WARNING (P2) - Notify but no page
├─ Degraded performance (still serving traffic)
├─ Resource saturation (approaching limits)
├─ Approaching SLA violation
└─ Needs attention during business hours

Action: Slack notification
Response SLA: 2 hours
Example: HighCPU (>80%), HighMemory (>85%), HighLatency

INFO (P3) - FYI notification
├─ Non-urgent information
├─ Completed operations
├─ Scheduled events
└─ No action needed

Action: Email digest
Response SLA: 1 day
Example: BackupCompleted, DeploymentFinished
```

---

### Routing Strategy

```
Alertmanager routing tree:

ALL ALERTS
│
├─ severity: critical
│  └─ Route to: PagerDuty + Slack (#incidents)
│     repeat_interval: 1h (keep paging until resolved)
│
├─ severity: warning
│  ├─ team: database
│  │  └─ Route to: Slack (#db-alerts) + Email (dba@company.com)
│  │
│  └─ team: backend
│     └─ Route to: Slack (#backend-alerts)
│
└─ severity: info
   └─ Route to: Email (daily digest)
      repeat_interval: 24h
```

**Example config:**

```yaml
route:
  receiver: 'default'
  group_by: ['alertname', 'instance']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    # Critical → PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty'
      repeat_interval: 1h

    # Database team
    - match:
        team: database
      receiver: 'dba-team'

    # Production only
    - match:
        environment: production
      receiver: 'prod-team'
      group_wait: 5s
```

---

## Grouping & Deduplication

### Grouping

```
Problem: 10 servers go down, receive 10 separate pages
→ Alert fatigue, hard to read

Solution: Group related alerts

WITHOUT grouping:
🚨 ServerDown server1
🚨 ServerDown server2
🚨 ServerDown server3
... (10 notifications!)

WITH grouping:
🚨 ServerDown
   Affected instances:
   - server1
   - server2
   - server3
   ... (1 notification, all info inside)
```

**Grouping config:**

```yaml
route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s        # Wait 10s to collect alerts
  group_interval: 5m     # Send grouped alerts every 5m
```

**How it works:**

```
Timeline:
00:00 → server1 down (wait 10s to group)
00:05 → server2 down (add to group)
00:08 → server3 down (add to group)
00:10 → Send 1 grouped notification (3 servers)
05:10 → If still down, send update (repeat)
```

---

### Deduplication

```
Problem: Multiple Prometheus instances scrape same target
→ Same alert from 2 sources

Solution: Alertmanager deduplicates by fingerprint

Fingerprint = Hash of (alertname + labels)

Example:
Prometheus 1 → HighCPU{instance="server1"}
Prometheus 2 → HighCPU{instance="server1"}
→ Same fingerprint → Only 1 notification sent
```

---

## Silencing & Inhibition

### Silences (Planned Maintenance)

```
Use case: Planned database migration at 2 AM
→ Don't want alerts during maintenance

Silence:
- Matchers: alertname=DBConnectionPoolExhausted
- Time range: 2025-05-10 02:00 - 2025-05-10 04:00
- Comment: "Database migration"

During maintenance:
- Alerts still FIRE in Prometheus
- Alertmanager SUPPRESSES notifications
- After maintenance ends: Silence expires, alerts resume
```

**When to use silences:**

```
✅ Planned maintenance
✅ Known issues (waiting for fix deployment)
✅ Testing in production
✅ Deployment windows

❌ DO NOT silence alerts permanently!
→ If alert is noisy, fix the alert rule, don't silence
```

---

### Inhibition Rules

```
Purpose: Suppress alerts caused by other alerts

Example:
If instance is DOWN,
don't alert on HighCPU/HighMemory on that instance
(Obviously CPU is 0% if instance is down!)

Inhibit rule:
source_match:
  alertname: InstanceDown
target_match_re:
  alertname: ^(HighCPU|HighMemory)$
equal: ['instance']

How it works:
- InstanceDown fires for server1
- HighCPU alert for server1 is suppressed
- HighCPU alert for server2 (different instance) still fires
```

**Common inhibition patterns:**

```
1. Instance down → suppress all alerts on that instance
2. High error rate → suppress low traffic alert
3. Network partition → suppress connectivity alerts
4. Cluster down → suppress pod alerts in that cluster
```

---

## Notification Channels

### Channel Selection by Severity

```
CRITICAL → PagerDuty (wake up on-call)
├─ Phone call (escalation after 5 min)
├─ SMS
└─ App notification

WARNING → Slack (check during work hours)
├─ #alerts channel
├─ Mention @oncall
└─ Thread for discussion

INFO → Email (daily digest)
└─ Batch alerts into single email
```

---

### Slack Best Practices

```
Channel structure:

#incidents (critical only)
├─ PagerDuty integration
├─ Only critical alerts
├─ Immediate response required
└─ @oncall auto-mentioned

#alerts (warnings)
├─ Warning-level alerts
├─ Review during business hours
├─ Discussion allowed
└─ No @oncall mentions (not urgent)

#monitoring (info)
├─ Info-level alerts
├─ Deployment notifications
├─ Backup status
└─ FYI only
```

**Slack message format:**

```
Good Slack alert message:

🔴 CRITICAL: HighErrorRate
Severity: critical
Instance: api-production
Error rate: 8.5% (threshold: 5%)
Duration: 7 minutes

Actions:
→ Dashboard: https://grafana.com/d/api
→ Logs: kubectl logs -l app=api
→ Runbook: https://wiki.com/runbooks/high-error-rate

@oncall
```

---

## On-call Best Practices

### Alert Fatigue Prevention

```
Alert fatigue = Too many alerts → Team ignores them

Symptoms:
❌ 100+ alerts per day
❌ Most alerts are false positives
❌ Team doesn't respond to pages
❌ "Boy who cried wolf" syndrome

Solution:

1. ALERT ON SYMPTOMS, NOT CAUSES
   ❌ Don't: Alert on high CPU
   ✅ Do: Alert on high latency (symptom)
         → Investigate CPU as possible cause

2. USE APPROPRIATE THRESHOLDS
   ❌ Don't: Alert on CPU >50% (too sensitive)
   ✅ Do: Alert on CPU >80% for 10 minutes

3. MAKE ALERTS ACTIONABLE
   ❌ Don't: "Something is wrong"
   ✅ Do: "Error rate 10%. Check /api/checkout endpoint"

4. USE "for" DURATION
   ❌ Don't: for: 30s (flapping)
   ✅ Do: for: 5m (sustained issue)

5. WRITE RUNBOOKS
   Every alert needs a runbook
   → Clear steps to investigate and fix

6. REVIEW ALERTS WEEKLY
   - Which alerts fired?
   - Were they actionable?
   - False positives?
   - Adjust thresholds
```

---

### Runbook Template

```
Alert: HighErrorRate

SEVERITY: Critical

DESCRIPTION:
Error rate on API service exceeds 5% for 5+ minutes

IMPACT:
Users experiencing errors when placing orders
Revenue loss: ~$500/minute

INVESTIGATION STEPS:
1. Check error logs:
   kubectl logs -l app=api --tail=100 | grep ERROR

2. Check which endpoint is failing:
   Grafana → API Dashboard → Errors by Endpoint

3. Check recent deployments:
   kubectl rollout history deployment/api

4. Check external dependencies:
   - Payment API: https://status.stripe.com
   - Database: Check connection pool

COMMON CAUSES:
1. Recent deployment (bad code)
   → Rollback: kubectl rollout undo deployment/api

2. Database overload
   → Scale DB or increase connection pool

3. External API timeout
   → Enable circuit breaker, use fallback

4. Memory leak
   → Restart pods: kubectl rollout restart deployment/api

ESCALATION:
If not resolved in 30 minutes:
1. Page @backend-lead
2. Create Slack thread in #incidents
3. Update status page

RELATED DOCS:
- Architecture: https://wiki.com/architecture/api
- Deployment process: https://wiki.com/deploy
- Database scaling: https://wiki.com/db-scaling
```

---

## Alert Metrics (Meta-monitoring)

### Monitoring Alerting System

```
Monitor Alertmanager itself!

Key metrics:

1. Alert send rate
   alertmanager_notifications_total
   → Are alerts being sent?

2. Alert send failures
   alertmanager_notifications_failed_total
   → Is Slack webhook broken?

3. Silences active
   alertmanager_silences
   → Too many silences = hiding problems?

4. Alerts firing
   ALERTS{alertstate="firing"}
   → How many alerts are active?

Dashboard panel:
- Alerts firing (by severity)
- Notification success rate
- Silences active
```

---

## Testing Alerts

### Test Strategy

```
1. Test alert rules (before production)
   promtool check rules alerts.yml

2. Test alert triggers (in staging)
   - Manually trigger condition (e.g., fill disk to 95%)
   - Verify alert fires
   - Verify notification sent
   - Verify runbook works

3. Game days (chaos engineering)
   - Quarterly: Simulate production incident
   - Kill random pod
   - Verify alerts fire
   - Verify on-call responds
   - Measure MTTR
   - Improve runbooks based on learnings

4. Alert retrospectives
   - After every incident, review:
     - Was alert helpful?
     - Was runbook accurate?
     - Response time acceptable?
     - How to prevent in future?
```

---

## Common Pitfalls

```
❌ No "for" duration
   Alert fires on transient spike
   → Use: for: 5m

❌ Alert on cause, not symptom
   Alert on "CPU high" instead of "latency high"
   → Alert on user-facing symptoms

❌ No runbook
   On-call doesn't know what to do
   → Write runbook for every alert

❌ Too many critical alerts
   Everything is critical → Nothing is critical
   → Reserve critical for real emergencies

❌ Alert but can't fix
   Alert fires at 3 AM but requires vendor (9 AM)
   → Alert during business hours only

❌ Silence alerts permanently
   Noisy alert → silence forever
   → Fix the alert, don't hide it

❌ No testing
   First time alert fires is in production incident
   → Test alerts in staging

❌ No alert ownership
   Alert fires, nobody knows who should respond
   → Label alerts with team/owner
```

---

## Real-world Example

```
Scenario: E-commerce checkout flow

CRITICAL alerts (page on-call):
1. CheckoutServiceDown
   - Checkout service can't serve traffic
   - Impact: $10,000/minute lost revenue

2. PaymentErrorRate >5%
   - Payments failing
   - Impact: Lost orders, angry customers

3. DatabaseConnectionPoolExhausted
   - Can't connect to DB
   - Impact: Service will crash soon

WARNING alerts (Slack):
1. CheckoutLatency p99 >2s
   - Slow but working
   - Impact: Bad UX, might abandon cart

2. PaymentErrorRate >1%
   - Some payments failing
   - Impact: Monitor, might need action

3. MemoryUsage >85%
   - Approaching limit
   - Impact: Might OOM soon, scale proactively

INFO alerts (Email):
1. DailyBackupCompleted
   - FYI, no action needed

2. DeploymentToProduction
   - FYI, watch for errors

Alert routing:
Critical → PagerDuty + Slack #incidents
Warning → Slack #backend-alerts
Info → Email (daily digest)
```

---

## Tóm Tắt

### Alerting Architecture

```
PROMETHEUS:
- Evaluate alert rules (every 30s)
- Fire alerts if condition met + "for" duration

ALERTMANAGER:
- Receive alerts from Prometheus
- Group/deduplicate alerts
- Route to receivers (Slack, PagerDuty, Email)
- Handle silences/inhibitions

NOTIFICATION CHANNELS:
- Critical → PagerDuty (wake up on-call)
- Warning → Slack (check during work)
- Info → Email (FYI)
```

---

### Best Practices Checklist

```
✅ Alert Rules:
- [ ] Alert on symptoms, not causes
- [ ] Include "for" duration (5-10 min)
- [ ] Actionable message with context
- [ ] Link to dashboard and runbook
- [ ] Appropriate severity labels

✅ Routing:
- [ ] Critical → PagerDuty
- [ ] Warning → Slack
- [ ] Info → Email
- [ ] Team-based routing

✅ Maintenance:
- [ ] Silences for planned maintenance
- [ ] Inhibition rules for cascading alerts
- [ ] Weekly alert review
- [ ] Test alerts in staging

✅ On-call:
- [ ] Runbook for every alert
- [ ] Clear escalation path
- [ ] Post-incident reviews
- [ ] Game days (quarterly)
```

---

### Next Steps

```
✅ Day 57: Alerting setup (today)
→ Day 58: Complete DevOps pipeline project (CI + CD + Monitoring + Alerting)
→ Day 59: Documentation and runbooks
→ Day 60: Month 2 review and assessment
```

Good alerting is about balance: Alert enough to catch issues early, but not so much that team gets fatigued and ignores alerts. The goal is actionable, timely notifications that help team maintain reliability!
