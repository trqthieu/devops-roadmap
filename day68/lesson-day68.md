# 📘 Ngày 68: Namespace & RBAC

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách tổ chức resources trong Kubernetes bằng Namespaces và bảo mật cluster bằng RBAC (Role-Based Access Control). Biết cách phân quyền cho users và service accounts.

---

## Tại Sao Cần Namespace & RBAC?

### Scenario Production

```
Công ty có:
- 3 teams: Frontend, Backend, Data
- 1 Kubernetes cluster chung
- Mỗi team cần deploy apps riêng

Vấn đề nếu KHÔNG có Namespaces:
❌ Frontend team xóa nhầm Pod của Backend team
❌ Tất cả resources trộn lẫn trong 1 namespace "default"
❌ Không giới hạn resources → 1 team dùng hết RAM
❌ Không phân quyền → ai cũng có thể xóa/sửa mọi thứ

Giải pháp:
✅ Namespaces: Cách ly resources theo team
✅ RBAC: Phân quyền read/write cho từng team
✅ ResourceQuota: Giới hạn CPU/RAM mỗi namespace
```

---

## Namespace Là Gì?

**Định nghĩa:**
> Namespace là cơ chế **phân vùng logic** trong cluster, giúp tách biệt resources giữa các teams/projects.

### Namespace Mặc Định

```
┌─────────────────────────────────────────────────┐
│            KUBERNETES CLUSTER                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  default    │  │ kube-system │  │kube-    │ │
│  │             │  │             │  │public   │ │
│  │  User apps  │  │  Control    │  │         │ │
│  │  (nếu không │  │  Plane pods │  │ConfigMap│ │
│  │  chỉ định)  │  │  (API, etcd)│  │public   │ │
│  └─────────────┘  └─────────────┘  └─────────┘ │
│                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  dev        │  │  staging    │  │  prod   │ │
│  │             │  │             │  │         │ │
│  │  Frontend   │  │  Testing    │  │ Live    │ │
│  │  Backend    │  │  env        │  │ apps    │ │
│  │  Database   │  │             │  │         │ │
│  └─────────────┘  └─────────────┘  └─────────┘ │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Built-in Namespaces:**

1. **default:**
   - Namespace mặc định khi không chỉ định
   - User apps chạy ở đây nếu không có `-n`

2. **kube-system:**
   - Control Plane components
   - API Server, Scheduler, Controller Manager
   - **KHÔNG deploy user apps vào đây**

3. **kube-public:**
   - Resources public, accessible cho tất cả users
   - ConfigMaps, cluster info

4. **kube-node-lease:**
   - Node heartbeats (health checks)
   - Giúp Control Plane detect node failures nhanh

### Khi Nào Dùng Namespace?

**Nên dùng:**
- ✅ Nhiều teams dùng chung cluster
- ✅ Tách dev/staging/prod environments
- ✅ Cần áp ResourceQuota khác nhau
- ✅ Phân quyền RBAC theo team

**Không cần:**
- ❌ Cluster nhỏ, 1 team
- ❌ Chỉ có vài apps đơn giản

---

## RBAC Là Gì?

**Định nghĩa:**
> RBAC (Role-Based Access Control) là cơ chế **phân quyền** dựa trên vai trò, kiểm soát ai có thể làm gì trong cluster.

### RBAC Components

```
┌──────────────────────────────────────────────┐
│              RBAC MODEL                      │
├──────────────────────────────────────────────┤
│                                              │
│  WHO (Subject)        WHAT (Role)            │
│  ┌─────────────┐     ┌──────────────┐       │
│  │   User      │     │    Role      │       │
│  │   Group     │◄────│  (Permissions│       │
│  │ServiceAccount     │   - get pods │       │
│  └─────────────┘     │   - create   │       │
│                      │     deploy)  │       │
│                      └──────────────┘       │
│         ▲                    ▲              │
│         │                    │              │
│         └────────────────────┘              │
│            RoleBinding                      │
│         (Kết nối WHO + WHAT)                │
└──────────────────────────────────────────────┘
```

**4 RBAC Objects:**

1. **Role:** Permissions trong 1 namespace
2. **ClusterRole:** Permissions toàn cluster
3. **RoleBinding:** Gán Role cho user/SA trong namespace
4. **ClusterRoleBinding:** Gán ClusterRole cho user/SA toàn cluster

---

## Service Account

**Định nghĩa:**
> Service Account là "user" cho applications chạy trong Pod, dùng để gọi Kubernetes API.

### Tại Sao Cần Service Account?

**Scenario:**
```
Pod Jenkins cần:
- List tất cả Pods trong namespace "dev"
- Tạo Deployments mới (CI/CD)
- Xem logs của Pods

→ Pod cần credentials để gọi API Server
→ Dùng Service Account (không dùng user account)
```

### Service Account Workflow

```
1. Tạo Service Account
         │
         ▼
2. Tạo Role với permissions
         │
         ▼
3. RoleBinding: Gán Role cho SA
         │
         ▼
4. Pod sử dụng SA
         │
         ▼
5. Pod gọi API Server
         │
         ▼
6. API Server kiểm tra permissions của SA
         │
         ▼
7. Cho phép/Từ chối request
```

**Ví dụ:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: dev
---
# Pod sử dụng SA này
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-pod
  namespace: dev
spec:
  serviceAccountName: jenkins  # ← Dùng SA "jenkins"
  containers:
  - name: jenkins
    image: jenkins/jenkins
```

**Mỗi Pod tự động có SA:**
- Nếu không chỉ định → dùng SA "default"
- Token của SA được mount vào `/var/run/secrets/kubernetes.io/serviceaccount/token`

---

## Role vs ClusterRole

### Role (Namespace-Scoped)

**Chỉ có quyền trong 1 namespace**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev        # ← Chỉ trong namespace "dev"
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]  # ← Chỉ đọc, không sửa/xóa
```

**Verbs (actions):**
- `get`: Xem 1 resource cụ thể
- `list`: List tất cả resources
- `watch`: Theo dõi thay đổi real-time
- `create`: Tạo mới
- `update`: Sửa
- `patch`: Sửa 1 phần
- `delete`: Xóa

### ClusterRole (Cluster-Wide)

**Có quyền toàn cluster hoặc non-namespaced resources**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader  # ← Không có namespace
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

**Khi nào dùng ClusterRole:**
- Resources không có namespace: Nodes, PersistentVolumes, Namespaces
- Cần quyền trên tất cả namespaces
- Cluster-level operations

**Built-in ClusterRoles:**
- `cluster-admin`: Full quyền (như root)
- `admin`: Quản lý resources trong namespace
- `edit`: Sửa/tạo resources (không sửa RBAC)
- `view`: Chỉ đọc

---

## RoleBinding vs ClusterRoleBinding

### RoleBinding

**Gán Role (hoặc ClusterRole) cho user/SA trong 1 namespace**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: dev
subjects:
- kind: ServiceAccount
  name: jenkins        # ← SA "jenkins"
  namespace: dev
roleRef:
  kind: Role
  name: pod-reader     # ← Role "pod-reader"
  apiGroup: rbac.authorization.k8s.io
```

**Kết quả:** SA "jenkins" trong namespace "dev" có quyền get/list/watch pods trong namespace "dev"

### ClusterRoleBinding

**Gán ClusterRole cho user/SA toàn cluster**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: dev
roleRef:
  kind: ClusterRole
  name: cluster-admin  # ← Full quyền
  apiGroup: rbac.authorization.k8s.io
```

**Kết quả:** SA "jenkins" có full quyền trên toàn cluster

---

## Workflow Thực Tế: Phân Quyền Cho Team

### Scenario: Frontend Team

**Yêu cầu:**
- Team có namespace riêng: `frontend`
- Chỉ được quản lý Pods, Deployments, Services trong namespace
- Không được xóa namespace
- Không được sửa RBAC

**Các bước:**

```
1. Tạo Namespace
         │
         ▼
2. Tạo Service Account cho team
         │
         ▼
3. Tạo Role với permissions giới hạn
         │
         ▼
4. RoleBinding: Gán Role cho SA
         │
         ▼
5. Team dùng SA này để deploy
```

**Implementation:**

```yaml
# 1. Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: frontend

---
# 2. Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-team
  namespace: frontend

---
# 3. Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: frontend-developer
  namespace: frontend
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]  # ← Xem logs

---
# 4. RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frontend-team-binding
  namespace: frontend
subjects:
- kind: ServiceAccount
  name: frontend-team
  namespace: frontend
roleRef:
  kind: Role
  name: frontend-developer
  apiGroup: rbac.authorization.k8s.io
```

**Test permissions:**

```bash
# Kiểm tra quyền của SA
kubectl auth can-i create deployments \
  --as=system:serviceaccount:frontend:frontend-team \
  -n frontend
# Output: yes

kubectl auth can-i delete namespace \
  --as=system:serviceaccount:frontend:frontend-team \
  -n frontend
# Output: no
```

---

## Namespace Isolation Best Practices

### 1. Tổ Chức Theo Environment

```
dev/          ← Development
staging/      ← Testing
prod/         ← Production
```

**Lợi ích:**
- Tách biệt rõ ràng
- ResourceQuota khác nhau (prod nhiều RAM hơn)
- RBAC: Dev chỉ có quyền trong `dev`, không vào `prod`

### 2. Tổ Chức Theo Team

```
frontend/
backend/
data/
ops/
```

**Lợi ích:**
- Mỗi team quản lý namespace riêng
- Giảm conflicts khi deploy

### 3. Tổ Chức Theo Project

```
project-a/
project-b/
shared-services/  ← Monitoring, logging chung
```

---

## 🚨 Troubleshooting

### Lỗi: Forbidden (403)

**Triệu chứng:**
```bash
kubectl get pods
# Error: pods is forbidden: User "jenkins" cannot list resource "pods"
```

**Nguyên nhân:** Thiếu quyền

**Debug:**
```bash
# Kiểm tra permissions
kubectl auth can-i list pods --as=jenkins

# Xem SA hiện tại
kubectl get sa

# Xem RoleBindings
kubectl get rolebindings
kubectl describe rolebinding <name>
```

**Fix:** Tạo Role + RoleBinding

### Pod không thể gọi API Server

**Triệu chứng:**
```
Application logs: "Unauthorized: ServiceAccount token is invalid"
```

**Debug:**
```bash
# Kiểm tra SA của Pod
kubectl get pod <pod-name> -o yaml | grep serviceAccount

# Xem token có được mount không
kubectl exec <pod-name> -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```

**Fix:** Gán đúng SA trong Pod spec

### RoleBinding không hoạt động

**Triệu chứng:** SA vẫn không có quyền sau khi tạo RoleBinding

**Debug:**
```bash
# Xem chi tiết binding
kubectl describe rolebinding <name>

# Kiểm tra Role có đúng không
kubectl describe role <role-name>
```

**Nguyên nhân thường gặp:**
- `roleRef` trỏ sai Role
- `subjects` trỏ sai SA/namespace
- RoleBinding và SA khác namespace

---

## 🎓 Tóm Tắt Ngày 68

✅ **Namespace** tách biệt resources giữa teams/environments
✅ **Service Account** là identity cho Pods khi gọi API
✅ **Role** định nghĩa permissions trong namespace
✅ **ClusterRole** định nghĩa permissions toàn cluster
✅ **RoleBinding** gán Role cho user/SA trong namespace
✅ **ClusterRoleBinding** gán ClusterRole toàn cluster
✅ Dùng `kubectl auth can-i` để test permissions

**Kỹ năng đạt được:**
- Tạo và quản lý Namespaces
- Tạo Service Accounts cho applications
- Phân quyền RBAC cho teams
- Test permissions với `kubectl auth can-i`
- Debug lỗi forbidden/unauthorized
