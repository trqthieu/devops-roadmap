# Cheatsheet: Day 82 - Kubernetes Ingress

## Ingress Resource

```bash
# Xem các Ingress resources
kubectl get ingress
kubectl get ingress -A                           # tất cả namespaces
kubectl describe ingress my-ingress

# Tạo Ingress từ YAML
kubectl apply -f ingress.yaml

# Xem IngressClass
kubectl get ingressclass
kubectl describe ingressclass nginx
```

## Nginx Ingress Controller

```bash
# Cài Nginx Ingress Controller (Helm)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx

# Kiểm tra Ingress Controller pods
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller

# Xem service của Ingress Controller
kubectl get svc -n ingress-nginx
```

## Path-based Routing YAML

```yaml
# ingress-path-based.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

## Host-based Routing YAML

```yaml
# ingress-host-based.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

## TLS/SSL cho Ingress

```yaml
# ingress-tls.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

```bash
# Tạo TLS Secret từ cert files
kubectl create secret tls myapp-tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

## Ingress Annotations

```yaml
# Common annotations
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## Debugging Ingress

```bash
# Kiểm tra Ingress configuration
kubectl describe ingress my-ingress

# Xem logs của Ingress Controller
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller --tail=100 -f

# Kiểm tra backend services
kubectl get endpoints

# Test connectivity từ pod
kubectl run test --image=curlimages/curl -it --rm -- curl http://myapp-service
```

## Default Backend

```yaml
# default-backend.yaml
apiVersion: v1
kind: Service
metadata:
  name: default-backend
spec:
  selector:
    app: default-backend
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-with-default
spec:
  ingressClassName: nginx
  defaultBackend:
    service:
      name: default-backend
      port:
        number: 80
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

## Kiểm tra Ingress Rules

```bash
# Xem chi tiết rules
kubectl get ingress my-ingress -o yaml

# Test DNS resolution
nslookup myapp.example.com

# Test từ local (với port-forward hoặc LoadBalancer IP)
curl -H "Host: myapp.example.com" http://EXTERNAL_IP/
```
