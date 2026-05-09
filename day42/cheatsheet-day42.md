# Reusable Workflows & Composite Actions

# Reusable workflow (được gọi từ workflow khác)
# .github/workflows/reusable-ci.yml
cat << 'EOF' > .github/workflows/reusable-ci.yml
name: Reusable CI

on:
  workflow_call:                                  # trigger: workflow_call
    inputs:
      node-version:
        required: false
        type: string
        default: '20'
    secrets:
      NPM_TOKEN:
        required: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
      - run: npm ci
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      - run: npm test
EOF

# Gọi reusable workflow
# .github/workflows/main.yml
cat << 'EOF' > .github/workflows/main.yml
name: Main

on: [push]

jobs:
  call-ci:
    uses: ./.github/workflows/reusable-ci.yml     # gọi workflow local
    with:
      node-version: '20'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
EOF

# Call workflow từ repo khác
jobs:
  call-ci:
    uses: owner/repo/.github/workflows/ci.yml@main  # remote workflow
    with:
      config: production
    secrets: inherit                              # pass tất cả secrets

# Composite action (nhóm nhiều steps)
# .github/actions/setup-node/action.yml
cat << 'EOF' > .github/actions/setup-node/action.yml
name: 'Setup Node.js'
description: 'Setup Node.js with cache'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '20'

runs:
  using: 'composite'
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'

    - run: npm ci
      shell: bash

    - run: echo "✓ Node.js setup complete"
      shell: bash
EOF

# Dùng composite action
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-node        # local composite action
        with:
          node-version: '20'
      - run: npm run build

# Composite action với outputs
cat << 'EOF' > .github/actions/get-version/action.yml
name: 'Get Version'
description: 'Extract version from package.json'

outputs:
  version:
    description: 'Package version'
    value: ${{ steps.version.outputs.value }}

runs:
  using: 'composite'
  steps:
    - id: version
      run: echo "value=$(jq -r .version package.json)" >> $GITHUB_OUTPUT
      shell: bash
EOF

# Use output
steps:
  - uses: ./.github/actions/get-version
    id: ver
  - run: echo "Version is ${{ steps.ver.outputs.version }}"

# Reusable workflow với outputs
# .github/workflows/build.yml
on:
  workflow_call:
    outputs:
      image-tag:
        description: 'Docker image tag'
        value: ${{ jobs.build.outputs.tag }}

jobs:
  build:
    outputs:
      tag: ${{ steps.meta.outputs.tags }}
    steps:
      - id: meta
        run: echo "tags=myapp:${{ github.sha }}" >> $GITHUB_OUTPUT

# Caller workflow
jobs:
  build:
    uses: ./.github/workflows/build.yml
    outputs:
      image: ${{ needs.build.outputs.image-tag }}

  deploy:
    needs: build
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.image }}"

# Centralized reusable workflows
# Organization: my-org
# Repo: my-org/.github (special repo)
# File: .github/workflows/shared-ci.yml
# Usage:
jobs:
  ci:
    uses: my-org/.github/.github/workflows/shared-ci.yml@main
    secrets: inherit

# Call workflow manually
gh workflow run reusable-ci.yml                   # run reusable workflow
# Error: reusable workflows can't be triggered directly
# Solution: tạo wrapper workflow

# Workflow matrix với reusable workflows
jobs:
  test:
    strategy:
      matrix:
        node: [18, 20, 22]
    uses: ./.github/workflows/test.yml
    with:
      node-version: ${{ matrix.node }}

# Best practices
# ✅ 1 reusable workflow = 1 responsibility
# ✅ Dùng inputs/outputs để pass data
# ✅ Document inputs/outputs trong description
# ❌ Không nest workflows quá sâu (max 2 levels)
# ❌ Không hardcode values, dùng inputs

# Local vs Remote reusable workflows
# Local: ./.github/workflows/ci.yml              # same repo
# Remote: owner/repo/.github/workflows/ci.yml@ref  # other repo

# Version pinning
uses: owner/repo/.github/workflows/ci.yml@v1.2.3  # tag (recommended)
uses: owner/repo/.github/workflows/ci.yml@main    # branch (auto-update)
uses: owner/repo/.github/workflows/ci.yml@abc123  # commit SHA (immutable)
