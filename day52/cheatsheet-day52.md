# Infrastructure as Code (IaC) Introduction

# Terraform basics - Infrastructure as Code
# IaC = Quản lý infrastructure bằng code thay vì manual GUI

# Install Terraform
# macOS
brew install terraform

# Ubuntu
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version                              # check version
terraform -help                                 # show help

# Basic Terraform workflow
terraform init                                  # initialize project, download providers
terraform plan                                  # preview changes (dry-run)
terraform apply                                 # apply changes (create/update resources)
terraform destroy                               # destroy all resources

# Example: Deploy Docker container via Terraform
cat << 'EOF' > main.tf
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Docker image resource
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

# Docker container resource
resource "docker_container" "nginx" {
  name  = "my-nginx"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }
}
EOF

terraform init                                  # download Docker provider
terraform plan                                  # preview: will create nginx container
terraform apply                                 # confirm: yes
curl http://localhost:8080                      # verify nginx running
terraform destroy                               # cleanup

# Example: Multiple environments
cat << 'EOF' > variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 1
}
EOF

cat << 'EOF' > main.tf
resource "docker_container" "app" {
  count = var.instance_count
  name  = "app-${var.environment}-${count.index}"
  image = "myapp:latest"

  ports {
    internal = 3000
    external = 3000 + count.index
  }

  env = [
    "NODE_ENV=${var.environment}"
  ]
}
EOF

# Deploy dev environment (1 instance)
terraform apply -var="environment=dev" -var="instance_count=1"

# Deploy production environment (3 instances)
terraform apply -var="environment=prod" -var="instance_count=3"

# Terraform state
terraform show                                  # show current state
terraform state list                            # list resources in state
terraform state show docker_container.nginx     # show specific resource

# Terraform output
cat << 'EOF' > outputs.tf
output "container_id" {
  description = "ID of the Docker container"
  value       = docker_container.nginx.id
}

output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.nginx.name
}
EOF

terraform output                                # show all outputs
terraform output container_id                   # show specific output

# Terraform workspace (for multiple environments)
terraform workspace list                        # list workspaces
terraform workspace new staging                 # create staging workspace
terraform workspace select staging              # switch to staging
terraform workspace show                        # show current workspace

# Example: VPS provisioning (DigitalOcean)
cat << 'EOF' > main.tf
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

resource "digitalocean_droplet" "web" {
  name   = "web-server"
  region = "sgp1"
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"

  ssh_keys = [var.ssh_fingerprint]

  user_data = <<-EOF
    #!/bin/bash
    apt update
    apt install -y docker.io
    docker run -d -p 80:80 nginx
  EOF
}

output "droplet_ip" {
  value = digitalocean_droplet.web.ipv4_address
}
EOF

cat << 'EOF' > variables.tf
variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_fingerprint" {
  description = "SSH key fingerprint"
  type        = string
}
EOF

# Set variables via environment
export TF_VAR_do_token="your-api-token"
export TF_VAR_ssh_fingerprint="your-ssh-fingerprint"

terraform apply                                 # provision VPS
terraform output droplet_ip                     # get IP address

# Terraform modules (reusable components)
cat << 'EOF' > modules/docker-app/main.tf
variable "app_name" { type = string }
variable "app_image" { type = string }
variable "port" { type = number }

resource "docker_container" "app" {
  name  = var.app_name
  image = var.app_image

  ports {
    internal = var.port
    external = var.port
  }
}

output "container_id" {
  value = docker_container.app.id
}
EOF

# Use module
cat << 'EOF' > main.tf
module "backend" {
  source    = "./modules/docker-app"
  app_name  = "backend"
  app_image = "myapp-backend:latest"
  port      = 3000
}

module "frontend" {
  source    = "./modules/docker-app"
  app_name  = "frontend"
  app_image = "myapp-frontend:latest"
  port      = 8080
}
EOF

terraform init                                  # initialize modules
terraform apply                                 # deploy both apps

# Remote state (for team collaboration)
cat << 'EOF' > backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "myapp/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
EOF

terraform init -backend-config="backend.tf"     # configure remote state

# Terraform import (import existing resources)
docker run -d --name existing-nginx -p 9090:80 nginx
terraform import docker_container.nginx $(docker ps -qf name=existing-nginx)

# Terraform graph (visualize dependencies)
terraform graph | dot -Tpng > graph.png         # requires graphviz

# Terraform validate
terraform validate                              # check syntax
terraform fmt                                   # format code
terraform fmt -check                            # check if formatted

# Terraform plan with output
terraform plan -out=tfplan                      # save plan
terraform apply tfplan                          # apply saved plan
terraform show tfplan                           # show plan details

# Targeted apply (only specific resource)
terraform apply -target=docker_container.nginx  # only apply nginx

# Refresh state
terraform refresh                               # sync state with reality

# Terraform console (interactive)
terraform console                               # enter console
> docker_container.nginx.name                   # query resources
> var.environment                               # check variables

# Lock state (prevent concurrent modifications)
# Automatic with remote backends like S3
# Manual: terraform state lock <lock-id>

# Terraform best practices checklist
cat << 'EOF' > terraform-checklist.md
## Terraform Best Practices

### Project Structure
- [ ] Use modules for reusable components
- [ ] Separate variables.tf and outputs.tf
- [ ] Use terraform.tfvars for variable values
- [ ] .gitignore: terraform.tfstate, .terraform/, *.tfvars

### State Management
- [ ] Use remote state (S3, Terraform Cloud)
- [ ] Enable state locking
- [ ] Never commit state files to git
- [ ] Backup state files regularly

### Code Quality
- [ ] Run terraform fmt before commit
- [ ] Run terraform validate
- [ ] Use terraform plan before apply
- [ ] Document variables and outputs

### Security
- [ ] Never hardcode secrets
- [ ] Use variables with sensitive = true
- [ ] Store secrets in environment variables
- [ ] Use .tfvars files (add to .gitignore)

### CI/CD Integration
- [ ] Automate terraform plan on PR
- [ ] Manual approval for terraform apply
- [ ] Store state in shared backend
- [ ] Use workspaces for environments
EOF

# Comparison: Manual vs IaC
cat << 'EOF' > manual-vs-iac.txt
┌────────────────────┬────────────────────┬────────────────────┐
│      Aspect        │   Manual Setup     │   IaC (Terraform)  │
├────────────────────┼────────────────────┼────────────────────┤
│ Repeatability      │ ❌ Error-prone     │ ✅ Consistent      │
│ Documentation      │ ❌ Outdated docs   │ ✅ Code = docs     │
│ Version control    │ ❌ No history      │ ✅ Git history     │
│ Collaboration      │ ❌ Hard to share   │ ✅ Team can review │
│ Disaster recovery  │ ❌ Manual rebuild  │ ✅ terraform apply │
│ Time to setup      │ ⏱️  Hours/days      │ ⏱️  Minutes        │
│ Scalability        │ ❌ Linear effort   │ ✅ Same effort     │
└────────────────────┴────────────────────┴────────────────────┘
EOF

# Common Terraform providers
# - AWS: aws
# - Google Cloud: google
# - Azure: azurerm
# - DigitalOcean: digitalocean
# - Docker: kreuzwerker/docker
# - Kubernetes: hashicorp/kubernetes
# - GitHub: integrations/github

# Terraform lifecycle
cat << 'EOF' > lifecycle-example.tf
resource "docker_container" "app" {
  name  = "myapp"
  image = "myapp:latest"

  lifecycle {
    create_before_destroy = true    # create new before destroying old
    prevent_destroy       = false   # prevent accidental destroy
    ignore_changes        = [image] # ignore changes to image
  }
}
EOF

# Terraform data sources (read existing resources)
cat << 'EOF' > data-sources.tf
data "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "web" {
  name  = "web"
  image = data.docker_image.nginx.repo_digest
}
EOF

# Terraform count vs for_each
# count: index-based (count.index)
resource "docker_container" "app" {
  count = 3
  name  = "app-${count.index}"
  image = "myapp:latest"
}

# for_each: key-based (more flexible)
resource "docker_container" "app" {
  for_each = toset(["web", "api", "worker"])
  name     = each.key
  image    = "myapp:latest"
}
