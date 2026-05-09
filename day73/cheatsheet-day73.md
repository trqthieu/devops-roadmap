# Cheatsheet Day 73: Health Checks

## === Liveness Probe ===
kubectl describe pod <pod-name> | grep -A 5 "Liveness"  # xem liveness probe config
kubectl get events --field-selector involvedObject.name=<pod-name> | grep Liveness  # xem liveness failures
kubectl logs <pod-name> --previous              # xem logs trước khi container restart (do liveness fail)

## === Readiness Probe ===
kubectl describe pod <pod-name> | grep -A 5 "Readiness"  # xem readiness probe config
kubectl get pods -o wide                        # xem READY status (0/1 = readiness fail)
kubectl get endpoints <service-name>            # xem pods nào trong service endpoints (readiness pass)
kubectl describe endpoints <service-name>       # chi tiết endpoints

## === Startup Probe ===
kubectl describe pod <pod-name> | grep -A 5 "Startup"  # xem startup probe config
kubectl get events | grep Started               # xem khi container started

## === Pod Status & Conditions ===
kubectl get pods                                # xem status (Running, CrashLoopBackOff)
kubectl describe pod <pod-name> | grep -A 10 Conditions  # xem Pod conditions
kubectl get pod <pod-name> -o jsonpath='{.status.conditions[*].type}'  # extract condition types
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].ready}'  # check container ready

## === Probe Types ===
# HTTP probe: GET request đến path
# TCP probe: Open TCP socket
# Exec probe: Run command trong container

## === Debug Probes ===
kubectl exec <pod-name> -- curl localhost:8080/health  # test HTTP probe manually
kubectl exec <pod-name> -- nc -zv localhost 3306  # test TCP probe manually
kubectl exec <pod-name> -- /health-check.sh     # test exec probe manually

## === Events ===
kubectl get events --sort-by='.lastTimestamp' | grep Unhealthy  # xem probe failures
kubectl describe pod <pod-name> | tail -20      # xem recent events

## === Restart Count ===
kubectl get pods                                # xem RESTARTS column
kubectl describe pod <pod-name> | grep "Restart Count"  # chi tiết restart count
kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount  # extract restarts

## === Probe Timing ===
# initialDelaySeconds: Đợi bao lâu trước probe đầu tiên
# periodSeconds: Tần suất probe (mặc định 10s)
# timeoutSeconds: Timeout mỗi probe (mặc định 1s)
# successThreshold: Số lần pass để considered successful (mặc định 1)
# failureThreshold: Số lần fail trước khi action (mặc định 3)
