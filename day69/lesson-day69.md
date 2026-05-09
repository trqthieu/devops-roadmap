# 📘 Ngày 69: Persistent Storage

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách lưu trữ dữ liệu lâu dài trong Kubernetes với PersistentVolume (PV), PersistentVolumeClaim (PVC), và StorageClass. Biết cách triển khai stateful applications như databases.

---

## Tại Sao Cần Persistent Storage?

### Vấn Đề Với Container Storage

**Container storage mặc định là ephemeral (tạm thời):**

```
1. Container chạy → ghi data vào filesystem
         │
         ▼
2. Container crash/restart
         │
         ▼
3. Data bị mất ❌

Ví dụ:
- MySQL container restart → database rỗng
- Logs container restart → logs biến mất
```

**Scenario thực tế:**
```
Database Pod crash
→ Pod được recreate trên Node khác
→ Data trên Node cũ không có trên Node mới
→ Database rỗng, users không login được ❌
```

**Giải pháp:** Persistent Storage

```
Database Pod ────► PersistentVolume (external storage)
                   │
Pod crash          │
                   │ Data vẫn còn ✅
Pod recreate ──────┘
(kết nối lại PV)
```

---

## Kubernetes Storage Architecture

```
┌─────────────────────────────────────────────────┐
│              APPLICATION LAYER                  │
│  ┌──────────────────────────────────────┐       │
│  │  Pod                                 │       │
│  │  ┌────────────┐                      │       │
│  │  │ Container  │                      │       │
│  │  │ /data ◄────┼──── VolumeMount      │       │
│  │  └────────────┘                      │       │
│  └───────────────────┬──────────────────┘       │
└────────────────────────┼────────────────────────┘
                        │
┌────────────────────────▼────────────────────────┐
│         KUBERNETES ABSTRACTION LAYER            │
│  ┌─────────────────────────────────────┐        │
│  │  PersistentVolumeClaim (PVC)        │        │
│  │  "Tôi cần 10GB storage"             │        │
│  └──────────────┬──────────────────────┘        │
│                 │ Binding                       │
│  ┌──────────────▼──────────────────────┐        │
│  │  PersistentVolume (PV)              │        │
│  │  "Đây là 10GB storage thực"         │        │
│  └──────────────┬──────────────────────┘        │
└──────────────────┼──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│           PHYSICAL STORAGE LAYER                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │   NFS    │  │   AWS    │  │  Local   │      │
│  │  Server  │  │   EBS    │  │   Disk   │      │
│  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────────────────────────────┘
```

**3 Layers:**

1. **Application Layer:** Pod mount volume vào container
2. **Abstraction Layer:** PVC/PV quản lý storage logic
3. **Physical Layer:** Storage backend thực (AWS EBS, NFS, local disk)

---

## PersistentVolume (PV)

**Định nghĩa:**
> PV là **storage resource** trong cluster, được admin provisioning sẵn hoặc tạo động qua StorageClass.

### Đặc Điểm

- **Cluster-scoped:** Không thuộc namespace nào
- **Độc lập với Pod:** PV tồn tại khi Pod chết
- **Backed by physical storage:** NFS, iSCSI, cloud storage (EBS, Azure Disk)

### PV Lifecycle

```
┌──────────────┐
│  Available   │  ← PV vừa tạo, chưa bind với PVC
└──────┬───────┘
       │
       │ PVC request
       ▼
┌──────────────┐
│    Bound     │  ← PV đã bind với PVC
└──────┬───────┘
       │
       │ PVC deleted
       ▼
┌──────────────┐
│  Released    │  ← PV chưa xóa nhưng không dùng được (còn data cũ)
└──────┬───────┘
       │
       │ Reclaim policy
       ▼
┌──────────────┐  ┌──────────────┐
│   Deleted    │  │   Recycled   │
│  (nếu Delete)│  │(nếu Recycle) │
└──────────────┘  └──────────────┘
```

### Access Modes

**Chế độ truy cập:**

1. **ReadWriteOnce (RWO):**
   - Volume mount bởi **1 Node** ở chế độ read-write
   - Nhiều Pods trên cùng Node có thể dùng
   - Use case: Database (1 Pod)

2. **ReadOnlyMany (ROX):**
   - Volume mount bởi **nhiều Nodes** ở chế độ read-only
   - Use case: Static content, shared config

3. **ReadWriteMany (RWX):**
   - Volume mount bởi **nhiều Nodes** ở chế độ read-write
   - Use case: Shared storage (NFS)
   - **Không phải storage nào cũng hỗ trợ**

**Lưu ý:**
- AWS EBS: Chỉ hỗ trợ RWO
- NFS: Hỗ trợ RWO, ROX, RWX
- Azure Disk: Chỉ RWO

### Reclaim Policy

**Khi PVC bị xóa, PV sẽ:**

1. **Retain:**
   - PV vẫn tồn tại, data vẫn còn
   - Admin phải xóa thủ công
   - **Production:** Dùng Retain để tránh mất data

2. **Delete:**
   - PV và storage backend đều bị xóa
   - Use case: Dynamic provisioning

3. **Recycle (deprecated):**
   - Xóa data (`rm -rf`) và PV quay về Available
   - Không nên dùng

### Ví Dụ PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 10Gi           # ← Dung lượng
  accessModes:
    - ReadWriteOnce         # ← Chỉ 1 Node
  persistentVolumeReclaimPolicy: Retain  # ← Giữ data khi PVC xóa
  storageClassName: manual  # ← Storage class (hoặc "" nếu không dùng)
  hostPath:                 # ← Backend type (local disk)
    path: "/mnt/data/mysql"
```

**Backend types:**
- `hostPath`: Local disk (chỉ dùng dev, single-node)
- `nfs`: NFS server
- `awsElasticBlockStore`: AWS EBS
- `azureDisk`: Azure Disk
- `gcePersistentDisk`: GCP Persistent Disk

---

## PersistentVolumeClaim (PVC)

**Định nghĩa:**
> PVC là **request** từ user/Pod xin storage với capacity và access mode cụ thể.

### Đặc Điểm

- **Namespace-scoped:** Thuộc 1 namespace
- **Abstract:** User không cần biết storage backend
- **Binding:** Kubernetes tự động tìm PV phù hợp

### PVC Workflow

```
1. User tạo PVC: "Tôi cần 5GB, RWO"
         │
         ▼
2. Kubernetes tìm PV:
   - Capacity >= 5GB
   - Access mode = RWO
   - StorageClass match (hoặc none)
         │
         ▼
3. Bind PVC với PV
         │
         ▼
4. Pod dùng PVC trong volumeMounts
```

### Ví Dụ PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce       # ← Must match PV
  resources:
    requests:
      storage: 8Gi        # ← PV phải >= 8Gi
  storageClassName: manual  # ← Match PV's storageClassName
```

**Binding rules:**
- `accessModes`: Phải match PV
- `storage`: PV phải >= PVC request
- `storageClassName`: Phải match (hoặc cả 2 đều "")

### Pod Sử Dụng PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-pod
spec:
  containers:
  - name: mysql
    image: mysql:8.0
    volumeMounts:
    - name: mysql-storage  # ← Tên volume
      mountPath: /var/lib/mysql  # ← Mount vào đâu trong container
  volumes:
  - name: mysql-storage
    persistentVolumeClaim:
      claimName: mysql-pvc  # ← Dùng PVC nào
```

**Workflow:**
```
Container /var/lib/mysql
    ↓
Volume "mysql-storage"
    ↓
PVC "mysql-pvc"
    ↓
PV "mysql-pv"
    ↓
Physical disk /mnt/data/mysql
```

---

## StorageClass

**Định nghĩa:**
> StorageClass cho phép **dynamic provisioning** — tự động tạo PV khi có PVC request.

### Static vs Dynamic Provisioning

**Static Provisioning (thủ công):**
```
1. Admin tạo PV trước
         │
         ▼
2. User tạo PVC
         │
         ▼
3. Kubernetes bind PVC với PV có sẵn
```

**Dynamic Provisioning (tự động):**
```
1. User tạo PVC với storageClassName
         │
         ▼
2. StorageClass tự động tạo PV
         │
         ▼
3. Bind PVC với PV vừa tạo
```

### Ví Dụ StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs  # ← Storage backend
parameters:
  type: gp3              # ← AWS EBS type (gp3 = SSD)
  iopsPerGB: "10"
  fsType: ext4
reclaimPolicy: Delete    # ← Xóa PV khi PVC deleted
allowVolumeExpansion: true  # ← Cho phép resize
volumeBindingMode: WaitForFirstConsumer  # ← Chỉ tạo PV khi Pod scheduled
```

**Provisioners:**
- `kubernetes.io/aws-ebs`: AWS EBS
- `kubernetes.io/azure-disk`: Azure Disk
- `kubernetes.io/gce-pd`: GCP Persistent Disk
- `kubernetes.io/no-provisioner`: Local volumes (no dynamic)

### PVC Với StorageClass

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc-dynamic
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast-ssd  # ← StorageClass tự tạo PV 20Gi
```

**Kết quả:**
- StorageClass gọi AWS API → tạo EBS volume 20GB
- Tạo PV object trong K8s → bind với PVC

---

## Stateful Applications Example: MySQL

### Deployment Hoàn Chỉnh

```yaml
# 1. StorageClass (nếu cluster chưa có)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer

---
# 2. PersistentVolume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: "/mnt/data/mysql"

---
# 3. PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage

---
# 4. Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1  # ← Database chỉ 1 replica (RWO)
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password123"
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql  # ← MySQL data directory
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc

---
# 5. Service
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  clusterIP: None  # ← Headless service (cho StatefulSet tốt hơn)
```

### Test Persistence

```bash
# 1. Tạo database
kubectl exec -it mysql-<pod-id> -- mysql -u root -ppassword123
mysql> CREATE DATABASE testdb;
mysql> USE testdb;
mysql> CREATE TABLE users (id INT, name VARCHAR(50));
mysql> INSERT INTO users VALUES (1, 'Alice');
mysql> SELECT * FROM users;
mysql> exit;

# 2. Xóa Pod
kubectl delete pod mysql-<pod-id>

# 3. Đợi Pod mới tạo
kubectl get pods --watch

# 4. Kiểm tra data vẫn còn
kubectl exec -it mysql-<new-pod-id> -- mysql -u root -ppassword123
mysql> USE testdb;
mysql> SELECT * FROM users;  # ← Data vẫn còn ✅
```

---

## 🚨 Troubleshooting

### PVC Stuck ở Pending

**Triệu chứng:**
```bash
kubectl get pvc
# NAME        STATUS    VOLUME   CAPACITY   ACCESS MODES
# mysql-pvc   Pending
```

**Nguyên nhân:**

1. **Không có PV phù hợp:**
   - Không đủ capacity
   - Access mode không match
   - StorageClass không match

2. **StorageClass không tồn tại:**
   ```bash
   kubectl get sc
   # No resources found
   ```

**Debug:**
```bash
kubectl describe pvc mysql-pvc
# Events:
#   Warning  ProvisioningFailed  no volume plugin matched
```

**Fix:**
- Tạo PV với capacity >= PVC request
- Kiểm tra `storageClassName` match
- Kiểm tra `accessModes` match

### Pod Không Mount Volume

**Triệu chứng:**
```bash
kubectl describe pod mysql-<id>
# Events:
#   Warning  FailedMount  MountVolume.SetUp failed: mount failed
```

**Nguyên nhân:**
- Volume backend không accessible (NFS server down)
- Node không có quyền access storage
- Volume đang được mount bởi Node khác (RWO)

**Fix:**
```bash
# Kiểm tra PV status
kubectl get pv
# NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS
# mysql-pv   10Gi       RWO            Retain           Bound

# Xem chi tiết
kubectl describe pv mysql-pv
```

### PV Không Xóa Được

**Triệu chứng:**
```bash
kubectl delete pv mysql-pv
# PV stuck in Terminating state
```

**Nguyên nhân:** PV vẫn bound với PVC

**Fix:**
```bash
# 1. Xóa PVC trước
kubectl delete pvc mysql-pvc

# 2. Xóa PV
kubectl delete pv mysql-pv

# Hoặc force delete
kubectl patch pv mysql-pv -p '{"metadata":{"finalizers":null}}'
```

---

## 🎓 Tóm Tắt Ngày 69

✅ **PersistentVolume (PV)** là storage resource, cluster-wide
✅ **PersistentVolumeClaim (PVC)** là request storage từ Pod
✅ **StorageClass** cho phép dynamic provisioning (tự tạo PV)
✅ **Access Modes:** RWO (1 node), ROX (nhiều node read-only), RWX (nhiều node read-write)
✅ **Reclaim Policy:** Retain (giữ data), Delete (xóa PV)
✅ Stateful apps (database) cần persistent storage

**Kỹ năng đạt được:**
- Tạo PV/PVC cho stateful applications
- Sử dụng StorageClass cho dynamic provisioning
- Mount volumes vào Pods
- Test data persistence khi Pod restart
- Debug lỗi PVC pending/mount failed
