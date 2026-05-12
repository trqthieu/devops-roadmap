# 📘 Ngày 31: Git Workflow Nâng Cao — GitFlow, GitHub Flow, Trunk-based Development

## 🎯 Mục Tiêu Ngày Hôm Nay

Nắm vững các Git branching strategy được sử dụng trong production, biết khi nào dùng workflow nào, và cách áp dụng vào team thực tế.

**Kỹ năng cốt lõi:**
- So sánh và lựa chọn workflow phù hợp với team size và release cycle
- Implement GitFlow cho team lớn với release planning
- Áp dụng GitHub Flow cho continuous deployment
- Hiểu trunk-based development cho CI/CD tốc độ cao
- Setup branch protection rules để tránh accidents

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
# ... 2 tháng không merge              # Branch trở thành "dust branch"

# Developer C:
git commit -m "WIP half done"          # Commit code chưa xong
git push origin main                   # CI fail, blocking team
```

**Hậu quả:**
- ❌ Main branch không bao giờ stable
- ❌ Không biết feature nào đang phát triển
- ❌ Hotfix phải từ code bị broken
- ❌ Release planning là ác mộng
- ❌ Merge conflicts mỗi ngày

**Giải pháp:** Git workflow — quy chuẩn về branch naming, lifetime, merge strategy

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
- **Mục đích:** Production-ready code only
- **Quy tắc:**
  - Chỉ merge từ `release` hoặc `hotfix`
  - Mỗi commit = một version (v1.0, v1.1, v2.0)
  - Protected branch, không ai commit trực tiếp
  - Luôn có tag version

**2. develop**
- **Mục đích:** Integration branch cho features
- **Quy tắc:**
  - Merge tất cả features vào đây
  - Always deployable (nhưng chưa release)
  - Nơi chạy integration tests
  - Nhánh chính cho daily development

**3. feature/***
- **Mục đích:** Develop tính năng mới
- **Cách tạo:** Branch từ `develop`
- **Cách kết thúc:** Merge về `develop`
- **Thời gian sống:** Vài ngày đến vài tuần
- **Naming:** `feature/user-authentication`, `feature/payment-integration`

**4. release/***
- **Mục đích:** Chuẩn bị release (QA, bug fixes, documentation)
- **Cách tạo:** Branch từ `develop` khi sắp release
- **Công việc:** Minor bug fixes, version bump, changelog
- **Cách kết thúc:** Merge về `main` VÀ `develop`
- **Naming:** `release/1.0.0`, `release/2024-Q1`

**5. hotfix/***
- **Mục đích:** Fix critical bug trên production
- **Cách tạo:** Branch từ `main`
- **Cách kết thúc:** Merge về `main` VÀ `develop`
- **Thời gian sống:** Vài giờ (urgent!)
- **Naming:** `hotfix/critical-security-patch`, `hotfix/login-bug`

---

## Hướng Dẫn Từng Bước: GitFlow Workflow

### Bước 1: Develop Feature Mới

**Mục đích:** Tạo tính năng mới isolation, không ảnh hưởng develop

**Thực hiện:**

1. Checkout từ develop
2. Tạo feature branch
3. Develop với nhiều commits
4. Merge về develop với `--no-ff`
5. Xóa feature branch

**Kết quả mong đợi:**
- Feature được merge vào develop
- Develop stable và có integration tests pass
- Feature branch bị xóa (clean up)

**Ví dụ:**
```bash
# 1. Developer checkout từ develop
git checkout develop
git pull origin develop

# 2. Tạo feature branch
git checkout -b feature/user-authentication

# 3. Develop (nhiều commits)
git add src/auth/
git commit -m "Add user model with email/password"
git commit -m "Add JWT token generation"
git commit -m "Add login endpoint"
git commit -m "Add tests for auth service"

# 4. Merge về develop
git checkout develop
git pull origin develop              # Update develop mới nhất
git merge --no-ff feature/user-authentication
#          ^^^^^^ Quan trọng: tạo merge commit!
git push origin develop

# 5. Xóa feature branch
git branch -d feature/user-authentication
git push origin --delete feature/user-authentication
```

**Giải thích:**

**Tại sao `--no-ff` (no fast-forward)?**

```
Without --no-ff (fast-forward merge):
develop ─●─●─●─●─●→
         └─ Feature commits hòa vào develop (không phân biệt được)

With --no-ff (merge commit):
develop ─●───────●→
          ╲     ╱
           ●─●─●  ← Feature branch (rõ ràng, dễ revert)
```

- **Preserve history:** Giữ lại boundary của feature
- **Easy revert:** Revert 1 merge commit = revert cả feature
- **Clear audit:** Dễ trace feature nào được merge khi nào

---

### Bước 2: Release Planning

**Mục đích:** Chuẩn bị code cho production release

**Thực hiện:**

1. Develop xong features → tạo release branch từ develop
2. QA test trên release branch
3. Fix minor bugs trên release branch
4. Bump version, update CHANGELOG
5. Merge về main (production) + tag version
6. Merge về develop (để develop có bug fixes)

**Kết quả mong đợi:**
- Main có version mới với tag
- Develop được update với bug fixes từ release
- Release branch bị xóa

**Ví dụ:**
```bash
# 1. Develop xong features cho v2.0
git checkout develop
git pull origin develop

# 2. Tạo release branch
git checkout -b release/2.0.0

# 3. QA test → phát hiện bugs
# Fix bugs trên release branch
git commit -m "Fix: Null pointer in payment service"
git commit -m "Fix: Validation error in signup form"

# 4. Update version
# Edit package.json: "version": "2.0.0"
git commit -m "Bump version to 2.0.0"

# Edit CHANGELOG.md
git commit -m "Update CHANGELOG for v2.0.0"

# 5. Merge về main (production)
git checkout main
git pull origin main
git merge --no-ff release/2.0.0
git tag -a v2.0.0 -m "Release version 2.0.0"
git push origin main --tags

# 6. Merge về develop (bug fixes)
git checkout develop
git merge --no-ff release/2.0.0
git push origin develop

# 7. Xóa release branch
git branch -d release/2.0.0
git push origin --delete release/2.0.0
```

**Giải thích:**

- **Release branch isolation:** QA test mà không block develop
- **Bug fixes preserved:** Develop cũng nhận được bug fixes
- **Version tagging:** Main luôn có version rõ ràng
- **Clean history:** Release boundary dễ track

---

### Bước 3: Production Hotfix (Khẩn Cấp)

**Mục đích:** Fix critical bug trên production NGAY LẬP TỨC

**Thực hiện:**

1. Tạo hotfix từ main (production code)
2. Fix bug + test kỹ
3. Merge về main → deploy ngay
4. Merge về develop → tránh regression

**Kết quả mong đợi:**
- Production được fix trong < 1 giờ
- Develop có fix để không bị bug lại
- Version được bump (v2.0.0 → v2.0.1)

**Ví dụ:**

**Kịch bản:** Production (v2.0.0) có critical bug - user không login được

```bash
# 10:00 AM - Phát hiện bug
# 10:05 AM - Start hotfix

# 1. Tạo hotfix từ main
git checkout main
git pull origin main
git checkout -b hotfix/critical-login-bug

# 2. Fix bug
# Edit src/auth/login.js - fix null pointer
git add src/auth/login.js
git commit -m "Fix: Null pointer exception in login when email is empty"

# Add test để prevent regression
git add tests/auth/login.test.js
git commit -m "Test: Add test for empty email login"

# 3. Test kỹ locally
npm test
npm run test:integration

# 4. Merge về main
git checkout main
git merge --no-ff hotfix/critical-login-bug
git tag -a v2.0.1 -m "Hotfix: Critical login bug"
git push origin main --tags

# 5. Merge về develop
git checkout develop
git merge --no-ff hotfix/critical-login-bug
git push origin develop

# 6. Xóa hotfix branch
git branch -d hotfix/critical-login-bug

# 10:30 AM - Production fixed!
```

**Timeline:**
```
10:00 - Bug reported
10:05 - Hotfix branch created
10:15 - Bug fixed + tested
10:25 - Merged to main + develop
10:30 - Deployed to production
Total: 30 phút
```

**Giải thích:**

- **Branch từ main:** Fix từ production code, không phụ thuộc develop
- **Fast track:** Không cần chờ release cycle
- **Double merge:** Main VÀ develop đều có fix
- **Version bump:** v2.0.0 → v2.0.1 (patch version)

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
3. Commit thường xuyên, push lên remote
4. Mở Pull Request sớm (draft PR)
5. Merge về `main` sau khi CI pass + review approved
6. Deploy ngay sau khi merge

**Khi nào dùng GitHub Flow?**
- ✅ Continuous deployment (deploy nhiều lần/ngày)
- ✅ Startup, web apps, SaaS
- ✅ Team nhỏ-trung bình (5-10 người)
- ✅ Không cần release planning phức tạp

---

## Hướng Dẫn Từng Bước: GitHub Flow

### Bước 1: Tạo Feature Branch và Draft PR

**Mục đích:** Develop feature với early feedback

**Thực hiện:**

```bash
# 1. Tạo branch từ main
git checkout main
git pull origin main
git checkout -b add-payment-feature

# 2. Commit nhỏ, thường xuyên
git add src/payment/stripe.js
git commit -m "Add Stripe SDK integration"
git push -u origin add-payment-feature

# 3. Tạo Draft Pull Request ngay (WIP)
gh pr create \
  --title "Add payment feature with Stripe" \
  --body "## What\nAdd Stripe payment integration\n\n## Status\nWIP - not ready for review" \
  --draft

# 4. Tiếp tục develop
git add src/payment/webhook.js
git commit -m "Add Stripe webhook handler"
git push

git add tests/payment.test.js
git commit -m "Add tests for payment flow"
git push

# 5. Chuyển từ draft → ready for review
gh pr ready

# 6. Request review
gh pr edit --add-reviewer teammate1,teammate2
```

**Giải thích:**

- **Draft PR early:** Team biết bạn đang làm gì, tránh duplicate work
- **Continuous feedback:** Teammate có thể comment ngay trong quá trình develop
- **CI runs early:** Phát hiện issues sớm

---

### Bước 2: Review và Merge

**Mục đích:** Code review + merge vào main + deploy

**Thực hiện:**

```bash
# 1. CI checks pass
✓ Tests pass
✓ Lint pass
✓ Security scan pass

# 2. Review approved (2 approvals)
✓ teammate1 approved
✓ teammate2 approved

# 3. Merge PR (squash recommended)
gh pr merge --squash
# --squash: Tất cả commits → 1 clean commit

# 4. Delete branch automatically
# (GitHub auto-delete sau merge)

# 5. Deploy ngay
# (CI/CD tự động deploy từ main)
```

**Merge strategies:**

```bash
# Option 1: Squash (recommended cho GitHub Flow)
gh pr merge --squash
# → 1 commit, clean history

# Option 2: Merge commit (preserve all commits)
gh pr merge --merge
# → Giữ tất cả commits + 1 merge commit

# Option 3: Rebase (linear history)
gh pr merge --rebase
# → Replay commits lên main
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
- **Trunk = main:** Mọi người commit gần như trực tiếp lên main
- **Short-lived branches:** Branch sống < 1 ngày (< 8 giờ ideal)
- **Feature flags:** Code mới deploy nhưng chưa enable
- **High discipline:** Test coverage cao, CI nhanh (<10 phút), review nhanh

**Khi nào dùng Trunk-based?**
- ✅ DevOps teams với CI/CD mạnh
- ✅ Microservices architecture
- ✅ Deploy nhiều lần/ngày (10-50 deploys/day)
- ✅ Team có test coverage tốt (>80%)

---

## Hướng Dẫn Từng Bước: Trunk-based

### Bước 1: Daily Integration

**Mục đích:** Integrate code vào main nhanh nhất có thể

**Thực hiện:**

```bash
# 1. Pull main mới nhất (nhiều lần/ngày)
git checkout main
git pull --rebase origin main
#        ^^^^^^^^ Rebase để linear history

# 2. Tạo short-lived branch (optional)
git checkout -b quick-fix

# 3. Make small change
git add src/components/Button.css
git commit -m "Fix: Button alignment on mobile"

# 4. Push + PR nhanh
git push origin quick-fix
gh pr create --title "Fix button alignment" --body "Fixes #123"

# 5. Review + merge nhanh (< 30 phút)
# CI pass → Review (1 approval) → Merge → Delete branch

# 6. Deploy ngay
# CI/CD auto-deploy từ main
```

**Timeline:**
```
09:00 - Create branch
09:15 - Push + create PR
09:30 - Review approved
09:35 - Merged to main
09:40 - Deployed to production
Total: 40 phút (from code to production)
```

---

### Bước 2: Feature Flags Cho Features Lớn

**Mục đích:** Deploy code chưa hoàn thiện mà không ảnh hưởng users

**Thực hiện:**

```javascript
// Code với feature flag
import { featureFlags } from './config/featureFlags';

function UserProfile() {
  if (featureFlags.enabled('new-profile-design')) {
    return <NewProfileDesign />;  // Code mới (chưa xong)
  } else {
    return <OldProfileDesign />;  // Code cũ (stable)
  }
}
```

```bash
# Day 1: Commit 30% feature với flag OFF
git add src/profile/NewProfileDesign.js
git commit -m "feat: Add new profile design (behind flag)"
git push origin main
# → Deploy to production (flag OFF, users không thấy)

# Day 2: Commit thêm 40% với flag OFF
git commit -m "feat: Add profile stats section (behind flag)"
git push origin main

# Day 3: Hoàn thiện 100%, turn flag ON cho 5% users
# config/featureFlags.js
{
  "new-profile-design": {
    "enabled": true,
    "rollout": 5  // 5% users
  }
}

# Day 4: Rollout 50% users
# Day 5: Rollout 100% users

# Day 6: Remove flag + old code
git rm src/profile/OldProfileDesign.js
git commit -m "feat: Remove old profile design"
```

**Giải thích:**

- **Continuous integration:** Merge code mỗi ngày vào main
- **Safe deployment:** Flag OFF = không ảnh hưởng users
- **Gradual rollout:** Test với % users trước khi 100%
- **Fast feedback:** Phát hiện bugs sớm với real users

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Startup Chọn Workflow

**Bối cảnh:**
- Team: 6 developers
- Product: SaaS web app (task management)
- Deploy: Heroku (manual deploy từ main branch)
- Release: Không có schedule cứng nhắc

**Vấn đề cần giải quyết:**
Team đang dùng "không có workflow" → main branch hay broken, không dám deploy

**Giải pháp từng bước:**

1. **Chọn GitHub Flow** (phù hợp với startup, continuous deployment)

2. **Setup branch protection:**
   ```yaml
   # Settings > Branches > Branch protection rules
   main:
     - Require pull request before merging
     - Require 1 approval
     - Require status checks: ci/tests
     - No direct push to main
   ```

3. **Developer workflow:**
   ```bash
   # Mỗi feature = 1 PR
   git checkout -b feature/add-due-dates
   # ... develop ...
   gh pr create --title "Add due dates to tasks"
   # Review → Merge → Deploy
   ```

4. **Deploy strategy:**
   ```bash
   # Sau khi merge PR → deploy ngay
   git push heroku main
   # Hoặc setup auto-deploy từ GitHub → Heroku
   ```

**Kết quả:**
- ✅ Main branch luôn stable (protected)
- ✅ Deploy 3-5 lần/ngày an toàn
- ✅ Code review bắt buộc → quality tăng
- ✅ Team có visibility về features đang phát triển

---

### Tình Huống 2: Enterprise Company Với Release Schedule

**Bối cảnh:**
- Team: 30 developers, 3 teams
- Product: Banking app (iOS + Android + Backend)
- Release: Mỗi tháng 1 version (v1.0, v1.1, v1.2...)
- Compliance: Cần QA team test kỹ trước release

**Vấn đề cần giải quyết:**
Cần workflow hỗ trợ release planning, QA cycle, và hotfix

**Giải pháp từng bước:**

1. **Chọn GitFlow** (phù hợp với release schedule và QA)

2. **Setup branches:**
   ```bash
   main      → Production (v1.0, v1.1, v1.2)
   develop   → Integration (daily builds)
   feature/* → Features (team members)
   release/* → QA testing
   hotfix/*  → Critical fixes
   ```

3. **Monthly release cycle:**
   ```bash
   # Week 1-3: Develop features
   git flow feature start payment-v2
   # ... develop ...
   git flow feature finish payment-v2

   # Week 4: Create release branch
   git flow release start 1.2.0
   # → QA team test trên release/1.2.0
   # → Developers fix bugs trên release branch

   # End of month: Release
   git flow release finish 1.2.0
   # → Merge to main + develop
   # → Tag v1.2.0
   # → Deploy to production
   ```

4. **Hotfix production bug:**
   ```bash
   # Critical bug in production v1.2.0
   git flow hotfix start login-crash
   # Fix bug
   git flow hotfix finish login-crash
   # → v1.2.1 deployed in 2 hours
   ```

**Kết quả:**
- ✅ Release planning rõ ràng
- ✅ QA có thời gian test dedicated branch
- ✅ Hotfix không block development
- ✅ Main branch luôn = production

---

## So Sánh 3 Workflows

| Tiêu chí | GitFlow | GitHub Flow | Trunk-based |
|----------|---------|-------------|-------------|
| **Complexity** | Cao (5 loại branch) | Trung bình (main + feature) | Thấp (chỉ main) |
| **Release cycle** | Scheduled (weeks/months) | Continuous (daily) | Continuous (hourly) |
| **Team size** | Lớn (>10 người) | Trung bình (5-10) | Nhỏ-Trung (<10) |
| **CI/CD** | Optional | Recommended | **Required** |
| **Branch lifetime** | Tuần/tháng | Vài ngày | < 1 ngày |
| **Merge conflicts** | Nhiều | Trung bình | Ít |
| **Deploy frequency** | Vài lần/tháng | Vài lần/ngày | 10-50 lần/ngày |
| **Test coverage** | Medium (60-70%) | High (70-80%) | **Very high (>80%)** |
| **Best for** | Enterprise, banks, regulated | Startups, web apps, SaaS | DevOps teams, microservices |
| **Learning curve** | Steep | Medium | Easy (but hard discipline) |

**Chọn workflow nào?**

```
Bạn có release schedule cứng?
├─ YES → GitFlow
└─ NO → Deploy bao nhiêu lần/ngày?
         ├─ < 5 lần → GitHub Flow
         └─ > 10 lần → Trunk-based
```

---

## Branch Protection Rules

### Tình Huống: Junior Dev Vô Tình Push Lên Main

**Vấn đề:**
```bash
# Junior dev
git commit -m "WIP testing"
git push origin main
# → CI break, production down, team blocked
```

**Giải pháp:** Branch Protection

### Setup Branch Protection (GitHub UI)

```
Settings > Branches > Add rule

Branch name pattern: main

☑ Require pull request before merging
  ☑ Require approvals: 2
  ☑ Dismiss stale reviews when new commits are pushed
  ☑ Require review from Code Owners

☑ Require status checks to pass before merging
  ☑ Require branches to be up to date before merging
  Status checks:
    - ci/tests
    - ci/lint
    - security/scan

☑ Require conversation resolution before merging

☑ Include administrators
☑ Restrict who can push to matching branches
  Teams: release-team
```

### Setup qua GitHub CLI

```bash
# Create protection.json
cat > protection.json <<EOF
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 2,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "required_status_checks": {
    "strict": true,
    "contexts": ["ci/tests", "ci/lint", "security/scan"]
  },
  "enforce_admins": true,
  "restrictions": {
    "users": [],
    "teams": ["release-team"]
  }
}
EOF

# Apply protection
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --input protection.json
```

**Kết quả:**
- ❌ Không ai push trực tiếp lên main (kể cả admin)
- ✅ Bắt buộc PR + 2 approvals
- ✅ CI phải pass trước khi merge
- ✅ Chỉ release-team merge được

---

## Merge Strategies

### 1. Merge Commit (--no-ff)

```bash
git merge --no-ff feature-branch
```

**Kết quả:**
```
main ─●───────●
       ╲     ╱
        ●─●─●  feature-branch
```

**Git log:**
```
* commit abc123 (Merge commit)
| Merge branch 'feature-branch'
|
| * commit def456
| | Add payment webhook
| |
| * commit ghi789
| | Add Stripe SDK
|/
* commit jkl012
  Previous commit on main
```

**Ưu điểm:**
- ✅ History rõ ràng (feature boundary)
- ✅ Dễ revert (revert merge commit = revert cả feature)
- ✅ Audit trail tốt (biết feature nào merge khi nào)

**Nhược điểm:**
- ❌ History rối nếu nhiều features merge (merge graph phức tạp)
- ❌ Git log khó đọc với nhiều nhánh

**Khi nào dùng:**
- GitFlow (bắt buộc)
- Team cần track feature boundaries

---

### 2. Squash and Merge

```bash
gh pr merge --squash
# hoặc
git merge --squash feature-branch
git commit -m "Add payment feature with Stripe"
```

**Kết quả:**
```
main ─●───●
       Squashed commit (chứa tất cả changes)

Feature branch: ●─●─● (bị "nén" thành 1 commit)
```

**Git log:**
```
* commit abc123
| Add payment feature with Stripe
|
| - Add Stripe SDK
| - Add webhook handler
| - Add tests
|
* commit def456
  Previous commit on main
```

**Ưu điểm:**
- ✅ History clean, linear
- ✅ Main branch dễ đọc (1 commit = 1 feature)
- ✅ Bisect dễ dàng (mỗi commit là complete feature)

**Nhược điểm:**
- ❌ Mất commit history chi tiết
- ❌ Không thể cherry-pick individual commits

**Khi nào dùng:**
- GitHub Flow (recommended)
- Team muốn clean history
- Features có nhiều "WIP" commits

---

### 3. Rebase and Merge

```bash
# Developer rebase trước khi merge
git checkout feature-branch
git rebase main
git push --force-with-lease

# Merge (fast-forward)
git checkout main
git merge feature-branch
```

**Kết quả:**
```
main ─●─●─●─●─●─●
           └─ Feature commits (linear)

No merge commit
```

**Git log:**
```
* commit abc123
| Add tests for payment
|
* commit def456
| Add webhook handler
|
* commit ghi789
| Add Stripe SDK
|
* commit jkl012
  Previous commit on main
```

**Ưu điểm:**
- ✅ History linear, không có merge commits
- ✅ Git log đẹp, dễ đọc (straight line)
- ✅ Bisect dễ (không có merge commits làm nhiễu)

**Nhược điểm:**
- ❌ Mất context về feature boundary
- ❌ Phải force-push (rủi ro nếu không cẩn thận)
- ❌ Conflict phải resolve từng commit (phức tạp)

**Khi nào dùng:**
- Trunk-based development
- Team advanced với Git
- Ưu tiên linear history

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: Merge Conflict Khi Rebase

**Triệu chứng:**
```bash
git rebase main
CONFLICT (content): Merge conflict in src/app.js
error: could not apply abc123... Add new feature
```

**Nguyên nhân:**
- Feature branch cũ (lâu chưa rebase)
- Main đã thay đổi cùng dòng code
- Nhiều developers cùng edit một file

**Cách khắc phục:**

```bash
# 1. Check conflict
git status
# Unmerged paths:
#   both modified:   src/app.js

# 2. Open file và fix conflict
vim src/app.js

# File trông như này:
<<<<<<< HEAD (main)
function handlePayment() {
  return processStripe();
}
=======
function handlePayment() {
  return processPaypal();
}
>>>>>>> abc123 (Add new feature)

# 3. Fix: giữ cả 2 hoặc chọn 1
function handlePayment(method) {
  if (method === 'stripe') {
    return processStripe();
  } else {
    return processPaypal();
  }
}

# 4. Mark resolved
git add src/app.js
git rebase --continue

# 5. Nếu conflict tiếp → lặp lại bước 2-4
# Nếu conflict quá nhiều → abort
git rebase --abort
# Dùng merge thay vì rebase
git merge main
```

**Verify fix:**
```bash
# Run tests
npm test

# Check code works
npm start
```

---

### ❌ Lỗi 2: Force Push Xóa Mất Code Của Teammate

**Triệu chứng:**
```bash
# You
git push --force origin feature-branch

# Teammate (đã push lên feature-branch trước đó)
git push origin feature-branch
# error: failed to push some refs
# Updates were rejected because the remote contains work that you do not have locally
```

**Nguyên nhân:**
- `--force` ghi đè lịch sử mù quáng
- Teammate đã push commits mới mà bạn chưa pull

**Cách khắc phục:**

```bash
# ❌ NGUY HIỂM - Không bao giờ dùng
git push --force

# ✅ AN TOÀN - Dùng này
git push --force-with-lease
```

**Giải thích `--force-with-lease`:**
```bash
# Check remote tracking branch
git push --force-with-lease origin feature-branch

# Behavior:
# - IF remote == local tracking branch → Push OK
# - IF remote có commits mới → REJECT (bảo vệ teammate's work)
```

**Nếu đã force push nhầm:**
```bash
# 1. Teammate check reflog
git reflog
# abc123 HEAD@{0}: reset: moving to HEAD~1
# def456 HEAD@{1}: commit: My work (BỊ MẤT)

# 2. Recover commit
git cherry-pick def456

# 3. Push again
git push origin feature-branch --force-with-lease
```

---

### ❌ Lỗi 3: Release Branch Out-of-date

**Triệu chứng:**

Release branch tạo 2 tuần trước, develop đã có thêm 30 commits

```bash
release/2.0.0 ─────────→ (2 weeks old)

develop ─────●─●─●─●─●─●─●→ (30 commits mới)
```

**Vấn đề:**
- Release branch thiếu bug fixes từ develop
- Không muốn merge toàn bộ develop (có features mới)

**Cách khắc phục:**

```bash
# ❌ KHÔNG NÊN: Merge develop vào release
# (Release chỉ fix bugs, không add features mới)

# ✅ ĐÚNG: Cherry-pick bug fixes cụ thể
git checkout release/2.0.0

# Cherry-pick bug fix từ develop
git cherry-pick abc123
# commit abc123: Fix login timeout issue

git cherry-pick def456
# commit def456: Fix memory leak in image upload

# Push
git push origin release/2.0.0
```

**Prevent future:**
```bash
# Best practice:
# Fix bugs trực tiếp trên release branch
# Sau đó merge release → develop (không ngược lại)
```

---

### ❌ Lỗi 4: Feature Branch Quá Cũ, Conflict Nhiều

**Triệu chứng:**
```bash
# Feature branch tạo 3 tháng trước
git checkout feature/old-authentication
git rebase main
# CONFLICT in 20 files 😱
```

**Nguyên nhân:**
- Feature branch sống quá lâu (> 2 tuần)
- Main đã thay đổi quá nhiều

**Cách khắc phục:**

**Option 1: Rebase từng phần (nếu < 50 conflicts)**
```bash
git rebase main
# Fix conflicts từng commit
git add .
git rebase --continue
# Lặp lại...
```

**Option 2: Recreate branch (nếu > 50 conflicts)**
```bash
# 1. List commits trong feature branch
git log main..feature/old-authentication --oneline
# abc123 Add login UI
# def456 Add JWT logic
# ghi789 Add tests

# 2. Create new branch từ main mới
git checkout main
git pull
git checkout -b feature/authentication-v2

# 3. Cherry-pick commits từ old branch
git cherry-pick abc123
# Conflict ít hơn (vì base mới)
git add .
git cherry-pick --continue

git cherry-pick def456
git cherry-pick ghi789

# 4. Test
npm test

# 5. Create PR
gh pr create --title "Add authentication (v2)"
```

**Verify fix:**
```bash
# Compare với old branch
git diff feature/old-authentication feature/authentication-v2
# Should be minimal diff
```

**Prevent future:**
```bash
# Best practices:
# - Feature branch sống < 1 tuần
# - Rebase thường xuyên (mỗi ngày)
# - Keep PRs small (< 300 lines)
```

---

## Best Practices

### 1. Branch Naming Conventions

```bash
# ✅ Good naming
feature/user-authentication
feature/payment-stripe-integration
feature/JIRA-1234-add-logging

bugfix/fix-login-redirect
bugfix/JIRA-5678-memory-leak

hotfix/critical-security-patch
hotfix/v1.2.1-login-crash

release/1.0.0
release/2024-Q1

# ❌ Bad naming
dev-branch
fix
test
my-branch
branch1
```

**Pattern:**
```
<type>/<description>
<type>/<ticket-id>-<description>

Types:
- feature/ : Tính năng mới
- bugfix/  : Fix bugs không critical
- hotfix/  : Fix bugs critical trên production
- release/ : Release branch (GitFlow)
- chore/   : Refactor, cleanup, dependencies
```

---

### 2. Commit Messages (Conventional Commits)

```bash
# Format
<type>(<scope>): <subject>

[optional body]

[optional footer]

# Types:
# feat     - Tính năng mới
# fix      - Bug fix
# docs     - Documentation
# style    - Formatting (không thay đổi logic)
# refactor - Refactor code
# test     - Add tests
# chore    - Maintenance, dependencies

# ✅ Good examples
git commit -m "feat(auth): Add JWT token generation"
git commit -m "fix(api): Handle null user in GET /profile"
git commit -m "docs(readme): Add deployment instructions"
git commit -m "refactor(db): Extract connection to separate file"
git commit -m "test(payment): Add integration tests for Stripe"
git commit -m "chore(deps): Upgrade React to v18"

# ❌ Bad examples
git commit -m "fix"
git commit -m "update"
git commit -m "changes"
git commit -m "asdfasdf"
git commit -m "working now"
```

**Breaking changes:**
```bash
git commit -m "feat(api)!: Change user endpoint from /user to /users

BREAKING CHANGE: API endpoint renamed. Update all clients.
"
```

---

### 3. Pull Request Best Practices

**Size:**
```bash
# ✅ Good PR size
100-300 lines changed
Review time: 15-30 phút
Merge trong: 1-2 giờ

# ❌ Bad PR size
2000 lines changed
Review time: 3 giờ (nobody has time)
Merge trong: 1 tuần (conflicts accumulate)
```

**Description template:**
```markdown
## What
Add user authentication with JWT tokens

## Why
Required for securing API endpoints. Currently all endpoints are public.

## How
- Add JWT middleware
- Add login/register endpoints
- Add token validation
- Add refresh token logic

## Testing
- ✓ Unit tests pass (95% coverage)
- ✓ Integration tests pass
- ✓ Tested on staging environment
- ✓ Manual test: Login flow works on iOS/Android/Web

## Screenshots
[Before/After images]

## Checklist
- [x] Code follows style guide
- [x] Tests added/updated
- [x] Documentation updated
- [x] No console.log() or debug code
- [x] Reviewed my own code first
```

**Self-review trước khi request:**
```bash
# 1. Review your own PR
gh pr diff

# Check:
# - Có console.log() thừa?
# - Có TODO comments?
# - Có commented code?
# - Code format đúng?
# - Tests đầy đủ?

# 2. Run tests locally
npm test
npm run lint

# 3. Test manually
npm start
# Test all changed features

# 4. Request review
gh pr edit --add-reviewer teammate1,teammate2
```

---

### 4. Code Review Best Practices

**Reviewer:**
```bash
# ✅ Good review comments
"Consider using async/await here for better readability"
"Should we add error handling for null user?"
"Nice solution! Can we add a test for edge case X?"
"This could cause race condition if two users..."

# ❌ Bad review comments
"This is wrong"
"Change this"
"I don't like it"
"Rewrite everything"
```

**Author:**
```bash
# ✅ Good responses
"Good point! Fixed in commit abc123"
"Added error handling and test"
"Thanks! Changed to async/await"

# ❌ Bad responses
"Works for me"
"I know what I'm doing"
"Just merge it"
```

---

### 5. Branch Hygiene

```bash
# Delete merged branches
git branch --merged main
# feature/old-feature-1
# feature/old-feature-2

git branch -d feature/old-feature-1
git branch -d feature/old-feature-2

# Delete remote merged branches
git remote prune origin

# Auto-delete after merge (GitHub setting)
Settings > General > Automatically delete head branches: ✓
```

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: GitHub Flow Workflow - Mức độ: Dễ

**Mô tả:**

Bạn đang làm việc trong team startup (5 người) dùng GitHub Flow. Implement một feature đơn giản: thêm button "Export CSV" vào dashboard.

**Yêu cầu:**
1. Tạo feature branch từ main
2. Commit changes (giả lập bằng tạo file export.js)
3. Tạo Pull Request
4. Simulate review approval
5. Merge về main (dùng squash)
6. Clean up branch

**Gợi ý:**
- Dùng `gh pr create` để tạo PR
- Check `gh pr status` để xem PR
- Dùng `gh pr merge --squash`
- Verify với `git log --oneline`

**Mục tiêu:**
Làm quen với GitHub Flow workflow cơ bản và GitHub CLI

---

### Bài Tập 2: GitFlow Release Cycle - Mức độ: Trung bình

**Mô tả:**

Bạn là tech lead của team 10 người dùng GitFlow. Team đang chuẩn bị release v2.0.0 với 2 features đã develop xong. Cần tạo release branch, fix bugs QA tìm ra, và release.

**Yêu cầu:**
1. Setup GitFlow (`git flow init`)
2. Tạo 2 feature branches và merge về develop
3. Tạo release branch v2.0.0
4. Simulate bug fix trên release branch
5. Finish release (merge về main + develop, tag version)
6. Verify version tag tồn tại

**Gợi ý:**
- Dùng `git flow feature start/finish`
- Dùng `git flow release start/finish`
- Check tags với `git tag -l`
- Xem history với `git log --graph --oneline --all`

**Mục tiêu:**
Hiểu GitFlow release cycle và cách manage multiple branches

---

### Bài Tập 3: Hotfix Under Pressure + Automation - Mức độ: Khó

**Mô tả:**

Production (v2.0.0) đang bị critical bug: API `/login` trả về 500 error. Bạn cần hotfix NGAY trong < 30 phút. Đồng thời, viết bash script (kết hợp kiến thức Day 12-14) để automate hotfix workflow.

**Yêu cầu:**

**Part 1: Manual hotfix**
1. Tạo hotfix branch từ main
2. Fix bug (tạo file hotfix-login.js để simulate)
3. Test (giả lập bằng chạy script test)
4. Merge về main VÀ develop
5. Tag v2.0.1
6. Verify hotfix trong cả 2 branches

**Part 2: Automate với bash script**
Viết script `hotfix.sh` nhận arguments:
- Hotfix name
- Bug description
- Affected file

Script tự động:
- Create hotfix branch
- Create fix file với timestamp
- Commit with proper message
- Show instructions để merge

**Gợi ý:**
- Dùng `git flow hotfix start/finish` hoặc manual workflow
- Script cần validate branch hiện tại
- Dùng `$1, $2, $3` cho arguments (Day 12)
- Add error handling với `set -e` (Day 14)
- Log timeline để track 30-minute goal

**Mục tiêu:**
Tích hợp Git workflow với bash scripting, simulate production pressure, automate repetitive tasks

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1: GitHub Flow Workflow

**Cách làm từng bước:**

```bash
# 1. Tạo feature branch từ main
git checkout main
git pull origin main
git checkout -b feature/export-csv
```

*Giải thích:* Luôn checkout từ main mới nhất để avoid conflicts

```bash
# 2. Commit changes
mkdir -p src/features
cat > src/features/export.js <<EOF
// Export CSV functionality
export function exportToCSV(data) {
  const csv = data.map(row => row.join(',')).join('\n');
  return csv;
}
EOF

git add src/features/export.js
git commit -m "feat(dashboard): Add CSV export functionality"

# Add tests
cat > src/features/export.test.js <<EOF
// Tests for CSV export
test('exportToCSV converts array to CSV', () => {
  const data = [['Name', 'Age'], ['Alice', '30']];
  const result = exportToCSV(data);
  expect(result).toBe('Name,Age\nAlice,30');
});
EOF

git add src/features/export.test.js
git commit -m "test(dashboard): Add tests for CSV export"

git push -u origin feature/export-csv
```

*Giải thích:* Commit nhỏ, focused. Mỗi commit = một logical change

```bash
# 3. Tạo Pull Request
gh pr create \
  --title "Add CSV export to dashboard" \
  --body "## What
Add CSV export button to dashboard

## Testing
- Unit tests added
- Tested manually with sample data

## Screenshot
[Attach image of new button]"
```

*Giải thích:* PR description chi tiết giúp reviewers hiểu context

```bash
# 4. Check PR status
gh pr status
# Current branch
#   #123  Add CSV export to dashboard [feature/export-csv]
#   - Checks: ✓ ci/tests

# 5. Simulate review (trong thực tế teammate approve)
# gh pr review --approve (teammate chạy)

# 6. Merge về main (squash)
gh pr merge --squash
# ✓ Merged pull request #123
```

*Giải thích:* Squash merge = clean history (1 commit = 1 feature)

```bash
# 7. Verify merge
git checkout main
git pull
git log --oneline -5
# abc123 Add CSV export to dashboard (#123)
# def456 Previous commit
```

**Output mong đợi:**
```
* abc123 (main) Add CSV export to dashboard (#123)
* def456 Previous commit
```

**Điểm chú ý:**
- Branch tự động bị xóa sau merge (GitHub setting)
- Squash merge nén tất cả commits thành 1
- Main history clean, dễ đọc

---

### Đáp Án Bài 2: GitFlow Release Cycle

**Cách làm từng bước:**

```bash
# 1. Setup GitFlow
git flow init
# Branch name for production releases: [main]
# Branch name for "next release" development: [develop]
# Feature branches prefix: [feature/]
# Release branches prefix: [release/]
# Hotfix branches prefix: [hotfix/]
```

*Giải thích:* GitFlow init tạo develop branch và config prefixes

```bash
# 2. Tạo feature 1: User notifications
git flow feature start user-notifications

# Simulate development
mkdir -p src/notifications
echo "// Notification service" > src/notifications/service.js
git add src/notifications/
git commit -m "feat: Add notification service"

echo "// Notification UI" > src/notifications/NotificationBell.js
git commit -am "feat: Add notification bell UI"

# Finish feature (merge về develop)
git flow feature finish user-notifications
```

*Giải thích:* Feature branch merge về develop với `--no-ff`

```bash
# 3. Tạo feature 2: Dark mode
git flow feature start dark-mode

echo "// Dark mode theme" > src/theme/dark.js
git add src/theme/
git commit -m "feat: Add dark mode theme"

git flow feature finish dark-mode
```

*Giải thích:* Develop giờ có 2 features ready for release

```bash
# 4. Tạo release branch v2.0.0
git flow release start 2.0.0
# Switched to a new branch 'release/2.0.0'

# Simulate QA testing → phát hiện bugs
echo "// Fix notification crash" >> src/notifications/service.js
git commit -am "fix: Handle null user in notifications"

echo "// Fix dark mode on iOS" >> src/theme/dark.js
git commit -am "fix: Dark mode flickering on iOS"

# Update version
echo "2.0.0" > VERSION
git commit -am "chore: Bump version to 2.0.0"
```

*Giải thích:* Release branch chỉ fix bugs, không add features

```bash
# 5. Finish release
git flow release finish 2.0.0
# Prompts:
# - Merge message for main: [Accept default]
# - Tag message: "Release version 2.0.0"
# - Merge message for develop: [Accept default]

# This does:
# - Merge release/2.0.0 → main
# - Tag v2.0.0 on main
# - Merge release/2.0.0 → develop
# - Delete release/2.0.0 branch
```

*Giải thích:* Finish release đồng bộ bug fixes về cả main và develop

```bash
# 6. Verify version tag
git tag -l
# v2.0.0

git log --oneline --graph --all -10
```

**Output mong đợi:**
```
*   abc123 (tag: v2.0.0, main) Merge branch 'release/2.0.0'
|\
| * def456 chore: Bump version to 2.0.0
| * ghi789 fix: Dark mode flickering on iOS
| * jkl012 fix: Handle null user in notifications
|/
*   mno345 (develop) Merge branch 'release/2.0.0' into develop
|\
| (same commits as above)
|/
* pqr678 feat: Add dark mode theme
* stu901 feat: Add notification bell UI
```

**Điểm chú ý:**
- Main và develop cùng có bug fixes
- Tag v2.0.0 chỉ trên main (production)
- Release branch tự động xóa sau finish

---

### Đáp Án Bài 3: Hotfix Under Pressure + Automation

**Part 1: Manual Hotfix**

```bash
# Scenario: Production v2.0.0 has login bug
# Time starts: 10:00 AM

# 1. Tạo hotfix branch từ main
git checkout main
git pull origin main
git checkout -b hotfix/login-500-error

# 2. Fix bug
cat > src/api/login-fix.js <<EOF
// Fix: Add null check for user object
export function handleLogin(req) {
  const user = getUserFromDB(req.email);

  // FIX: Check if user exists before accessing properties
  if (!user) {
    return { error: 'User not found', status: 404 };
  }

  // Original code (was crashing on null user)
  return { token: generateToken(user.id), status: 200 };
}
EOF

git add src/api/login-fix.js
git commit -m "fix(api): Add null check in login handler

Fixes 500 error when user doesn't exist.
Now returns 404 instead of crashing.

Resolves: #TICKET-123"
```

*Giải thích:* Commit message chi tiết giúp audit và rollback sau này

```bash
# 3. Test locally
echo "Running tests..."
# npm test (in real scenario)
echo "✓ All tests pass"

# 4. Merge về main
git checkout main
git merge --no-ff hotfix/login-500-error
git tag -a v2.0.1 -m "Hotfix: Login 500 error"
git push origin main --tags

# 5. Merge về develop
git checkout develop
git merge --no-ff hotfix/login-500-error
git push origin develop

# 6. Clean up
git branch -d hotfix/login-500-error

# Time ends: 10:25 AM
# Total: 25 minutes ✓
```

**Part 2: Automation Script**

```bash
# Tạo file hotfix.sh
cat > hotfix.sh <<'EOF'
#!/bin/bash

# Hotfix automation script
# Usage: ./hotfix.sh <hotfix-name> <description> <affected-file>

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validation
if [ $# -ne 3 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <hotfix-name> <description> <affected-file>"
    echo "Example: $0 login-500 'Fix null user' src/api/login.js"
    exit 1
fi

HOTFIX_NAME=$1
DESCRIPTION=$2
AFFECTED_FILE=$3
START_TIME=$(date +%s)

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}Warning: Not on main branch (currently on $CURRENT_BRANCH)${NC}"
    echo "Switching to main..."
    git checkout main
fi

# Update main
echo -e "${GREEN}Updating main branch...${NC}"
git pull origin main

# Create hotfix branch
BRANCH_NAME="hotfix/$HOTFIX_NAME"
echo -e "${GREEN}Creating hotfix branch: $BRANCH_NAME${NC}"
git checkout -b "$BRANCH_NAME"

# Create fix file with timestamp
FIX_FILE="$AFFECTED_FILE"
echo -e "${GREEN}Creating fix in: $FIX_FILE${NC}"

cat > "$FIX_FILE" <<FIXEOF
// Hotfix: $DESCRIPTION
// Created: $(date)
// Branch: $BRANCH_NAME

// TODO: Implement fix here

// Add your fix code...

FIXEOF

# Commit
echo -e "${GREEN}Committing fix...${NC}"
git add "$FIX_FILE"
git commit -m "fix: $DESCRIPTION

Hotfix for production issue.
Affected file: $AFFECTED_FILE

$(date)"

# Calculate time elapsed
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Hotfix branch created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Branch: $BRANCH_NAME"
echo "Time elapsed: ${ELAPSED}s"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit $FIX_FILE and implement the fix"
echo "2. Test the fix: npm test"
echo "3. Merge to main:"
echo "   git checkout main"
echo "   git merge --no-ff $BRANCH_NAME"
echo "   git tag -a v2.0.1 -m 'Hotfix: $DESCRIPTION'"
echo "   git push origin main --tags"
echo "4. Merge to develop:"
echo "   git checkout develop"
echo "   git merge --no-ff $BRANCH_NAME"
echo "   git push origin develop"
echo "5. Clean up:"
echo "   git branch -d $BRANCH_NAME"
echo ""
echo -e "${YELLOW}Target: Complete within 30 minutes!${NC}"
echo -e "${YELLOW}Time remaining: $((1800 - ELAPSED))s${NC}"
EOF

chmod +x hotfix.sh
```

*Giải thích:* Script automate các bước lặp lại, reduce human error

**Chạy script:**
```bash
./hotfix.sh login-500 "Fix null user check" src/api/login.js
```

**Output mong đợi:**
```
Updating main branch...
Already up to date.
Creating hotfix branch: hotfix/login-500
Creating fix in: src/api/login.js
Committing fix...
[hotfix/login-500 abc123] fix: Fix null user check
 1 file changed, 8 insertions(+)

========================================
Hotfix branch created successfully!
========================================

Branch: hotfix/login-500
Time elapsed: 3s

Next steps:
1. Edit src/api/login.js and implement the fix
2. Test the fix: npm test
3. Merge to main:
   git checkout main
   git merge --no-ff hotfix/login-500
   git tag -a v2.0.1 -m 'Hotfix: Fix null user check'
   git push origin main --tags
...

Target: Complete within 30 minutes!
Time remaining: 1797s
```

**Điểm chú ý:**
- Script validate inputs để avoid errors
- Track time elapsed để meet 30-minute goal
- Generate template code với TODO để guide developer
- Clear next steps để không quên bước nào
- Color output để dễ đọc under pressure

**Advanced enhancement:**
```bash
# Thêm vào script để auto-merge sau khi test pass
if [ "$4" == "--auto-merge" ]; then
    echo "Running tests..."
    npm test && {
        echo "Tests passed! Auto-merging..."
        git checkout main
        git merge --no-ff "$BRANCH_NAME"
        # ... rest of merge steps
    }
fi
```

---

## 🎓 Tóm Tắt Ngày 31

✅ **GitFlow cho team lớn với release planning** — 5 loại branches (main, develop, feature, release, hotfix), structured workflow

✅ **GitHub Flow đơn giản cho continuous deployment** — Chỉ main + feature branches, PR-based workflow

✅ **Trunk-based cho tốc độ tối đa** — Commit thẳng lên main với short-lived branches (<1 ngày), feature flags

✅ **Branch protection rules** — Prevent accidents, require reviews + CI pass trước khi merge

✅ **Merge strategies** — Merge commit (preserve history), squash (clean history), rebase (linear history)

**Kỹ năng đạt được:**
- Chọn workflow phù hợp dựa trên team size, release cycle, và deploy frequency
- Implement GitFlow với hotfix và release branches
- Setup branch protection rules trên GitHub để enforce quality
- Resolve merge conflicts và use force-with-lease an toàn
- Automate hotfix workflow với bash scripting

**Lệnh quan trọng:**
- `git flow feature/release/hotfix start/finish` - GitFlow workflow
- `gh pr create/merge` - GitHub Flow
- `git merge --no-ff` - Preserve feature boundaries
- `git push --force-with-lease` - Safe force push
- `git rebase -i` - Clean up commit history

**Kết nối với ngày tiếp theo:**

Ngày 32 sẽ học về **GitHub PRs & Code Review** — Pull Request templates, review checklist, code review best practices, và automated checks!
