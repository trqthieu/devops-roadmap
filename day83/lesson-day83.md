# Lesson: Day 83 - Kubernetes Network Policies

## Mục tiêu ngày hôm nay

- Hiểu Kubernetes Network Policy là gì và tại sao cần thiết
- Nắm được ingress vs egress rules
- Triển khai pod selector và namespace isolation
- Implement deny-all default policy
- Apply network segmentation cho multi-tier applications

## Tại sao Network Policies quan trọng?

### Default Behavior của Kubernetes Networking

```
Kubernetes mặc định: "Allow All"

┌────────────────────────────────────────────────┐
│              Kubernetes Cluster                │
│                                                │
│  ┌──────┐    ┌──────┐    ┌──────┐            │
│  │ Pod1 │◄──►│ Pod2 │◄──►│ Pod3 │            │
│  │      │    │      │    │      │            │
│  └──────┘    └──────┘    └──────┘            │
│     ▲           ▲           ▲                 │
│     │           │           │                 │
│     └───────────┴───────────┘                 │
│                 │                             │
│        Mọi pod có thể nói chuyện              │
│        với mọi pod khác                       │
└────────────────────────────────────────────────┘

Risk:
- Frontend có thể truy cập trực tiếp database
- Compromised pod có thể attack toàn bộ cluster
- Không có network segmentation
```

### Với Network Policies

```
Implement "Zero Trust" Networking:

┌────────────────────────────────────────────────┐
│              Kubernetes Cluster                │
│                                                │
│  ┌──────────┐     ┌──────────┐   ┌─────────┐ │
│  │ Frontend │────►│ Backend  │──►│Database │ │
│  │          │     │          │   │         │ │
│  └──────────┘     └──────────┘   └─────────┘ │
│       │                ▲              ▲       │
│       │                │              │       │
│       └────────X───────┘              │       │
│         Blocked by                    │       │
│         NetworkPolicy                 │       │
│                                       │       │
│       ┌────────────────X──────────────┘       │
│       │      Blocked by NetworkPolicy         │
│       │                                        │
│  ┌────▼──────┐                                │
│  │Compromised│  ← Cannot access database      │
│  │    Pod    │                                │
│  └───────────┘                                │
└────────────────────────────────────────────────┘

Benefits:
- Micro-segmentation: Mỗi tier chỉ nói chuyện với tier cần thiết
- Least privilege: Deny by default, allow explicitly
- Defense in depth: Ngay cả khi pod bị compromise, damage bị giới hạn
```

## NetworkPolicy Architecture

### Components

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-policy
  namespace: production
spec:
  podSelector:           # Target pods (rule áp dụng cho pods nào?)
    matchLabels:
      app: backend

  policyTypes:           # Rule type: Ingress, Egress, hoặc cả hai
  - Ingress
  - Egress

  ingress:               # Ingress rules (traffic VÀO pods)
  - from:
    - podSelector:       # Source pods
        matchLabels:
          app: frontend
    ports:               # Allowed ports
    - protocol: TCP
      port: 8080

  egress:                # Egress rules (traffic RA KHỎI pods)
  - to:
    - podSelector:       # Destination pods
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

### Ingress vs Egress

```
Ingress (Traffic VÀO pod):

  External/Other Pods
         │
         │ Ingress
         ▼
    ┌─────────┐
    │ Target  │
    │  Pod    │
    └─────────┘

Egress (Traffic RA KHỎI pod):

    ┌─────────┐
    │ Source  │
    │  Pod    │
    └─────────┘
         │
         │ Egress
         ▼
  External/Other Pods
```

### Rule Evaluation Logic

```
1. Nếu KHÔNG có NetworkPolicy nào select pod:
   → Allow all traffic (default Kubernetes behavior)

2. Nếu CÓ ít nhất 1 NetworkPolicy select pod:
   → Default DENY all
   → Chỉ allow traffic match với ít nhất 1 rule

3. Ingress và Egress độc lập:
   - policyTypes: [Ingress] → Chỉ control ingress, egress vẫn allow all
   - policyTypes: [Egress] → Chỉ control egress, ingress vẫn allow all
   - policyTypes: [Ingress, Egress] → Control cả hai

4. Rules trong cùng 1 NetworkPolicy: OR logic
   - Match bất kỳ rule nào → allow

5. Rules từ nhiều NetworkPolicies: OR logic
   - Match rule từ bất kỳ policy nào → allow
```

## Pod Selector

### Pod Selector trong spec.podSelector

```yaml
# Target specific pods
spec:
  podSelector:
    matchLabels:
      app: backend
      tier: api

# Target TẤT CẢ pods trong namespace
spec:
  podSelector: {}  # Empty selector = all pods
```

### Pod Selector trong ingress/egress rules

```yaml
ingress:
- from:
  - podSelector:           # Source pods
      matchLabels:
        app: frontend

egress:
- to:
  - podSelector:           # Destination pods
      matchLabels:
        app: database
```

### Workflow Example

```
NetworkPolicy:
  podSelector: {app: backend}
  ingress:
  - from:
    - podSelector: {app: frontend}

Pods in cluster:
  Pod A: {app: frontend}   ─┐
  Pod B: {app: frontend}   ─┤ Can access
  Pod C: {app: backend}    ─┘   ▼
  Pod D: {app: admin}      ─── Blocked

  Pod E: {app: backend}    ← Policy applies
  Pod F: {app: backend}    ← Policy applies
  Pod G: {app: database}   ← No policy (allow all)
```

## Namespace Selector

### Namespace Isolation

```yaml
# Only allow traffic từ pods trong cùng namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}      # Pods trong cùng namespace
```

### Cross-Namespace Access

```yaml
# Allow traffic từ specific namespace
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        env: production    # Namespace phải có label env=production
```

### Combined Pod + Namespace Selector

```yaml
# Allow từ specific pods trong specific namespace
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        env: production
    podSelector:
      matchLabels:
        app: frontend
# AND logic: Cả namespace VÀ pod phải match
```

```yaml
# Allow từ specific pods HOẶC specific namespace
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        env: production
  - podSelector:
      matchLabels:
        app: frontend
# OR logic: Namespace match HOẶC pod match
```

### Namespace Labels

```bash
# Label namespaces để dùng với namespaceSelector
kubectl label namespace production env=prod
kubectl label namespace staging env=staging
kubectl label namespace monitoring name=monitoring

# NetworkPolicy có thể reference:
namespaceSelector:
  matchLabels:
    env: prod
```

## Deny-All Default Policy

### Best Practice Pattern

```
Strategy: Default Deny + Explicit Allow

Step 1: Deploy deny-all policy
Step 2: Deploy allow policies cho từng service
Step 3: Test connectivity
Step 4: Iterate (add more allow rules as needed)
```

### Deny All Ingress

```yaml
# Trong mỗi namespace, deploy policy này đầu tiên
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}          # Áp dụng cho ALL pods
  policyTypes:
  - Ingress
  # Không có ingress rules → deny all ingress traffic
```

### Deny All Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  # Không có egress rules → deny all egress traffic
```

### Sau đó add Allow Rules

```yaml
# Allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Kết quả:**
- Default: Deny all (deny-all-ingress policy)
- Explicit allow: frontend → backend:8080
- Mọi traffic khác: Blocked

## Multi-tier Application Example

### 3-Tier Architecture

```
┌──────────────┐
│   Internet   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Frontend   │  Port 80
│              │
└──────┬───────┘
       │
       │ NetworkPolicy: frontend → backend:8080
       ▼
┌──────────────┐
│   Backend    │  Port 8080
│   (API)      │
└──────┬───────┘
       │
       │ NetworkPolicy: backend → database:5432
       ▼
┌──────────────┐
│   Database   │  Port 5432
│  (Postgres)  │
└──────────────┘
```

### Frontend Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  - Egress

  ingress:
  - from:
    - podSelector: {}        # Allow từ any pod (hoặc từ Ingress Controller)
    ports:
    - protocol: TCP
      port: 80

  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend      # Chỉ gọi được backend
    ports:
    - protocol: TCP
      port: 8080
  - to:                      # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Backend Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress

  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend     # Chỉ nhận từ frontend
    ports:
    - protocol: TCP
      port: 8080

  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database     # Chỉ gọi database
    ports:
    - protocol: TCP
      port: 5432
  - to:                      # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Database Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  - Egress

  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend      # Chỉ nhận từ backend
    ports:
    - protocol: TCP
      port: 5432

  egress:
  - to:                      # Chỉ allow DNS, không cho egress khác
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Traffic Flow với Policies

```
Request Flow:
  User → Frontend:80 (allowed: ingress rule)
       → Frontend → Backend:8080 (allowed: egress + ingress)
                 → Backend → Database:5432 (allowed: egress + ingress)
                          → Database returns data

Blocked Scenarios:
  Frontend → Database:5432 ❌ (no egress rule in frontend-policy)
  Internet → Backend:8080 ❌ (no ingress rule allowing external)
  Database → External ❌ (only DNS egress allowed)
```

## IP Block (CIDR) Rules

### Allow External API Access

```yaml
egress:
- to:
  - ipBlock:
      cidr: 203.0.113.0/24    # External IP range
      except:
      - 203.0.113.10/32       # Except specific IP
  ports:
  - protocol: TCP
    port: 443
```

### Use Case Example

```yaml
# Backend cần gọi external payment API
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-external-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0       # Allow all external
        except:
        - 10.0.0.0/8          # Except internal networks
        - 172.16.0.0/12
        - 192.168.0.0/16
    ports:
    - protocol: TCP
      port: 443
```

## Common Patterns

### 1. Allow DNS Resolution

```yaml
# DNS là critical, hầu hết egress policies cần allow DNS
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
  - podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
```

### 2. Allow Health Checks từ Kubelet

```yaml
# Kubelet cần health check pods
ingress:
- from:
  - ipBlock:
      cidr: 10.0.0.0/8      # Node CIDR (adjust theo cluster)
  ports:
  - protocol: TCP
    port: 8080              # Health check port
```

### 3. Allow Metrics Scraping

```yaml
# Prometheus scrape metrics
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring
  - podSelector:
      matchLabels:
        app: prometheus
  ports:
  - protocol: TCP
    port: 9090              # Metrics port
```

### 4. Allow Ingress Controller Access

```yaml
# Frontend pods nhận traffic từ Ingress Controller
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: ingress-nginx
  ports:
  - protocol: TCP
    port: 80
```

## Troubleshooting Network Policies

### Issue 1: Traffic bị block không rõ lý do

```
Debug workflow:

1. Verify NetworkPolicy được apply:
   kubectl get networkpolicy -n production
   kubectl describe networkpolicy my-policy -n production

2. Check pod labels:
   kubectl get pods --show-labels -n production
   → Pod có labels match với podSelector không?

3. Check namespace labels (nếu dùng namespaceSelector):
   kubectl get namespaces --show-labels

4. Test connectivity:
   kubectl run test -n production --image=busybox -it --rm -- sh
   # Inside:
   wget -O- http://backend-service:8080
   nc -zv database-service 5432

5. Check CNI plugin logs (Calico/Cilium/Weave):
   kubectl logs -n kube-system <cni-pod>
```

### Issue 2: DNS không work

```
Symptom: Pods không resolve DNS sau khi apply NetworkPolicy

Cause: Egress policy block DNS traffic

Fix: Add DNS egress rule
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53              # Thêm TCP cho DNS over TCP
```

### Issue 3: Health checks fail

```
Symptom: Pods marked Unhealthy sau khi apply NetworkPolicy

Cause: Kubelet không thể probe health check port

Fix: Allow traffic từ nodes
ingress:
- from:
  - ipBlock:
      cidr: <NODE_CIDR>    # VD: 10.0.0.0/16
  ports:
  - protocol: TCP
    port: 8080             # Liveness/readiness port
```

### Issue 4: Policy không apply

```
Check CNI plugin support:

Not all CNI plugins support NetworkPolicy:
- ✅ Calico: Full support
- ✅ Cilium: Full support
- ✅ Weave Net: Full support
- ❌ Flannel: No support (cần combine với Calico)

Verify:
kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'
```

## CNI Plugin Requirements

```
NetworkPolicy cần CNI plugin hỗ trợ:

┌────────────────────────────────────────────────┐
│         Kubernetes API Server                  │
│    (stores NetworkPolicy resources)            │
└────────────────┬───────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────┐
│          CNI Plugin (node agent)               │
│   - Watches NetworkPolicy resources            │
│   - Implements rules in iptables/eBPF          │
│   - Enforces network segmentation              │
└────────────────────────────────────────────────┘

Examples:
- Calico: Uses iptables + BGP
- Cilium: Uses eBPF (more efficient)
- Weave Net: Uses iptables
```

## Best Practices

### 1. Start với Deny-All

```yaml
# Deploy này đầu tiên trong mỗi namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 2. Document Policies

```yaml
metadata:
  name: backend-policy
  annotations:
    description: "Allow frontend access to backend API"
    owner: "platform-team@company.com"
    last-reviewed: "2026-05-01"
```

### 3. Test trong Staging Trước

```
Workflow:
1. Apply policies trong staging namespace
2. Run integration tests
3. Verify không có connectivity issues
4. Deploy sang production
```

### 4. Monitor NetworkPolicy Changes

```bash
# Audit NetworkPolicy changes
kubectl get events --field-selector involvedObject.kind=NetworkPolicy

# Version control policies
git log -- network-policies/
```

### 5. Layer Defense

```
NetworkPolicy là một layer, không phải toàn bộ security:

Defense Layers:
1. Network Policy (K8s level)
2. Pod Security Policy / Pod Security Standards
3. RBAC (API access control)
4. Service Mesh (mTLS, advanced policies)
5. Application-level auth/authz
```

## Tóm tắt

Kubernetes Network Policies cung cấp network segmentation trong cluster:

**Core Concepts:**
- Default K8s: Allow all traffic
- NetworkPolicy: Implement deny-by-default, explicit allow
- Ingress rules: Traffic VÀO pods
- Egress rules: Traffic RA KHỎI pods

**Selectors:**
- podSelector: Target/source pods by labels
- namespaceSelector: Target/source namespaces by labels
- ipBlock: External IP ranges (CIDR)

**Best Practice:**
1. Deploy deny-all policy đầu tiên
2. Add explicit allow rules
3. Always allow DNS egress
4. Test thoroughly trong staging

**Common Use Cases:**
- Multi-tier app segmentation
- Namespace isolation
- Restrict database access
- Control external API access

**Next:** Day 84 sẽ học Helm để package và deploy K8s applications.
