# Cheatsheet Day 72: HPA - Horizontal Pod Autoscaler

## === Metrics Server ===
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml  # cài metrics-server
kubectl get deployment metrics-server -n kube-system  # check metrics-server deployed
kubectl top nodes                               # test metrics server (xem CPU/memory nodes)
kubectl top pods                                # xem CPU/memory pods
kubectl top pods -A --sort-by=memory            # sort pods theo memory usage

## === HPA Basics ===
kubectl get hpa                                 # list tất cả HPAs
kubectl describe hpa <name>                     # chi tiết HPA (current/target metrics)
kubectl delete hpa <name>                       # xóa HPA

## === Create HPA ===
kubectl autoscale deployment <name> --cpu-percent=50 --min=2 --max=10  # tạo HPA từ CLI
kubectl apply -f hpa.yaml                       # tạo HPA từ YAML

## === Monitor HPA ===
kubectl get hpa --watch                         # theo dõi HPA real-time
kubectl get hpa <name> -o yaml                  # xem config đầy đủ
kubectl describe hpa <name>                     # xem events, conditions
kubectl get hpa -o custom-columns=NAME:.metadata.name,REPLICAS:.status.currentReplicas,TARGET:.spec.targetCPUUtilizationPercentage,CURRENT:.status.currentCPUUtilizationPercentage

## === Test HPA Scaling ===
kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://<service-name>; done"  # generate load
kubectl get hpa --watch                         # xem HPA scale up
# Ctrl+C để stop load generator
kubectl get hpa --watch                         # xem HPA scale down

## === HPA với Custom Metrics ===
kubectl get hpa <name> -o yaml | grep -A 10 metrics  # xem metrics config
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1  # check custom metrics API available

## === Troubleshooting ===
kubectl describe hpa <name> | grep -i "unable"  # xem lỗi HPA
kubectl get apiservices | grep metrics         # check metrics API
kubectl logs -n kube-system deployment/metrics-server  # logs metrics-server
kubectl get events --sort-by='.lastTimestamp' | grep HPA  # xem HPA events

## === HPA Status ===
kubectl get hpa <name> -o jsonpath='{.status.conditions[*].message}'  # xem HPA conditions
kubectl get hpa <name> -o jsonpath='{.status.currentMetrics}'  # xem current metrics
