# Cheatsheet Day 67: Thực Hành K8s Full Stack

## === Deploy Full Stack App ===
# 1. Database (PostgreSQL)
kubectl create deployment postgres --image=postgres:16
kubectl set env deployment/postgres POSTGRES_PASSWORD=secret
kubectl expose deployment postgres --port=5432 --type=ClusterIP

# 2. Backend API (Node.js)
kubectl create deployment api --image=myapi:latest
kubectl set env deployment/api DATABASE_URL=postgres://postgres:secret@postgres:5432/db
kubectl expose deployment api --port=3000 --type=ClusterIP
kubectl scale deployment/api --replicas=3

# 3. Frontend (React)
kubectl create deployment frontend --image=myfrontend:latest
kubectl set env deployment/frontend API_URL=http://api:3000
kubectl expose deployment frontend --port=80 --type=NodePort

## === Verify Full Stack ===
kubectl get all                                 # xem tất cả resources
kubectl get pods -o wide                        # xem pods và nodes
kubectl get svc                                 # xem services

## === Test Connectivity ===
# Exec vào backend pod để test DB connection
kubectl exec -it deployment/api -- sh
# Trong pod:
nc -zv postgres 5432                            # test DB port
curl http://postgres:5432                       # test connection

# Test API từ frontend pod
kubectl exec -it deployment/frontend -- sh
curl http://api:3000/health

## === Check Logs ===
kubectl logs deployment/postgres --tail=50      # DB logs
kubectl logs deployment/api -f                  # API logs (follow)
kubectl logs deployment/frontend                # Frontend logs

## === Scale Components ===
kubectl scale deployment/api --replicas=5       # scale API
kubectl scale deployment/frontend --replicas=3  # scale frontend

## === Update & Rollout ===
kubectl set image deployment/api api=myapi:v2   # update image
kubectl rollout status deployment/api           # watch rollout
kubectl rollout undo deployment/api             # rollback nếu lỗi

## === ConfigMap cho Config ===
kubectl create configmap api-config --from-literal=PORT=3000 --from-literal=NODE_ENV=production
kubectl set env deployment/api --from=configmap/api-config

## === Secret cho Passwords ===
kubectl create secret generic db-credentials --from-literal=password=secret123
# Update deployment để dùng secret
kubectl edit deployment postgres

## === Health Check ===
kubectl get pods --field-selector=status.phase=Running  # pods healthy
kubectl describe pod <pod-name>                 # check events
kubectl top pods                                # CPU/memory usage

## === Cleanup ===
kubectl delete deployment postgres api frontend
kubectl delete svc postgres api frontend
kubectl delete configmap api-config
kubectl delete secret db-credentials
