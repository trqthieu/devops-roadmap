# 📘 Ngày 66: ConfigMap & Secret

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách quản lý configuration và sensitive data trong Kubernetes bằng ConfigMap và Secret, cách inject vào Pods qua environment variables hoặc volumes, và best practices về security.

---

## Tại Sao Cần ConfigMap & Secret?

### Vấn Đề Với Hardcoded Config

**Bad practice:**

```yaml
# app-deployment.yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: DATABASE_URL
      value: "postgres://user:password@db.prod.com:5432/mydb"  # ❌ Hardcoded
    - name: API_KEY
      value: "sk_live_12345abcdef"  # ❌ Secret trong code
```

**Vấn đề:**
- ❌ Thay config → phải rebuild image
- ❌ Secrets trong YAML → push lên Git → lộ credentials
- ❌ Dev/staging/prod dùng cùng image → không thay được config
- ❌ Rotate password → phải edit deployment.yaml

### Giải Pháp: Externalize Configuration

**ConfigMap:** Non-sensitive configuration (URLs, feature flags, configs)
**Secret:** Sensitive data (passwords, API keys, certificates)

```
┌────────────────────────────────────────┐
│          Application Image             │
│          (myapp:1.0)                   │
│                                        │
│  Code KHÔNG chứa config                │
│  Code đọc từ env vars / files          │
└────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌──────────────┐      ┌──────────────┐
│  ConfigMap   │      │    Secret    │
│              │      │              │
│ DATABASE_URL │      │  DB_PASSWORD │
│ CACHE_SIZE   │      │  API_KEY     │
│ LOG_LEVEL    │      │  TLS_CERT    │
└──────────────┘      └──────────────┘

→ Same image, different environments
   (dev ConfigMap vs prod ConfigMap)
```

**Lợi ích:**
- ✅ 1 image cho tất cả môi trường
- ✅ Thay config không cần rebuild
- ✅ Secrets không bao giờ ở trong code
- ✅ Rotate credentials dễ dàng

---

## ConfigMap: Quản Lý Configuration

**Định nghĩa:**
> ConfigMap lưu trữ configuration data dạng key-value, inject vào Pods qua env vars hoặc files.

### Tạo ConfigMap

**Từ literal values:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_URL: "postgres://db.example.com:5432/mydb"
  CACHE_SIZE: "1024"
  LOG_LEVEL: "info"
  FEATURE_FLAG_NEW_UI: "true"
```

**Từ file:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
      listen 80;
      location / {
        proxy_pass http://backend:3000;
      }
    }
```

**Từ directory (imperative):**
```bash
# Tạo ConfigMap từ tất cả files trong configs/
kubectl create configmap app-config --from-file=configs/
```

---

## Secret: Quản Lý Sensitive Data

**Định nghĩa:**
> Secret lưu trữ sensitive data (passwords, tokens, keys) được encode base64, có access control tốt hơn ConfigMap.

### Tạo Secret

**Opaque Secret (generic):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  # Data phải encode base64
  username: YWRtaW4=           # "admin" base64
  password: cGFzc3dvcmQxMjM=   # "password123" base64
```

**Encode base64:**
```bash
echo -n "admin" | base64
# Output: YWRtaW4=
```

**stringData (auto-encode):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  # K8s tự động encode base64
  username: admin
  password: password123
```

### Các Loại Secret

**1. Opaque (default):**
```yaml
type: Opaque
# Generic key-value secrets
```

**2. TLS Certificate:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

**3. Docker registry credentials:**
```yaml
type: kubernetes.io/dockerconfigjson
# Dùng để pull private images
```

**4. Service Account token:**
```yaml
type: kubernetes.io/service-account-token
# Auto-generated, mount vào Pod để gọi K8s API
```

---

## Inject ConfigMap/Secret Vào Pod

### Method 1: Environment Variables

**Inject toàn bộ ConfigMap:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    envFrom:
    - configMapRef:
        name: app-config  # Tất cả keys → env vars
```

**Workflow:**
```
ConfigMap: app-config
  DATABASE_URL: postgres://...
  LOG_LEVEL: info
         │
         ▼
Container env vars:
  DATABASE_URL=postgres://...
  LOG_LEVEL=info
```

**Inject specific keys:**

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: DB_HOST              # Env var name
      valueFrom:
        configMapKeyRef:
          name: app-config       # ConfigMap name
          key: DATABASE_URL      # Key trong ConfigMap
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret        # Secret name
          key: password          # Key trong Secret
```

**Workflow:**
```
ConfigMap: app-config
  DATABASE_URL: postgres://db:5432

Secret: db-secret
  password: abc123
         │
         ▼
Container env vars:
  DB_HOST=postgres://db:5432
  DB_PASSWORD=abc123
```

---

### Method 2: Volume Mounts (Files)

**Mount ConfigMap as files:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d  # Mount path trong container
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config  # ConfigMap name
```

**Workflow:**
```
ConfigMap: nginx-config
  nginx.conf: |
    server {
      listen 80;
      ...
    }
         │
         ▼
Container filesystem:
  /etc/nginx/conf.d/nginx.conf
  (chứa nội dung từ ConfigMap)
```

**Mount Secret as files:**

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true  # Secret luôn nên read-only
  volumes:
  - name: tls-certs
    secret:
      secretName: tls-secret
```

**Filesystem:**
```
/etc/tls/
  tls.crt  (decoded từ base64)
  tls.key  (decoded từ base64, permission 0400)
```

---

### Method 3: Subpath (Specific Files)

**Mount only specific keys:**

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config-volume
      mountPath: /app/config.json
      subPath: config.json  # Chỉ mount file này
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
      - key: app-config-json  # Key trong ConfigMap
        path: config.json     # Filename trong container
```

**Use case:** Không muốn overwrite toàn bộ directory, chỉ mount 1 file cụ thể.

---

## Update ConfigMap/Secret

### ConfigMap Update → Pod Restart?

**Volume mount:** Auto-update (sau ~60s)
```yaml
volumeMounts:
- name: config
  mountPath: /etc/config

# ConfigMap update → file trong Pod tự động thay đổi
# App phải reload config (không tự restart)
```

**Env vars:** KHÔNG auto-update
```yaml
env:
- name: CONFIG
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: value

# ConfigMap update → env var KHÔNG đổi
# Phải restart Pod để áp dụng
```

**Force Pod restart sau khi update ConfigMap:**
```bash
# Update ConfigMap
kubectl apply -f configmap.yaml

# Restart Pods (rollout deployment)
kubectl rollout restart deployment/myapp
```

---

## Workflow Thực Tế: Multi-Environment Setup

**Scenario:** App chạy trên dev, staging, prod với configs khác nhau.

### Setup

**ConfigMap cho mỗi environment:**

```yaml
# dev-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: dev
data:
  DATABASE_URL: "postgres://db.dev.local:5432/mydb"
  LOG_LEVEL: "debug"
---
# prod-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: prod
data:
  DATABASE_URL: "postgres://db.prod.com:5432/mydb"
  LOG_LEVEL: "error"
```

**Secret cho mỗi environment:**

```yaml
# dev-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: dev
stringData:
  password: "dev_password"
---
# prod-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: prod
stringData:
  password: "super_secure_prod_password"
```

**Deployment (SAME for all envs):**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:1.0  # SAME image
        envFrom:
        - configMapRef:
            name: app-config  # Tên giống nhau
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret  # Tên giống nhau
              key: password
```

**Deploy:**
```bash
# Dev
kubectl apply -f dev-config.yaml -f dev-secret.yaml
kubectl apply -f deployment.yaml -n dev

# Prod
kubectl apply -f prod-config.yaml -f prod-secret.yaml
kubectl apply -f deployment.yaml -n prod
```

**Result:**
```
Dev namespace:
  App image: myapp:1.0
  DATABASE_URL: postgres://db.dev.local:5432/mydb
  DB_PASSWORD: dev_password

Prod namespace:
  App image: myapp:1.0  (SAME!)
  DATABASE_URL: postgres://db.prod.com:5432/mydb
  DB_PASSWORD: super_secure_prod_password
```

---

## Best Practices: Security

### 1. Secret Không An Toàn Như Bạn Nghĩ

**Thực tế:**
- Secret chỉ encode base64 (KHÔNG encrypt)
- Bất kỳ ai có quyền `get secret` → đọc được plaintext
- Secret lưu trong etcd (nếu etcd không encrypt at rest → rò rỉ)

**Decode Secret:**
```bash
kubectl get secret db-secret -o yaml
# data:
#   password: cGFzc3dvcmQxMjM=

echo "cGFzc3dvcmQxMjM=" | base64 -d
# Output: password123
```

### 2. RBAC - Giới Hạn Access

**Không cho phép users đọc Secrets:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]  # Được đọc ConfigMaps
- apiGroups: [""]
  resources: ["secrets"]
  verbs: []  # KHÔNG được đọc Secrets
```

### 3. Encrypt Secrets at Rest

**Enable etcd encryption (cluster admin):**

```yaml
# encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-key>
  - identity: {}
```

→ Secrets trong etcd được encrypt

### 4. External Secret Managers

**Thay vì Kubernetes Secrets, dùng:**

**AWS Secrets Manager:**
```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: db-secret
  data:
  - secretKey: password
    remoteRef:
      key: prod/db/password
```

**HashiCorp Vault:**
- Centralized secret storage
- Dynamic secrets
- Audit logs
- Encryption

**Google Secret Manager, Azure Key Vault:** Tương tự

→ K8s Secrets chỉ là cache, source of truth ở external system

### 5. Immutable ConfigMaps/Secrets

**Prevent accidental changes:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
immutable: true  # Không thể edit, chỉ có thể delete và tạo lại
data:
  DATABASE_URL: "postgres://..."
```

**Lợi ích:**
- Tránh config drift
- ConfigMap change = new version (Git history rõ ràng)

### 6. Không Log Secrets

**Bad practice:**
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password

# App code
console.log(process.env)  # ❌ Log toàn bộ env → lộ password
```

**Good practice:**
```javascript
// Chỉ log non-sensitive env vars
const sensitiveKeys = ['DB_PASSWORD', 'API_KEY'];
const safeEnv = Object.keys(process.env)
  .filter(k => !sensitiveKeys.includes(k))
  .reduce((obj, k) => ({ ...obj, [k]: process.env[k] }), {});
console.log(safeEnv);
```

---

## 🚨 Troubleshooting

### Pod không start: ConfigMap not found

**Triệu chứng:**
```bash
kubectl get pods
# NAME    STATUS                RESTARTS
# app     CreateContainerConfigError  0
```

**Debug:**
```bash
kubectl describe pod app

# Events:
# Warning  Failed  kubelet  Error: configmap "app-config" not found
```

**Fix:**
```bash
# Tạo ConfigMap trước Pod
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
```

### Env var không được set

**Triệu chứng:**
```bash
kubectl exec -it app -- env | grep DATABASE_URL
# (no output)
```

**Debug checklist:**

```bash
# 1. ConfigMap có đúng key không?
kubectl get configmap app-config -o yaml
# data:
#   DATABASE_URL: postgres://...  ✅

# 2. Pod spec có reference đúng key không?
kubectl get pod app -o yaml | grep -A 10 env:
# env:
# - name: DB_URL  ❌ Tên sai!
#   valueFrom:
#     configMapKeyRef:
#       key: DATABASE_URL  # Key đúng nhưng env name sai

# Fix: Sửa env name thành DATABASE_URL
```

### Secret không decrypt

**Triệu chứng:**
```bash
# Trong Pod
cat /etc/secrets/password
# cGFzc3dvcmQxMjM=  ❌ Vẫn còn base64
```

**Nguyên nhân:** Mount sai cách

**Fix:**
```yaml
# Dùng secret volume (auto-decode)
volumes:
- name: secret-volume
  secret:
    secretName: db-secret  # Tự động decode

# KHÔNG dùng configMap cho secret
volumes:
- name: secret-volume
  configMap:  # ❌ ConfigMap không decode base64
    name: db-secret
```

---

## 🎓 Tóm Tắt Ngày 66

✅ **ConfigMap** lưu non-sensitive config, **Secret** lưu sensitive data
✅ **Inject vào Pod** qua env vars (không auto-update) hoặc volumes (auto-update sau ~60s)
✅ **Secret chỉ encode base64**, không phải encryption thực sự
✅ **RBAC** để giới hạn ai được đọc Secrets
✅ **Best practice:** Dùng external secret managers (Vault, AWS Secrets Manager) cho production
✅ **Immutable ConfigMaps** để tránh accidental changes
✅ **Multi-environment:** Same image, different ConfigMaps/Secrets per namespace

**Kỹ năng đạt được:**
- Tạo và quản lý ConfigMaps/Secrets
- Inject config vào Pods bằng env vars và volumes
- Setup multi-environment configs (dev/staging/prod)
- Hiểu security limitations của K8s Secrets
- Apply best practices để bảo vệ sensitive data
