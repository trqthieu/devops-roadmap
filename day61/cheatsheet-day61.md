# Cheatsheet Day 61: Kubernetes Introduction

## === Minikube - Local Kubernetes ===
minikube start                              # khởi động cluster local
minikube status                             # xem trạng thái cluster
minikube stop                               # dừng cluster
minikube delete                             # xóa cluster
minikube dashboard                          # mở Kubernetes dashboard
minikube ip                                 # lấy IP của cluster

## === Kind - Kubernetes in Docker ===
kind create cluster                         # tạo cluster
kind get clusters                           # xem danh sách clusters
kind delete cluster                         # xóa cluster
kind load docker-image <image>              # load image vào cluster

## === Kubectl Context ===
kubectl config get-contexts                 # xem danh sách contexts
kubectl config current-context              # context hiện tại
kubectl config use-context <name>           # chuyển context
kubectl cluster-info                        # thông tin cluster
kubectl version                             # version kubectl và cluster

## === Basic Cluster Check ===
kubectl get nodes                           # xem nodes trong cluster
kubectl get nodes -o wide                   # xem chi tiết nodes
kubectl describe node <name>                # chi tiết 1 node
kubectl top nodes                           # xem resource usage của nodes
