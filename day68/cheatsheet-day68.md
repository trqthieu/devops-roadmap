# Cheatsheet Day 68: Namespace & RBAC

## === Namespace Management ===
kubectl get namespaces                          # list tất cả namespaces
kubectl get ns                                  # alias của namespaces
kubectl create namespace dev                    # tạo namespace mới
kubectl delete namespace dev                    # xóa namespace (và tất cả resources)
kubectl get pods -n dev                         # list pods trong namespace dev
kubectl get all -n dev                          # list tất cả resources trong namespace
kubectl config set-context --current --namespace=dev  # đổi default namespace

## === Namespace Isolation ===
kubectl apply -f pod.yaml -n dev                # deploy vào namespace cụ thể
kubectl get pods --all-namespaces               # xem pods trong tất cả namespaces
kubectl get pods -A                             # alias của --all-namespaces
kubectl describe namespace dev                  # xem chi tiết namespace (quotas, limits)

## === Service Account ===
kubectl get serviceaccounts                     # list service accounts
kubectl get sa                                  # alias
kubectl create serviceaccount jenkins           # tạo service account
kubectl describe sa jenkins                     # xem chi tiết SA (tokens, secrets)
kubectl get sa jenkins -o yaml                  # xem YAML của SA

## === Role (namespace-scoped) ===
kubectl get roles                               # list roles trong namespace hiện tại
kubectl get roles -n dev                        # list roles trong namespace dev
kubectl create role pod-reader --verb=get,list,watch --resource=pods  # tạo role
kubectl describe role pod-reader                # xem permissions của role
kubectl get roles -o yaml                       # xem tất cả roles dạng YAML

## === ClusterRole (cluster-wide) ===
kubectl get clusterroles                        # list tất cả cluster roles
kubectl describe clusterrole view               # xem built-in ClusterRole "view"
kubectl create clusterrole secret-reader --verb=get,list --resource=secrets  # tạo ClusterRole
kubectl get clusterroles -o wide                # xem với thêm info

## === RoleBinding (namespace-scoped) ===
kubectl get rolebindings                        # list role bindings
kubectl create rolebinding dev-pod-reader --role=pod-reader --serviceaccount=dev:jenkins  # bind role đến SA
kubectl describe rolebinding dev-pod-reader     # xem chi tiết binding
kubectl delete rolebinding dev-pod-reader       # xóa binding

## === ClusterRoleBinding (cluster-wide) ===
kubectl get clusterrolebindings                 # list tất cả cluster role bindings
kubectl create clusterrolebinding jenkins-admin --clusterrole=cluster-admin --serviceaccount=dev:jenkins  # bind ClusterRole đến SA
kubectl describe clusterrolebinding jenkins-admin  # xem chi tiết
kubectl delete clusterrolebinding jenkins-admin # xóa binding

## === Check Permissions ===
kubectl auth can-i create deployments           # kiểm tra permission của user hiện tại
kubectl auth can-i get pods --namespace=dev     # check permission trong namespace cụ thể
kubectl auth can-i '*' '*' --all-namespaces     # check xem có quyền admin không
kubectl auth can-i list secrets --as=system:serviceaccount:dev:jenkins  # check permission của SA khác

## === RBAC Debug ===
kubectl describe clusterrolebinding             # xem tất cả bindings
kubectl get rolebindings,clusterrolebindings -A # xem tất cả bindings trong cluster
kubectl auth reconcile -f rbac.yaml             # apply RBAC và fix conflicts
