# GitHub Secrets & Environments

# Quản lý Secrets
gh secret list                                    # list tất cả secrets
gh secret set AWS_ACCESS_KEY                      # set secret (nhập từ prompt)
gh secret set DB_PASSWORD < secret.txt            # set từ file
echo "my-token" | gh secret set API_TOKEN         # set từ stdin
gh secret delete API_TOKEN                        # xóa secret

# Secrets cho environments
gh secret set PROD_API_KEY --env production       # set cho env production
gh secret set STAGING_DB --env staging            # set cho env staging

# Organization secrets (cho nhiều repos)
gh secret set ORG_TOKEN --org my-org              # set org-level secret
gh secret set ORG_TOKEN --org my-org --repos repo1,repo2  # chỉ định repos

# View secrets trong repo (không thấy value)
gh api repos/{owner}/{repo}/actions/secrets       # list qua API

# Encrypted secrets trong workflow
# .github/workflows/deploy.yml
# secrets.AWS_ACCESS_KEY                          # access secret trong workflow
# env:
#   API_KEY: ${{ secrets.API_TOKEN }}             # inject vào env variable

# Environments
gh api repos/{owner}/{repo}/environments                    # list environments
gh api repos/{owner}/{repo}/environments/production \
  --method PUT --input env-config.json                      # create/update environment

# Environment protection rules (qua Web UI)
# Settings → Environments → production → Protection rules
# - Required reviewers: @senior-dev
# - Wait timer: 5 minutes
# - Deployment branches: only main

# Environment secrets vs Repository secrets
# Repository secrets: dùng cho mọi workflows
# Environment secrets: chỉ dùng khi deploy vào environment đó

# Variables (không encrypted, dùng cho config không nhạy cảm)
gh variable list                                  # list variables
gh variable set NODE_ENV --body "production"      # set variable
gh variable set REGION --body "us-east-1"         # non-sensitive config
gh variable delete NODE_ENV                       # xóa variable

# Variables cho environment
gh variable set API_URL --env production --body "https://api.prod.com"
gh variable set API_URL --env staging --body "https://api.staging.com"

# Best practices
# ✅ Secrets: passwords, API keys, tokens
# ✅ Variables: region, environment name, feature flags
# ❌ KHÔNG commit secrets vào code
# ❌ KHÔNG log secrets trong CI

# Rotate secrets (đổi secret định kỳ)
# 1. Generate new secret
# 2. Test với new secret
# 3. Update trong GitHub
gh secret set AWS_KEY < new-key.txt
# 4. Deploy
# 5. Revoke old secret

# Local testing với secrets
# .env.local (KHÔNG commit)
API_KEY=local-test-key
DB_PASSWORD=local-password

# act tool - run GitHub Actions locally
act --secret-file .env.local                      # test workflow với secrets local
