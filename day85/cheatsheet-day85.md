# Cheatsheet: Day 85 - Kubernetes Monitoring (Prometheus & Grafana)

## Prometheus Operator

```bash
# Install Prometheus Operator với Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Verify installation
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

## Access Prometheus UI

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access: http://localhost:9090

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access: http://localhost:3000
# Default credentials: admin / prom-operator
```

## ServiceMonitor Resource

```yaml
# servicemonitor.yaml - Monitor custom application
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  namespace: production
  labels:
    release: prometheus    # Prometheus Operator selector
spec:
  selector:
    matchLabels:
      app: myapp          # Select service với label này
  endpoints:
  - port: metrics         # Service port name
    interval: 30s
    path: /metrics
```

## PodMonitor Resource

```yaml
# podmonitor.yaml - Monitor pods directly
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: myapp-pods
  namespace: production
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: myapp
  podMetricsEndpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## PrometheusRule - Alerting

```yaml
# prometheusrule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: production
  labels:
    release: prometheus
spec:
  groups:
  - name: myapp
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate on {{ $labels.instance }}"
        description: "Error rate is {{ $value }} requests/sec"

    - alert: PodDown
      expr: up{job="myapp"} == 0
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.instance }} is down"
```

## kubectl top Commands

```bash
# View node resource usage
kubectl top nodes

# View pod resource usage
kubectl top pods

# Pod usage trong specific namespace
kubectl top pods -n production

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory

# Show containers
kubectl top pods --containers
```

## Metrics Server

```bash
# Install Metrics Server (nếu chưa có)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system

# Check metrics available
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

## Expose Metrics từ Application

```go
// Go application với Prometheus metrics
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
}

func handler(w http.ResponseWriter, r *http.Request) {
    httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
    w.Write([]byte("Hello World"))
}

func main() {
    http.HandleFunc("/", handler)
    http.Handle("/metrics", promhttp.Handler())  // Metrics endpoint
    http.ListenAndServe(":8080", nil)
}
```

## Service cho Metrics Endpoint

```yaml
# service.yaml - Expose /metrics endpoint
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: production
  labels:
    app: myapp
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: metrics      # Metrics port
    port: 9090
    targetPort: 8080
```

## PromQL Queries

```bash
# Access Prometheus UI → Graph

# CPU usage per pod
rate(container_cpu_usage_seconds_total{namespace="production"}[5m])

# Memory usage
container_memory_usage_bytes{namespace="production"}

# HTTP request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Percentile latency (p95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Pod restart count
kube_pod_container_status_restarts_total{namespace="production"}

# Available replicas
kube_deployment_status_replicas_available{namespace="production"}
```

## Grafana Dashboard

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Login: admin / prom-operator

# Import dashboard:
# 1. Click "+" → Import
# 2. Enter dashboard ID:
#    - 315: Kubernetes cluster monitoring
#    - 6417: Kubernetes pod monitoring
#    - 1860: Node Exporter Full
# 3. Select Prometheus data source
# 4. Import
```

## Custom Grafana Dashboard JSON

```json
{
  "dashboard": {
    "title": "My App Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{app='myapp'}[5m])",
            "legendFormat": "{{ instance }}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{app='myapp',status=~'5..'}[5m])",
            "legendFormat": "{{ instance }}"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

## ConfigMap cho Grafana Dashboard

```yaml
# grafana-dashboard.yaml - Auto-load dashboard
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"    # Grafana sidecar sẽ load dashboard này
data:
  myapp-dashboard.json: |
    {
      "dashboard": {
        "title": "My App Dashboard",
        "panels": [...]
      }
    }
```

## Alertmanager Configuration

```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-prometheus-kube-prometheus-alertmanager
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m

    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack'

    receivers:
    - name: 'slack'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Check Prometheus Targets

```bash
# Access Prometheus UI → Status → Targets

# Hoặc query API
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

curl http://localhost:9090/api/v1/targets | jq .

# Check ServiceMonitor discovered
kubectl get servicemonitor -A
```

## Debug Metrics Collection

```bash
# Check if metrics endpoint accessible
kubectl run test --image=curlimages/curl -it --rm -- \
  curl http://myapp-service.production:9090/metrics

# Check Prometheus config
kubectl get secret -n monitoring prometheus-prometheus-kube-prometheus-prometheus -o yaml

# Check ServiceMonitor labels
kubectl get servicemonitor myapp-monitor -o yaml

# Check Prometheus Operator logs
kubectl logs -n monitoring deployment/prometheus-operator
```

## Horizontal Pod Autoscaler với Custom Metrics

```yaml
# hpa-custom-metrics.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
```

## Recording Rules

```yaml
# recording-rules.yaml - Pre-compute expensive queries
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-recording-rules
  namespace: production
spec:
  groups:
  - name: myapp_rules
    interval: 30s
    rules:
    - record: job:http_requests_total:rate5m
      expr: rate(http_requests_total[5m])

    - record: job:http_request_duration_seconds:p95
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```
