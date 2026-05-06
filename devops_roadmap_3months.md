# 🚀 DevOps Roadmap 3 Tháng — Lộ Trình Từng Ngày

> **Mục tiêu:** Nắm vững Linux, Docker, CI/CD, Kubernetes, Network & Nginx trong 90 ngày  
> **Thời gian học:** 2–3 giờ/ngày  
> **Nguyên tắc:** Học lý thuyết → Thực hành ngay → Làm project nhỏ cuối tuần

---

## 📅 THÁNG 1: Linux & Docker Foundation (Ngày 1–30)

### 🐧 TUẦN 1 — Linux Command Line Cơ Bản (Ngày 1–7)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
|✅ **Ngày 1** | Giới thiệu Linux | Linux là gì, các distro phổ biến (Ubuntu, CentOS, Alpine), cài Ubuntu Server/WSL2 | Cài đặt môi trường, login SSH lần đầu |
|✅ **Ngày 2** | Navigation cơ bản | `pwd`, `ls`, `cd`, `mkdir`, `rmdir`, `touch`, `rm`, `cp`, `mv` | Tạo cấu trúc thư mục dự án giả lập | 
|✅ **Ngày 3** | Xem & chỉnh sửa file | `cat`, `less`, `more`, `head`, `tail`, `nano`, `vim` cơ bản | Đọc log file, chỉnh sửa config đơn giản |
|✅ **Ngày 4** | Permissions & Ownership | `chmod`, `chown`, `chgrp`, `umask`, `ls -la`, hiểu rwx | Set permission cho script deploy |
|✅ **Ngày 5** | Users & Groups | `useradd`, `usermod`, `passwd`, `su`, `sudo`, `/etc/passwd`, `/etc/shadow` | Tạo user deploy riêng biệt cho app |
|✅ **Ngày 6** | Process Management | `ps`, `top`, `htop`, `kill`, `pkill`, `jobs`, `bg`, `fg`, `nohup`, `&` | Monitor process, kill hung process |
|✅ **Ngày 7** | **Thực hành tổng hợp** | Ôn tập + mini project: Setup server Ubuntu từ đầu với user/permission đúng chuẩn | Deploy một script bash đơn giản |

---

### 🐧 TUẦN 2 — Linux Nâng Cao (Ngày 8–14)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
|✅ **Ngày 8** | Text Processing | `grep`, `awk`, `sed`, `cut`, `sort`, `uniq`, `wc`, pipes `|` | Parse log nginx tìm IP access nhiều nhất |
|✅ **Ngày 9** | File System & Disk | `df`, `du`, `mount`, `umount`, `lsblk`, `fdisk` cơ bản, `/etc/fstab` | Kiểm tra disk usage, tìm file chiếm dung lượng |
|✅ **Ngày 10** | Networking cơ bản Linux | `ip`, `ifconfig`, `ping`, `netstat`, `ss`, `curl`, `wget`, `traceroute` | Debug kết nối mạng, test endpoint API |
|✅ **Ngày 11** | Package Management | `apt`/`apt-get`, `dpkg`, `snap`, cập nhật hệ thống, install/remove package | Cài LAMP stack thủ công |
|✅ **Ngày 12** | Bash Scripting cơ bản | Variables, if/else, for/while loop, functions, arguments `$1 $2`, exit code | Viết script backup file tự động |
|✅ **Ngày 13** | Bash Scripting nâng cao | `cron`, `crontab -e`, scheduling, `systemd` service cơ bản, `journalctl` | Tạo cronjob dọn log cũ mỗi đêm |
|✅ **Ngày 14** | **Project cuối tuần** | Build script deploy app Node.js/Python thủ công: clone repo, install deps, restart service | Script production-ready với error handling |

---

### 🐧 TUẦN 3 — SSH, Security & Môi Trường Thực Tế (Ngày 15–17) + Docker Bắt Đầu (Ngày 18–21)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
|✅ **Ngày 15** | SSH & Remote Access | `ssh-keygen`, `ssh-copy-id`, `~/.ssh/config`, port forwarding, `scp`, `rsync` | Setup SSH key-based auth, copy file lên server |
|✅ **Ngày 16** | Firewall cơ bản | `ufw`, `iptables` cơ bản, mở/đóng port, `fail2ban` | Hardening server: chỉ cho phép port cần thiết |
|✅ **Ngày 17** | Environment Variables | `export`, `.env`, `.bashrc`, `.bash_profile`, `source`, `printenv` | Quản lý config theo môi trường dev/prod |
|✅ **Ngày 18** | Docker Introduction | Container vs VM, Docker architecture, `docker pull`, `docker run`, `docker ps` | Chạy container Nginx, Hello World |
|✅ **Ngày 19** | Docker Images | `docker images`, `docker build`, `Dockerfile` cơ bản: `FROM`, `RUN`, `CMD`, `COPY` | Build image cho app Node.js đơn giản |
|✅ **Ngày 20** | Dockerfile nâng cao | `EXPOSE`, `ENV`, `ARG`, `WORKDIR`, `ENTRYPOINT`, multi-stage builds, `.dockerignore` | Build image production tối ưu cho Python Flask |
|✅ **Ngày 21** | **Thực hành Docker** | Ôn tập + Dockerize một app thực tế (React hoặc Node.js) | Image size phải < 200MB |

---

### 🐳 TUẦN 4 — Docker Compose & Container Management (Ngày 22–30)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
|✅ **Ngày 22** | Docker Volumes & Networks | `docker volume`, `docker network`, bridge/host/overlay network, mount bind | App container kết nối database container |
|✅ **Ngày 23** | Docker Compose cơ bản | `docker-compose.yml`, `services`, `version`, `up`, `down`, `logs`, `exec` | Compose app + database (PostgreSQL) |
|✅**Ngày 24** | Docker Compose nâng cao | `depends_on`, `healthcheck`, `restart policy`, `environment`, `networks` | Compose full stack: frontend + backend + DB |
| **Ngày 25** | Docker Registry | Docker Hub, push/pull image, `docker tag`, private registry, image versioning | Push image lên Docker Hub với tag version |
| **Ngày 26** | Docker Resource & Security | CPU/memory limits, `docker stats`, non-root user, read-only filesystem | Hardening container production |
| **Ngày 27** | Docker Troubleshooting | `docker logs`, `docker inspect`, `docker exec -it`, debug container crash | Debug app container không start được |
| **Ngày 28** | **Project Tháng 1** | Deploy full-stack app (React + Node.js + PostgreSQL + Redis) bằng Docker Compose | App chạy được, có healthcheck, auto-restart |
| **Ngày 29** | Review & Document | Viết README.md cho project, document Dockerfile và compose file | PR documentation đạt chuẩn |
| **Ngày 30** | **Ôn tập & Test** | Kiểm tra lại toàn bộ kiến thức tháng 1, làm quiz/flashcard | Có thể setup từ đầu không cần Google |

---

## 📅 THÁNG 2: CI/CD & GitHub Actions (Ngày 31–60)

### ⚙️ TUẦN 5 — Git & GitHub Nâng Cao (Ngày 31–35) + CI/CD Foundation (Ngày 36–37)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 31** | Git workflow nâng cao | Git branching strategy: GitFlow, GitHub Flow, trunk-based development | Setup branch protection rules |
| **Ngày 32** | GitHub PRs & Code Review | Pull Request, review checklist, merge strategies (squash/rebase/merge) | Tạo PR template cho team |
| **Ngày 33** | GitHub Secrets & Environments | `Settings > Secrets`, environment variables trong repo, `github.env` | Store AWS credentials, DB password vào secrets |
| **Ngày 34** | CI/CD là gì? | Khái niệm CI, CD, pipeline, artifact, trigger, runner, job, step | Vẽ sơ đồ pipeline cho dự án thực tế |
| **Ngày 35** | GitHub Actions cơ bản | `.github/workflows/`, YAML syntax, `on`, `jobs`, `steps`, `uses`, `run` | Tạo workflow in ra Hello World khi push code |
| **Ngày 36** | Triggers & Events | `push`, `pull_request`, `schedule`, `workflow_dispatch`, `on.branches` | Workflow chỉ chạy khi push lên `main` |
| **Ngày 37** | **Thực hành** | Build workflow CI: checkout → install → lint → test | Workflow xanh/đỏ rõ ràng trên GitHub |

---

### ⚙️ TUẦN 6 — CI Pipeline Thực Tế (Ngày 38–44)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 38** | Build & Test tự động | `actions/setup-node`, `actions/setup-python`, cache dependencies | CI cho Node.js app: install + test + coverage |
| **Ngày 39** | Docker trong CI | Build Docker image trong workflow, `docker/build-push-action`, layer caching | CI tự build và push image lên Docker Hub |
| **Ngày 40** | Matrix Strategy | `strategy.matrix` để test nhiều version (Node 18, 20, 22) | Test app trên 3 version Node cùng lúc |
| **Ngày 41** | Artifacts & Reports | `actions/upload-artifact`, `actions/download-artifact`, test reports, coverage badge | Upload test results, download và dùng ở job khác |
| **Ngày 42** | Reusable Workflows | `workflow_call`, composite actions, `uses: ./.github/workflows/` | Tách CI thành reusable components |
| **Ngày 43** | Security Scanning trong CI | `trivy` scan Docker image, `snyk`, SAST tools, dependency audit | CI block deploy nếu có critical vulnerability |
| **Ngày 44** | **Project CI** | Full CI pipeline: lint → test → build docker → scan → push image | Pipeline chạy < 5 phút |

---

### ⚙️ TUẦN 7 — CD Pipeline & Deploy (Ngày 45–51)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 45** | Deploy strategies | Rolling update, Blue/Green, Canary deployment, feature flags | So sánh ưu/nhược từng strategy |
| **Ngày 46** | Deploy lên VPS/EC2 | SSH action, `appleboy/ssh-action`, rsync qua CI, deploy script | CD tự động push code lên server khi merge PR |
| **Ngày 47** | Docker Hub & Registry CD | Tag image theo `git sha`, `latest`, semantic versioning, rollback | CD push `v1.2.3` tag lên production |
| **Ngày 48** | Environment Protection | `environments` trong GitHub, required reviewers, deployment gates | Approve thủ công trước khi deploy production |
| **Ngày 49** | Notifications & Monitoring | Slack notification, Discord webhook, email on failure, `actions/github-script` | Nhận thông báo Slack khi deploy thành công/fail |
| **Ngày 50** | Rollback Strategy | Revert commit, rollback bằng tag, health check sau deploy | Script rollback tự động nếu healthcheck fail |
| **Ngày 51** | **Project CD** | Full CD: merge PR → CI pass → auto deploy staging → manual approve → deploy prod | Zero-downtime deployment |

---

### ⚙️ TUẦN 8 — Review, Monitoring & Best Practices (Ngày 52–60)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 52** | Infrastructure as Code intro | Khái niệm IaC, tại sao cần, Terraform cơ bản | Đọc và hiểu Terraform plan |
| **Ngày 53** | GitHub Actions Best Practices | Secrets rotation, pin action versions, least privilege, OIDC auth | Audit lại workflow, fix security issues |
| **Ngày 54** | Self-hosted Runners | Setup GitHub runner trên VPS, labels, runner groups | Runner tự host chạy pipeline nhanh hơn |
| **Ngày 55** | Observability cơ bản | Logs, Metrics, Traces (3 pillars), ELK stack giới thiệu | Tích hợp log từ container vào Loki/ELK |
| **Ngày 56** | Prometheus & Grafana cơ bản | `docker-compose` stack monitoring, scrape metrics, dashboard | Dashboard theo dõi CPU/RAM/HTTP request |
| **Ngày 57** | Alerting | Alert rules trong Grafana/Prometheus, PagerDuty, Alertmanager | Alert khi CPU > 80% hoặc error rate tăng |
| **Ngày 58** | **Project Tháng 2** | Full DevOps pipeline: code → CI → CD → staging → production + monitoring | App được monitor end-to-end |
| **Ngày 59** | Review & Document | Viết post-mortem giả lập, diagram pipeline, runbook | Documentation đủ để người khác tiếp quản |
| **Ngày 60** | **Ôn tập & Test tháng 2** | Quiz CI/CD, troubleshoot pipeline lỗi cố ý | Debug được pipeline fail trong < 15 phút |

---

## 📅 THÁNG 3: Kubernetes & Networking (Ngày 61–90)

### ☸️ TUẦN 9 — Kubernetes Foundation (Ngày 61–67)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 61** | Kubernetes là gì? | Container orchestration, so sánh với Docker Compose, architecture: master/worker nodes | Cài minikube hoặc kind trên local |
| **Ngày 62** | Kubernetes Components | API Server, etcd, Scheduler, Controller Manager, kubelet, kube-proxy | Vẽ sơ đồ K8s architecture |
| **Ngày 63** | kubectl cơ bản | `kubectl get`, `kubectl describe`, `kubectl apply`, `kubectl delete`, `kubectl logs` | Deploy nginx pod đầu tiên |
| **Ngày 64** | Pod & Deployment | Pod lifecycle, `Deployment`, `ReplicaSet`, rolling update, rollback | Deploy app với 3 replicas |
| **Ngày 65** | Service | `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName`, DNS trong cluster | Expose app ra ngoài cluster |
| **Ngày 66** | ConfigMap & Secret | `ConfigMap`, `Secret`, inject vào Pod qua env/volume, base64 encoding | App đọc config từ ConfigMap |
| **Ngày 67** | **Thực hành K8s** | Deploy full app (backend + frontend + DB) trên minikube | Tất cả services giao tiếp được với nhau |

---

### ☸️ TUẦN 10 — Kubernetes Nâng Cao (Ngày 68–74)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 68** | Namespace & RBAC | Namespace isolation, `Role`, `ClusterRole`, `RoleBinding`, service account | Tạo namespace riêng cho dev/staging/prod |
| **Ngày 69** | Persistent Storage | `PersistentVolume`, `PersistentVolumeClaim`, StorageClass, stateful apps | Database với persistent storage |
| **Ngày 70** | StatefulSet | Khi nào dùng StatefulSet vs Deployment, headless service, ordered pod | Deploy PostgreSQL bằng StatefulSet |
| **Ngày 71** | Resource Management | `requests`, `limits`, `LimitRange`, `ResourceQuota`, VPA/HPA cơ bản | Set resource limits cho mọi container |
| **Ngày 72** | HPA - Auto Scaling | `HorizontalPodAutoscaler`, metrics-server, scale dựa trên CPU/memory | App tự scale khi load tăng |
| **Ngày 73** | Health Checks | `livenessProbe`, `readinessProbe`, `startupProbe`, probe types (HTTP/TCP/Exec) | App không nhận traffic khi chưa sẵn sàng |
| **Ngày 74** | **Project K8s** | Deploy microservices 3 services (user, product, order) trên K8s với full config | Services khỏe mạnh, auto-heal khi crash |

---

### 🌐 TUẦN 11 — Network & Nginx (Ngày 75–81)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 75** | Networking fundamentals | OSI model, TCP/IP, DNS, HTTP/HTTPS, TLS/SSL, port, socket cơ bản | Trace một HTTP request từ browser đến server |
| **Ngày 76** | Nginx cơ bản | Cài Nginx, `nginx.conf` structure, `server block`, `location block`, `proxy_pass` | Serve static files với Nginx |
| **Ngày 77** | Nginx Reverse Proxy | Reverse proxy cho Node.js/Python app, `upstream`, load balancing, header forwarding | Nginx → forward request đến app port 3000 |
| **Ngày 78** | Nginx SSL/TLS | Cài SSL với Let's Encrypt + Certbot, HTTPS redirect, HSTS, cert renewal | Website chạy HTTPS với certificate miễn phí |
| **Ngày 79** | Nginx Load Balancing | `upstream` với `least_conn`, `ip_hash`, `weight`, health checks, passive failover | 3 backend instances, Nginx cân bằng tải |
| **Ngày 80** | Nginx Performance | `gzip`, `brotli`, browser caching, `sendfile`, `keepalive`, rate limiting, buffering | Trang tải nhanh hơn, PageSpeed tăng |
| **Ngày 81** | **Thực hành Nginx** | Setup production-ready Nginx: SSL + reverse proxy + rate limiting + logging | Security headers đạt chuẩn (A+ trên SSL Labs) |

---

### ☸️🌐 TUẦN 12 — Kubernetes Ingress, Network & Final Project (Ngày 82–90)

| Ngày | Chủ đề | Nội dung chi tiết | Bài tập thực hành |
|------|--------|-------------------|-------------------|
| **Ngày 82** | Kubernetes Ingress | `Ingress`, `IngressClass`, Nginx Ingress Controller, path-based routing | Route `/api` → backend, `/` → frontend |
| **Ngày 83** | K8s Network Policies | `NetworkPolicy`, ingress/egress rules, namespace isolation, pod selector | Frontend chỉ được gọi backend, không gọi DB |
| **Ngày 84** | Helm cơ bản | Helm là gì, `helm install`, `helm upgrade`, `values.yaml`, chart structure | Deploy Nginx Ingress bằng Helm |
| **Ngày 85** | K8s Monitoring | Prometheus Operator, ServiceMonitor, Grafana trên K8s, `kubectl top` | Dashboard theo dõi toàn bộ cluster |
| **Ngày 86** | K8s Logging | Fluentd/Fluent Bit, ELK/Loki trên K8s, centralized logging | Log từ mọi pod về một nơi |
| **Ngày 87** | **Final Project — Ngày 1** | Deploy full production stack: K8s + Ingress (Nginx) + SSL + CI/CD pipeline | Setup infrastructure hoàn chỉnh |
| **Ngày 88** | **Final Project — Ngày 2** | Thêm monitoring (Prometheus + Grafana) + alerting + centralized logging | Observability đầy đủ |
| **Ngày 89** | **Final Project — Ngày 3** | Viết documentation: Architecture diagram, runbook, disaster recovery plan | Có thể bàn giao cho người khác |
| **Ngày 90** | **Tổng kết 3 tháng** | Review toàn bộ, làm bài test thực hành tổng hợp, plan học tiếp (Terraform, ArgoCD) | Tự deploy app từ A→Z trong 2 giờ |

---

## 🎯 Tổng Kết Lộ Trình

### Kiến thức đạt được sau 90 ngày

| Kỹ năng | Mức độ |
|---------|--------|
| Linux Command Line | ⭐⭐⭐⭐⭐ Thành thạo |
| Bash Scripting | ⭐⭐⭐⭐ Tốt |
| Docker & Docker Compose | ⭐⭐⭐⭐⭐ Thành thạo |
| GitHub Actions CI/CD | ⭐⭐⭐⭐ Tốt |
| Kubernetes | ⭐⭐⭐ Nền tảng vững |
| Nginx & Networking | ⭐⭐⭐⭐ Tốt |
| Monitoring & Logging | ⭐⭐⭐ Cơ bản |

---

### 📚 Tài Nguyên Học Tập

**Linux:**
- [linuxcommand.org](https://linuxcommand.org) — free, rất tốt cho beginners
- TryHackMe Linux Fundamentals (thực hành trên browser)

**Docker:**
- Docker Official Docs: [docs.docker.com](https://docs.docker.com)
- Play with Docker: [labs.play-with-docker.com](https://labs.play-with-docker.com)

**GitHub Actions:**
- [docs.github.com/en/actions](https://docs.github.com/en/actions)
- Khóa học GitHub Actions trên YouTube (TechWorld with Nana)

**Kubernetes:**
- [kubernetes.io/docs](https://kubernetes.io/docs/home/)
- KillerCoda interactive labs (miễn phí)
- CKA exam prep nếu muốn chứng chỉ

**Nginx:**
- [nginx.org/en/docs](https://nginx.org/en/docs/)
- DigitalOcean Nginx tutorials (rất chi tiết)

---

### 💡 Tips từ Senior DevOps

1. **Đừng skip thực hành** — 70% thời gian phải gõ lệnh thật, không chỉ đọc
2. **Break things on purpose** — xóa pod, kill process, xem hệ thống tự recover
3. **Document mọi thứ** — tạo thói quen viết README và runbook từ sớm
4. **Dùng cloud free tier** — AWS Free Tier, GCP Free Tier để thực hành thật
5. **Join community** — DevOps VN Facebook group, CNCF Slack, Reddit r/devops
6. **Học incident mindset** — luôn hỏi "nếu thứ này down thì sao?"

---

*Roadmap được thiết kế bởi Senior DevOps — Cập nhật 2025*
