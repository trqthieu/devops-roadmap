# 📘 Ngày 32: GitHub Pull Requests & Code Review

## 🎯 Mục Tiêu Ngày Hôm Nay

Nắm vững quy trình Pull Request và Code Review trong môi trường team collaboration, hiểu các merge strategies, và thiết lập quy trình review chuẩn mực cho dự án thực tế.

---

## Tại Sao Pull Request Quan Trọng?

Trong môi trường DevOps, code không bao giờ được merge trực tiếp vào `main` mà phải qua **Pull Request (PR)**. Đây là cơ chế đảm bảo:

### 1. **Quality Gate** - Cổng kiểm tra chất lượng
```
Developer → Commit → Push Branch → Create PR
                                      ↓
                            ┌─────────┴─────────┐
                            ├─ Code Review      │
                            ├─ CI Tests Pass    │
                            ├─ Security Scan    │
                            └─────────┬─────────┘
                                      ↓
                              Merge vào Main
```

**Tại sao không push trực tiếp vào main?**
- ❌ Không có ai review → bug dễ lọt vào production
- ❌ Không chạy tests → breaking changes không bị phát hiện
- ❌ Không có audit trail → không biết ai thay đổi gì, khi nào

**Với PR workflow:**
- ✅ Luôn có ít nhất 1 người review code
- ✅ CI pipeline tự động chạy tests
- ✅ Có history đầy đủ: ai approve, ai merge, lý do gì
- ✅ Có thể rollback dễ dàng nếu có vấn đề

### 2. **Knowledge Sharing** - Chia sẻ kiến thức trong team

```
Senior Dev review code của Junior
    ↓
Junior học best practices
    ↓
Code quality của cả team tăng lên
```

PR không chỉ là "approve/reject", mà còn là cơ hội:
- Junior dev học cách viết code tốt hơn từ feedback
- Senior dev hiểu codebase nhiều hơn (không chỉ phần mình viết)
- Team sync kiến thức về architecture decisions

---

## Pull Request Lifecycle

### Workflow hoàn chỉnh của một PR

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Developer tạo feature branch                             │
│    git checkout -b feature/add-payment                       │
│    git push -u origin feature/add-payment                    │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Tạo Pull Request                                          │
│    gh pr create --title "Add Stripe payment"                │
│    --reviewer @senior-dev --label "feature"                 │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. CI Pipeline tự động chạy                                  │
│    ✓ Linting                                                │
│    ✓ Unit tests                                             │
│    ✓ Security scan                                          │
│    ✓ Build Docker image                                     │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Code Review                                               │
│    Reviewer xem code → comment → request changes            │
│    Developer fix theo feedback → push updates               │
│    Reviewer approve ✓                                        │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Merge Pull Request                                        │
│    Choose strategy: Merge / Squash / Rebase                 │
│    gh pr merge --squash --delete-branch                      │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Post-merge                                                │
│    - Feature branch deleted                                  │
│    - CD pipeline deploy lên staging                          │
│    - Notification gửi tới Slack                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Merge Strategies: Khi Nào Dùng Gì?

### 1. **Merge Commit** (`gh pr merge --merge`)

```
main:       A---B---C-------G  (merge commit)
                     \     /
feature:              D---E---F
```

**Khi nào dùng:**
- ✅ Muốn giữ toàn bộ history của feature branch
- ✅ Feature lớn, nhiều commits có ý nghĩa riêng
- ✅ Cần trace được quá trình phát triển feature

**Ưu điểm:**
- Giữ nguyên commit history
- Dễ trace khi nào feature được merge
- Có thể revert toàn bộ feature bằng 1 commit

**Nhược điểm:**
- Git graph phức tạp nếu nhiều PR
- History bị "nhiễu" với merge commits

**Ví dụ thực tế:**
```bash
# Feature: Implement OAuth authentication (10 commits)
# Commits có ý nghĩa:
#   - Add OAuth config
#   - Implement Google provider
#   - Implement GitHub provider
#   - Add tests
# → Merge commit giữ lại toàn bộ history này
```

---

### 2. **Squash and Merge** (`gh pr merge --squash`)

```
main:       A---B---C---D'  (1 commit gộp)
                     \
feature:              D---E---F (bị gộp thành D')
```

**Khi nào dùng:**
- ✅ Feature branch có nhiều commits nhỏ, WIP, "fix typo"
- ✅ Muốn main branch clean, mỗi feature = 1 commit
- ✅ Team quy định: 1 PR = 1 commit

**Ưu điểm:**
- Main branch clean, dễ đọc `git log`
- Mỗi commit là 1 feature hoàn chỉnh
- Dễ revert (chỉ cần revert 1 commit)

**Nhược điểm:**
- Mất toàn bộ commit history của feature branch
- Không biết quá trình phát triển feature

**Ví dụ thực tế:**
```bash
# Feature branch có 15 commits:
#   - WIP: starting payment
#   - add stripe sdk
#   - fix typo
#   - update test
#   - fix lint
#   - ...
# → Squash thành 1 commit: "Add Stripe payment integration"
```

---

### 3. **Rebase and Merge** (`gh pr merge --rebase`)

```
main:       A---B---C---D---E---F  (commits được rebase)
```

**Khi nào dùng:**
- ✅ Muốn linear history (không có merge commits)
- ✅ Commits trong PR đã clean, có ý nghĩa
- ✅ Team quy định: no merge commits

**Ưu điểm:**
- History hoàn toàn linear
- Giữ lại commits của feature
- `git log` đẹp, dễ đọc

**Nhược điểm:**
- Mất thông tin "khi nào feature được merge"
- Khó rollback toàn bộ feature (phải revert nhiều commits)
- Commit hashes thay đổi (rewrite history)

**Ví dụ thực tế:**
```bash
# Feature có 3 commits clean:
#   - Add payment model
#   - Add payment controller
#   - Add payment tests
# → Rebase: 3 commits này nằm thẳng hàng trên main
```

---

### So Sánh Nhanh

| Strategy | Main History | Feature History | Rollback | Use Case |
|----------|--------------|-----------------|----------|----------|
| **Merge** | Có merge commits | Giữ nguyên | Dễ (1 revert) | Feature lớn |
| **Squash** | Clean, 1 commit/PR | Mất hết | Dễ (1 revert) | PR nhiều commits nhỏ |
| **Rebase** | Linear, clean | Giữ nguyên | Khó (nhiều revert) | Commits đã clean |

**Khuyến nghị cho team mới:**
→ **Squash and Merge** - dễ quản lý nhất, main branch luôn clean.

---

## Code Review Best Practices

### Review Checklist

Khi review PR, cần kiểm tra:

#### **1. Functionality**
- ✅ Code có hoạt động đúng như mô tả?
- ✅ Edge cases được xử lý chưa?
- ✅ Error handling có đầy đủ?

#### **2. Code Quality**
- ✅ Code dễ đọc, dễ hiểu?
- ✅ Có duplicate code không cần thiết?
- ✅ Naming conventions đúng chuẩn?
- ✅ Functions/methods có quá dài không?

#### **3. Tests**
- ✅ Có unit tests cho code mới?
- ✅ Tests cover được edge cases?
- ✅ Tests pass hết chưa?

#### **4. Security**
- ✅ Có SQL injection risk?
- ✅ Có XSS vulnerability?
- ✅ Credentials có bị hardcode?
- ✅ API keys có được protect?

#### **5. Performance**
- ✅ Có N+1 query problem?
- ✅ Có memory leak?
- ✅ Database indexes đủ chưa?

#### **6. Documentation**
- ✅ API changes có update docs?
- ✅ README có cần update?
- ✅ Breaking changes có được note?

---

### Cách Comment Hiệu Quả

**❌ Bad comments:**
```
"This is wrong"
"Fix this"
"Bad code"
```

**✅ Good comments:**
```
"Consider using Promise.all() here to run API calls in parallel
instead of sequential. This would reduce response time from 3s to 1s."

"This function might throw an error if userId is null.
Should we add a check: if (!userId) throw new Error(...)"

"Great implementation! One small suggestion: we could extract
this logic into a separate validator function for reusability."
```

**Nguyên tắc:**
- 📝 Giải thích **tại sao** cần thay đổi
- 💡 Đưa ra **gợi ý cụ thể**
- 🎯 Focus vào **code**, không phải **người**
- 🙏 Tôn trọng effort của developer

---

## PR Templates & Automation

### Tạo PR Template

File: `.github/pull_request_template.md`

```markdown
## What changed?
<!-- Mô tả ngắn gọn thay đổi gì -->

## Why?
<!-- Lý do cần thay đổi này -->

## How to test?
<!-- Hướng dẫn reviewer test thủ công -->

## Screenshots (if applicable)
<!-- Đính kèm ảnh nếu có UI changes -->

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes
- [ ] Backward compatible
```

**Lợi ích:**
- Developer không quên thông tin quan trọng
- Reviewer hiểu context nhanh hơn
- Standardize PR quality trong team

---

### CODEOWNERS - Auto-assign Reviewers

File: `.github/CODEOWNERS`

```
# Backend team owns API code
/src/api/**          @backend-team @senior-backend

# Frontend team owns UI
/src/components/**   @frontend-team

# DevOps owns CI/CD
/.github/workflows/** @devops-team
/Dockerfile          @devops-team
/docker-compose.yml  @devops-team

# Security team reviews auth code
/src/auth/**         @security-team
```

**Khi có PR thay đổi file trong `/src/api/`:**
→ GitHub tự động assign `@backend-team` và `@senior-backend` làm reviewers

---

## Workflow Thực Tế: Kịch Bản Production

### Scenario: Developer tạo PR cho feature mới

```bash
# 1. Developer tạo feature branch
git checkout -b feature/add-2fa
# ... code implementation ...
git add .
git commit -m "Add two-factor authentication"
git push -u origin feature/add-2fa

# 2. Tạo PR với full context
gh pr create \
  --title "Add two-factor authentication" \
  --body "Implements 2FA using TOTP. Closes #123" \
  --reviewer @security-lead,@backend-lead \
  --label "security,feature" \
  --assignee @me

# 3. CI tự động chạy
# GitHub Actions workflow:
#   - Lint code ✓
#   - Run tests ✓
#   - Security scan ✓
#   - Build Docker image ✓

# 4. Reviewer comment:
# "Good work! One issue: TOTP secret should be encrypted at rest.
#  Consider using vault or encrypted database column."

# 5. Developer fix theo feedback
git add .
git commit -m "Encrypt TOTP secret before storing"
git push  # PR tự động update

# 6. Reviewer approve
gh pr review 456 --approve --body "LGTM! Security issue fixed ✓"

# 7. Merge PR
gh pr merge 456 --squash --delete-branch

# 8. Post-merge automation:
#   - Feature branch deleted
#   - CD pipeline deploy lên staging
#   - Slack notification: "PR #456 merged by @dev"
#   - Jira ticket auto-closed
```

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### Problem 1: CI fails nhưng locally pass

**Nguyên nhân:**
- Environment khác nhau (Node version, dependencies)
- Tests chạy thành công do cached data local
- Missing environment variables trong CI

**Giải pháp:**
```bash
# 1. Check CI logs
gh pr checks 456

# 2. Reproduce locally với Docker (giống CI environment)
docker run -v $(pwd):/app -w /app node:18 npm test

# 3. Fix issue, commit, push
git add .
git commit -m "Fix tests for CI environment"
git push
```

---

### Problem 2: Merge conflicts

**Khi nào xảy ra:**
- Main branch có commits mới conflict với PR
- Nhiều PRs edit cùng file

**Giải pháp:**
```bash
# 1. Update feature branch từ main
git checkout feature/add-2fa
git fetch origin
git rebase origin/main

# 2. Resolve conflicts
# (sửa file manually)
git add .
git rebase --continue

# 3. Force push (an toàn hơn --force)
git push --force-with-lease
```

---

### Problem 3: PR quá lớn, khó review

**Dấu hiệu:**
- PR có > 500 lines changed
- Reviewer mất > 30 phút để review
- Nhiều files không liên quan

**Giải pháp:**
```bash
# ❌ Tránh: 1 PR chứa cả feature lớn
PR: "Add payment system" (1500 lines, 30 files)

# ✅ Tốt hơn: Chia thành nhiều PRs nhỏ
PR #1: "Add payment models" (100 lines)
PR #2: "Add Stripe integration" (200 lines)
PR #3: "Add payment UI" (150 lines)
PR #4: "Add payment tests" (180 lines)
```

**Rule of thumb:**
- 1 PR nên < 400 lines
- 1 PR nên làm 1 việc (single responsibility)
- Nếu PR description có "and" nhiều lần → nên split

---

### Problem 4: Reviewer không approve sau nhiều ngày

**Nguyên nhân:**
- Reviewer quá bận
- PR description không rõ ràng
- PR quá lớn, intimidating

**Giải pháp:**
```bash
# 1. Ping reviewer nhẹ nhàng
gh pr comment 456 --body "@reviewer Friendly ping! This PR is ready for review 🙏"

# 2. Nếu vẫn không response, request reviewer khác
gh pr edit 456 --add-reviewer @another-senior

# 3. Trong meeting standup, mention PR
"I have PR #456 waiting for review, it's blocking me from starting next task"
```

---

## 🎓 Tóm Tắt Ngày 32

✅ **Pull Request** là cơ chế kiểm soát chất lượng code trước khi merge vào main
✅ **3 merge strategies**: Merge commit (giữ history), Squash (clean main), Rebase (linear)
✅ **Code review** không chỉ là approve/reject mà còn là knowledge sharing
✅ **PR template + CODEOWNERS** giúp standardize quy trình review
✅ **Workflow production**: Create PR → CI → Review → Merge → Deploy

**Kỹ năng đạt được:**
- Tạo và quản lý Pull Requests với `gh pr` CLI
- Chọn merge strategy phù hợp cho từng tình huống
- Review code hiệu quả với checklist đầy đủ
- Setup automation với PR templates và CODEOWNERS
- Debug và resolve PR issues (conflicts, CI failures)

**Next:** Ngày 33 - GitHub Secrets & Environments (quản lý credentials an toàn trong CI/CD)
