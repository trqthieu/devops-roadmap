# Cheatsheet Day 74: Project K8s - Microservices Deployment

## === Project Setup ===
kubectl create namespace microservices           # tạo namespace cho project
kubectl config set-context --current --namespace=microservices  # switch namespace

## === Deploy Services ===
kubectl apply -f frontend-deployment.yaml        # deploy frontend
kubectl apply -f backend-deployment.yaml         # deploy backend API
kubectl apply -f database-statefulset.yaml       # deploy database

## === Verify Deployments ===
kubectl get all                                  # xem tất cả resources
kubectl get pods -o wide                         # xem pods đang chạy trên node nào
kubectl get deployments                          # xem deployments status
kubectl get statefulsets                         # xem statefulsets
kubectl get services                             # xem services
kubectl get pvc                                  # xem persistent volume claims
kubectl get hpa                                  # xem HPAs

## === Check Health ===
kubectl describe deployment frontend             # xem deployment details
kubectl get pods -l app=frontend                 # filter pods theo label
kubectl logs -f deployment/frontend              # xem logs frontend
kubectl logs -f deployment/backend               # xem logs backend
kubectl logs -f statefulset/database             # xem logs database

## === Test Service Communication ===
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh  # tạo test pod
# Trong pod:
# wget -qO- http://backend:8080/api/health
# nslookup database

## === Port Forward để Test Local ===
kubectl port-forward service/frontend 3000:80   # access frontend localhost:3000
kubectl port-forward service/backend 8080:8080  # access backend localhost:8080
kubectl port-forward service/database 5432:5432 # access database localhost:5432

## === Scale Services ===
kubectl scale deployment frontend --replicas=5   # scale frontend
kubectl scale deployment backend --replicas=3    # scale backend

## === Update Image ===
kubectl set image deployment/frontend frontend=myapp/frontend:v2  # update frontend version
kubectl rollout status deployment/frontend       # xem rollout progress
kubectl rollout history deployment/frontend      # xem rollout history
kubectl rollout undo deployment/frontend         # rollback nếu có lỗi

## === Resource Monitoring ===
kubectl top pods                                 # xem CPU/memory usage
kubectl top pods --containers                    # usage per container
kubectl describe hpa frontend-hpa                # xem HPA status

## === Troubleshooting ===
kubectl get events --sort-by='.lastTimestamp'    # xem recent events
kubectl describe pod <pod-name>                  # debug specific pod
kubectl logs <pod-name> --previous               # logs của container trước khi crash
kubectl exec -it <pod-name> -- sh                # exec vào pod để debug

## === ConfigMaps & Secrets ===
kubectl get configmaps                           # xem ConfigMaps
kubectl describe configmap <name>                # chi tiết ConfigMap
kubectl get secrets                              # xem Secrets
kubectl describe secret <name>                   # chi tiết Secret

## === Clean Up ===
kubectl delete namespace microservices           # xóa toàn bộ project (cascade delete all)
kubectl delete -f .                              # xóa tất cả resources từ YAML files

## === Apply All Project Files ===
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f database/
kubectl apply -f backend/
kubectl apply -f frontend/
# Hoặc:
kubectl apply -f . --recursive                   # apply tất cả YAMLs recursive

## === Export Resources ===
kubectl get all -o yaml > backup.yaml            # backup tất cả resources
kubectl get deployment frontend -o yaml > frontend-backup.yaml  # backup specific resource
