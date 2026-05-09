# Cheatsheet Day 69: Persistent Storage

## === PersistentVolume (PV) ===
kubectl get pv                                  # list tất cả PVs (cluster-wide)
kubectl describe pv <pv-name>                   # chi tiết PV (capacity, access modes, status)
kubectl delete pv <pv-name>                     # xóa PV
kubectl get pv -o wide                          # xem claim, storage class, reason

## === PersistentVolumeClaim (PVC) ===
kubectl get pvc                                 # list PVCs trong namespace hiện tại
kubectl get pvc -n <namespace>                  # list PVCs trong namespace cụ thể
kubectl describe pvc <pvc-name>                 # chi tiết PVC (bound PV, capacity)
kubectl delete pvc <pvc-name>                   # xóa PVC (không xóa PV nếu policy=Retain)
kubectl get pvc --all-namespaces                # list tất cả PVCs

## === StorageClass ===
kubectl get storageclass                        # list tất cả storage classes
kubectl get sc                                  # alias
kubectl describe sc <sc-name>                   # chi tiết SC (provisioner, parameters)
kubectl get sc -o yaml                          # xem YAML của SC
kubectl patch sc <name> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'  # set default SC

## === Volume Info in Pod ===
kubectl describe pod <pod-name>                 # xem volumes được mount
kubectl get pod <pod-name> -o yaml | grep -A 10 volumes  # xem volume config
kubectl exec <pod-name> -- df -h                # xem disk usage trong container
kubectl exec <pod-name> -- ls -la /data         # xem files trong volume

## === PV/PVC Binding ===
kubectl get pvc -o wide                         # xem PVC nào bound với PV nào
kubectl get pv -o wide                          # xem PV nào bound với PVC nào
kubectl get events --sort-by='.lastTimestamp'   # xem events liên quan đến binding

## === Dynamic Provisioning ===
kubectl apply -f pvc.yaml                       # tạo PVC → StorageClass tự tạo PV
kubectl get pv --watch                          # theo dõi PV được tạo tự động
kubectl logs -n kube-system <provisioner-pod>   # xem logs của storage provisioner

## === StatefulSet with Storage ===
kubectl get statefulsets                        # list StatefulSets
kubectl describe sts <name>                     # xem volumeClaimTemplates
kubectl get pvc -l app=<app-name>               # xem PVCs của StatefulSet

## === Troubleshooting ===
kubectl describe pvc <name> | grep -i events    # xem lỗi khi binding
kubectl get events --field-selector involvedObject.name=<pvc-name>  # events của PVC cụ thể
kubectl get pv --sort-by=.spec.capacity.storage # sort PVs theo size
