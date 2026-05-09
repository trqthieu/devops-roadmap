# Cheatsheet Day 65: Service

## === Service Types ===
kubectl expose deployment nginx --port=80 --type=ClusterIP    # ClusterIP (default)
kubectl expose deployment nginx --port=80 --type=NodePort     # NodePort
kubectl expose deployment nginx --port=80 --type=LoadBalancer # LoadBalancer

## === Get Services ===
kubectl get services                            # list services (hoặc kubectl get svc)
kubectl get svc -o wide                         # xem selector và endpoints
kubectl describe svc <name>                     # chi tiết service

## === Endpoints ===
kubectl get endpoints                           # xem endpoints (Pods behind Service)
kubectl get ep <service-name>                   # endpoints của service cụ thể

## === Service Discovery - DNS ===
# Từ trong Pod, có thể gọi Service qua DNS:
# <service-name>.<namespace>.svc.cluster.local
# Ví dụ: nginx.default.svc.cluster.local

## === ClusterIP - Internal Only ===
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP
# Chỉ truy cập được từ trong cluster

## === NodePort - External Access ===
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}'  # lấy port number
# Access: http://<NodeIP>:<NodePort>

## === LoadBalancer - Cloud Provider ===
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'  # lấy external IP

## === Port Forwarding ===
kubectl port-forward svc/nginx 8080:80          # forward service port đến local

## === Service Selector ===
kubectl get svc nginx -o yaml                   # xem selector
kubectl get pods -l app=nginx                   # xem pods match selector

## === Delete Service ===
kubectl delete svc <name>                       # xóa service
kubectl delete svc --all                        # xóa tất cả services

## === Testing Service ===
kubectl run test-pod --image=busybox -it --rm -- sh
# Trong pod:
wget -qO- http://nginx.default.svc.cluster.local
# hoặc
wget -qO- http://nginx
