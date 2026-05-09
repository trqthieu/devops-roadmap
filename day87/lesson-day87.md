# Lesson: Day 87 - Final Project Day 1 (Production Stack Deployment)

## Mục tiêu ngày hôm nay

- Deploy production-ready Kubernetes stack từ đầu
- Implement Nginx Ingress Controller với SSL/TLS
- Setup multi-tier application (Frontend + Backend + Database)
- Configure Network Policies cho security
- Integrate CI/CD pipeline với GitHub Actions

## Project Architecture

### High-level Architecture

```
                        Internet
                           │
                           ▼
                ┌──────────────────┐
                │  DNS Records      │
                │  myapp.example.com│
                │  api.myapp.com    │
                └────────┬──────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  Cloud LoadBalancer            │
        │  (External IP)                 │
        └────────┬───────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│          Kubernetes Cluster                      │
│                                                  │
│  ┌────────────────────────────────────┐         │
│  │  Nginx Ingress Controller          │         │
│  │  - SSL Termination (cert-manager)  │         │
│  │  - Host-based routing              │         │
│  └────────┬───────────────────────────┘         │
│           │                                      │
│     ┌─────┴─────┐                               │
│     │           │                               │
│     ▼           ▼                               │
│  ┌──────┐   ┌──────┐                           │
│  │Frontend   │Backend                           │
│  │(3 pods)   │(3 pods)                          │
│  │         │ │                                   │
│  │ Nginx   │ │ API                              │
│  │ React   │ │ Go/Node/Python                   │
│  └──────┘   └──┬───┘                            │
│               │                                  │
│               ▼                                  │
│          ┌──────────┐                           │
│          │ Database │                           │
│          │(PostgreSQL)                          │
│          │ StatefulSet│                         │
│          │ Persistent │                         │
│          │  Volume    │                         │
│          └──────────┘                           │
│                                                  │
│  Security:                                      │
│  - Network Policies (micro-segmentation)        │
│  - TLS encryption (Let's Encrypt)               │
│  - Secret management (Kubernetes Secrets)       │
│                                                  │
│  Scalability:                                   │
│  - HPA (Horizontal Pod Autoscaler)              │
│  - Multi-replica deployments                    │
│                                                  │
│  CI/CD:                                         │
│  - GitHub Actions (automated deployments)       │
│  - Container registry (GHCR/DockerHub)          │
└─────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Infrastructure Setup

```
Checklist:

1. Kubernetes Cluster
   □ 3 nodes (control-plane + 2 workers)
   □ kubectl configured
   □ Cluster reachable

2. Namespaces
   □ production (main application)
   □ staging (testing)
   □ monitoring (Prometheus, Grafana)
   □ ingress-nginx (Ingress Controller)
   □ Labels applied (for NetworkPolicy)

3. Nginx Ingress Controller
   □ Installed via Helm
   □ LoadBalancer IP assigned
   □ Metrics enabled (for Prometheus)

4. cert-manager
   □ Installed
   □ ClusterIssuers configured (staging + prod)
   □ ACME challenge working
```

### Phase 2: Database Layer

```
PostgreSQL StatefulSet:

Why StatefulSet (not Deployment)?
- Stable network identity (postgres-0)
- Ordered deployment & scaling
- Persistent storage attached to pod identity
- Graceful shutdown (prevents data corruption)

Architecture:

┌─────────────────────────────────────────────────┐
│              StatefulSet: postgres              │
│                                                  │
│  ┌────────────────────────────────┐             │
│  │  Pod: postgres-0               │             │
│  │  - Stable hostname             │             │
│  │  - Volume claim (PVC)          │             │
│  │                                │             │
│  │  ┌──────────────────┐          │             │
│  │  │  PostgreSQL      │          │             │
│  │  │  - Database: myapp          │             │
│  │  │  - User: myapp_user         │             │
│  │  └──────────────────┘          │             │
│  │         │                      │             │
│  │         ▼                      │             │
│  │  ┌──────────────────┐          │             │
│  │  │ Persistent Volume│          │             │
│  │  │ /var/lib/postgresql/data  │             │
│  │  │ - 10Gi storage   │          │             │
│  │  └──────────────────┘          │             │
│  └────────────────────────────────┘             │
│                                                  │
│  Service: postgres (ClusterIP)                  │
│  - Internal DNS: postgres.production.svc        │
│  - Port: 5432                                   │
└─────────────────────────────────────────────────┘

Secret Management:
- Credentials stored in Secret
- Injected as env vars
- NOT hardcoded in image
```

### Phase 3: Backend API

```
Deployment: backend (3 replicas)

┌─────────────────────────────────────────────────┐
│          Deployment: backend                     │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │backend-1 │  │backend-2 │  │backend-3 │      │
│  │          │  │          │  │          │      │
│  │ API      │  │ API      │  │ API      │      │
│  │ :8080    │  │ :8080    │  │ :8080    │      │
│  │          │  │          │  │          │      │
│  │ Metrics  │  │ Metrics  │  │ Metrics  │      │
│  │ :9090    │  │ :9090    │  │ :9090    │      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘      │
│       │             │             │             │
│       └─────────────┼─────────────┘             │
│                     ▼                           │
│            Service: backend                     │
│            - ClusterIP                          │
│            - Port 8080 (API)                    │
│            - Port 9090 (metrics)                │
│                     │                           │
│                     ▼                           │
│            StatefulSet: postgres                │
└─────────────────────────────────────────────────┘

Health Checks:
- Liveness: /health (restart if fails)
- Readiness: /ready (remove from service if not ready)

Benefits:
- Zero downtime during updates (rolling update)
- Auto-restart if unhealthy
- Load balancing across replicas
```

### Phase 4: Frontend

```
Deployment: frontend (3 replicas)

┌─────────────────────────────────────────────────┐
│          Deployment: frontend                    │
│                                                  │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │frontend-1 │  │frontend-2 │  │frontend-3 │   │
│  │           │  │           │  │           │   │
│  │ Nginx     │  │ Nginx     │  │ Nginx     │   │
│  │ React/Vue │  │ React/Vue │  │ React/Vue │   │
│  │ :80       │  │ :80       │  │ :80       │   │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘   │
│        │               │               │        │
│        └───────────────┼───────────────┘        │
│                        ▼                        │
│               Service: frontend                 │
│               - ClusterIP                       │
│               - Port 80                         │
└─────────────────────────────────────────────────┘

Environment Variables:
- BACKEND_URL: http://backend:8080
- API_ENDPOINT: /api

Frontend gọi backend qua internal Service DNS
(trong cluster, không qua Ingress)
```

### Phase 5: Ingress và SSL/TLS

```
Traffic Flow với Ingress:

1. User Request:
   https://myapp.example.com

2. DNS Resolution:
   myapp.example.com → LoadBalancer IP (203.0.113.10)

3. LoadBalancer:
   → Forwards to Nginx Ingress Controller (NodePort/Service)

4. Ingress Controller:
   - Checks Host header: myapp.example.com
   - Matches Ingress rule
   - SSL Termination (TLS decryption)
   - Forwards to backend: frontend Service

5. Frontend Service:
   - Load balances to one of 3 frontend pods

6. Response:
   frontend pod → Service → Ingress → TLS encryption → User

cert-manager Workflow:

1. Ingress created với annotation:
   cert-manager.io/cluster-issuer: "letsencrypt-prod"

2. cert-manager detects annotation:
   - Creates Certificate resource
   - Initiates ACME challenge (HTTP-01)

3. Let's Encrypt challenge:
   - Sends HTTP request to http://myapp.example.com/.well-known/acme-challenge/<token>
   - Ingress routes to cert-manager solver pod
   - Challenge validated

4. Certificate issued:
   - cert-manager stores in Secret: myapp-tls
   - Ingress uses Secret for TLS

5. Auto-renewal:
   - cert-manager renews before expiry (30 days before)
   - Zero-downtime renewal
```

### Phase 6: Network Policies

```
Zero Trust Networking:

Default: Deny All
  ↓
Explicit Allow:

1. Ingress Controller → Frontend
   ┌───────────────┐       ┌──────────┐
   │ Ingress NS    │──────►│ Frontend │
   │ (nginx)       │ :80   │  Pods    │
   └───────────────┘       └──────────┘

2. Frontend → Backend
   ┌──────────┐       ┌──────────┐
   │ Frontend │──────►│ Backend  │
   │  Pods    │ :8080 │  Pods    │
   └──────────┘       └──────────┘

3. Backend → Database
   ┌──────────┐       ┌──────────┐
   │ Backend  │──────►│ Postgres │
   │  Pods    │ :5432 │  Pod     │
   └──────────┘       └──────────┘

4. All → kube-dns (DNS resolution)
   ┌──────────┐       ┌──────────┐
   │ Any Pod  │──────►│ kube-dns │
   │          │ :53   │(kube-system)
   └──────────┘       └──────────┘

Blocked Scenarios:
❌ Frontend → Postgres (direct DB access)
❌ Internet → Backend (bypass Ingress)
❌ Compromised pod → Other namespaces
```

### Phase 7: Horizontal Pod Autoscaler

```
HPA Workflow:

1. Metrics Server collects resource usage:
   - CPU: 150m / 200m limit = 75%
   - Memory: 200Mi / 256Mi limit = 78%

2. HPA evaluates:
   - Target: 70% CPU
   - Current: 75% CPU
   - Decision: Scale up

3. HPA updates Deployment:
   - replicas: 3 → 4

4. Deployment creates new pod:
   - Rolling deployment
   - New pod ready

5. Service load balances:
   - Traffic distributed across 4 pods
   - CPU drops to 60%

6. Cooldown period:
   - Wait 3 minutes before next scale decision
   - Prevents flapping

Scaling decisions:
  replicas = ceil(current_replicas × (current_metric / target_metric))

Example:
  current_replicas = 3
  current_cpu = 75%
  target_cpu = 70%

  replicas = ceil(3 × (75 / 70)) = ceil(3.21) = 4
```

### Phase 8: CI/CD Pipeline

```
GitHub Actions Workflow:

Trigger: git push to main branch

┌─────────────────────────────────────────────────┐
│              GitHub Actions                      │
│                                                  │
│  Job 1: Build and Push                          │
│  ┌────────────────────────────────┐             │
│  │ 1. Checkout code               │             │
│  │ 2. Build Docker image           │             │
│  │ 3. Tag: ghcr.io/user/app:sha    │             │
│  │ 4. Push to registry             │             │
│  └────────────────────────────────┘             │
│           │                                      │
│           ▼                                      │
│  Job 2: Deploy to Kubernetes                    │
│  ┌────────────────────────────────┐             │
│  │ 1. Configure kubectl            │             │
│  │ 2. Update Deployment image      │             │
│  │    kubectl set image...         │             │
│  │ 3. Wait for rollout             │             │
│  │    kubectl rollout status...    │             │
│  │ 4. Verify deployment            │             │
│  └────────────────────────────────┘             │
└─────────────────────────────────────────────────┘
           │
           ▼
    Kubernetes Cluster
    - Rolling update
    - Zero downtime
    - Health checks pass
    - New version live

Secrets needed:
- KUBECONFIG: Cluster access (base64 encoded)
- GITHUB_TOKEN: Container registry push (auto-provided)
```

## Best Practices Applied

### 1. Security

```
✅ TLS encryption (HTTPS only)
✅ Network Policies (micro-segmentation)
✅ Secrets management (not hardcoded)
✅ Non-root containers
✅ Resource limits (prevent DoS)
✅ RBAC (least privilege)
```

### 2. High Availability

```
✅ Multi-replica deployments (3+ replicas)
✅ Pod Anti-Affinity (spread across nodes)
✅ Health checks (liveness + readiness)
✅ Rolling updates (zero downtime)
✅ HPA (auto-scaling)
```

### 3. Observability

```
✅ Metrics endpoint (/metrics)
✅ Structured logging (JSON)
✅ Health endpoints (/health, /ready)
✅ Prometheus integration (Day 88)
✅ Centralized logging (Day 88)
```

### 4. Resource Management

```
✅ Resource requests (scheduling guarantee)
✅ Resource limits (prevent resource hogging)
✅ HPA (dynamic scaling)
✅ Persistent volumes (data persistence)
✅ Storage classes (appropriate storage tiers)
```

### 5. GitOps

```
✅ Infrastructure as Code (YAML manifests)
✅ Version control (Git)
✅ Automated deployments (CI/CD)
✅ Rollback capability (git revert)
✅ Audit trail (git history)
```

## Troubleshooting Guide

### Issue 1: Certificate not issued

```
Symptoms:
- Ingress shows no TLS secret
- Browser shows "not secure"

Debug:
1. Check Certificate resource:
   kubectl get certificate -n production
   kubectl describe certificate myapp-tls -n production

2. Check CertificateRequest:
   kubectl get certificaterequest -n production
   kubectl describe certificaterequest -n production

3. Check Challenge (ACME):
   kubectl get challenge -n production
   kubectl describe challenge -n production

4. Check cert-manager logs:
   kubectl logs -n cert-manager deployment/cert-manager

Common issues:
- DNS not pointing to LoadBalancer IP
- Firewall blocking port 80 (HTTP challenge)
- Rate limit (use staging issuer first)
- Incorrect email in ClusterIssuer
```

### Issue 2: Pods not accessible via Ingress

```
Debug:

1. Check Ingress created:
   kubectl get ingress -n production
   kubectl describe ingress app-ingress -n production

2. Check Ingress Controller logs:
   kubectl logs -n ingress-nginx deployment/nginx-ingress-controller

3. Check Service endpoints:
   kubectl get endpoints frontend -n production
   # Should show pod IPs

4. Check Network Policies:
   kubectl get networkpolicy -n production
   # Verify allow rule from ingress-nginx namespace

5. Test directly (bypass Ingress):
   kubectl port-forward -n production svc/frontend 8080:80
   curl localhost:8080
```

### Issue 3: Backend can't connect to database

```
Debug:

1. Check database pod running:
   kubectl get pods -n production -l app=postgres

2. Check Service DNS:
   kubectl run test --image=busybox -it --rm -- nslookup postgres.production.svc.cluster.local

3. Check Network Policy:
   kubectl get networkpolicy -n production
   # Verify allow rule: backend → postgres:5432

4. Check credentials:
   kubectl get secret postgres-secret -n production -o yaml
   # Decode base64 values

5. Test connection from backend pod:
   kubectl exec -it -n production <backend-pod> -- sh
   # Install psql, test: psql -h postgres -U myapp_user -d myapp
```

## Tóm tắt

Day 87 - Production Stack Deployment:

**Components Deployed:**
- Kubernetes cluster (3 nodes)
- Nginx Ingress Controller (SSL/TLS termination)
- cert-manager (auto SSL certificates)
- Multi-tier app (Frontend, Backend, Database)
- Network Policies (security)
- HPA (auto-scaling)
- CI/CD pipeline (GitHub Actions)

**Architecture:**
- Frontend (Nginx + React/Vue) - 3 replicas
- Backend (API) - 3 replicas
- Database (PostgreSQL) - StatefulSet
- Ingress (host-based routing + TLS)
- LoadBalancer (external access)

**Security:**
- TLS encryption (Let's Encrypt)
- Network Policies (micro-segmentation)
- Secrets management
- Non-root containers

**High Availability:**
- Multi-replica deployments
- Health checks (liveness/readiness)
- Rolling updates
- Auto-scaling (HPA)

**Next:** Day 88 sẽ add monitoring (Prometheus + Grafana) và logging (Loki + Promtail) vào stack.
