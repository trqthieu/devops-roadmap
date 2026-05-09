# Cheatsheet Day 66: ConfigMap & Secret

## === ConfigMap ===
kubectl create configmap app-config --from-literal=DB_HOST=localhost  # từ literal
kubectl create configmap app-config --from-file=config.yaml  # từ file
kubectl create configmap app-config --from-env-file=.env     # từ env file

kubectl get configmaps                          # list configmaps (hoặc kubectl get cm)
kubectl describe cm <name>                      # xem data trong configmap
kubectl get cm <name> -o yaml                   # xem full YAML

kubectl delete cm <name>                        # xóa configmap

## === Secret ===
kubectl create secret generic db-secret --from-literal=password=secret123  # từ literal
kubectl create secret generic db-secret --from-file=./password.txt  # từ file
kubectl create secret docker-registry my-registry \
  --docker-server=docker.io \
  --docker-username=user \
  --docker-password=pass  # Docker registry secret

kubectl get secrets                             # list secrets
kubectl describe secret <name>                  # xem metadata (không show data)
kubectl get secret <name> -o yaml               # xem data (base64 encoded)

kubectl delete secret <name>                    # xóa secret

## === Decode Secret ===
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d  # decode password

## === Sử Dụng ConfigMap trong Pod - Environment Variables ===
# Inject toàn bộ ConfigMap vào env
envFrom:
- configMapRef:
    name: app-config

# Inject từng key cụ thể
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: DB_HOST

## === Sử Dụng ConfigMap trong Pod - Volume ===
volumes:
- name: config-volume
  configMap:
    name: app-config
volumeMounts:
- name: config-volume
  mountPath: /etc/config

## === Sử Dụng Secret trong Pod - Environment Variables ===
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password

## === Sử Dụng Secret trong Pod - Volume ===
volumes:
- name: secret-volume
  secret:
    secretName: db-secret
volumeMounts:
- name: secret-volume
  mountPath: /etc/secrets
  readOnly: true

## === Update ConfigMap/Secret ===
kubectl create configmap app-config --from-literal=KEY=value --dry-run=client -o yaml | kubectl apply -f -
# Pod phải restart để nhận config mới (nếu dùng env)
kubectl rollout restart deployment/myapp
