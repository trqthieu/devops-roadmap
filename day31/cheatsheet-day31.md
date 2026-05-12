# Git Workflow Nâng Cao - GitFlow, GitHub Flow, Trunk-based

# === GitFlow Workflow ===
git flow init                                    # khởi tạo gitflow
git flow feature start feature-name              # tạo feature branch từ develop
git flow feature finish feature-name             # merge feature về develop
git flow release start v1.0.0                    # tạo release branch từ develop
git flow release finish v1.0.0                   # merge release về main+develop, tag version
git flow hotfix start hotfix-name                # tạo hotfix từ main
git flow hotfix finish hotfix-name               # merge hotfix về main+develop

# === GitHub Flow (Simplified) ===
git checkout -b feature/user-auth                # tạo feature branch từ main
git push -u origin feature/user-auth             # push lên remote
gh pr create --title "Add user auth" --draft     # tạo draft PR
gh pr ready                                      # chuyển từ draft → ready for review
gh pr merge --merge                              # merge PR (merge commit)
gh pr merge --squash                             # merge PR (squash commits thành 1)
gh pr merge --rebase                             # merge PR (rebase lên main)

# === Trunk-based Development ===
git checkout main                                # về main branch
git pull --rebase                                # update từ remote (linear history)
git checkout -b quick-feature                    # tạo short-lived branch
git push origin quick-feature                    # push
gh pr create --base main                         # PR về main
git branch -d quick-feature                      # xóa sau khi merge

# === Branch Protection Rules ===
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT --input protection.json           # set protection cho main branch
# protection.json: required reviews, status checks, etc.

# === Rebase Workflow ===
git fetch origin                                 # fetch changes từ remote
git rebase origin/main                           # rebase feature lên main mới nhất
git rebase --continue                            # tiếp tục sau khi resolve conflict
git rebase --abort                               # hủy rebase
git push --force-with-lease                      # force push an toàn (check remote không đổi)

# === Interactive Rebase (Clean History) ===
git rebase -i HEAD~3                             # interactive rebase 3 commits cuối
# pick/squash/fixup/reword/drop commits
git commit --amend                               # sửa commit cuối
git commit --amend --no-edit                     # amend không đổi message

# === Branch Management ===
git branch -a                                    # xem tất cả branches (local + remote)
git branch -d feature-branch                     # xóa local branch
git push origin --delete feature-branch          # xóa remote branch
git remote prune origin                          # xóa remote-tracking branches đã xóa

# === Semantic Versioning Tags ===
git tag v1.2.3                                   # tạo lightweight tag
git tag -a v1.2.3 -m "Release 1.2.3"             # annotated tag (recommended)
git push origin v1.2.3                           # push một tag
git push origin --tags                           # push tất cả tags

# === Compare & Analyze ===
git log --graph --oneline --all                  # xem branch topology
git log main..feature-branch                     # commits trong feature chưa merge vào main
git diff main...feature-branch                   # diff từ lúc branch ra

# === Cherry-pick Commits ===
git cherry-pick abc123                           # apply commit từ branch khác
git cherry-pick abc123..def456                   # apply range commits

# === Merge Strategies ===
git merge --no-ff feature-branch                 # merge với merge commit (preserve history)
git merge --squash feature-branch                # squash tất cả commits thành 1
git merge --ff-only feature-branch               # chỉ merge nếu fast-forward được

# === Conflict Resolution ===
git status                                       # xem files conflict
git diff                                         # xem chi tiết conflicts
git add .                                        # mark conflicts đã resolved
git merge --continue                             # tiếp tục merge
git merge --abort                                # hủy merge

# === Stash (Tạm cất changes) ===
git stash                                        # cất changes chưa commit
git stash pop                                    # lấy lại stash mới nhất
git stash list                                   # xem tất cả stashes
git stash apply stash@{0}                        # apply stash cụ thể
git stash drop stash@{0}                         # xóa stash

# === Undo Changes ===
git reset --soft HEAD~1                          # undo commit, giữ changes staged
git reset --mixed HEAD~1                         # undo commit, giữ changes unstaged
git reset --hard HEAD~1                          # undo commit, xóa changes (NGUY HIỂM)
git revert abc123                                # tạo commit mới undo commit abc123

# === GitHub CLI Shortcuts ===
gh pr list                                       # list PRs
gh pr view 123                                   # xem PR #123
gh pr checkout 123                               # checkout PR #123 về local
gh pr diff                                       # xem diff của PR hiện tại
gh pr review --approve                           # approve PR
gh pr review --request-changes -b "Fix issues"   # request changes
