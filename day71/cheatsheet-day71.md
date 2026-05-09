# Cheatsheet Day 71: Resource Management

## === Resource Requests & Limits ===
kubectl describe node <node-name>               # xem allocated resources trên node
kubectl top nodes                               # xem CPU/memory usage của nodes
kubectl top pods                                # xem CPU/memory usage của pods
kubectl top pods --containers                   # xem usage per container

## === Pod Resources ===
kubectl describe pod <pod-name>                 # xem requests/limits của pod
kubectl get pod <pod-name> -o yaml | grep -A 5 resources  # xem resource config
kubectl get pods -o json | jq '.items[].spec.containers[].resources'  # extract resources

## === LimitRange ===
kubectl get limitrange                          # list LimitRanges trong namespace
kubectl get limits                              # alias
kubectl describe limitrange <name>              # chi tiết LimitRange
kubectl delete limitrange <name>                # xóa LimitRange

## === ResourceQuota ===
kubectl get resourcequota                       # list ResourceQuotas
kubectl get quota                               # alias
kubectl describe quota <name>                   # xem used/hard limits
kubectl describe namespace <name>               # xem quotas của namespace

## === QoS Classes ===
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass  # xem QoS class
kubectl describe pod <name> | grep "QoS Class"  # xem QoS của 1 pod

## === Node Resources ===
kubectl describe node <name> | grep -A 5 "Allocated resources"  # xem resources đã dùng
kubectl describe node <name> | grep -A 10 "Capacity"  # xem total capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory  # list node capacity

## === Debugging Resource Issues ===
kubectl get events --sort-by='.lastTimestamp'   # xem events (Insufficient memory/cpu)
kubectl describe pod <name> | grep -i insufficient  # xem lỗi thiếu resources
kubectl get pods --field-selector=status.phase=Pending  # list pods pending (có thể thiếu resources)

## === Metrics Server (required for HPA) ===
kubectl top nodes                               # check metrics server hoạt động
kubectl top pods -A                             # xem metrics tất cả pods
kubectl get apiservices | grep metrics          # check metrics API available

## === HPA Preview ===
kubectl get hpa                                 # list HorizontalPodAutoscalers
kubectl describe hpa <name>                     # chi tiết HPA (current/target metrics)

## === Calculate Resource Usage ===
# CPU: 1 CPU = 1000m (millicores)
# 500m = 0.5 CPU
# Memory: 1Gi = 1024Mi
