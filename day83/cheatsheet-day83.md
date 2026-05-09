# Cheatsheet: Day 83 - Kubernetes Network Policies

## NetworkPolicy Resource

```bash
# Xem Network Policies
kubectl get networkpolicy
kubectl get netpol                               # short form
kubectl describe networkpolicy my-policy

# Tạo NetworkPolicy từ YAML
kubectl apply -f network-policy.yaml

# Delete NetworkPolicy
kubectl delete networkpolicy my-policy
```

## Deny-All Default Policy

```yaml
# deny-all-ingress.yaml - Block tất cả traffic vào pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}      # Áp dụng cho tất cả pods trong namespace
  policyTypes:
  - Ingress
  # Không có ingress rules → deny all
```

```yaml
# deny-all-egress.yaml - Block tất cả traffic ra ngoài
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  # Không có egress rules → deny all
```

## Allow Ingress từ specific pods

```yaml
# allow-from-frontend.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend       # Áp dụng cho backend pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend  # Chỉ cho phép từ frontend pods
    ports:
    - protocol: TCP
      port: 8080
```

## Allow Ingress từ specific namespace

```yaml
# allow-from-namespace.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring  # Cho phép từ namespace có label name=monitoring
    ports:
    - protocol: TCP
      port: 9090
```

## Allow Egress đến specific service

```yaml
# allow-egress-to-database.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mysql
    ports:
    - protocol: TCP
      port: 3306
```

## Allow DNS Resolution

```yaml
# allow-dns.yaml - Cho phép pods resolve DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## Allow External Traffic (CIDR)

```yaml
# allow-external-api.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
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
        cidr: 203.0.113.0/24     # Allow traffic đến external IP range
        except:
        - 203.0.113.10/32        # Except specific IP
    ports:
    - protocol: TCP
      port: 443
```

## Multi-tier Application Policy

```yaml
# 3-tier-app-policy.yaml
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
    - podSelector: {}           # Allow từ bất kỳ pod nào trong namespace
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend          # Chỉ gọi được backend tier
    ports:
    - protocol: TCP
      port: 8080
  - to:                          # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
---
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
          tier: frontend         # Chỉ nhận từ frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database         # Chỉ gọi được database tier
    ports:
    - protocol: TCP
      port: 5432
  - to:                          # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
---
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
          tier: backend          # Chỉ nhận từ backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:                          # Allow DNS only
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## Namespace Isolation

```yaml
# namespace-isolation.yaml - Isolate namespace khỏi traffic bên ngoài
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
    - podSelector: {}            # Chỉ allow traffic từ pods trong cùng namespace
```

## Testing Network Policies

```bash
# Test connectivity từ pod
kubectl run test-pod --image=busybox -it --rm -- sh
# Inside pod:
wget -O- http://backend-service:8080
nc -zv database-service 5432

# Test từ specific namespace
kubectl run test-pod -n staging --image=busybox -it --rm -- sh
wget -O- http://backend-service.production:8080

# Kiểm tra pod labels
kubectl get pods --show-labels

# Debug NetworkPolicy
kubectl describe networkpolicy my-policy
kubectl get networkpolicy -o yaml
```

## Label Namespaces (for namespace selector)

```bash
# Add label cho namespace để dùng với namespaceSelector
kubectl label namespace monitoring name=monitoring
kubectl label namespace production env=prod

# Xem labels của namespaces
kubectl get namespaces --show-labels
```
