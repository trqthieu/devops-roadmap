# GitHub Actions Cơ Bản

# Workflow file structure
# .github/workflows/ci.yml

# Basic workflow
cat << 'EOF' > .github/workflows/hello.yml
name: Hello World

on: [push]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Hello, World!"
EOF

# Workflow syntax - triggers
on: push                                          # trigger on any push
on: [push, pull_request]                          # multiple triggers
on:
  push:
    branches: [main, develop]                     # only specific branches
on:
  pull_request:
    paths: ['src/**']                             # only if src/ changed

# Jobs
jobs:
  job1:
    runs-on: ubuntu-latest                        # runner OS
    steps:
      - run: echo "Job 1"

  job2:
    runs-on: ubuntu-latest
    needs: job1                                    # run after job1
    steps:
      - run: echo "Job 2"

# Steps
steps:
  - uses: actions/checkout@v4                     # pre-built action
  - run: npm install                               # shell command
  - run: npm test
  - run: |                                         # multi-line command
      echo "Line 1"
      echo "Line 2"

# Environment variables
env:
  NODE_ENV: production
steps:
  - run: echo "Env: $NODE_ENV"

# Step-level env
steps:
  - run: npm test
    env:
      API_URL: http://localhost:3000

# Common actions
- uses: actions/checkout@v4                       # clone repo
- uses: actions/setup-node@v4                     # setup Node.js
  with:
    node-version: 20
- uses: actions/cache@v4                          # cache dependencies
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}

# Workflow commands từ CLI
gh workflow list                                  # list workflows
gh workflow view ci.yml                           # xem workflow
gh workflow run ci.yml                            # trigger manual
gh workflow enable ci.yml                         # enable workflow
gh workflow disable ci.yml                        # disable workflow

# Run history
gh run list                                       # list workflow runs
gh run view 123456                                # xem run details
gh run watch                                      # watch latest run
gh run rerun 123456                               # re-run workflow
gh run cancel 123456                              # cancel running workflow

# Logs
gh run view --log                                 # xem logs
gh run view --log-failed                          # chỉ xem failed jobs

# Naming conventions
name: CI                                          # workflow name
jobs:
  lint:                                           # job name (lowercase)
    name: Lint Code                               # display name
    steps:
      - name: Run ESLint                          # step name
        run: npm run lint

# Conditions
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'           # only on main branch
    steps:
      - run: ./deploy.sh

# Context variables
${{ github.repository }}                          # repo name
${{ github.ref }}                                 # branch ref
${{ github.sha }}                                 # commit SHA
${{ github.actor }}                               # user triggered
${{ secrets.API_KEY }}                            # secret value
${{ vars.REGION }}                                # variable value
