# Cheatsheet: Day 84 - Helm Basics

## Helm Installation

```bash
# Install Helm (macOS)
brew install helm

# Install Helm (Linux)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## Helm Repo Management

```bash
# Add repository
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami

# List repos
helm repo list

# Update repos
helm repo update

# Search charts
helm search repo nginx
helm search repo wordpress --versions
```

## Install Charts

```bash
# Install chart
helm install my-release bitnami/nginx

# Install với custom name
helm install my-nginx bitnami/nginx

# Install vào specific namespace
helm install my-nginx bitnami/nginx -n production --create-namespace

# Install với values file
helm install my-nginx bitnami/nginx -f values.yaml

# Install với inline values
helm install my-nginx bitnami/nginx --set service.type=LoadBalancer

# Dry-run (không apply, chỉ xem manifest)
helm install my-nginx bitnami/nginx --dry-run --debug
```

## List Releases

```bash
# List releases trong current namespace
helm list

# List tất cả namespaces
helm list -A

# List với specific namespace
helm list -n production

# Show all releases (including failed)
helm list --all
```

## Get Release Info

```bash
# Get release info
helm status my-nginx

# Get values used
helm get values my-nginx

# Get manifest
helm get manifest my-nginx

# Get all info
helm get all my-nginx
```

## Upgrade Releases

```bash
# Upgrade với new values
helm upgrade my-nginx bitnami/nginx -f new-values.yaml

# Upgrade với inline values
helm upgrade my-nginx bitnami/nginx --set replicaCount=3

# Upgrade chart version
helm upgrade my-nginx bitnami/nginx --version 13.2.0

# Upgrade hoặc install nếu chưa có (idempotent)
helm upgrade --install my-nginx bitnami/nginx -f values.yaml
```

## Rollback Releases

```bash
# Rollback về previous revision
helm rollback my-nginx

# Rollback về specific revision
helm rollback my-nginx 2

# Xem history
helm history my-nginx
```

## Uninstall Releases

```bash
# Uninstall release
helm uninstall my-nginx

# Uninstall và keep history
helm uninstall my-nginx --keep-history

# Uninstall từ specific namespace
helm uninstall my-nginx -n production
```

## values.yaml Example

```yaml
# values.yaml - Override default values
replicaCount: 3

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

## Chart Structure

```bash
# Create new chart
helm create my-chart

# Chart directory structure:
my-chart/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── charts/             # Dependency charts
├── templates/          # Template files
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # Template helpers
│   └── NOTES.txt       # Post-install notes
└── .helmignore         # Ignore patterns
```

## Chart.yaml

```yaml
# Chart.yaml
apiVersion: v2
name: my-app
description: A Helm chart for my application
type: application
version: 1.0.0        # Chart version
appVersion: "2.1.0"   # Application version

keywords:
  - nginx
  - web

maintainers:
  - name: DevOps Team
    email: devops@example.com

dependencies:
  - name: mysql
    version: 9.3.0
    repository: https://charts.bitnami.com/bitnami
```

## Template Example

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-chart.fullname" . }}
  labels:
    {{- include "my-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-chart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        ports:
        - containerPort: {{ .Values.service.port }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

## Helm Template Functions

```yaml
# Conditionals
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
{{- end }}

# Loops
{{- range .Values.hosts }}
- host: {{ . }}
{{- end }}

# Variables
{{- $relname := .Release.Name }}
name: {{ $relname }}-service

# Default values
image: {{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}

# Include templates
labels:
  {{- include "my-chart.labels" . | nindent 4 }}
```

## Lint and Validate

```bash
# Lint chart
helm lint my-chart/

# Template chart (render templates locally)
helm template my-chart/

# Template với values
helm template my-chart/ -f values.yaml

# Validate against cluster
helm install my-nginx my-chart/ --dry-run --debug
```

## Package Charts

```bash
# Package chart
helm package my-chart/

# Output: my-chart-1.0.0.tgz

# Install từ package
helm install my-release my-chart-1.0.0.tgz
```

## Chart Dependencies

```bash
# Update dependencies (download charts từ Chart.yaml)
helm dependency update my-chart/

# List dependencies
helm dependency list my-chart/

# Build dependencies
helm dependency build my-chart/
```

```yaml
# Chart.yaml với dependencies
dependencies:
  - name: mysql
    version: 9.3.0
    repository: https://charts.bitnami.com/bitnami
    condition: mysql.enabled
  - name: redis
    version: 17.0.0
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
```

```yaml
# values.yaml - control dependencies
mysql:
  enabled: true
  auth:
    rootPassword: "secret"
    database: myapp

redis:
  enabled: false
```

## Show Chart Values

```bash
# Show default values của chart
helm show values bitnami/nginx

# Show chart info
helm show chart bitnami/nginx

# Show all (chart + values + readme)
helm show all bitnami/nginx

# Save values to file
helm show values bitnami/nginx > nginx-values.yaml
```

## Debugging

```bash
# Debug install
helm install my-nginx bitnami/nginx --dry-run --debug

# Get generated manifests
helm get manifest my-nginx

# Describe release
helm status my-nginx

# Check history
helm history my-nginx
```
