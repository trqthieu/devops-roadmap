# Cheatsheet Day 62: Kubernetes Components

## === Cluster Info ===
kubectl cluster-info                        # xem cluster endpoints
kubectl cluster-info dump                   # dump toàn bộ cluster state
kubectl get componentstatuses               # xem health của components (deprecated)

## === Control Plane Components ===
kubectl get pods -n kube-system             # xem tất cả control plane pods
kubectl describe pod <pod> -n kube-system   # chi tiết 1 control plane pod
kubectl logs <pod> -n kube-system           # xem logs của control plane pod

## === API Server ===
kubectl proxy                               # tạo proxy đến API server (localhost:8001)
curl http://localhost:8001/api/v1           # access API server qua proxy
kubectl api-resources                       # list tất cả resources API hỗ trợ
kubectl api-versions                        # list API versions

## === etcd ===
kubectl get pods -n kube-system | grep etcd # xem etcd pod
kubectl logs -n kube-system etcd-<node>     # xem etcd logs

## === Scheduler ===
kubectl get pods -n kube-system | grep scheduler  # xem scheduler pod
kubectl logs -n kube-system kube-scheduler-<node> # xem scheduler logs

## === Controller Manager ===
kubectl get pods -n kube-system | grep controller # xem controller manager pod
kubectl logs -n kube-system kube-controller-manager-<node> # logs

## === Node Components ===
kubectl get nodes                           # list nodes
kubectl describe node <name>                # chi tiết node (kubelet, runtime info)
kubectl top nodes                           # xem resource usage
kubectl get pods -o wide                    # xem Pods đang chạy trên Node nào

## === Debug & Troubleshoot ===
kubectl get events --all-namespaces         # xem cluster events
kubectl get events --sort-by='.lastTimestamp' # events mới nhất
journalctl -u kubelet                       # xem kubelet logs (trên worker node)
