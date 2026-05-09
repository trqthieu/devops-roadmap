# Cheatsheet Day 63: kubectl Cơ Bản

## === kubectl Get - Xem Resources ===
kubectl get pods                            # xem pods trong namespace hiện tại
kubectl get pods -A                         # xem pods trong tất cả namespaces
kubectl get pods -o wide                    # xem thêm thông tin (IP, Node)
kubectl get pods -w                         # watch mode (real-time updates)
kubectl get pods --show-labels              # xem labels của pods
kubectl get pods -l app=nginx               # filter pods theo label
kubectl get all                             # xem tất cả resources (pods, services, deployments)

## === kubectl Describe - Chi Tiết Resource ===
kubectl describe pod <pod-name>             # xem chi tiết pod (events, status)
kubectl describe node <node-name>           # xem chi tiết node
kubectl describe deployment <name>          # xem chi tiết deployment

## === kubectl Apply & Create - Tạo Resources ===
kubectl apply -f pod.yaml                   # tạo/update resource từ file
kubectl apply -f .                          # apply tất cả YAML trong folder
kubectl create deployment nginx --image=nginx  # tạo deployment nhanh
kubectl run nginx --image=nginx             # tạo pod nhanh (1 lệnh)

## === kubectl Delete - Xóa Resources ===
kubectl delete pod <pod-name>               # xóa pod
kubectl delete -f pod.yaml                  # xóa resource từ file
kubectl delete pod --all                    # xóa tất cả pods
kubectl delete deployment <name>            # xóa deployment

## === kubectl Logs - Xem Logs ===
kubectl logs <pod-name>                     # xem logs của pod
kubectl logs <pod-name> -c <container>      # logs của container cụ thể (multi-container pod)
kubectl logs <pod-name> -f                  # follow logs (real-time)
kubectl logs <pod-name> --tail=100          # 100 dòng cuối
kubectl logs <pod-name> --since=1h          # logs trong 1 giờ qua

## === kubectl Exec - Chạy Lệnh Trong Pod ===
kubectl exec <pod-name> -- ls /app          # chạy lệnh trong pod
kubectl exec -it <pod-name> -- /bin/bash    # shell vào pod
kubectl exec -it <pod-name> -c <container> -- sh  # exec vào container cụ thể

## === kubectl Port-Forward - Truy Cập Pod Local ===
kubectl port-forward pod/<pod-name> 8080:80 # forward port 80 của pod → localhost:8080
kubectl port-forward svc/<service> 8080:80  # forward service port

## === kubectl Edit - Sửa Resource Trực Tiếp ===
kubectl edit pod <pod-name>                 # mở editor sửa pod
kubectl edit deployment <name>              # sửa deployment

## === kubectl Set - Cập Nhật Nhanh ===
kubectl set image deployment/nginx nginx=nginx:1.25  # update image
kubectl scale deployment/nginx --replicas=5 # scale số replicas

## === kubectl Rollout - Quản Lý Deployment ===
kubectl rollout status deployment/nginx     # xem trạng thái rollout
kubectl rollout history deployment/nginx    # xem lịch sử rollout
kubectl rollout undo deployment/nginx       # rollback về version trước
kubectl rollout restart deployment/nginx    # restart deployment

## === kubectl Get Events - Debug ===
kubectl get events                          # xem events trong namespace
kubectl get events --sort-by='.lastTimestamp'  # sort theo thời gian
kubectl get events --field-selector type=Warning  # chỉ xem warnings

## === Namespace ===
kubectl get namespaces                      # list namespaces
kubectl config set-context --current --namespace=<ns>  # switch namespace
kubectl get pods -n <namespace>             # xem pods trong namespace cụ thể

## === Output Formats ===
kubectl get pods -o json                    # output JSON
kubectl get pods -o yaml                    # output YAML
kubectl get pods -o name                    # chỉ in tên
kubectl get pods -o wide                    # thêm thông tin
