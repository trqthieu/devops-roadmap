# 📘 Ngày 73: Health Checks

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu cách Kubernetes kiểm tra health của containers với Liveness, Readiness, và Startup Probes. Biết khi nào dùng probe nào và cách configure probe types (HTTP, TCP, Exec).

---

## Tại Sao Cần Health Checks?

### Vấn Đề Khi Không Có Probes

**Scenario 1: Container chạy nhưng app deadlock**
```
Container status: Running ✅
Process: PID 1 đang chạy ✅
Nhưng:
- App bị deadlock (thread stuck)
- Không xử lý requests được
- Users thấy timeout ❌

Kubernetes KHÔNG biết → không restart container
```

**Scenario 2: App cần thời gian startup**
```
Container start
→ Load config (5s)
→ Connect database (10s)
→ Warm up cache (15s)
→ Ready nhận traffic (30s total)

Không có probe:
- Kubernetes gửi traffic ngay sau container start
- App chưa ready → requests fail ❌
```

**Scenario 3: App tạm thời không healthy**
```
App đang:
- Reconnecting database (5s)
- Running migration (30s)
- Full GC (garbage collection)

Không có probe:
- Kubernetes vẫn gửi traffic
- Users thấy errors ❌
```

**Giải pháp: Health Probes**

```
✅ Liveness Probe: "App có đang sống không?"
   → Fail → Restart container

✅ Readiness Probe: "App có sẵn sàng nhận traffic không?"
   → Fail → Remove khỏi Service endpoints (không nhận traffic)

✅ Startup Probe: "App đã start xong chưa?"
   → Fail → Cho thêm thời gian, không check liveness
```

---

## Liveness Probe

**Định nghĩa:**
> Liveness Probe kiểm tra xem container có **còn sống** (alive) không. Nếu fail → Kubernetes restart container.

### Khi Nào Dùng Liveness?

**Use cases:**
- ✅ Detect deadlocks (app stuck)
- ✅ Detect memory leaks (OOM sắp xảy ra)
- ✅ App crash nhưng process vẫn chạy
- ✅ Unrecoverable errors (database connection pool exhausted)

**Không nên dùng nếu:**
- ❌ Errors tạm thời (database reconnecting) → Dùng Readiness
- ❌ App đang startup → Dùng Startup

### Liveness Probe Types

#### 1. HTTP Probe

**Check bằng HTTP GET request:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: app
    image: myapp:latest
    ports:
    - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /healthz      # ← Endpoint để check
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Health-Check
      initialDelaySeconds: 30  # ← Đợi 30s sau khi container start
      periodSeconds: 10        # ← Check mỗi 10s
      timeoutSeconds: 5        # ← Timeout 5s
      failureThreshold: 3      # ← Fail 3 lần → restart
```

**App implementation (example trong Node.js):**
```javascript
app.get('/healthz', (req, res) => {
  // Check app có healthy không
  if (isHealthy()) {
    res.status(200).send('OK');
  } else {
    res.status(500).send('Unhealthy');
  }
});

function isHealthy() {
  // Check database connection
  // Check memory usage < 90%
  // Check no deadlocks
  return true;
}
```

**HTTP response codes:**
- `200-399`: Success ✅
- `>= 400`: Failure ❌

#### 2. TCP Probe

**Check bằng TCP socket connection:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: database
spec:
  containers:
  - name: mysql
    image: mysql:8.0
    livenessProbe:
      tcpSocket:
        port: 3306         # ← Check MySQL port
      initialDelaySeconds: 30
      periodSeconds: 10
```

**Use case:**
- Databases (MySQL, PostgreSQL, Redis)
- Apps không có HTTP endpoint
- Check port có listen không

#### 3. Exec Probe

**Check bằng command trong container:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    livenessProbe:
      exec:
        command:
        - /bin/sh
        - -c
        - pgrep -f myapp || exit 1  # ← Check process có chạy không
      initialDelaySeconds: 30
      periodSeconds: 10
```

**Use case:**
- Apps không expose port
- Custom health check logic
- File-based checks

**Example commands:**
```bash
# Check process running
pgrep myapp

# Check file exists
test -f /tmp/healthy

# Check script
/health-check.sh
```

### Liveness Workflow

```
Every 10s (periodSeconds):

1. Kubernetes chạy probe
         │
         ▼
2. Success → OK, đợi 10s nữa
         │
         ▼ (nếu fail)
3. Fail count++
         │
         ▼
4. Fail count >= 3 (failureThreshold)?
         │
         ▼ Yes
5. Restart container
         │
         ▼
6. Container start lại
         │
         ▼
7. Đợi initialDelaySeconds
         │
         ▼
8. Bắt đầu probe lại
```

---

## Readiness Probe

**Định nghĩa:**
> Readiness Probe kiểm tra xem container có **sẵn sàng nhận traffic** không. Nếu fail → Remove khỏi Service endpoints.

### Readiness vs Liveness

| | Liveness | Readiness |
|---|---|---|
| **Mục đích** | App có sống không? | App có sẵn sàng nhận traffic không? |
| **Fail action** | Restart container | Remove từ Service |
| **Use case** | Deadlocks, crashes | Temporary unavailability |
| **Recovery** | Restart | Wait until ready |

### Khi Nào Dùng Readiness?

**Use cases:**
- ✅ App đang startup (loading config, warming cache)
- ✅ Database connection lost (reconnecting)
- ✅ Dependent service down
- ✅ Overloaded (too many requests)
- ✅ Maintenance mode

### Readiness Probe Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: app
    image: myapp:latest
    ports:
    - containerPort: 8080
    readinessProbe:
      httpGet:
        path: /ready       # ← Readiness endpoint
        port: 8080
      initialDelaySeconds: 10  # ← Startup nhanh hơn liveness
      periodSeconds: 5         # ← Check thường xuyên hơn
      failureThreshold: 3
```

**App implementation:**
```javascript
app.get('/ready', (req, res) => {
  if (isReady()) {
    res.status(200).send('Ready');
  } else {
    res.status(503).send('Not Ready');
  }
});

function isReady() {
  // Check database connected
  if (!db.isConnected()) return false;

  // Check dependencies reachable
  if (!canReachAPI()) return false;

  // Check not overloaded
  if (requestQueue.length > 1000) return false;

  return true;
}
```

### Readiness + Service

**Service chỉ forward traffic đến Pods có readiness pass:**

```
Service: web-app
         │
         ▼
Endpoints:
  Pod-1: 10.244.1.5  ← Readiness: OK ✅ → nhận traffic
  Pod-2: 10.244.1.6  ← Readiness: FAIL ❌ → KHÔNG nhận traffic
  Pod-3: 10.244.1.7  ← Readiness: OK ✅ → nhận traffic
```

**Workflow:**
```
1. Pod-2 readiness fail (database disconnected)
         │
         ▼
2. Kubernetes remove Pod-2 khỏi Service endpoints
         │
         ▼
3. Traffic chỉ đến Pod-1, Pod-3
         │
         ▼
4. Pod-2 reconnect database success
         │
         ▼
5. Readiness pass
         │
         ▼
6. Kubernetes add Pod-2 vào endpoints lại
         │
         ▼
7. Pod-2 nhận traffic
```

---

## Startup Probe

**Định nghĩa:**
> Startup Probe kiểm tra xem container đã **start xong** chưa. Khi startup probe running, liveness/readiness KHÔNG chạy.

### Tại Sao Cần Startup Probe?

**Vấn đề với chỉ có Liveness:**

```
App cần 60s để startup (load data, connect services)

Liveness config:
  initialDelaySeconds: 30  ← Quá ngắn
  failureThreshold: 3
  periodSeconds: 10

Timeline:
0s:  Container start
30s: Liveness bắt đầu check
40s: Liveness fail (1)
50s: Liveness fail (2)
60s: Liveness fail (3) → Restart container ❌

App chưa kịp startup đã bị restart!
```

**Giải pháp: Startup Probe**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slow-app
spec:
  containers:
  - name: app
    image: slow-startup-app
    startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 30  # ← 30 * 10s = 300s = 5 phút để startup
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      periodSeconds: 10
      failureThreshold: 3
```

**Workflow:**
```
0s:   Container start
0s:   Startup probe bắt đầu (liveness chưa chạy)
10s:  Startup fail (1/30)
20s:  Startup fail (2/30)
...
60s:  Startup SUCCESS ✅
      → Startup probe dừng
      → Liveness probe bắt đầu
70s:  Liveness check
80s:  Liveness check
...
```

**Use case:**
- Apps cần thời gian startup lâu (legacy apps, Java apps)
- Apps load large datasets
- Apps cần warm up

---

## Probe Configuration Best Practices

### Timing Parameters

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30   # Đợi bao lâu sau container start
  periodSeconds: 10         # Tần suất check
  timeoutSeconds: 5         # Timeout mỗi probe
  successThreshold: 1       # Số lần pass để OK (liveness/startup luôn = 1)
  failureThreshold: 3       # Số lần fail trước khi action
```

**Công thức tính thời gian fail:**
```
Total time = (failureThreshold * periodSeconds)

Example:
failureThreshold = 3
periodSeconds = 10
→ 30 giây fail → restart

Nếu app có thể recover trong 30s → tăng failureThreshold
```

### Recommendations

**Liveness Probe:**
```yaml
livenessProbe:
  initialDelaySeconds: 30      # Ít nhất = startup time
  periodSeconds: 10            # Check mỗi 10s
  timeoutSeconds: 5            # Timeout 5s
  failureThreshold: 3          # 30s để recover
```

**Readiness Probe:**
```yaml
readinessProbe:
  initialDelaySeconds: 5       # Ngắn hơn liveness
  periodSeconds: 5             # Check thường xuyên hơn
  timeoutSeconds: 3
  failureThreshold: 3
  successThreshold: 1          # Readiness có thể > 1 (đợi stable)
```

**Startup Probe (slow apps):**
```yaml
startupProbe:
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 30         # 300s = 5 phút
```

---

## Deployment với Probes

### Full Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: myapp:v1.0
        ports:
        - containerPort: 8080

        # Startup probe (chỉ khi startup lâu)
        startupProbe:
          httpGet:
            path: /healthz
            port: 8080
          periodSeconds: 10
          failureThreshold: 12  # 120s startup time

        # Liveness probe
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness probe
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

---
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
```

---

## 🚨 Troubleshooting

### Pod Liên Tục Restart (CrashLoopBackOff)

**Triệu chứng:**
```bash
kubectl get pods
# NAME       READY   STATUS             RESTARTS   AGE
# web-app    0/1     CrashLoopBackOff   5          3m
```

**Nguyên nhân:** Liveness probe fail

**Debug:**
```bash
# Xem events
kubectl describe pod web-app
# Events:
#   Unhealthy  Liveness probe failed: HTTP probe failed with statuscode: 500
#   Killing    Container app failed liveness probe, will be restarted

# Xem logs trước khi restart
kubectl logs web-app --previous

# Test probe manually
kubectl exec web-app -- curl localhost:8080/healthz
```

**Fix:**
- Tăng `initialDelaySeconds` (app chưa kịp start)
- Tăng `failureThreshold` (cho app thời gian recover)
- Fix app code (healthz endpoint lỗi)
- Dùng startup probe

### Pod Không Nhận Traffic

**Triệu chứng:**
```bash
kubectl get pods
# NAME       READY   STATUS    RESTARTS   AGE
# web-app    0/1     Running   0          2m

kubectl get endpoints web-app
# NAME       ENDPOINTS
# web-app    <none>  ← Không có endpoints
```

**Nguyên nhân:** Readiness probe fail

**Debug:**
```bash
kubectl describe pod web-app
# Readiness probe failed: HTTP probe failed with statuscode: 503

# Test readiness endpoint
kubectl exec web-app -- curl localhost:8080/ready
# Not Ready: Database not connected
```

**Fix:**
- Check dependencies (database, APIs)
- Tăng `initialDelaySeconds`
- Fix app readiness logic

### Probe Timeout

**Triệu chứng:**
```bash
kubectl describe pod web-app
# Events:
#   Unhealthy  Liveness probe failed: Get http://10.244.1.5:8080/healthz: context deadline exceeded
```

**Nguyên nhân:** Probe timeout (app phản hồi chậm)

**Fix:**
- Tăng `timeoutSeconds`
- Optimize health endpoint (đừng query database lâu)
- Check network latency

---

## 🎓 Tóm Tắt Ngày 73

✅ **Liveness Probe:** App có sống không? Fail → Restart
✅ **Readiness Probe:** App sẵn sàng nhận traffic không? Fail → Remove khỏi Service
✅ **Startup Probe:** App đã start xong chưa? Chạy trước liveness/readiness
✅ **Probe types:** HTTP (web apps), TCP (databases), Exec (custom)
✅ **Timing:** `initialDelaySeconds`, `periodSeconds`, `failureThreshold`
✅ Readiness fail → Pod vẫn Running nhưng không nhận traffic
✅ Liveness fail → Pod restart

**Kỹ năng đạt được:**
- Configure liveness/readiness/startup probes
- Implement health endpoints trong app
- Tune probe timing parameters
- Debug CrashLoopBackOff (liveness fail)
- Debug Pods không nhận traffic (readiness fail)
- Hiểu khi nào dùng probe nào
