# Cheatsheet Day 64: Pod & Deployment

## === Pod Basics ===
kubectl run nginx --image=nginx                 # tạo pod nhanh
kubectl get pods                                # xem tất cả pods
kubectl get pods -o yaml                        # xem pod manifest
kubectl delete pod <name>                       # xóa pod

## === Deployment ===
kubectl create deployment nginx --image=nginx   # tạo deployment
kubectl get deployments                         # xem deployments
kubectl get rs                                  # xem replicasets
kubectl describe deployment <name>              # chi tiết deployment

## === Scale Deployment ===
kubectl scale deployment/nginx --replicas=3     # scale lên 3 replicas
kubectl scale deployment/nginx --replicas=0     # scale về 0 (stop all)
kubectl autoscale deployment/nginx --min=2 --max=10 --cpu-percent=80  # auto-scale

## === Update Deployment ===
kubectl set image deployment/nginx nginx=nginx:1.25  # update image
kubectl edit deployment nginx                   # edit trực tiếp
kubectl apply -f deployment.yaml                # update từ file

## === Rollout Management ===
kubectl rollout status deployment/nginx         # xem trạng thái rollout
kubectl rollout history deployment/nginx        # xem lịch sử versions
kubectl rollout history deployment/nginx --revision=2  # chi tiết revision cụ thể
kubectl rollout undo deployment/nginx           # rollback về version trước
kubectl rollout undo deployment/nginx --to-revision=2  # rollback về revision cụ thể
kubectl rollout restart deployment/nginx        # restart toàn bộ pods
kubectl rollout pause deployment/nginx          # tạm dừng rollout
kubectl rollout resume deployment/nginx         # tiếp tục rollout

## === Pod Lifecycle ===
kubectl get pods --watch                        # theo dõi pod lifecycle
kubectl get pods --field-selector=status.phase=Running  # chỉ xem Running pods
kubectl get pods --field-selector=status.phase=Pending  # chỉ xem Pending pods

## === Labels & Selectors ===
kubectl get pods --show-labels                  # xem labels
kubectl get pods -l app=nginx                   # filter theo label
kubectl label pod nginx env=prod                # thêm label
kubectl label pod nginx env-                    # xóa label

## === Deployment Strategies ===
kubectl patch deployment nginx -p '{"spec":{"strategy":{"type":"RollingUpdate"}}}'  # set rolling update
kubectl patch deployment nginx -p '{"spec":{"strategy":{"type":"Recreate"}}}'  # set recreate

## === Debug Pods ===
kubectl describe pod <name>                     # xem events và status
kubectl logs <pod-name>                         # xem logs
kubectl exec -it <pod-name> -- sh               # shell vào pod
kubectl top pod <name>                          # xem CPU/memory usage (cần metrics-server)
