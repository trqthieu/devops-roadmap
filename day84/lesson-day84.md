# Lesson: Day 84 - Helm Basics

## Mục tiêu ngày hôm nay

- Hiểu Helm là gì và tại sao cần dùng
- Nắm được Helm architecture: Chart, Release, Repository
- Sử dụng helm install/upgrade/rollback
- Làm việc với values.yaml và templating
- Hiểu chart structure và dependencies

## Tại sao Helm quan trọng?

### Vấn đề với Plain Kubernetes YAML

```
Deploy 1 application cần nhiều YAML files:

app-deployment/
├── 01-namespace.yaml
├── 02-configmap.yaml
├── 03-secret.yaml
├── 04-deployment.yaml
├── 05-service.yaml
├── 06-ingress.yaml
├── 07-hpa.yaml
└── 08-networkpolicy.yaml

Challenges:
❌ Phải apply theo thứ tự đúng
❌ Khó manage versions (v1.0, v1.1, v2.0)
❌ Rollback phải revert từng file thủ công
❌ Duplicate manifests cho staging/prod (chỉ khác values)
❌ Khó share configurations giữa teams
❌ Không có dependency management
```

### Giải pháp với Helm

```
Helm Chart = Package of Kubernetes manifests

my-app-chart/
├── Chart.yaml              # Metadata
├── values.yaml             # Configuration
└── templates/              # Kubernetes manifests
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml

Benefits:
✅ Single command install: helm install my-app ./my-app-chart
✅ Version management: helm upgrade, helm rollback
✅ Templating: 1 template → multiple environments
✅ Sharing: helm repo add, helm install
✅ Dependencies: MySQL, Redis, etc.
✅ Atomic operations: All-or-nothing deployments
```

## Helm Architecture

### Core Concepts

```
┌─────────────────────────────────────────────────┐
│               Helm Ecosystem                     │
│                                                  │
│  ┌──────────────┐                               │
│  │ Helm Client  │ (CLI tool)                    │
│  │  - helm CLI  │                               │
│  └──────┬───────┘                               │
│         │                                        │
│         │ Uses                                   │
│         ▼                                        │
│  ┌──────────────┐                               │
│  │   Charts     │ (Package format)              │
│  │  - Templates │                               │
│  │  - Values    │                               │
│  │  - Metadata  │                               │
│  └──────┬───────┘                               │
│         │                                        │
│         │ Stored in                              │
│         ▼                                        │
│  ┌──────────────┐                               │
│  │ Repositories │ (Chart storage)               │
│  │  - ArtifactHub                               │
│  │  - Bitnami   │                               │
│  │  - Custom    │                               │
│  └──────┬───────┘                               │
│         │                                        │
│         │ Deployed as                            │
│         ▼                                        │
│  ┌──────────────┐                               │
│  │  Releases    │ (Running instances)           │
│  │  - my-app-v1 │                               │
│  │  - my-app-v2 │                               │
│  └──────────────┘                               │
│         │                                        │
│         │ Creates resources in                   │
│         ▼                                        │
│  ┌──────────────────────────────────┐           │
│  │   Kubernetes Cluster              │           │
│  │   (Deployments, Services, etc.)   │           │
│  └──────────────────────────────────┘           │
└─────────────────────────────────────────────────┘
```

### Chart vs Release

```
Chart = Template/Blueprint
  - Reusable package
  - Contains templates + default values
  - Stored in repositories
  - Version controlled (v1.0.0, v1.1.0)

Release = Running Instance
  - Deployed chart in cluster
  - Has unique name
  - Can install same chart multiple times
  - Each release has own configuration

Example:
  Chart: "nginx" version 13.2.0
  Releases:
    - "my-nginx-staging" (in staging namespace)
    - "my-nginx-prod" (in production namespace)
    - "my-nginx-test" (in test namespace)
```

### Repository

```
Helm Repository = HTTP server hosting chart packages

Public Repositories:
  - Artifact Hub: https://artifacthub.io (search all charts)
  - Bitnami: https://charts.bitnami.com/bitnami
  - Stable: https://charts.helm.sh/stable

Private Repositories:
  - ChartMuseum (self-hosted)
  - Harbor
  - Nexus
  - S3 bucket
  - Git repo (helm git plugin)

Usage:
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm search repo nginx
  helm install my-nginx bitnami/nginx
```

## Helm Workflow

### Install Workflow

```
1. User runs:
   helm install my-app bitnami/nginx -f values.yaml

2. Helm client:
   ├─ Downloads chart từ repo
   ├─ Reads values.yaml (user overrides)
   ├─ Merges với chart's default values
   ├─ Renders templates với merged values
   └─ Generates final Kubernetes manifests

3. Apply to cluster:
   ├─ Creates all resources (Deployment, Service, etc.)
   ├─ Stores release metadata in Secret
   └─ Returns status

4. Result:
   Release "my-app" created
   - Revision: 1
   - Status: Deployed
```

### Upgrade Workflow

```
1. User runs:
   helm upgrade my-app bitnami/nginx --set replicaCount=3

2. Helm client:
   ├─ Fetches current release config (revision 1)
   ├─ Applies new values (replicaCount=3)
   ├─ Re-renders templates
   ├─ Generates diff between revision 1 vs 2
   └─ Applies changes

3. Kubernetes:
   ├─ Updates Deployment (replica: 1→3)
   ├─ Rolling update pods
   └─ No downtime

4. Result:
   Release "my-app" upgraded
   - Revision: 2
   - Status: Deployed
```

### Rollback Workflow

```
1. User runs:
   helm rollback my-app 1

2. Helm client:
   ├─ Fetches revision 1 configuration
   ├─ Re-applies revision 1 manifests
   └─ Creates new revision 3 (same config as revision 1)

3. Kubernetes:
   ├─ Updates resources back to revision 1 state
   ├─ Rolling update to previous config
   └─ No data loss

4. Result:
   Release "my-app" rolled back
   - Current Revision: 3 (config from revision 1)
   - Status: Deployed

History:
  Rev 1: Initial install
  Rev 2: Upgrade (failed or undesired)
  Rev 3: Rollback to Rev 1
```

## values.yaml and Templating

### Values Hierarchy

```
Values merge priority (lowest to highest):

1. Chart's values.yaml (defaults)
   ↓
2. Parent chart's values (if subchart)
   ↓
3. User's values file (-f values.yaml)
   ↓
4. Individual --set parameters
   ↓
Final merged values → Template rendering
```

### Example: values.yaml

```yaml
# Chart's default values.yaml
replicaCount: 1

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
```

### User Override

```yaml
# my-values.yaml
replicaCount: 3         # Override

image:
  tag: "1.22"           # Override

service:
  type: LoadBalancer    # Override

# resources: không override → dùng default
```

### Template Rendering

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-nginx
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: nginx
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

**Rendered output (với my-values.yaml):**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-nginx      # .Release.Name = my-app
spec:
  replicas: 3             # .Values.replicaCount = 3
  template:
    spec:
      containers:
      - name: nginx
        image: "nginx:1.22"  # image.repository:image.tag
        resources:
          limits:
            cpu: 100m        # Default values (not overridden)
            memory: 128Mi
```

## Template Functions and Objects

### Built-in Objects

```yaml
# .Release object
.Release.Name          # Release name (my-app)
.Release.Namespace     # Target namespace
.Release.Service       # Helm (always "Helm")
.Release.IsUpgrade     # true if upgrade
.Release.IsInstall     # true if install
.Release.Revision      # Revision number

# .Chart object
.Chart.Name            # Chart name (nginx)
.Chart.Version         # Chart version (13.2.0)
.Chart.AppVersion      # App version (1.21.0)

# .Values object
.Values.replicaCount   # User-provided values
.Values.image.tag

# .Files object
{{ .Files.Get "config.txt" }}  # Read file from chart

# .Capabilities object
.Capabilities.KubeVersion.Version  # K8s version (1.25.0)
```

### Template Functions

```yaml
# String manipulation
{{ .Values.name | upper }}           # MYAPP
{{ .Values.name | lower }}           # myapp
{{ .Values.name | quote }}           # "myapp"
{{ .Values.name | default "nginx" }} # Use default if empty

# Type conversion
{{ .Values.port | toString }}        # "80"
{{ .Values.enabled | ternary "yes" "no" }}

# YAML/JSON
{{- toYaml .Values.resources | nindent 10 }}
{{- toJson .Values.config }}

# Conditionals
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
{{- end }}

# Loops
{{- range .Values.hosts }}
- host: {{ . }}
{{- end }}

# With (scope)
{{- with .Values.image }}
image: {{ .repository }}:{{ .tag }}
{{- end }}
```

### Template Helpers (_helpers.tpl)

```yaml
# templates/_helpers.tpl
{{/*
Generate fullname
*/}}
{{- define "my-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-chart.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

**Usage:**

```yaml
# templates/deployment.yaml
metadata:
  name: {{ include "my-chart.fullname" . }}
  labels:
    {{- include "my-chart.labels" . | nindent 4 }}
```

## Chart Structure

### Directory Layout

```
my-chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default configuration
├── values.schema.json      # JSON schema validation
├── charts/                 # Dependency charts (subcharts)
├── templates/              # Kubernetes manifests
│   ├── NOTES.txt          # Post-install notes
│   ├── _helpers.tpl       # Template helpers
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   └── tests/             # Helm tests
│       └── test-connection.yaml
├── .helmignore            # Ignore patterns (như .gitignore)
└── README.md              # Chart documentation
```

### Chart.yaml

```yaml
apiVersion: v2                    # Helm 3
name: my-app                      # Chart name
description: My Application       # Short description
type: application                 # application | library
version: 1.0.0                    # Chart version (SemVer)
appVersion: "2.1.0"              # App version

keywords:
  - web
  - nginx

home: https://github.com/myorg/my-app
sources:
  - https://github.com/myorg/my-app

maintainers:
  - name: DevOps Team
    email: devops@company.com

icon: https://example.com/icon.png

dependencies:                     # Chart dependencies
  - name: mysql
    version: 9.3.0
    repository: https://charts.bitnami.com/bitnami
    condition: mysql.enabled     # Conditional dependency
  - name: redis
    version: 17.0.0
    repository: https://charts.bitnami.com/bitnami
    alias: cache                 # Reference as .Values.cache
```

### NOTES.txt

```
# templates/NOTES.txt - Post-install message
Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To access your application:

{{- if .Values.ingress.enabled }}
  Visit: http://{{ .Values.ingress.host }}
{{- else }}
  Run: kubectl port-forward svc/{{ include "my-chart.fullname" . }} 8080:80
  Visit: http://localhost:8080
{{- end }}

To get the admin password:
  kubectl get secret {{ include "my-chart.fullname" . }} -o jsonpath="{.data.password}" | base64 -d
```

## Chart Dependencies

### Dependency Workflow

```
1. Declare dependencies in Chart.yaml:
   dependencies:
     - name: mysql
       version: 9.3.0
       repository: https://charts.bitnami.com/bitnami

2. Download dependencies:
   helm dependency update my-chart/

   Result:
   my-chart/
   ├── charts/
   │   └── mysql-9.3.0.tgz     # Downloaded subchart
   └── Chart.lock              # Lock file (exact versions)

3. Install chart:
   helm install my-app my-chart/

   → Installs my-app + mysql dependency
```

### Configure Subchart Values

```yaml
# my-chart/values.yaml
# Configure parent chart
replicaCount: 3

# Configure subchart (mysql)
mysql:
  auth:
    rootPassword: "supersecret"
    database: myapp_db
    username: myapp_user
    password: "userpass"
  primary:
    persistence:
      enabled: true
      size: 10Gi
```

### Conditional Dependencies

```yaml
# Chart.yaml
dependencies:
  - name: mysql
    condition: mysql.enabled
  - name: postgresql
    condition: postgresql.enabled
```

```yaml
# values.yaml
mysql:
  enabled: true      # Install MySQL

postgresql:
  enabled: false     # Skip PostgreSQL
```

## Common Helm Patterns

### Pattern 1: Environment-specific Values

```bash
# Structure
my-chart/
├── values.yaml              # Defaults
├── values-staging.yaml      # Staging overrides
└── values-production.yaml   # Production overrides

# Deploy to staging
helm install my-app my-chart/ -f values-staging.yaml

# Deploy to production
helm install my-app my-chart/ -f values-production.yaml
```

### Pattern 2: Secrets Management

```yaml
# Don't commit secrets to values.yaml!

# Option 1: --set during install
helm install my-app my-chart/ --set mysql.auth.password=secret

# Option 2: Separate secrets file (gitignored)
helm install my-app my-chart/ -f values.yaml -f secrets.yaml

# Option 3: External secrets (Sealed Secrets, Vault)
# templates/secret.yaml
{{- if .Values.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "my-chart.fullname" . }}
spec:
  secretStoreRef:
    name: vault
  target:
    name: {{ include "my-chart.fullname" . }}-secret
  data:
  - secretKey: password
    remoteRef:
      key: /myapp/database/password
{{- end }}
```

### Pattern 3: Conditional Resources

```yaml
# values.yaml
ingress:
  enabled: false    # Default: no ingress

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
```

```yaml
# templates/ingress.yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "my-chart.fullname" . }}
spec:
  # ... ingress spec
{{- end }}
```

```yaml
# templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "my-chart.fullname" . }}
spec:
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  # ... hpa spec
{{- end }}
```

## Troubleshooting Helm

### Issue 1: Template rendering errors

```bash
# Debug template rendering
helm template my-app my-chart/ --debug

# Show rendered output
helm install my-app my-chart/ --dry-run --debug

# Error example:
Error: template: my-chart/templates/deployment.yaml:10:23:
executing "my-chart/templates/deployment.yaml" at <.Values.image.tg>:
can't evaluate field tg in type interface {}

Fix: Typo in template (.Values.image.tg → .Values.image.tag)
```

### Issue 2: Release stuck in pending-install

```bash
# Symptom
helm list
NAME    STATUS          REVISION
my-app  pending-install 1

# Debug
kubectl get all -l app.kubernetes.io/instance=my-app
# Check pod logs for errors

# Fix: Uninstall and retry
helm uninstall my-app
helm install my-app my-chart/ --debug
```

### Issue 3: Values not applied

```bash
# Check what values were used
helm get values my-app

# Check all values (including defaults)
helm get values my-app --all

# Verify rendered manifest
helm get manifest my-app

# Re-render locally to debug
helm template my-app my-chart/ -f my-values.yaml
```

### Issue 4: Dependency issues

```bash
# Error: found in Chart.yaml, but missing in charts/ directory
helm dependency update my-chart/

# Error: dependency version conflict
# Check Chart.lock vs Chart.yaml
helm dependency build my-chart/

# Force update
rm my-chart/Chart.lock
rm -rf my-chart/charts/
helm dependency update my-chart/
```

## Best Practices

### 1. Version Control Charts

```bash
# Chart versioning (SemVer)
Chart.yaml:
  version: 1.2.3

  Major: Breaking changes (1.x.x → 2.0.0)
  Minor: New features (1.2.x → 1.3.0)
  Patch: Bug fixes (1.2.3 → 1.2.4)

# Tag releases
git tag -a chart-v1.2.3 -m "Release v1.2.3"
```

### 2. Use helm lint

```bash
# Validate chart before install
helm lint my-chart/

# Output shows warnings/errors
==> Linting my-chart/
[INFO] Chart.yaml: icon is recommended
[ERROR] templates/: template validation error
```

### 3. Document values

```yaml
# values.yaml với comments
## Number of replicas
## @param replicaCount - Number of pod replicas
replicaCount: 1

## Image configuration
## @param image.repository - Image repository
## @param image.tag - Image tag
image:
  repository: nginx
  tag: "1.21"
```

### 4. Use .helmignore

```
# .helmignore
.git/
.gitignore
*.md
*.txt
ci/
test/
```

### 5. Atomic Installs

```bash
# Rollback automatically if install fails
helm install my-app my-chart/ --atomic --timeout 5m

# Rollback automatically if upgrade fails
helm upgrade my-app my-chart/ --atomic --timeout 5m
```

## Tóm tắt

Helm là package manager cho Kubernetes:

**Core Concepts:**
- Chart: Package of K8s manifests (template)
- Release: Running instance of chart
- Repository: Storage for charts
- Values: Configuration parameters

**Key Commands:**
- `helm install`: Deploy chart
- `helm upgrade`: Update release
- `helm rollback`: Revert to previous version
- `helm uninstall`: Remove release

**Templating:**
- values.yaml: Configuration
- Templates: K8s manifests với variables
- Functions: upper, default, toYaml, if, range
- Helpers: Reusable template snippets

**Benefits:**
- Version management and rollback
- Templating (DRY principle)
- Dependency management
- Sharing and reusability

**Next:** Day 85 sẽ học K8s Monitoring với Prometheus và Grafana.
