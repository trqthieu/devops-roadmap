# 📘 Ngày 31: Git Workflow Nâng Cao — GitFlow, GitHub Flow, Trunk-based Development

## 🎯 Mục Tiêu Ngày Hôm Nay

Hiểu sâu các Git branching strategy được sử dụng trong production, biết khi nào dùng workflow nào, và cách áp dụng vào team thực tế. Nắm được ưu nhược điểm của GitFlow, GitHub Flow, và Trunk-based Development.

**Kỹ năng cốt lõi:**
- So sánh và lựa chọn workflow phù hợp với team
- Implement GitFlow cho team lớn
- Áp dụng GitHub Flow cho continuous deployment
- Hiểu trunk-based development cho CI/CD nhanh
- Setup branch protection rules

---

## Tại Sao Cần Git Workflow?

### Tình Huống: Chaos Khi Không Có Quy Chuẩn

**Team 5 người, không có workflow:**
```bash
# Developer A:
git commit -m "fix"                    # Commit trực tiếp lên main
git push origin main                   # Production bị break

# Developer B:
git checkout -b dev-branch             # Branch tên bừa
# ... 2 tháng không merge              # Branch đống dust

# Developer C:
git commit -m "WIP half done"          # Commit code chưa xong
git push origin main                   # Test fail trên CI
```

**Hậu quả:**
- ❌ Main branch không stable
- ❌ Không biết feature nào đang phát triển
- ❌ Hotfix phải từ code broken
- ❌ Release planning là ác mộng

**Giải pháp:** Git workflow — quy chuẩn về branch, merge, release

---

## GitFlow: Workflow Cho Team Lớn & Release Planning

### Cấu Trúc GitFlow

```
                    Hotfix
                      ↓
main    ─────●───────●──────●─────→  Production (v1.0, v1.1, v2.0)
              ↑       ↑      ↑
              │       │      └─── Release branch (v2.0)
develop ──●───●───●───●───●───●───→  Integration branch
          │   │   │   │
          │   │   │   └─ Feature C
          │   │   └───── Feature B
          │   └───────── Feature A
          └───────────── Bugfix
```

### Các Branch Trong GitFlow

**1. main (master)**
- **Mục đích:** Production-ready code
- **Quy tắc:**
  - Chỉ merge từ `release` hoặc `hotfix`
  - Mỗi commit là một version (v1.0, v1.1, v2.0)
  - Protected, không ai commit trực tiếp

**2. develop**
- **Mục đích:** Integration branch cho features
- **Quy tắc:**
  - Merge tất cả features vào đây
  - Always deployable (nhưng chưa release)
  - Nơi chạy integration tests

**3. feature/***
- **Mục đích:** Develop tính năng mới
- **Cách tạo:** Branch từ `develop`
- **Cách kết thúc:** Merge về `develop`
- **Thời gian sống:** Vài ngày đến vài tuần

**4. release/***
- **Mục đích:** Chuẩn bị release
- **Cách tạo:** Branch từ `develop` khi sắp release
- **Công việc:** Bug fixes, documentation, version bump
- **Cách kết thúc:** Merge về `main` VÀ `develop`

**5. hotfix/***
- **Mục đích:** Fix critical bug trên production
- **Cách tạo:** Branch từ `main`
- **Cách kết thúc:** Merge về `main` VÀ `develop`

---

## Workflow GitFlow Chi Tiết

### Tình Huống 1: Develop Feature Mới

```bash
# 1. Developer checkout từ develop
git checkout develop
git pull origin develop

# 2. Tạo feature branch
git checkout -b feature/user-authentication

# 3. Develop (nhiều commits)
git add .
git commit -m "Add user model"
git commit -m "Add login endpoint"
git commit -m "Add JWT token generation"

# 4. Merge về develop
git checkout develop
git pull origin develop              # Update develop mới nhất
git merge --no-ff feature/user-authentication
#          ^^^^^^ Tạo merge commit (quan trọng!)
git push origin develop

# 5. Xóa feature branch
git branch -d feature/user-authentication
```

**Tại sao `--no-ff`?**
```
Without --no-ff (fast-forward):
develop ─●─●─●─●─●→
         └─ Feature commits (không phân biệt được)

With --no-ff (merge commit):
develop ─●───────●→
          ╲     ╱
           ●─●─●  ← Feature branch (rõ ràng)
```

---

### Tình Huống 2: Release Planning

```bash
# 1. Develop xong features cho v2.0
git checkout develop

# 2. Tạo release branch
git checkout -b release/2.0.0

# 3. Công việc trên release branch:
# - Fix minor bugs
# - Update version numbers
# - Update CHANGELOG.md
git commit -m "Bump version to 2.0.0"
git commit -m "Update changelog"
git commit -m "Fix last-minute bug in login"

# 4. Merge về main (production)
git checkout main
git merge --no-ff release/2.0.0
git tag -a v2.0.0 -m "Release version 2.0.0"
git push origin main --tags

# 5. Merge về develop (để có bug fixes)
git checkout develop
git merge --no-ff release/2.0.0
git push origin develop

# 6. Xóa release branch
git branch -d release/2.0.0
```

---

### Tình Huống 3: Production Hotfix (Khẩn Cấp)

**Kịch bản:** Production (v2.0.0) có critical bug, cần fix NGAY

```bash
# 1. Tạo hotfix từ main
git checkout main
git checkout -b hotfix/critical-login-bug

# 2. Fix bug
git commit -m "Fix null pointer in login endpoint"

# 3. Test kỹ
# Run tests locally

# 4. Merge về main
git checkout main
git merge --no-ff hotfix/critical-login-bug
git tag -a v2.0.1 -m "Hotfix: Login bug"
git push origin main --tags

# 5. Merge về develop (để develop cũng có fix)
git checkout develop
git merge --no-ff hotfix/critical-login-bug
git push origin develop

# 6. Xóa hotfix branch
git branch -d hotfix/critical-login-bug
```

**Timeline:**
```
Phát hiện bug:  10:00
Fix xong:       10:15
Deploy:         10:30
→ Total: 30 phút (nhanh vì không cần chờ release branch)
```

---

## GitHub Flow: Simplified Workflow

### Cấu Trúc GitHub Flow

```
main ─●───────●───────●───────●───→  (Always deployable)
       ╲     ╱ ╲     ╱ ╲     ╱
        ●─●─●   ●─●─●   ●─●─●
        Feature A  Feature B  Hotfix
```

**Quy tắc đơn giản:**
1. `main` branch luôn deployable
2. Tạo branch từ `main` cho mọi thay đổi
3. Commit thường xuyên
4. Mở Pull Request sớm
5. Merge về `main` sau khi review
6. Deploy ngay sau khi merge

---

### Workflow GitHub Flow

```bash
# 1. Tạo branch từ main
git checkout main
git pull origin main
git checkout -b add-payment-feature

# 2. Commit nhỏ, thường xuyên
git add .
git commit -m "Add Stripe SDK"
git push -u origin add-payment-feature

# 3. Tạo Pull Request (ngay cả khi chưa xong)
gh pr create --title "Add payment feature" --draft
# Draft PR = WIP, không merge được

# 4. Tiếp tục develop
git commit -m "Add payment endpoint"
git push

# 5. Chuyển từ draft → ready
gh pr ready

# 6. Request review
gh pr edit --add-reviewer teammate1,teammate2

# 7. CI pass + Review approved → Merge
gh pr merge --squash
# --squash: tất cả commits thành 1 commit khi merge
```

---

## Trunk-based Development: Speed-first Workflow

### Cấu Trúc Trunk-based

```
main ─●─●─●─●─●─●─●─●─●─●→  (Trunk = main)
       ╲╱ ╲╱ ╲╱ ╲╱
       Short-lived branches (<1 day)
```

**Đặc điểm:**
- **Main = Trunk:** Mọi người commit gần như trực tiếp lên main
- **Short-lived branches:** Branch sống < 1 ngày
- **Feature flags:** Code mới deploy nhưng chưa enable
- **High discipline:** Test tốt, CI nhanh, review nhanh

---

### Workflow Trunk-based

```bash
# 1. Pull main mới nhất (nhiều lần/ngày)
git checkout main
git pull --rebase origin main

# 2. Tạo short-lived branch (nếu cần)
git checkout -b quick-fix

# 3. Commit + push nhanh
git add .
git commit -m "Fix button alignment"
git push origin quick-fix

# 4. PR nhỏ → merge nhanh (< 30 phút)
gh pr create --title "Fix button alignment"
# Review ngay, merge ngay

# 5. Deploy ngay (với feature flag nếu chưa xong)
# Code:
if (featureFlag.enabled('new-feature')) {
  // New code
} else {
  // Old code
}
```

---

## So Sánh Workflows

| Tiêu chí | GitFlow | GitHub Flow | Trunk-based |
|----------|---------|-------------|-------------|
| **Complexity** | Cao (nhiều loại branch) | Trung bình | Thấp |
| **Release cycle** | Scheduled (vài tuần/tháng) | Continuous | Continuous |
| **Team size** | Lớn (>10) | Trung bình (5-10) | Nhỏ-Trung (<10) |
| **CI/CD** | Optional | Recommended | Required |
| **Branch lifetime** | Tuần/tháng | Vài ngày | <1 ngày |
| **Merge conflicts** | Nhiều | Trung bình | Ít |
| **Best for** | Enterprise, regulated industries | Startups, web apps | DevOps teams, microservices |

---

## Branch Protection Rules

### Tình Huống: Ai cũng push lên main

**Vấn đề:**
```bash
# Junior dev vô tình push lên main
git push origin main
# → CI break, production down
```

**Giải pháp:** Branch Protection

```yaml
# .github/branch-protection.yml
main:
  required_pull_request_reviews:
    required_approving_review_count: 2      # Cần 2 approvals
    dismiss_stale_reviews: true             # Review cũ tự hủy khi có commit mới
    require_code_owner_reviews: true        # CODEOWNERS phải review

  required_status_checks:
    strict: true                            # Branch phải update với base
    contexts:
      - "ci/tests"                          # CI test phải pass
      - "ci/lint"
      - "security/scan"

  enforce_admins: true                      # Admin cũng phải follow rules
  restrictions:
    users: []
    teams: ["release-team"]                 # Chỉ release-team merge được
```

**Setup qua UI:**
```
Settings > Branches > Add rule
- Branch name pattern: main
- ✓ Require pull request before merging
  - ✓ Require approvals (2)
- ✓ Require status checks to pass
  - ✓ ci/tests
- ✓ Include administrators
```

---

## Merge Strategies

### 1. Merge Commit (Default)

```bash
git merge --no-ff feature-branch
```

**Kết quả:**
```
main ─●───────●
       ╲     ╱
        ●─●─●  feature-branch

History: Giữ nguyên tất cả commits + 1 merge commit
```

**Ưu điểm:**
- Lịch sử rõ ràng
- Dễ revert cả feature (revert merge commit)

**Nhược điểm:**
- History rối nếu nhiều features

---

### 2. Squash and Merge

```bash
gh pr merge --squash
```

**Kết quả:**
```
main ─●───●
           ↑
       Squashed commit (chứa tất cả changes)

Feature branch: ●─●─● (bị "nén" thành 1 commit)
```

**Ưu điểm:**
- History clean (1 commit = 1 feature)
- Main branch dễ đọc

**Nhược điểm:**
- Mất commit history chi tiết

---

### 3. Rebase and Merge

```bash
git rebase main
git push --force-with-lease
```

**Kết quả:**
```
main ─●─●─●─●─●─●
           └─ Feature commits (linear)

No merge commit, commits replay lên main
```

**Ưu điểm:**
- History linear (không có merge commits)
- Dễ đọc git log

**Nhược điểm:**
- Mất context về feature boundary

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### 1. Merge Conflict Khi Rebase

```bash
git rebase main
# CONFLICT (content): Merge conflict in app.js

# Fix conflict trong app.js
vim app.js
# <<<<<<< HEAD
# =======
# >>>>>>> feature-branch

git add app.js
git rebase --continue

# Nếu conflict quá nhiều
git rebase --abort   # Hủy, dùng merge thay vì rebase
```

---

### 2. Force Push Xóa Mất Code Của Teammate

```bash
# ❌ NGUY HIỂM
git push --force

# ✅ AN TOÀN HƠN
git push --force-with-lease
# Chỉ force nếu remote chưa có commits mới
```

**Giải thích:**
```
--force:              Ghi đè mù quáng
--force-with-lease:   Ghi đè nếu remote == local tracking branch
                      (Fail nếu teammate đã push)
```

---

### 3. Release Branch Bị Out-of-date

**Kịch bản:** Release branch tạo 2 tuần trước, giờ develop đã có thêm 20 commits

```bash
# ❌ Không nên merge develop vào release
# (Release chỉ fix bugs, không add features)

# ✅ Cherry-pick bug fixes nếu cần
git checkout release/2.0.0
git cherry-pick abc123   # Bug fix từ develop
```

---

### 4. Feature Branch Quá Cũ, Conflict Nhiều

```bash
git checkout feature-old-branch
git fetch origin

# Option 1: Rebase lên develop mới
git rebase origin/develop
# Fix conflicts từng commit
git rebase --continue

# Option 2: Recreate branch
git checkout develop
git pull
git checkout -b feature-old-branch-v2
git cherry-pick abc123..def456  # Pick commits từ branch cũ
```

---

## Best Practices

### Naming Conventions

```bash
# Features
feature/user-authentication
feature/payment-integration
feature/JIRA-1234-add-logging

# Bugs
bugfix/fix-login-redirect
bugfix/JIRA-5678-memory-leak

# Hotfixes
hotfix/critical-security-patch
hotfix/v1.2.1-login-bug

# Releases
release/1.0.0
release/2024-Q1
```

---

### Commit Messages

```bash
# ✅ Good
git commit -m "Add user authentication with JWT"
git commit -m "Fix: Null pointer in payment service"
git commit -m "Refactor: Extract config to environment variables"

# ❌ Bad
git commit -m "fix"
git commit -m "update"
git commit -m "changes"
```

**Convention: Conventional Commits**
```
<type>(<scope>): <subject>

feat(auth): Add JWT token generation
fix(api): Handle null user in GET /profile
docs(readme): Add deployment instructions
refactor(db): Extract connection to separate file
```

---

### Pull Request Best Practices

**1. Kích thước nhỏ:**
```bash
# ✅ 100-300 lines changed
# Review nhanh, ít bug

# ❌ 2000 lines changed
# Không ai review kỹ
```

**2. Mô tả rõ ràng:**
```markdown
## What
Add user authentication with JWT

## Why
Required for secure API access

## Testing
- ✓ Unit tests pass
- ✓ Integration tests pass
- ✓ Tested on staging

## Screenshots
[Before/After images]
```

**3. Self-review trước khi request:**
```bash
gh pr diff    # Xem lại changes
# Check:
# - Có console.log() thừa?
# - Có TODO comments?
# - Code format đúng?
```

---

## 🎓 Tóm Tắt Ngày 31

✅ **GitFlow cho team lớn với release planning** — main, develop, feature, release, hotfix branches
✅ **GitHub Flow đơn giản cho continuous deployment** — main + feature branches + PR
✅ **Trunk-based cho speed** — Commit thẳng lên main với short-lived branches
✅ **Branch protection ngăn accidents** — Require reviews, status checks trước khi merge
✅ **Merge strategies:** Merge commit (preserve history), squash (clean history), rebase (linear)

**Kỹ năng đạt được:**
- Chọn workflow phù hợp với team size và release cycle
- Implement GitFlow với hotfix và release branches
- Setup branch protection rules trên GitHub
- Resolve merge conflicts khi rebase

**Commands quan trọng:**
```bash
git flow feature start/finish feature-name
gh pr create --title "Feature" --draft
git merge --no-ff feature-branch
git rebase origin/main
git push --force-with-lease
gh pr merge --squash
```

**Ngày mai:** GitHub PRs & Code Review — Pull Request templates, review checklist, merge strategies!
