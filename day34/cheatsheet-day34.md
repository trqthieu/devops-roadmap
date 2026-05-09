# CI/CD Concepts Cheatsheet

# CI/CD không phải commands, mà là concepts!
# Ngày này tập trung vào hiểu khái niệm, vẽ sơ đồ

# Các khái niệm chính:
# CI (Continuous Integration): merge code thường xuyên, test tự động
# CD (Continuous Delivery): luôn sẵn sàng deploy
# CD (Continuous Deployment): tự động deploy lên production

# Pipeline: chuỗi steps tự động
# Runner: máy chạy pipeline
# Job: nhóm steps
# Step: 1 command/action
# Artifact: file output từ build (Docker image, binary, bundle.js)
# Trigger: event khởi động pipeline (push, PR, schedule, manual)

# GitHub Actions terminology
# .github/workflows/ci.yml                        # workflow file
# on: [push, pull_request]                        # triggers
# jobs:                                            # list các jobs
#   build:                                         # job name
#     runs-on: ubuntu-latest                       # runner
#     steps:                                       # list các steps
#       - uses: actions/checkout@v4                # action (pre-built)
#       - run: npm install                         # command

# Visualize pipeline
# git push → Trigger workflow
#              ↓
#          Job 1: Lint
#              ↓
#          Job 2: Test (depends on Lint)
#              ↓
#          Job 3: Build Docker Image
#              ↓
#          Job 4: Push to Registry

# CI/CD benefits
# ✅ Phát hiện bugs sớm (test mỗi khi commit)
# ✅ Deploy nhanh (tự động, không manual)
# ✅ Rollback dễ dàng (mỗi version được track)
# ✅ Confidence cao (tests pass → production ready)

# Traditional vs CI/CD
# Traditional:
#   - Code 1 tuần → merge cuối tuần → conflicts nhiều
#   - Test manual → slow, dễ quên
#   - Deploy manual → error-prone, downtime

# CI/CD:
#   - Code + commit mỗi ngày → merge dễ dàng
#   - Test tự động mỗi commit → bugs phát hiện ngay
#   - Deploy tự động → nhanh, consistent

# Pipeline stages
# Stage 1: Build
#   - Checkout code
#   - Install dependencies
#   - Compile/bundle

# Stage 2: Test
#   - Unit tests
#   - Integration tests
#   - E2E tests

# Stage 3: Package
#   - Build Docker image
#   - Create artifact
#   - Tag version

# Stage 4: Deploy
#   - Push image to registry
#   - Deploy to staging
#   - Deploy to production (với approval)

# Monitoring & Feedback
#   - Health check
#   - Monitor metrics
#   - Alert on failures
#   - Rollback nếu cần
