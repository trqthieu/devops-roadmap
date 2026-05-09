# GitHub Actions Triggers & Events

# Push trigger
on: push                                          # any push to any branch
on:
  push:
    branches: [main, develop]                     # specific branches
    branches-ignore: [staging]                    # exclude branches
    tags: ['v*']                                  # only tags matching v*
    paths: ['src/**', '*.js']                     # only if these paths change
    paths-ignore: ['docs/**', '*.md']             # ignore these paths

# Pull Request trigger
on: pull_request                                  # any PR
on:
  pull_request:
    types: [opened, synchronize, reopened]        # PR events
    branches: [main]                              # target branch
    paths: ['src/**']                             # only if src changed

# PR types
# opened: PR mới tạo
# synchronize: push commits mới vào PR
# reopened: PR được mở lại
# closed: PR đóng (merged hoặc rejected)

# Schedule (cron)
on:
  schedule:
    - cron: '0 2 * * *'                           # 2 AM hàng ngày
    - cron: '0 0 * * 0'                           # 00:00 chủ nhật
    - cron: '*/15 * * * *'                        # mỗi 15 phút

# Cron syntax: minute hour day month weekday
# 0 2 * * * → 2 AM every day
# 0 */6 * * * → every 6 hours
# 0 0 1 * * → 1st day of month

# Manual trigger (workflow_dispatch)
on:
  workflow_dispatch:                              # button "Run workflow" trên GitHub
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

# Use input trong workflow
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying to ${{ inputs.environment }}"

# Trigger workflow manually từ CLI
gh workflow run deploy.yml                        # no inputs
gh workflow run deploy.yml -f environment=production  # với input

# Multiple triggers
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

# Branch filters
on:
  push:
    branches:
      - main
      - 'releases/**'                             # releases/v1, releases/v2
      - '!releases/old'                           # exclude releases/old

# Tag filters
on:
  push:
    tags:
      - 'v*'                                      # v1.0, v2.0
      - 'v[0-9]+.[0-9]+.[0-9]+'                   # v1.2.3 (regex)

# Workflow call (reusable workflows)
on:
  workflow_call:                                  # được gọi từ workflow khác
    inputs:
      config:
        required: true
        type: string

# Repository dispatch (external trigger)
on:
  repository_dispatch:
    types: [deploy-prod]

# Trigger qua API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/owner/repo/dispatches \
  -d '{"event_type":"deploy-prod"}'

# Filter theo file changes
on:
  push:
    paths:
      - 'src/**'                                  # only src changes
      - '!src/docs/**'                            # but not docs

# Conditions trong jobs
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'           # only main branch
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh

  notify:
    if: failure()                                 # only if previous jobs failed
    runs-on: ubuntu-latest
    steps:
      - run: echo "Build failed!"

# Common conditions
if: github.event_name == 'push'                   # only on push
if: github.event_name == 'pull_request'           # only on PR
if: startsWith(github.ref, 'refs/tags/')          # only on tags
if: contains(github.event.head_commit.message, '[skip ci]')  # skip if commit has [skip ci]
