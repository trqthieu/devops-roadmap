# Cheatsheet: Day 90 - Tổng kết 90 ngày DevOps Journey

## Journey Overview

```
90-Day DevOps Roadmap - Completed!

Month 1 (Days 1-30): Linux & Docker Foundation
  ✅ Week 1: Linux basics (navigation, files, permissions)
  ✅ Week 2: Advanced Linux (text processing, networking, scripting)
  ✅ Week 3: SSH, Security, Docker introduction
  ✅ Week 4: Docker Compose, Container management

Month 2 (Days 31-60): CI/CD & GitHub Actions
  ✅ Week 5-6: Git workflows, GitHub Actions, CI pipelines
  ✅ Week 7: CD pipelines, deployment strategies
  ✅ Week 8: IaC, monitoring (Prometheus/Grafana)

Month 3 (Days 61-90): Kubernetes & Production
  ✅ Week 9-10: Kubernetes fundamentals, advanced concepts
  ✅ Week 11: Nginx, networking fundamentals
  ✅ Week 12: K8s Ingress, Helm, Final Production Project
```

## Skills Acquired

### Month 1: Foundation

```bash
Linux Command Line:
  ✓ Navigation: cd, ls, pwd, tree
  ✓ File operations: cp, mv, rm, mkdir, touch
  ✓ Permissions: chmod, chown, umask
  ✓ Text processing: grep, sed, awk, cut, sort
  ✓ Networking: curl, wget, netstat, ss, ip
  ✓ Process management: ps, top, kill, systemctl
  ✓ Bash scripting: variables, loops, conditionals, functions

Docker:
  ✓ Container basics: run, stop, rm, exec
  ✓ Images: build, tag, push, pull
  ✓ Volumes: mount, data persistence
  ✓ Networks: bridge, host, custom networks
  ✓ Docker Compose: multi-container apps
  ✓ Dockerfile: multi-stage builds, optimization
```

### Month 2: CI/CD

```bash
Git & GitHub:
  ✓ Version control: commit, branch, merge, rebase
  ✓ Workflows: feature branch, GitFlow
  ✓ Collaboration: pull requests, code review

GitHub Actions:
  ✓ CI pipelines: build, test, lint
  ✓ CD pipelines: deploy to staging/production
  ✓ Secrets management: GitHub Secrets
  ✓ Matrix builds: multi-platform testing
  ✓ Artifacts: build outputs, test reports

Monitoring:
  ✓ Prometheus: metrics collection, PromQL queries
  ✓ Grafana: dashboards, visualization
  ✓ Alerting: alert rules, Alertmanager
```

### Month 3: Kubernetes

```bash
Kubernetes Core:
  ✓ Pods, Deployments, Services, ConfigMaps, Secrets
  ✓ StatefulSets: stateful applications
  ✓ DaemonSets: node-level agents
  ✓ Jobs, CronJobs: batch workloads
  ✓ PersistentVolumes: data persistence
  ✓ Namespaces: resource isolation

Advanced Concepts:
  ✓ Ingress: L7 routing, SSL/TLS
  ✓ Network Policies: micro-segmentation
  ✓ HPA: auto-scaling
  ✓ RBAC: access control
  ✓ Helm: package management

Production Skills:
  ✓ Monitoring: Prometheus Operator, ServiceMonitor
  ✓ Logging: Loki, Promtail, LogQL
  ✓ CI/CD integration: automated deployments
  ✓ Documentation: runbooks, disaster recovery
```

## Key Projects Completed

### Project 1: Containerized Application

```
Week 3-4: Docker Multi-container App

Components:
  - Frontend: Nginx serving static site
  - Backend: Node.js API
  - Database: PostgreSQL
  - Redis: Caching layer

Skills demonstrated:
  ✓ Dockerfile creation
  ✓ Docker Compose orchestration
  ✓ Volume management
  ✓ Network configuration
  ✓ Environment variables
```

### Project 2: CI/CD Pipeline

```
Week 5-8: Automated Build & Deploy

Pipeline:
  1. Code push → GitHub
  2. GitHub Actions triggered
  3. Lint + Test
  4. Build Docker image
  5. Push to registry
  6. Deploy to staging
  7. Manual approval
  8. Deploy to production

Skills demonstrated:
  ✓ Workflow YAML
  ✓ Matrix builds
  ✓ Secrets management
  ✓ Deployment strategies
  ✓ Rollback procedures
```

### Project 3: Production Kubernetes Stack

```
Week 12: Full Production Deployment

Components:
  - Kubernetes cluster (3 nodes)
  - Nginx Ingress Controller
  - SSL/TLS (cert-manager + Let's Encrypt)
  - Multi-tier app (Frontend, Backend, Database)
  - Monitoring (Prometheus + Grafana)
  - Logging (Loki + Promtail)
  - CI/CD (GitHub Actions)
  - Network Policies
  - HPA (auto-scaling)

Skills demonstrated:
  ✓ Cluster setup
  ✓ Ingress configuration
  ✓ SSL automation
  ✓ StatefulSet management
  ✓ ServiceMonitor creation
  ✓ PrometheusRule (alerting)
  ✓ LogQL queries
  ✓ Grafana dashboards
  ✓ Documentation (runbooks, DR plans)
  ✓ Production-ready deployment
```

## Command Mastery Checklist

### Linux (Month 1)

```bash
# File operations ✓
ls -lah                           # list with details
find . -name "*.log"              # find files
grep -r "error" /var/log/         # search in files
sed 's/old/new/g' file.txt        # replace text
awk '{print $1}' file.txt         # extract columns

# System operations ✓
systemctl status nginx            # check service
ps aux | grep nginx               # find process
top                               # monitor resources
df -h                            # disk usage
du -sh /var/log/*                # directory sizes

# Networking ✓
curl -I https://example.com       # HTTP headers
netstat -tulpn                   # listening ports
ip addr show                     # IP addresses
ping -c 3 8.8.8.8                # network test
```

### Docker (Month 1)

```bash
# Container lifecycle ✓
docker run -d -p 80:80 nginx     # run detached
docker ps                         # list running
docker stop <container>          # stop
docker rm <container>            # remove
docker logs -f <container>       # follow logs
docker exec -it <container> sh   # interactive shell

# Image management ✓
docker build -t myapp:v1 .       # build image
docker images                     # list images
docker tag myapp:v1 user/myapp:v1 # tag image
docker push user/myapp:v1        # push to registry
docker rmi <image>               # remove image

# Docker Compose ✓
docker-compose up -d             # start services
docker-compose ps                # list services
docker-compose logs -f           # follow logs
docker-compose down              # stop and remove
```

### Git & GitHub Actions (Month 2)

```bash
# Git workflow ✓
git clone <repo>                 # clone repository
git checkout -b feature-branch   # create branch
git add .                        # stage changes
git commit -m "message"          # commit
git push origin feature-branch   # push branch
git merge main                   # merge branch
git rebase main                  # rebase

# GitHub CLI ✓
gh pr create                     # create PR
gh pr list                       # list PRs
gh pr merge 123                  # merge PR
gh workflow list                 # list workflows
gh run view                      # view run details
```

### Kubernetes (Month 3)

```bash
# Resource management ✓
kubectl get pods -A              # all pods
kubectl describe pod <pod>       # pod details
kubectl logs <pod> -f            # follow logs
kubectl exec -it <pod> -- sh     # shell into pod
kubectl apply -f manifest.yaml   # apply config
kubectl delete -f manifest.yaml  # delete resources

# Deployments ✓
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3
kubectl set image deployment/nginx nginx=nginx:1.21
kubectl rollout status deployment/nginx
kubectl rollout undo deployment/nginx

# Services & Networking ✓
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc                  # list services
kubectl get ingress              # list ingress
kubectl get networkpolicy        # network policies

# Debugging ✓
kubectl get events --sort-by='.lastTimestamp'
kubectl top nodes                # node resources
kubectl top pods                 # pod resources
kubectl describe node <node>     # node details
```

### Helm (Month 3)

```bash
# Repository management ✓
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update                 # update repos
helm search repo nginx           # search charts

# Chart operations ✓
helm install my-nginx bitnami/nginx -f values.yaml
helm list                        # list releases
helm upgrade my-nginx bitnami/nginx --set replicaCount=3
helm rollback my-nginx 1         # rollback to revision 1
helm uninstall my-nginx          # uninstall release

# Chart development ✓
helm create my-chart             # create chart
helm lint my-chart/              # validate chart
helm template my-chart/          # render templates
helm package my-chart/           # package chart
```

### Monitoring & Logging (Month 3)

```bash
# Prometheus ✓
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# PromQL queries
up{job="backend"}                # check targets up
rate(http_requests_total[5m])    # request rate
histogram_quantile(0.95, ...)    # p95 latency

# Grafana ✓
kubectl port-forward -n monitoring svc/grafana 3000:80

# Loki/LogQL ✓
{namespace="production"}         # namespace logs
{app="backend"} |= "error"       # filter errors
rate({namespace="production"}[5m]) # log rate
```

## Knowledge Progression

### Week 1 vs Week 12

```
Day 1: Complete Beginner
  ❓ "What is a container?"
  ❓ "How do I connect to a server?"
  ❓ "What is DevOps?"

Day 90: Production-Ready DevOps Engineer
  ✅ Design and deploy production Kubernetes clusters
  ✅ Implement CI/CD pipelines with automated testing
  ✅ Monitor applications with Prometheus and Grafana
  ✅ Manage logs with Loki and analyze with LogQL
  ✅ Secure applications with Network Policies and TLS
  ✅ Scale applications automatically with HPA
  ✅ Debug production issues using observability tools
  ✅ Write runbooks and documentation
  ✅ Perform disaster recovery procedures

Transformation:
  "I don't know what kubectl is"
  →
  "I can deploy a production-grade K8s stack with monitoring, logging, CI/CD, and DR plans"
```

## Self-Assessment Test

### Beginner to Expert Roadmap

```
Level 1: Beginner (Day 1-30)
  ☐ Understand Linux file system
  ☐ Navigate with command line
  ☐ Manage files and permissions
  ☐ Write basic bash scripts
  ☐ Run Docker containers
  ☐ Build Docker images
  ☐ Use Docker Compose

Level 2: Intermediate (Day 31-60)
  ☐ Create Git branches and PRs
  ☐ Write GitHub Actions workflows
  ☐ Build CI pipelines
  ☐ Deploy with CD pipelines
  ☐ Query metrics with PromQL
  ☐ Create Grafana dashboards
  ☐ Configure Alertmanager

Level 3: Advanced (Day 61-90)
  ☐ Deploy Kubernetes applications
  ☐ Configure Ingress and SSL/TLS
  ☐ Implement Network Policies
  ☐ Use Helm charts
  ☐ Setup Prometheus Operator
  ☐ Query logs with LogQL
  ☐ Implement HPA
  ☐ Write runbooks
  ☐ Perform disaster recovery

Level 4: Expert (Post-90 days - Next Steps)
  ☐ Terraform/IaC
  ☐ Service Mesh (Istio, Linkerd)
  ☐ ArgoCD/GitOps
  ☐ Kubernetes Operators
  ☐ Multi-cluster management
  ☐ Cost optimization
  ☐ Security hardening (OPA, Falco)
```

## Next Steps Roadmap

### Immediate Next Steps (Days 91-120)

```
Focus Area 1: Terraform (Infrastructure as Code)
  Week 13: Terraform basics
    - Resources, providers, state
    - Variables, outputs
    - Modules

  Week 14: Terraform advanced
    - Remote state (S3/GCS)
    - Workspaces (staging/prod)
    - Import existing resources

  Week 15: Provision Kubernetes with Terraform
    - GKE/EKS/AKS cluster
    - Node pools
    - Networking

Focus Area 2: GitOps with ArgoCD
  Week 16: ArgoCD setup
    - Install ArgoCD
    - Connect Git repository
    - Deploy applications

  Week 17: Advanced ArgoCD
    - App of Apps pattern
    - Sync waves
    - Rollback strategies

Focus Area 3: Service Mesh
  Week 18: Istio basics
    - Install Istio
    - Traffic management
    - Security (mTLS)

Resources:
  - Terraform docs: https://terraform.io/docs
  - ArgoCD docs: https://argo-cd.readthedocs.io
  - Istio docs: https://istio.io/docs
```

### Long-term Goals (6-12 months)

```
Expertise Development:

1. Cloud Certifications
   - AWS Certified Solutions Architect
   - Google Cloud Professional Cloud Architect
   - Certified Kubernetes Administrator (CKA)
   - Certified Kubernetes Application Developer (CKAD)

2. Advanced Topics
   - Kubernetes Operators (write custom controllers)
   - eBPF and Cilium (advanced networking)
   - Platform Engineering (internal developer platforms)
   - SRE practices (error budgets, SLOs)

3. Programming Skills
   - Go (for Kubernetes tooling)
   - Python (for automation)
   - Understand K8s source code

4. Production Experience
   - On-call rotation (incident response)
   - Capacity planning
   - Cost optimization
   - Multi-region deployments
```

## Resources for Continued Learning

```
Documentation:
  ✓ Kubernetes docs: https://kubernetes.io/docs
  ✓ Docker docs: https://docs.docker.com
  ✓ Prometheus docs: https://prometheus.io/docs
  ✓ Grafana docs: https://grafana.com/docs

Books:
  ✓ "Kubernetes in Action" - Marko Luksa
  ✓ "The DevOps Handbook" - Gene Kim
  ✓ "Site Reliability Engineering" - Google
  ✓ "Terraform: Up & Running" - Yevgeniy Brikman

Communities:
  ✓ CNCF Slack: https://slack.cncf.io
  ✓ Kubernetes Slack: #kubernetes-users
  ✓ r/kubernetes, r/devops (Reddit)
  ✓ DevOps Slack communities

Practice Platforms:
  ✓ KillerCoda: Interactive K8s scenarios
  ✓ Katacoda: Free interactive tutorials
  ✓ Play with Kubernetes: Browser-based K8s
  ✓ Cloud free tiers: GCP, AWS, Azure

YouTube Channels:
  ✓ TechWorld with Nana (DevOps tutorials)
  ✓ That DevOps Guy (K8s deep dives)
  ✓ CNCF Official (conference talks)
```

## Celebration and Reflection

```
🎉 Congratulations! 90 Days Completed! 🎉

You've transformed from:
  "What is DevOps?"

To:
  "I deployed a production Kubernetes stack with monitoring,
   logging, CI/CD, auto-scaling, and disaster recovery plans!"

Skills acquired:
  ✅ Linux command line mastery
  ✅ Docker containerization
  ✅ CI/CD pipelines (GitHub Actions)
  ✅ Kubernetes orchestration
  ✅ Monitoring and Logging (Prometheus, Grafana, Loki)
  ✅ Infrastructure automation (Helm, YAML manifests)
  ✅ Production operations (runbooks, incident response)
  ✅ Documentation and handover

Portfolio pieces:
  ✓ GitHub repository with 90 days of learning
  ✓ Production Kubernetes deployment
  ✓ CI/CD pipeline configurations
  ✓ Monitoring dashboards
  ✓ Documentation (runbooks, architecture diagrams)

Next chapter:
  → Continue learning (Terraform, ArgoCD, Service Mesh)
  → Get certified (CKA, CKAD, Cloud certifications)
  → Build real-world projects
  → Contribute to open source
  → Share knowledge (blog, mentoring)

The journey doesn't end here - it's just beginning!
Keep learning, keep building, keep growing! 🚀
```
