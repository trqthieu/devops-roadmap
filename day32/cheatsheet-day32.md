# GitHub PRs & Code Review

# Tạo Pull Request
gh pr create --title "Add feature X" --body "Description"   # tạo PR
gh pr create --draft                                         # tạo draft PR (WIP)
gh pr create --base develop --head feature-branch            # chỉ định base và head
gh pr create --assignee @me                                  # assign cho mình
gh pr create --reviewer user1,user2                          # request reviewers
gh pr create --label "bug,urgent"                            # add labels

# Quản lý PR
gh pr list                                                   # list tất cả PRs
gh pr list --author @me                                      # PRs của mình
gh pr list --state open                                      # PRs đang open
gh pr list --label "needs-review"                            # filter theo label
gh pr view 123                                               # xem chi tiết PR
gh pr view 123 --web                                         # mở PR trên browser
gh pr diff 123                                               # xem diff

# Update PR
gh pr edit 123 --title "New title"                           # đổi title
gh pr edit 123 --add-reviewer user1                          # add reviewer
gh pr edit 123 --remove-reviewer user2                       # remove reviewer
gh pr edit 123 --add-label "ready-to-merge"                  # add label
gh pr ready                                                  # convert draft → ready

# Review PR
gh pr review 123 --approve                                   # approve
gh pr review 123 --request-changes --body "Please fix X"     # request changes
gh pr review 123 --comment --body "LGTM"                     # comment only
gh pr review 123 --approve --body "Great work!"              # approve với comment

# Merge PR
gh pr merge 123 --merge                                      # merge commit
gh pr merge 123 --squash                                     # squash and merge
gh pr merge 123 --rebase                                     # rebase and merge
gh pr merge 123 --auto                                       # auto merge khi CI pass
gh pr merge 123 --delete-branch                              # merge + xóa branch

# Comment trên PR
gh pr comment 123 --body "Can you add tests?"                # add comment
gh pr comment 123 --body "Fixed in latest commit"            # reply

# Checkout PR để test local
gh pr checkout 123                                           # checkout PR branch
gh pr checks 123                                             # xem CI status
gh pr checks 123 --watch                                     # watch CI progress

# Close/Reopen PR
gh pr close 123                                              # close PR
gh pr close 123 --comment "Duplicate of #100"                # close với lý do
gh pr reopen 123                                             # reopen PR

# PR templates (tạo file)
# .github/pull_request_template.md
cat << 'EOF' > .github/pull_request_template.md
## What
- Description of changes

## Why
- Reason for changes

## Testing
- [ ] Unit tests added
- [ ] Manual testing done

## Checklist
- [ ] Code follows style guide
- [ ] Documentation updated
EOF

# CODEOWNERS file (auto-assign reviewers)
# .github/CODEOWNERS
cat << 'EOF' > .github/CODEOWNERS
# Backend team reviews backend code
/src/api/* @backend-team

# Frontend team reviews frontend
/src/ui/* @frontend-team

# DevOps reviews CI/CD
/.github/workflows/* @devops-team
EOF

# Suggested reviewers trong PR description
# Uses GitHub's ML to suggest best reviewers
gh pr create --fill                                          # auto-fill với commit msgs
