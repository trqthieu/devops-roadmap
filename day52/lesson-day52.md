# 📘 Ngày 52: Infrastructure as Code (IaC) Introduction

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu concept của Infrastructure as Code, tại sao cần IaC, và học Terraform basics để provision infrastructure bằng code thay vì manual configuration.

---

## Tại Sao Cần Infrastructure as Code?

### Vấn Đề: Manual Infrastructure Setup

```
❌ Traditional manual setup:

1. Login to cloud provider UI (AWS Console, DigitalOcean)
2. Click through 20+ screens to create VPS
3. Manually configure:
   - Instance type
   - Region
   - Security groups
   - SSH keys
   - Networking
4. Wait for provisioning
5. Manually install software via SSH
6. Take screenshots/notes for documentation
7. Repeat for staging, production environments

Problems:
- Time consuming: 1-2 hours per environment
- Error-prone: Forgot to open port, wrong settings
- Not reproducible: Hard to replicate exact setup
- No version control: Can't track changes
- Documentation outdated: Screenshots don't match reality
- Disaster recovery: Have to remember all steps
```

**Real scenario:**
```
Friday afternoon: Production server crashes
→ Need to rebuild from scratch
→ Look for documentation (outdated)
→ Try to remember settings (forgot some)
→ 4 hours to rebuild
→ Still missing some configuration
→ Weekend ruined
```

---

### Giải Pháp: Infrastructure as Code (IaC)

```
✅ Modern IaC approach:

1. Write infrastructure in code (main.tf)
2. Run: terraform apply
3. Infrastructure created automatically
4. Same result every time

Benefits:
- Fast: 5-10 minutes to provision
- Reproducible: Same code = same infrastructure
- Version controlled: Track changes in git
- Documentation: Code IS the documentation
- Disaster recovery: Just run terraform apply
- Multi-environment: dev, staging, prod from same code
```

**Same scenario with IaC:**
```
Friday afternoon: Production server crashes
→ Run: terraform apply
→ 10 minutes later: Production restored
→ Identical to original setup
→ Go home on time
```

---

## Infrastructure as Code Concepts

### IaC Definition

```
Infrastructure as Code (IaC) = Managing infrastructure using code files

Instead of:
- Clicking in web UI
- Running manual commands
- Following documentation

You:
- Write code (*.tf files for Terraform)
- Commit to git
- Run: terraform apply
- Infrastructure created automatically

Code describes DESIRED STATE:
"I want 3 servers, with these specs, in this region"
→ Terraform makes it happen
```

---

### IaC Benefits

```
┌─────────────────────────────────────────────────────┐
│  Benefit              │  Explanation                │
├─────────────────────────────────────────────────────┤
│  📝 Documentation     │  Code = docs (never outdated)│
│  🔄 Reproducibility   │  Same code = same result    │
│  📜 Version Control   │  Track changes via git      │
│  👥 Collaboration     │  Team can review changes    │
│  🚀 Speed             │  Minutes vs hours           │
│  🔒 Consistency       │  No human errors            │
│  🌍 Multi-env         │  Dev/staging/prod from 1 code│
│  💾 Disaster Recovery │  Rebuild in minutes         │
└─────────────────────────────────────────────────────┘
```

---

### Popular IaC Tools

```
┌──────────────┬─────────────────┬──────────────────────┐
│     Tool     │   Provider      │   Best For           │
├──────────────┼─────────────────┼──────────────────────┤
│  Terraform   │  All clouds     │  Multi-cloud         │
│  AWS CDK     │  AWS            │  AWS-specific        │
│  Pulumi      │  All clouds     │  Use your language   │
│  Ansible     │  Config mgmt    │  Server config       │
│  CloudFormation│ AWS           │  AWS-native          │
└──────────────┴─────────────────┴──────────────────────┘

→ Terraform = Most popular, works everywhere
```

---

## Terraform Basics

### Terraform Workflow

```
┌──────────────────────────────────────────────────────┐
│                 Terraform Workflow                   │
└──────────────────────────────────────────────────────┘

1. Write
   ├─ main.tf (resources)
   ├─ variables.tf (inputs)
   └─ outputs.tf (outputs)

2. Initialize
   $ terraform init
   → Downloads providers (AWS, Docker, etc.)

3. Plan (dry-run)
   $ terraform plan
   → Shows what will change (no actual changes)

4. Apply
   $ terraform apply
   → Creates/updates infrastructure

5. Destroy (cleanup)
   $ terraform destroy
   → Removes all resources
```

---

### Basic Terraform Example: Docker Container

**File: `main.tf`**

```hcl
# Terraform configuration
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Provider configuration
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Resource: Docker image
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

# Resource: Docker container
resource "docker_container" "nginx" {
  name  = "my-nginx-container"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }

  env = [
    "NGINX_HOST=localhost",
    "NGINX_PORT=80"
  ]
}
```

**Run:**

```bash
# Initialize
terraform init
# → Downloads Docker provider

# Preview changes
terraform plan
# Output:
# + docker_image.nginx
# + docker_container.nginx
# → Will create 2 resources

# Apply changes
terraform apply
# → Type: yes
# → Creates nginx container

# Verify
curl http://localhost:8080
# → Nginx welcome page

# Cleanup
terraform destroy
# → Removes container and image
```

---

### Terraform State

```
Terraform State = Current state của infrastructure

┌────────────────────────────────────────────┐
│  terraform.tfstate (JSON file)             │
├────────────────────────────────────────────┤
│  {                                         │
│    "resources": [                          │
│      {                                     │
│        "type": "docker_container",         │
│        "name": "nginx",                    │
│        "instances": [{                     │
│          "attributes": {                   │
│            "id": "abc123",                 │
│            "name": "my-nginx-container",   │
│            "image": "nginx:latest"         │
│          }                                 │
│        }]                                  │
│      }                                     │
│    ]                                       │
│  }                                         │
└────────────────────────────────────────────┘

Purpose:
- Tracks what resources exist
- Compares desired state (code) vs actual state (reality)
- Determines what changes to make

⚠️  IMPORTANT: Never edit state file manually!
```

---

### Variables in Terraform

**File: `variables.tf`**

```hcl
variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 1
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true  # Won't show in logs
}
```

**File: `main.tf` (using variables)**

```hcl
resource "docker_container" "app" {
  count = var.instance_count
  name  = "app-${var.environment}-${count.index}"
  image = "myapp:latest"

  ports {
    internal = var.app_port
    external = var.app_port + count.index
  }

  env = [
    "NODE_ENV=${var.environment}",
    "DB_PASSWORD=${var.db_password}"
  ]
}
```

**Usage:**

```bash
# Default values
terraform apply

# Override variables
terraform apply -var="environment=prod" -var="instance_count=3"

# Or use .tfvars file
cat > prod.tfvars << EOF
environment = "prod"
instance_count = 3
app_port = 3000
db_password = "secret123"
EOF

terraform apply -var-file="prod.tfvars"
```

---

### Outputs in Terraform

**File: `outputs.tf`**

```hcl
output "container_ids" {
  description = "IDs of created containers"
  value       = docker_container.app[*].id
}

output "container_names" {
  description = "Names of containers"
  value       = docker_container.app[*].name
}

output "app_urls" {
  description = "URLs to access apps"
  value       = [for i in range(var.instance_count) : "http://localhost:${var.app_port + i}"]
}
```

**Usage:**

```bash
# Show all outputs
terraform output

# Show specific output
terraform output container_ids

# Use in scripts
CONTAINER_ID=$(terraform output -raw container_ids)
docker logs $CONTAINER_ID
```

---

## Real-World Example: VPS Provisioning

### Example: DigitalOcean Droplet

**File: `main.tf`**

```hcl
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# SSH key
resource "digitalocean_ssh_key" "default" {
  name       = "Terraform Key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# VPS (Droplet)
resource "digitalocean_droplet" "web" {
  name   = "${var.environment}-web-server"
  region = var.region
  size   = var.droplet_size
  image  = "ubuntu-22-04-x64"

  ssh_keys = [digitalocean_ssh_key.default.id]

  # Cloud-init script
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt update
    apt upgrade -y

    # Install Docker
    apt install -y docker.io
    systemctl start docker
    systemctl enable docker

    # Deploy app
    docker run -d \
      --name myapp \
      -p 80:3000 \
      --restart always \
      myapp:latest
  EOF

  tags = ["web", var.environment]
}

# Firewall
resource "digitalocean_firewall" "web" {
  name = "${var.environment}-web-firewall"

  droplet_ids = [digitalocean_droplet.web.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
```

**File: `variables.tf`**

```hcl
variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "sgp1"  # Singapore
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-1vcpu-1gb"  # $6/month
}
```

**File: `outputs.tf`**

```hcl
output "droplet_ip" {
  description = "Public IP of the droplet"
  value       = digitalocean_droplet.web.ipv4_address
}

output "droplet_url" {
  description = "URL to access the server"
  value       = "http://${digitalocean_droplet.web.ipv4_address}"
}
```

**Usage:**

```bash
# Set API token
export TF_VAR_do_token="your-digitalocean-api-token"

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Get server IP
terraform output droplet_ip
# → 128.199.123.45

# SSH to server
ssh root@$(terraform output -raw droplet_ip)

# Destroy when done
terraform destroy
```

---

## Terraform Modules

### Module Concept

```
Module = Reusable Terraform code

Instead of duplicating code for:
- Backend server
- Frontend server
- Database server

Create module once, reuse 3 times:

modules/
├── docker-app/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
main.tf (use module 3 times)
```

---

### Module Example

**File: `modules/docker-app/main.tf`**

```hcl
variable "app_name" {
  type = string
}

variable "app_image" {
  type = string
}

variable "app_port" {
  type = number
}

resource "docker_image" "app" {
  name = var.app_image
}

resource "docker_container" "app" {
  name  = var.app_name
  image = docker_image.app.image_id

  ports {
    internal = var.app_port
    external = var.app_port
  }

  restart = "unless-stopped"
}

output "container_id" {
  value = docker_container.app.id
}
```

**File: `main.tf` (using module)**

```hcl
module "backend" {
  source    = "./modules/docker-app"
  app_name  = "backend"
  app_image = "myapp-backend:latest"
  app_port  = 3000
}

module "frontend" {
  source    = "./modules/docker-app"
  app_name  = "frontend"
  app_image = "myapp-frontend:latest"
  app_port  = 8080
}

module "worker" {
  source    = "./modules/docker-app"
  app_name  = "worker"
  app_image = "myapp-worker:latest"
  app_port  = 3001
}

output "backend_id" {
  value = module.backend.container_id
}
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: Provider not found

**Dấu hiệu:**
```
Error: Could not find provider docker
```

**Giải pháp:**
```bash
# Run terraform init first
terraform init

# Check provider configuration
cat main.tf | grep -A 5 required_providers
```

---

### Problem 2: State file conflicts

**Dấu hiệu:**
```
Error: state lock failed
```

**Giải pháp:**
```bash
# If using remote state and lock is stuck
terraform force-unlock <lock-id>

# Or delete local state (careful!)
rm -rf .terraform/
rm terraform.tfstate*
terraform init
```

---

### Problem 3: Resource already exists

**Dấu hiệu:**
```
Error: resource already exists
```

**Giải pháp:**
```bash
# Import existing resource
terraform import docker_container.nginx <container-id>

# Or destroy existing resource manually
docker rm -f <container-name>
terraform apply
```

---

## 🎓 Tóm Tắt Ngày 52

✅ **IaC concept**: Infrastructure as Code = manage infrastructure using code
✅ **Benefits**: Reproducible, version controlled, documented, fast
✅ **Terraform workflow**: init → plan → apply → destroy
✅ **Resources**: Infrastructure components (VPS, container, database)
✅ **Variables**: Parameterize configuration (environment, region, size)
✅ **Outputs**: Get information from created resources
✅ **State**: Terraform tracks current infrastructure state
✅ **Modules**: Reusable code components
✅ **Real examples**: Docker containers, DigitalOcean VPS

**Key commands:**
- `terraform init` - Download providers
- `terraform plan` - Preview changes
- `terraform apply` - Create/update infrastructure
- `terraform destroy` - Remove all resources
- `terraform state list` - Show resources
- `terraform output` - Show outputs

**Best practices:**
- ✅ Always run `terraform plan` before `apply`
- ✅ Use variables for different environments
- ✅ Never hardcode secrets (use variables with sensitive=true)
- ✅ Use modules for reusable components
- ✅ Commit code to git, NOT state files
- ✅ Use remote state for team collaboration

**Next:** Ngày 53 - GitHub Actions Best Practices (security, OIDC, secrets rotation, action pinning)
