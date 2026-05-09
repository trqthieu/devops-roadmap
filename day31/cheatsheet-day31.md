# Git Workflow Nâng Cao - GitFlow, GitHub Flow, Trunk-based

# GitFlow workflow
git flow init                                    # khởi tạo gitflow
git flow feature start feature-name              # tạo feature branch
git flow feature finish feature-name             # merge feature về develop
git flow release start v1.0.0                    # tạo release branch
git flow release finish v1.0.0                   # merge release về main+develop
git flow hotfix start hotfix-name                # tạo hotfix từ main
git flow hotfix finish hotfix-name               # merge hotfix về main+develop

# GitHub Flow (simplified)
git checkout -b feature/user-auth                # tạo feature branch
git push -u origin feature/user-auth             # push lên remote
gh pr create --title "Add user auth"             # tạo pull request
gh pr merge --merge                              # merge PR (merge commit)
gh pr merge --squash                             # merge PR (squash commits)
gh pr merge --rebase                             # merge PR (rebase)

# Trunk-based Development
git checkout main                                # về main branch
git pull --rebase                                # update từ remote
git checkout -b short-lived-feature              # tạo short-lived branch
# commit + push nhanh (< 1 ngày)
git push origin short-lived-feature              # push
gh pr create --base main                         # PR về main
git branch -d short-lived-feature                # xóa sau khi merge

# Branch protection rules
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT --input protection.json           # set protection cho main
# protection.json: required reviews, status checks, etc.

# Rebase workflow
git checkout feature-branch
git fetch origin
git rebase origin/main                           # rebase feature lên main mới nhất
git rebase --continue                            # tiếp tục sau khi resolve conflict
git rebase --abort                               # hủy rebase
git push --force-with-lease                      # force push an toàn hơn --force

# Clean commit history
git rebase -i HEAD~3                             # interactive rebase 3 commits cuối
# pick/squash/fixup/reword/drop commits
git commit --amend                               # sửa commit cuối
git commit --amend --no-edit                     # amend không đổi message

# Branch management
git branch -a                                    # xem tất cả branches
git branch -d feature-branch                     # xóa local branch
git push origin --delete feature-branch          # xóa remote branch
git remote prune origin                          # xóa remote-tracking branches đã xóa

# Tag theo semantic versioning
git tag v1.2.3                                   # tạo lightweight tag
git tag -a v1.2.3 -m "Release 1.2.3"             # annotated tag
git push origin v1.2.3                           # push tag
git push origin --tags                           # push tất cả tags

# Compare workflows
git log --graph --oneline --all                  # xem branch topology
git log main..feature-branch                     # commits trong feature chưa merge
git diff main...feature-branch                   # diff từ lúc branch ra

# Cherry-pick commits
git cherry-pick abc123                           # apply commit từ branch khác
git cherry-pick abc123..def456                   # apply range commits
