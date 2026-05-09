# Cheatsheet Day 70: StatefulSet

## === StatefulSet Basics ===
kubectl get statefulsets                        # list tất cả StatefulSets
kubectl get sts                                 # alias
kubectl describe sts <name>                     # chi tiết StatefulSet
kubectl get sts -o wide                         # xem với thêm info
kubectl delete sts <name>                       # xóa StatefulSet (không xóa PVCs)

## === Scaling StatefulSet ===
kubectl scale sts <name> --replicas=5           # scale lên 5 replicas
kubectl patch sts <name> -p '{"spec":{"replicas":3}}'  # scale xuống 3
kubectl get sts --watch                         # theo dõi scaling process

## === StatefulSet Pods ===
kubectl get pods -l app=<app-name>              # xem pods của StatefulSet
kubectl get pods --show-labels                  # xem labels của pods
kubectl delete pod <statefulset-name>-0         # xóa pod 0 (sẽ recreate với cùng name)
kubectl exec -it <statefulset-name>-0 -- sh     # exec vào pod 0

## === PVCs của StatefulSet ===
kubectl get pvc -l app=<app-name>               # xem PVCs của StatefulSet
kubectl describe pvc <pvc-name>                 # chi tiết PVC
kubectl delete sts <name> --cascade=orphan      # xóa StatefulSet nhưng giữ Pods và PVCs

## === Headless Service ===
kubectl get svc <service-name>                  # xem headless service
kubectl describe svc <service-name>             # chi tiết (clusterIP = None)
nslookup <pod-name>.<service-name>.<namespace>.svc.cluster.local  # DNS lookup pod

## === Update Strategy ===
kubectl rollout status sts <name>               # xem trạng thái rollout
kubectl rollout history sts <name>              # xem history updates
kubectl set image sts/<name> <container>=<image>:<tag>  # update image
kubectl rollout undo sts <name>                 # rollback về version trước

## === StatefulSet vs Deployment ===
kubectl get deployments                         # so sánh với deployments
kubectl get sts,deploy                          # xem cả 2 loại

## === Debugging ===
kubectl logs <statefulset-name>-0               # xem logs pod 0
kubectl logs <statefulset-name>-0 --previous    # logs của container trước khi crash
kubectl describe pod <statefulset-name>-0       # xem events
kubectl get events --field-selector involvedObject.name=<statefulset-name>-0  # events cụ thể

## === Deleting StatefulSet Safely ===
kubectl delete sts <name> --cascade=false       # deprecated, dùng --cascade=orphan
kubectl delete sts <name> --cascade=orphan      # xóa StatefulSet, giữ Pods
kubectl delete pod -l app=<app> --grace-period=0 --force  # force delete pods
