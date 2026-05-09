# Cheatsheet: Day 89 - Final Project Day 3 (Documentation & Handover)

## Documentation Structure

```
docs/
├── architecture/
│   ├── system-overview.md
│   ├── network-diagram.md
│   └── component-details.md
├── runbooks/
│   ├── deployment-runbook.md
│   ├── incident-response.md
│   └── troubleshooting-guide.md
├── operations/
│   ├── backup-restore.md
│   ├── disaster-recovery.md
│   └── maintenance-procedures.md
└── handover/
    ├── access-credentials.md
    ├── monitoring-alerts.md
    └── contact-information.md
```

## Architecture Diagram (ASCII)

```
Production Kubernetes Cluster Architecture
═══════════════════════════════════════════

                    Internet
                       │
                       ▼
           ┌───────────────────────┐
           │  Cloud Load Balancer  │
           │  IP: 203.0.113.10     │
           └──────────┬────────────┘
                      │
                      │ HTTPS (443)
                      ▼
┌─────────────────────────────────────────────────┐
│          Kubernetes Cluster (3 nodes)           │
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │  Namespace: ingress-nginx              │    │
│  │  ┌──────────────────────────────────┐  │    │
│  │  │  Nginx Ingress Controller        │  │    │
│  │  │  - SSL Termination               │  │    │
│  │  │  - Host-based routing            │  │    │
│  │  │  - cert-manager integration      │  │    │
│  │  └─────────────┬────────────────────┘  │    │
│  └────────────────┼───────────────────────┘    │
│                   │                            │
│         ┌─────────┴─────────┐                  │
│         │                   │                  │
│         ▼                   ▼                  │
│  ┌──────────────┐    ┌──────────────┐         │
│  │ Namespace:   │    │ Namespace:   │         │
│  │ production   │    │ monitoring   │         │
│  │              │    │              │         │
│  │ ┌──────────┐ │    │ ┌──────────┐│         │
│  │ │Frontend  │ │    │ │Prometheus││         │
│  │ │ 3 pods   │ │    │ │          ││         │
│  │ └────┬─────┘ │    │ └──────────┘│         │
│  │      │       │    │ ┌──────────┐│         │
│  │      ▼       │    │ │ Grafana  ││         │
│  │ ┌──────────┐ │    │ │          ││         │
│  │ │Backend   │ │    │ └──────────┘│         │
│  │ │ 3 pods   │ │    │ ┌──────────┐│         │
│  │ └────┬─────┘ │    │ │   Loki   ││         │
│  │      │       │    │ │          ││         │
│  │      ▼       │    │ └──────────┘│         │
│  │ ┌──────────┐ │    │ ┌──────────┐│         │
│  │ │PostgreSQL│ │    │ │ Promtail ││         │
│  │ │StatefulSet│ │    │ │(DaemonSet)         │
│  │ │  + PVC   │ │    │ └──────────┘│         │
│  │ └──────────┘ │    │              │         │
│  └──────────────┘    └──────────────┘         │
│                                                │
│  Network Policies: Enabled                    │
│  HPA: frontend, backend (2-10 replicas)       │
│  Persistent Volumes: Database, Monitoring     │
└─────────────────────────────────────────────────┘

External Services:
  - GitHub (CI/CD, Container Registry)
  - Let's Encrypt (SSL Certificates)
  - Slack (Alerting)
```

## Component Inventory

```yaml
# component-inventory.yaml
cluster:
  name: production-cluster
  provider: GKE/EKS/AKS/minikube
  kubernetes_version: 1.28
  nodes:
    - name: node-1
      role: control-plane
      cpu: 4 cores
      memory: 8Gi
    - name: node-2
      role: worker
      cpu: 4 cores
      memory: 8Gi
    - name: node-3
      role: worker
      cpu: 4 cores
      memory: 8Gi

namespaces:
  production:
    deployments:
      - name: frontend
        replicas: 3
        image: ghcr.io/user/frontend:v1.0.0
        resources:
          requests: {cpu: 50m, memory: 64Mi}
          limits: {cpu: 100m, memory: 128Mi}
      - name: backend
        replicas: 3
        image: ghcr.io/user/backend:v1.0.0
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: 200m, memory: 256Mi}
    statefulsets:
      - name: postgres
        replicas: 1
        image: postgres:15-alpine
        pvc: postgres-pvc (10Gi)

  monitoring:
    deployments:
      - prometheus (kube-prometheus-stack)
      - grafana (kube-prometheus-stack)
      - loki
    daemonsets:
      - promtail

  ingress-nginx:
    deployments:
      - nginx-ingress-controller

  cert-manager:
    deployments:
      - cert-manager
      - cert-manager-webhook
      - cert-manager-cainjector

persistent_volumes:
  - name: postgres-pvc
    namespace: production
    size: 10Gi
    storage_class: standard
  - name: prometheus-storage
    namespace: monitoring
    size: 50Gi
  - name: loki-storage
    namespace: monitoring
    size: 50Gi

ingress:
  - name: app-ingress
    namespace: production
    hosts:
      - myapp.example.com → frontend:80
      - api.myapp.example.com → backend:8080
    tls:
      - secretName: myapp-tls
        issuer: letsencrypt-prod

services:
  external:
    - nginx-ingress-controller (LoadBalancer)
      ip: 203.0.113.10
  internal:
    - frontend (ClusterIP)
    - backend (ClusterIP)
    - postgres (ClusterIP)
    - prometheus (ClusterIP)
    - grafana (ClusterIP)
    - loki (ClusterIP)
```

## Deployment Runbook

```markdown
# Deployment Runbook

## Prerequisites
- kubectl configured
- Helm 3+ installed
- GitHub access (repository and container registry)
- DNS configured (myapp.example.com → LoadBalancer IP)

## Fresh Deployment

### 1. Cluster Setup
```bash
# Create cluster (adjust for provider)
gcloud container clusters create production-cluster \
  --num-nodes=3 --machine-type=e2-standard-4

# Verify
kubectl get nodes
```

### 2. Create Namespaces
```bash
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace monitoring
kubectl create namespace ingress-nginx
kubectl create namespace cert-manager

# Label namespaces
kubectl label namespace production env=prod
kubectl label namespace monitoring name=monitoring
kubectl label namespace kube-system name=kube-system
```

### 3. Install Nginx Ingress
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  -f manifests/ingress/values.yaml
```

### 4. Install cert-manager
```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

kubectl apply -f manifests/cert-manager/clusterissuer.yaml
```

### 5. Deploy Application
```bash
# Database
kubectl apply -f manifests/production/database.yaml

# Backend
kubectl apply -f manifests/production/backend.yaml

# Frontend
kubectl apply -f manifests/production/frontend.yaml

# Ingress
kubectl apply -f manifests/production/ingress.yaml

# Network Policies
kubectl apply -f manifests/production/network-policies.yaml

# HPA
kubectl apply -f manifests/production/hpa.yaml
```

### 6. Install Monitoring Stack
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f manifests/monitoring/prometheus-values.yaml

kubectl apply -f manifests/monitoring/servicemonitor.yaml
kubectl apply -f manifests/monitoring/prometheus-rules.yaml
```

### 7. Install Logging Stack
```bash
helm install loki grafana/loki -n monitoring -f manifests/logging/loki-values.yaml
helm install promtail grafana/promtail -n monitoring -f manifests/logging/promtail-values.yaml

kubectl apply -f manifests/monitoring/grafana-dashboards.yaml
```

### 8. Verify Deployment
```bash
# All pods running
kubectl get pods -A

# Services healthy
kubectl get svc -A

# Ingress configured
kubectl get ingress -n production

# Certificate issued
kubectl get certificate -n production

# Access application
curl -I https://myapp.example.com
```

## Update Deployment

### Rolling Update
```bash
# Update image
kubectl set image deployment/backend \
  backend=ghcr.io/user/backend:v1.1.0 \
  -n production

# Monitor rollout
kubectl rollout status deployment/backend -n production

# Check new pods
kubectl get pods -n production -l app=backend
```

### Rollback
```bash
# Rollback to previous version
kubectl rollout undo deployment/backend -n production

# Rollback to specific revision
kubectl rollout history deployment/backend -n production
kubectl rollout undo deployment/backend --to-revision=2 -n production
```

## Scaling

### Manual Scaling
```bash
kubectl scale deployment/backend --replicas=5 -n production
```

### HPA Status
```bash
kubectl get hpa -n production
kubectl describe hpa backend-hpa -n production
```
```

## Incident Response Runbook

```markdown
# Incident Response Runbook

## Severity Levels

**Critical (P0):**
- Service completely down
- Data loss
- Security breach

**High (P1):**
- Partial service outage
- Significant performance degradation
- High error rate

**Medium (P2):**
- Minor issues affecting some users
- Degraded performance
- Non-critical errors

**Low (P3):**
- Cosmetic issues
- Minor bugs
- Enhancement requests

## Response Procedures

### P0: Service Down

**Symptoms:**
- All backend pods down
- 503 errors
- No response from application

**Immediate Actions:**

1. Check pod status:
   ```bash
   kubectl get pods -n production
   kubectl describe pod <pod-name> -n production
   kubectl logs <pod-name> -n production --previous
   ```

2. Check recent changes:
   ```bash
   kubectl rollout history deployment/backend -n production
   ```

3. Rollback if recent deployment:
   ```bash
   kubectl rollout undo deployment/backend -n production
   ```

4. Check cluster health:
   ```bash
   kubectl get nodes
   kubectl top nodes
   ```

5. Check events:
   ```bash
   kubectl get events -n production --sort-by='.lastTimestamp'
   ```

**Escalation:**
- Notify: #incidents Slack channel
- Page: On-call engineer
- Update: Status page

### P1: High Error Rate

**Symptoms:**
- Prometheus alert: HighErrorRate
- Grafana dashboard shows >5% errors

**Debug Steps:**

1. Check Grafana dashboard:
   - Error rate panel
   - Time of spike

2. Query logs for errors:
   ```bash
   # Grafana Explore → Loki
   {namespace="production",app="backend"} |= "error" | json | level="error"
   ```

3. Check database connection:
   ```bash
   kubectl exec -it postgres-0 -n production -- psql -U myapp_user -d myapp -c "SELECT 1"
   ```

4. Check backend logs:
   ```bash
   kubectl logs -n production -l app=backend --tail=100 | grep ERROR
   ```

5. Check resource usage:
   ```bash
   kubectl top pods -n production
   ```

**Resolution:**
- Identify root cause from logs
- Apply fix (config change, code deploy, resource increase)
- Monitor metrics until error rate normalizes

### P2: High Memory Usage

**Symptoms:**
- Prometheus alert: HighMemoryUsage
- Pod memory >90%

**Actions:**

1. Identify pod:
   ```bash
   kubectl top pods -n production --sort-by=memory
   ```

2. Check for memory leak:
   ```bash
   # Monitor over time
   watch kubectl top pod <pod-name> -n production
   ```

3. Get heap dump (if applicable):
   ```bash
   kubectl exec <pod-name> -n production -- <heap-dump-command>
   ```

4. Temporary fix - restart pod:
   ```bash
   kubectl delete pod <pod-name> -n production
   ```

5. Long-term fix:
   - Investigate memory leak in code
   - Increase memory limits if legitimate usage
   - Update HPA memory target

## Disaster Recovery

### Database Backup

**Automated Backup (Daily):**
```bash
# CronJob for daily backup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: production
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgres -U myapp_user myapp > /backup/dump-$(date +%Y%m%d).sql
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

**Manual Backup:**
```bash
kubectl exec postgres-0 -n production -- \
  pg_dump -U myapp_user myapp > backup-$(date +%Y%m%d).sql
```

### Database Restore

**From Backup:**
```bash
# Copy backup to pod
kubectl cp backup-20260509.sql production/postgres-0:/tmp/

# Restore
kubectl exec postgres-0 -n production -- \
  psql -U myapp_user myapp < /tmp/backup-20260509.sql
```

### Complete Cluster Recovery

**Scenario: Cluster lost, need to rebuild**

1. Create new cluster:
   ```bash
   # Follow Deployment Runbook Section 1-2
   ```

2. Restore configuration from Git:
   ```bash
   git clone https://github.com/user/k8s-manifests
   cd k8s-manifests
   ```

3. Deploy infrastructure (Ingress, cert-manager):
   ```bash
   # Follow Deployment Runbook Section 3-4
   ```

4. Restore database:
   ```bash
   # Deploy empty database
   kubectl apply -f manifests/production/database.yaml

   # Restore data
   kubectl cp latest-backup.sql production/postgres-0:/tmp/
   kubectl exec postgres-0 -n production -- \
     psql -U myapp_user myapp < /tmp/latest-backup.sql
   ```

5. Deploy application:
   ```bash
   # Follow Deployment Runbook Section 5
   ```

6. Deploy monitoring:
   ```bash
   # Follow Deployment Runbook Section 6-7
   ```

7. Verify:
   ```bash
   # Follow Deployment Runbook Section 8
   ```

**Recovery Time Objective (RTO):** 2 hours
**Recovery Point Objective (RPO):** 24 hours (daily backups)

## Maintenance Procedures

### Certificate Renewal

**Automatic Renewal:**
- cert-manager auto-renews 30 days before expiry
- No action needed

**Manual Renewal (if needed):**
```bash
# Delete certificate (will be re-issued)
kubectl delete certificate myapp-tls -n production

# Wait for re-issuance
kubectl get certificate -n production -w
```

### Kubernetes Upgrade

1. Check current version:
   ```bash
   kubectl version
   ```

2. Backup all resources:
   ```bash
   kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
   ```

3. Upgrade cluster (cloud provider specific):
   ```bash
   # GKE example
   gcloud container clusters upgrade production-cluster --master --cluster-version=1.29
   gcloud container clusters upgrade production-cluster --node-pool=default-pool
   ```

4. Verify:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

### Scaling Up Resources

**Increase Database Storage:**
```bash
# Edit PVC
kubectl edit pvc postgres-pvc -n production
# Change size: 10Gi → 20Gi

# Restart pod to apply
kubectl delete pod postgres-0 -n production
```

**Increase Node Count:**
```bash
# GKE example
gcloud container clusters resize production-cluster --num-nodes=5
```
```

## Access Credentials

```markdown
# Access Credentials

## Cluster Access

**kubectl config:**
- Location: `~/.kube/config`
- Context: `production-cluster`

**Service Accounts:**
- CI/CD: `github-actions-sa` (namespace: production)
- Monitoring: `prometheus` (namespace: monitoring)

## Application Credentials

**Database:**
- Host: `postgres.production.svc.cluster.local`
- Port: `5432`
- Database: `myapp`
- Secret: `postgres-secret` (namespace: production)

**Grafana:**
- URL: `http://localhost:3000` (port-forward)
- Username: `admin`
- Password: Secret `prometheus-grafana` key `admin-password`

**Container Registry:**
- Registry: `ghcr.io`
- Authentication: GitHub token (CI/CD secret)

## External Services

**GitHub:**
- Repository: `https://github.com/user/myapp`
- Container Registry: `ghcr.io/user/frontend`, `ghcr.io/user/backend`
- Secrets:
  - `KUBECONFIG`: Base64-encoded kubeconfig
  - `GITHUB_TOKEN`: Auto-provided for GHCR

**Let's Encrypt:**
- Email: `admin@example.com`
- Staging API: Testing certificates
- Production API: Live certificates

**Slack:**
- Webhook URL: Stored in Alertmanager secret
- Channel: `#alerts`

## Emergency Contacts

**On-Call Rotation:**
- Primary: DevOps Team Lead
- Secondary: Senior DevOps Engineer
- Escalation: CTO

**Slack Channels:**
- `#incidents`: Critical incidents
- `#alerts`: Automated alerts
- `#deployments`: Deployment notifications
```

## Health Check Dashboard

```bash
# health-check.sh - Run this daily
#!/bin/bash

echo "=== Cluster Health Check ==="
echo

echo "1. Nodes:"
kubectl get nodes
echo

echo "2. Pods (all namespaces):"
kubectl get pods -A | grep -v Running | grep -v Completed
echo

echo "3. PVCs:"
kubectl get pvc -A
echo

echo "4. Ingress:"
kubectl get ingress -A
echo

echo "5. Certificates:"
kubectl get certificate -A
echo

echo "6. HPA:"
kubectl get hpa -A
echo

echo "7. Top Pods (CPU):"
kubectl top pods -A --sort-by=cpu | head -10
echo

echo "8. Top Pods (Memory):"
kubectl top pods -A --sort-by=memory | head -10
echo

echo "9. Recent Events (last 10):"
kubectl get events -A --sort-by='.lastTimestamp' | tail -10
echo

echo "10. Endpoint Check:"
curl -I https://myapp.example.com
echo

echo "=== End Health Check ==="
```
