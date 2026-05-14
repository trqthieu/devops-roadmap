# 📘 Ngày 35: GitHub Actions Cơ Bản

## 🎯 Mục Tiêu Ngày Hôm Nay

- Hiểu kiến trúc và cách hoạt động của GitHub Actions
- Nắm vững YAML syntax cho workflow files
- Tạo được workflow đầu tiên với `on`, `jobs`, `steps`, `uses`, `run`
- Phân biệt khi nào dùng pre-built actions và khi nào chạy commands trực tiếp
- Setup CI pipeline cơ bản cho Node.js app

---

## Tại Sao GitHub Actions Quan Trọng?

### So Sánh Với CI/CD Tools Khác

```
┌────────────────────────────────────────────────────┐
│ Traditional CI/CD (Jenkins, GitLab CI, CircleCI)   │
├────────────────────────────────────────────────────┤
│ ✅ Powerful, flexible                              │
│ ❌ Cần setup server riêng                          │
│ ❌ Configuration phức tạp                          │
│ ❌ Maintain infrastructure                         │
│ ❌ Chi phí hosting                                 │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ GitHub Actions                                      │
├────────────────────────────────────────────────────┤
│ ✅ Tích hợp sẵn với GitHub (zero setup)            │
│ ✅ Không cần quản lý servers                       │
│ ✅ YAML đơn giản và dễ đọc                         │
│ ✅ Marketplace với 20,000+ actions                 │
│ ✅ Free: 2000 phút/tháng cho private repos         │
│ ✅ Unlimited cho public repos                      │
│ ✅ Self-hosted runners nếu cần                     │
└────────────────────────────────────────────────────┘
```

**Khi nào dùng GitHub Actions:**
- ✅ Code đã host trên GitHub
- ✅ Team muốn CI/CD setup nhanh
- ✅ Không muốn maintain infrastructure
- ✅ Budget hạn chế (free tier rất generous)

**Khi nào cân nhắc alternatives:**
- Jenkins: Cần customization cao, on-premise, legacy systems
- GitLab CI: Code host trên GitLab
- CircleCI: Cần advanced caching và performance optimization

---

## GitHub Actions Là Gì?

### Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│ GitHub Repository                                     │
│ ├── .github/                                         │
│ │   └── workflows/            ← Workflow definitions │
│ │       ├── ci.yml                                   │
│ │       ├── deploy.yml                               │
│ │       └── test.yml                                 │
│ └── src/                                             │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ Event: push, PR, schedule, manual...
                   ↓
┌──────────────────────────────────────────────────────┐
│ GitHub Actions Engine                                 │
│ - Detect event                                       │
│ - Parse workflow YAML                                │
│ - Queue jobs                                         │
│ - Allocate runners                                   │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ Provision runner
                   ↓
┌──────────────────────────────────────────────────────┐
│ GitHub-hosted Runner (VM mới cho mỗi run)           │
│ ┌──────────────────────────────────────────────────┐ │
│ │ Job 1: build                                      │ │
│ │   Step 1: ✅ Checkout code                       │ │
│ │   Step 2: ✅ Setup Node.js 20                    │ │
│ │   Step 3: ✅ Install dependencies (npm ci)       │ │
│ │   Step 4: ✅ Run tests (npm test)                │ │
│ │   Step 5: ✅ Build app (npm run build)           │ │
│ └──────────────────────────────────────────────────┘ │
│                                                       │
│ Runner specs (ubuntu-latest):                        │
│ - CPU: 2 cores                                       │
│ - RAM: 7 GB                                          │
│ - Disk: 14 GB SSD                                    │
│ - Pre-installed: Node, Python, Docker, Git, etc.     │
└──────────────────┬───────────────────────────────────┘
                   │
                   │ Stream logs + status
                   ↓
┌──────────────────────────────────────────────────────┐
│ GitHub UI - Actions Tab                               │
│ - Workflow status (✅ Success / ❌ Failed)           │
│ - Real-time logs                                     │
│ - Artifacts storage                                  │
│ - Run history                                        │
└──────────────────────────────────────────────────────┘
```

**Ví dụ minh họa:**
Khi bạn push code lên GitHub:
1. **Event trigger:** GitHub detect có push event
2. **Workflow selection:** Tìm file `.github/workflows/*.yml` có `on: push`
3. **Job execution:** Spin up runner VM → chạy từng step → stream logs
4. **Result:** Green checkmark ✅ hoặc red X ❌ trên commit

---

## Hướng Dẫn Từng Bước

### Bước 1: Tạo Folder Workflows

**Mục đích:** GitHub Actions yêu cầu workflow files phải nằm đúng vị trí `.github/workflows/`

**Thực hiện:**
```bash
# Trong root của repository
mkdir -p .github/workflows
```

**Kết quả mong đợi:**
```
your-repo/
├── .github/
│   └── workflows/    ← Folder này
├── src/
├── package.json
└── README.md
```

**Giải thích:**
- `.github/` là folder convention của GitHub (giống `.git/`)
- `workflows/` chứa tất cả workflow definition files
- File extension phải là `.yml` hoặc `.yaml`
- Tên file tùy ý (VD: `ci.yml`, `deploy.yml`, `tests.yml`)

---

### Bước 2: Tạo Workflow File Đầu Tiên

**Mục đích:** Viết workflow đơn giản nhất để hiểu cấu trúc YAML

**Thực hiện:**
Tạo file `.github/workflows/hello.yml`:

```yaml
name: Hello World

on: [push]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Hello, World!"
```

**Kết quả mong đợi:**
File có 3 phần chính:
1. `name`: Tên workflow hiển thị trên UI
2. `on`: Event trigger (chạy khi push)
3. `jobs`: Danh sách công việc

**Ví dụ:**
```yaml
# .github/workflows/hello.yml
name: Hello World                    # ← Metadata

on: [push]                           # ← Trigger

jobs:                                # ← Jobs section
  greet:                             # ← Job ID
    runs-on: ubuntu-latest           # ← Runner OS
    steps:                           # ← Steps list
      - run: echo "Hello, World!"    # ← Command
```

**Giải thích:**

**Line 1 - `name: Hello World`:**
- Tên hiển thị trong GitHub Actions tab
- Không bắt buộc nhưng nên có để dễ nhận diện
- Có thể dùng emoji: `name: 🚀 Deploy Production`

**Line 3 - `on: [push]`:**
- Event trigger: workflow chạy khi có event nào
- `[push]` = mọi push vào bất kỳ branch nào
- Có thể filter theo branch, path, etc. (học ở Ngày 36)

**Line 5-9 - `jobs`:**
- Workflow có thể có nhiều jobs
- `greet` là job ID (tùy đặt)
- `runs-on: ubuntu-latest`: Chạy trên Ubuntu runner (VM)
- `steps`: Danh sách các bước thực hiện tuần tự

**Line 9 - `- run: echo "Hello, World!"`:**
- Chạy shell command trực tiếp
- Tương đương với gõ lệnh trong terminal

---

### Bước 3: Commit và Push Workflow File

**Mục đích:** Kích hoạt workflow lần đầu tiên

**Thực hiện:**
```bash
git add .github/workflows/hello.yml
git commit -m "Add Hello World workflow"
git push origin main
```

**Kết quả mong đợi:**
```
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Writing objects: 100% (4/4), 345 bytes | 345.00 KiB/s, done.
Total 4 (delta 0), reused 0 (delta 0)
To github.com:your-username/your-repo.git
   abc1234..def5678  main -> main
```

**Giải thích:**
- Ngay sau khi push, GitHub detect file trong `.github/workflows/`
- GitHub Actions engine sẽ:
  1. Parse YAML file
  2. Validate syntax
  3. Queue workflow run
  4. Allocate runner VM
  5. Execute jobs

---

### Bước 4: Kiểm Tra Workflow Run Trên GitHub

**Mục đích:** Xem workflow có chạy thành công không

**Thực hiện:**
1. Mở repository trên GitHub
2. Click tab **Actions** (bên cạnh Pull requests)
3. Thấy workflow "Hello World" đang chạy hoặc đã xong

**Kết quả mong đợi:**
```
┌─────────────────────────────────────────────┐
│ Actions                                      │
├─────────────────────────────────────────────┤
│ All workflows                                │
│                                              │
│ ✅ Hello World                              │
│    Add Hello World workflow                  │
│    #1: Commit abc1234 pushed by username    │
│    ✅ greet                                 │
│    Completed in 15s                          │
└─────────────────────────────────────────────┘
```

**Giải thích:**
- ✅ Green checkmark = workflow passed
- ❌ Red X = workflow failed
- 🟡 Yellow dot = đang chạy
- Click vào workflow name để xem chi tiết logs

---

### Bước 5: Xem Logs Chi Tiết

**Mục đích:** Hiểu workflow chạy những gì, debug nếu fail

**Thực hiện:**
1. Click vào workflow run (VD: "Add Hello World workflow")
2. Click vào job name "greet"
3. Expand step "Run echo "Hello, World!""

**Kết quả mong đợi:**
```
Run echo "Hello, World!"
  echo "Hello, World!"
  shell: /usr/bin/bash -e {0}
Hello, World!
```

**Ví dụ đầy đủ logs:**
```
Set up job
  ✅ Runner: GitHub Actions 10
  ✅ Prepare workflow directory
  ✅ Prepare all required actions
  ✅ Complete job preparation

Run echo "Hello, World!"
  Hello, World!

Complete job
  ✅ Cleaning up orphan processes
```

**Giải thích:**
- **Set up job:** GitHub chuẩn bị runner (pull Docker image, setup environment)
- **Run echo:** Thực thi command, output ra "Hello, World!"
- **Complete job:** Cleanup resources

**Điểm chú ý:**
- Mỗi step có thể expand/collapse
- Có timestamp chính xác
- Failed steps sẽ highlight đỏ với error message
- Có thể download logs dạng text file

---

### Bước 6: Thêm Multiple Steps Vào Workflow

**Mục đích:** Hiểu cách workflow chạy nhiều bước tuần tự

**Thực hiện:**
Sửa `.github/workflows/hello.yml`:

```yaml
name: Hello World

on: [push]

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Say hello
        run: echo "Hello, World!"

      - name: Show date
        run: date

      - name: List files
        run: ls -la
```

**Kết quả mong đợi:**
Push lên GitHub và xem logs:
```
✅ Say hello
   Hello, World!

✅ Show date
   Mon May 13 10:30:45 UTC 2024

✅ List files
   total 8
   drwxr-xr-x 3 runner docker 4096 May 13 10:30 .
   drwxr-xr-x 3 runner docker 4096 May 13 10:30 ..
   drwxr-xr-x 8 runner docker 4096 May 13 10:30 .git
```

**Giải thích:**
- `name:` cho mỗi step giúp logs dễ đọc
- Steps chạy **tuần tự** (không parallel)
- Nếu step nào fail → các steps sau không chạy
- Mỗi step có working directory riêng (mặc định là repo root)

---

### Bước 7: Sử Dụng Pre-built Actions

**Mục đích:** Hiểu cách dùng actions từ Marketplace thay vì viết commands thủ công

**Thực hiện:**
Tạo workflow mới `.github/workflows/checkout-demo.yml`:

```yaml
name: Checkout Demo

on: [push]

jobs:
  demo:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: List files after checkout
        run: ls -la
```

**Kết quả mong đợi:**
```
✅ Checkout repository
   Syncing repository: your-username/your-repo
   Fetching the repository
   ...

✅ List files after checkout
   total 24
   -rw-r--r-- 1 runner docker  1234 May 13 10:30 README.md
   -rw-r--r-- 1 runner docker   567 May 13 10:30 package.json
   drwxr-xr-x 3 runner docker  4096 May 13 10:30 src
```

**Ví dụ so sánh:**

**❌ Không dùng action (phức tạp):**
```yaml
- run: |
    git init
    git remote add origin https://github.com/${{ github.repository }}
    git fetch --depth=1 origin ${{ github.ref }}
    git checkout FETCH_HEAD
```

**✅ Dùng action (đơn giản):**
```yaml
- uses: actions/checkout@v4
```

**Giải thích:**

**`uses: actions/checkout@v4`:**
- `actions/checkout`: Repository chứa action (trên GitHub)
- `@v4`: Version của action (pin version để stable)
- Action này clone repo code vào runner

**Tại sao cần checkout:**
- Runner VM ban đầu **RỖNG**
- Không có code của bạn
- Phải checkout trước khi chạy npm, build, test, etc.

**Tại sao dùng actions thay vì commands:**
- ✅ Reusable: Hàng nghìn projects dùng, đã tested kỹ
- ✅ Maintained: Cộng đồng update khi có breaking changes
- ✅ Simple: Giảm boilerplate code
- ✅ Documented: Có README và examples

---

## Áp Dụng Vào Dự Án Thực Tế

### Tình Huống 1: Startup Cần CI Tự Động Cho Node.js App

**Bối cảnh:**
Bạn làm trong startup 5 người, develop một Node.js API. Team có quy tắc:
- Mọi code push lên `main` hoặc `develop` phải pass lint và tests
- Không được merge PR nếu tests fail
- Hiện tại dev phải nhớ chạy `npm run lint` và `npm test` thủ công trước khi push → dễ quên, dễ sai

**Vấn đề cần giải quyết:**
Làm sao tự động chạy lint + test mỗi khi có code mới, và block merge nếu fail?

**Giải pháp từng bước:**

**1. Tạo workflow CI:**
```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
```

**2. Setup branch protection:**
- GitHub repo → Settings → Branches
- Add rule for `main` branch
- Check: "Require status checks to pass before merging"
- Select: "Lint Code" và "Run Tests"

**3. Test workflow:**
- Tạo PR với code có lỗi lint → workflow fail → không merge được
- Fix lỗi → push lại → workflow pass → có thể merge

**Kết quả:**
- ✅ Mọi code vào main đều đã qua lint + test
- ✅ Không thể merge code bị lỗi (GitHub block)
- ✅ Dev không cần nhớ chạy commands thủ công
- ✅ Team confidence cao hơn khi merge code

---

### Tình Huống 2: Team Muốn Build Docker Image Mỗi Khi Merge PR

**Bối cảnh:**
Team bạn deploy app bằng Docker. Quy trình cũ:
1. Dev merge PR vào `main`
2. Ai đó phải nhớ vào local
3. Chạy `docker build` thủ công
4. `docker push` lên Docker Hub
5. Notify team → ai đó deploy

→ **Vấn đề:** Manual, dễ quên, lỗi không consistent

**Vấn đề cần giải quyết:**
Tự động build Docker image mỗi khi code mới merge vào `main`

**Giải pháp từng bước:**

**1. Setup Docker Hub credentials:**
- GitHub repo → Settings → Secrets and variables → Actions
- Add secrets:
  - `DOCKERHUB_USERNAME`: your-username
  - `DOCKERHUB_TOKEN`: your-access-token

**2. Tạo workflow build Docker:**
```yaml
# .github/workflows/docker-build.yml
name: Build Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: your-username/your-app:latest
```

**3. Test workflow:**
- Merge PR vào `main`
- GitHub Actions tự động:
  1. Checkout code
  2. Login Docker Hub
  3. Build image từ Dockerfile
  4. Push image với tag `latest`

**4. Team deploy:**
```bash
# Trên production server
docker pull your-username/your-app:latest
docker restart app
```

**Kết quả:**
- ✅ Mỗi merge vào main → image mới tự động build
- ✅ Không cần developer chạy docker build thủ công
- ✅ Image luôn consistent với code trên main
- ✅ Deploy nhanh hơn (chỉ pull và restart)

---

## 🚨 Troubleshooting / Lỗi Thường Gặp

### ❌ Lỗi 1: Workflow Không Chạy Sau Khi Push

**Triệu chứng:**
- Push code lên GitHub
- Không thấy workflow xuất hiện trong Actions tab
- Không có notification email

**Nguyên nhân:**

**1. File path sai:**
```
❌ github/workflows/ci.yml       # thiếu dấu chấm
❌ .github/workflow/ci.yml        # thiếu 's'
❌ .github/workflows/ci.yaml.txt  # extension sai
✅ .github/workflows/ci.yml       # ĐÚNG
✅ .github/workflows/ci.yaml      # ĐÚNG
```

**2. YAML syntax error:**
```yaml
❌ jobs:
  build:
  runs-on: ubuntu-latest    # indentation sai

✅ jobs:
  build:
    runs-on: ubuntu-latest  # indent đúng (2 spaces)
```

**3. Branch filter không match:**
```yaml
on:
  push:
    branches: [main]

# → Chỉ chạy khi push lên 'main'
# → Nếu push lên 'develop' → KHÔNG chạy
```

**Cách khắc phục:**

**Step 1: Validate YAML syntax**
```bash
# Online validator
# → yamllint.com

# Hoặc dùng CLI tool
npm install -g yaml-lint
yaml-lint .github/workflows/ci.yml
```

**Step 2: Check file path**
```bash
# Đúng structure
ls -la .github/workflows/
# Output:
# ci.yml
# deploy.yml
```

**Step 3: Check GitHub Actions page**
- Repo → Actions tab
- Nếu thấy "No workflows found" → file path sai
- Nếu thấy workflows nhưng không run → check branch filter

**Step 4: Test với simple workflow**
```yaml
name: Test
on: [push]  # Trigger on ANY push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Working!"
```

**Verify đã fix:**
- Push file test lên GitHub
- Vào Actions tab
- Thấy workflow "Test" xuất hiện và chạy
- Logs in ra "Working!"

---

### ❌ Lỗi 2: Step Fail Với "npm: command not found"

**Triệu chứng:**
Logs hiện:
```
Run npm ci
/usr/bin/bash: npm: command not found
Error: Process completed with exit code 127.
```

**Nguyên nhân:**
GitHub runner VM không có Node.js pre-installed **trong context của workflow**. Phải setup Node.js trước khi dùng npm.

**Ví dụ workflow bị lỗi:**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci              # ❌ FAIL: npm chưa có
```

**Cách khắc phục:**

**Step 1: Thêm action setup Node.js**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js        # ← Thêm step này
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci                 # ✅ Giờ npm đã có
```

**Step 2: Verify Node.js installed**
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: 20

- name: Verify installation
  run: |
    node --version
    npm --version
```

**Output:**
```
v20.12.0
10.5.0
```

**Giải thích:**
- `ubuntu-latest` runner có sẵn nhiều tools (git, curl, docker)
- NHƯNG không có Node.js trong PATH mặc định
- `actions/setup-node@v4`:
  1. Download Node.js version được chỉ định
  2. Add vào PATH
  3. Setup npm cache (nếu có `cache: 'npm'`)

**Verify đã fix:**
- Push workflow đã sửa
- Check logs → step "Install dependencies" pass ✅
- Không còn lỗi "command not found"

---

### ❌ Lỗi 3: Workflow Chạy Mãi Không Xong (Timeout)

**Triệu chứng:**
- Workflow chạy 30 phút, 1 giờ, vẫn chưa xong
- Status: "In progress" với spinner xoay mãi
- Sau 6 giờ → GitHub cancel với "Job was cancelled"

**Nguyên nhân:**

**1. Command bị hang (đợi input):**
```bash
# Command này đợi user nhập password
npm install -g some-package
# → Workflow stuck vì không có user input

# Script đợi confirmation
rm -i file.txt  # -i hỏi "Are you sure?"
```

**2. Infinite loop trong code:**
```javascript
// test.js
while (true) {
  console.log("Running...");
}
```

**3. Long-running task không cần thiết:**
```yaml
- run: npm install  # Download hàng GB dependencies
```

**Cách khắc phục:**

**Step 1: Set timeout cho jobs**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 10    # ← Fail nếu job > 10 phút
    steps:
      - run: npm ci
      - run: npm test
```

**Step 2: Set timeout cho steps riêng lẻ**
```yaml
steps:
  - name: Install dependencies
    run: npm ci
    timeout-minutes: 5     # ← Step này max 5 phút

  - name: Run tests
    run: npm test
    timeout-minutes: 10    # ← Step này max 10 phút
```

**Step 3: Fix commands hang**
```yaml
# ❌ Command có interactive prompt
- run: npm install -g package

# ✅ Non-interactive mode
- run: npm install -g package --yes

# ❌ Script đợi input
- run: ./deploy.sh

# ✅ Pass input qua pipe hoặc env var
- run: echo "yes" | ./deploy.sh
  env:
    AUTO_APPROVE: true
```

**Step 4: Cache dependencies**
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'npm'           # ← Cache ~/.npm folder

- name: Install dependencies
  run: npm ci              # Nhanh hơn nhờ cache
```

**Verify đã fix:**
- Workflow complete trong thời gian hợp lý (< 10 phút)
- Không bị timeout
- Logs không show spinning cursor lâu

**Điểm chú ý:**
- Timeout default: **6 giờ** (quá lâu cho hầu hết workflows)
- Recommended timeout: **10-30 phút** cho CI
- Nếu cần > 30 phút → xem xét optimization (cache, parallel jobs)

---

## 💪 Bài Tập Thực Hành

### Bài Tập 1: Hello World Có Custom Message - Mức độ: Dễ

**Mô tả:**
Tạo workflow in ra message tùy chỉnh khi push code lên branch `main`. Workflow phải có:
- Tên workflow: "Greeting"
- Job chạy trên ubuntu-latest
- 2 steps:
  1. In ra "Hello from GitHub Actions!"
  2. In ra ngày giờ hiện tại

**Gợi ý:**
- File path: `.github/workflows/greeting.yml`
- Dùng `echo` để in message
- Dùng `date` command để show thời gian
- Trigger: `on: push` với filter `branches: [main]`

**Mục tiêu:**
- Làm quen với YAML syntax cơ bản
- Hiểu workflow structure: name → on → jobs → steps
- Practice tạo file workflow và commit lên GitHub

---

### Bài Tập 2: CI Workflow Cho Node.js App - Mức độ: Trung bình

**Mô tả:**
Bạn có một Node.js project với:
- `package.json` có scripts: `lint`, `test`, `build`
- Muốn tự động chạy lint → test → build mỗi khi push lên `main` hoặc `develop`
- Nếu bất kỳ step nào fail → workflow phải fail

Tạo workflow với:
- Tên: "Node.js CI"
- 1 job có 5 steps:
  1. Checkout code
  2. Setup Node.js version 20
  3. Install dependencies với `npm ci`
  4. Run lint với `npm run lint`
  5. Run tests với `npm test`

**Gợi ý:**
- Dùng `actions/checkout@v4` để clone code
- Dùng `actions/setup-node@v4` để setup Node.js
- Trigger: `on: push` với filter `branches: [main, develop]`
- Đặt tên cho mỗi step với `name:`

**Mục tiêu:**
- Practice sử dụng pre-built actions
- Hiểu sequential steps execution
- Setup CI pipeline thực tế cho Node.js

---

### Bài Tập 3: Multi-Job Workflow Với Dependencies - Mức độ: Khó

**Mô tả:**
Tạo workflow phức tạp với 3 jobs:
1. **lint**: Chạy ESLint
2. **test**: Chạy tests (phải chờ lint xong)
3. **build**: Build production bundle (phải chờ cả lint VÀ test xong)

Requirements:
- Workflow chỉ chạy khi push lên `main` branch
- Mỗi job phải có tên rõ ràng (display name)
- Tất cả jobs chạy trên ubuntu-latest
- Phải có caching cho npm dependencies

**Gợi ý:**
- Dùng `needs:` để tạo job dependencies
- Dùng `cache: 'npm'` trong setup-node action
- Job test phải có `needs: lint`
- Job build phải có `needs: [lint, test]`

**Mục tiêu:**
- Hiểu job dependencies và execution order
- Practice với multi-job workflows
- Tích hợp caching để optimize performance
- Áp dụng concepts từ Ngày 12 (bash scripting) và Ngày 14 (automation)

---

## ✅ Đáp Án Bài Tập

### Đáp Án Bài 1:

**Cách làm từng bước:**

1. Tạo file workflow
   ```bash
   mkdir -p .github/workflows
   touch .github/workflows/greeting.yml
   ```
   *Giải thích:* Tạo folder structure đúng convention của GitHub Actions

2. Viết workflow content
   ```yaml
   # .github/workflows/greeting.yml
   name: Greeting

   on:
     push:
       branches: [main]

   jobs:
     greet:
       runs-on: ubuntu-latest
       steps:
         - name: Say hello
           run: echo "Hello from GitHub Actions!"

         - name: Show current date
           run: date
   ```
   *Giải thích:*
   - `name: Greeting`: Tên workflow hiển thị trên UI
   - `on.push.branches: [main]`: Chỉ chạy khi push lên main
   - `jobs.greet`: Job ID (có thể đặt tên khác)
   - `runs-on: ubuntu-latest`: Dùng Ubuntu runner
   - 2 steps với `run:` chạy shell commands

3. Commit và push
   ```bash
   git add .github/workflows/greeting.yml
   git commit -m "Add greeting workflow"
   git push origin main
   ```
   *Giải thích:* Push file workflow lên GitHub để trigger lần đầu

4. Kiểm tra kết quả
   - Vào GitHub → Actions tab
   - Click workflow "Greeting"
   - Xem logs

**Output mong đợi:**
```
✅ Say hello
   Hello from GitHub Actions!

✅ Show current date
   Mon May 13 10:45:30 UTC 2024
```

**Điểm chú ý:**
- Nếu push lên branch khác (không phải main) → workflow không chạy
- Date sẽ show theo UTC timezone (không phải local time)
- Có thể thêm emoji vào message: `echo "👋 Hello from GitHub Actions!"`

---

### Đáp Án Bài 2:

**Cách làm từng bước:**

1. Tạo file workflow
   ```bash
   touch .github/workflows/ci.yml
   ```

2. Viết workflow với 5 steps
   ```yaml
   # .github/workflows/ci.yml
   name: Node.js CI

   on:
     push:
       branches: [main, develop]

   jobs:
     ci:
       name: CI Pipeline
       runs-on: ubuntu-latest
       steps:
         - name: Checkout code
           uses: actions/checkout@v4

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: 20

         - name: Install dependencies
           run: npm ci

         - name: Run linter
           run: npm run lint

         - name: Run tests
           run: npm test
   ```
   *Giải thích chi tiết từng step:*

   **Step 1 - Checkout code:**
   ```yaml
   - name: Checkout code
     uses: actions/checkout@v4
   ```
   - Clone repository code vào runner VM
   - Không có step này → runner không có source code
   - `@v4` là version của action (nên pin version)

   **Step 2 - Setup Node.js:**
   ```yaml
   - name: Setup Node.js
     uses: actions/setup-node@v4
     with:
       node-version: 20
   ```
   - Download và install Node.js version 20
   - Add node và npm vào PATH
   - Cần thiết vì runner mặc định không có Node.js

   **Step 3 - Install dependencies:**
   ```yaml
   - name: Install dependencies
     run: npm ci
   ```
   - `npm ci` (clean install) thay vì `npm install`
   - Nhanh hơn, deterministic hơn
   - Require file `package-lock.json`

   **Step 4 - Run linter:**
   ```yaml
   - name: Run linter
     run: npm run lint
   ```
   - Chạy script `lint` từ package.json
   - Nếu có lỗi lint → exit code != 0 → workflow fail
   - Step sau không chạy nếu step này fail

   **Step 5 - Run tests:**
   ```yaml
   - name: Run tests
     run: npm test
   ```
   - Chạy test suite
   - Workflow pass chỉ khi tất cả tests pass

3. Commit và test
   ```bash
   git add .github/workflows/ci.yml
   git commit -m "Add CI workflow"
   git push origin develop
   ```

**Output mong đợi:**
```
✅ Checkout code
✅ Setup Node.js
✅ Install dependencies (35s)
✅ Run linter
   > eslint src/
✅ Run tests
   > jest
   PASS  src/utils.test.js
   Test Suites: 1 passed, 1 total
   Tests:       5 passed, 5 total
```

**Điểm chú ý:**
- Nếu push lên branch khác (VD: feature/xyz) → workflow KHÔNG chạy
- Step nào fail trước → các step sau skip
- Install dependencies thường mất 30-60s (có thể cache để nhanh hơn)

**Cách làm alternative (có caching):**
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'npm'           # ← Thêm caching

- name: Install dependencies
  run: npm ci              # Lần 2 trở đi nhanh hơn nhờ cache
```

---

### Đáp Án Bài 3:

**Cách làm từng bước:**

1. Tạo workflow với 3 jobs
   ```yaml
   # .github/workflows/multi-job.yml
   name: Multi-Job CI

   on:
     push:
       branches: [main]

   jobs:
     lint:
       name: Lint Code
       runs-on: ubuntu-latest
       steps:
         - name: Checkout code
           uses: actions/checkout@v4

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: 20
             cache: 'npm'

         - name: Install dependencies
           run: npm ci

         - name: Run ESLint
           run: npm run lint

     test:
       name: Run Tests
       runs-on: ubuntu-latest
       needs: lint              # ← Chờ job 'lint' xong
       steps:
         - name: Checkout code
           uses: actions/checkout@v4

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: 20
             cache: 'npm'

         - name: Install dependencies
           run: npm ci

         - name: Run tests
           run: npm test

     build:
       name: Build Production
       runs-on: ubuntu-latest
       needs: [lint, test]      # ← Chờ CẢ lint VÀ test xong
       steps:
         - name: Checkout code
           uses: actions/checkout@v4

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: 20
             cache: 'npm'

         - name: Install dependencies
           run: npm ci

         - name: Build bundle
           run: npm run build
   ```

   *Giải thích chi tiết:*

   **Job dependencies:**
   ```yaml
   jobs:
     lint:
       # Không có 'needs' → chạy ngay

     test:
       needs: lint
       # Chờ 'lint' complete (pass) mới chạy
       # Nếu 'lint' fail → 'test' skip

     build:
       needs: [lint, test]
       # Chờ CẢ 'lint' VÀ 'test' pass
       # Nếu 1 trong 2 fail → 'build' skip
   ```

   **Timeline execution:**
   ```
   Time: 0s ────────> 45s ────> 90s ────> 120s

   lint:  [━━━━━━━━━] (45s)
   test:             [━━━━━━━━━] (45s) ← Chờ lint xong
   build:                       [━━━━] (30s) ← Chờ test xong

   Total: 120s (sequential, không parallel)
   ```

   **Caching hoạt động:**
   ```yaml
   cache: 'npm'
   ```
   - Lần đầu: Download tất cả node_modules (~60s)
   - Lần 2+: Restore từ cache (~5s)
   - Cache key: Hash của `package-lock.json`
   - Cache invalid khi dependencies thay đổi

2. Commit và test
   ```bash
   git add .github/workflows/multi-job.yml
   git commit -m "Add multi-job workflow with dependencies"
   git push origin main
   ```

3. Xem logs trên GitHub
   ```
   ✅ Lint Code (45s)
      ✅ Checkout code
      ✅ Setup Node.js (cache restored)
      ✅ Install dependencies (5s - from cache)
      ✅ Run ESLint

   ✅ Run Tests (45s)
      ✅ Checkout code
      ✅ Setup Node.js (cache restored)
      ✅ Install dependencies (5s - from cache)
      ✅ Run tests

   ✅ Build Production (30s)
      ✅ Checkout code
      ✅ Setup Node.js (cache restored)
      ✅ Install dependencies (5s - from cache)
      ✅ Build bundle
   ```

**Output mong đợi:**
Workflow graph trên GitHub UI:
```
┌──────┐
│ lint │ ✅
└───┬──┘
    │
    ↓
┌──────┐
│ test │ ✅
└───┬──┘
    │
    ↓
┌───────┐
│ build │ ✅
└───────┘
```

**Điểm chú ý:**
- Jobs có dependencies → chạy **sequential** (không parallel)
- Mỗi job có VM riêng → phải checkout + install lại dependencies
- Cache giúp install nhanh hơn (~5s thay vì ~60s)
- Nếu lint fail → test và build skip (màu xám trên UI)

**Cách làm alternative (parallel lint + test):**
```yaml
jobs:
  lint:
    # Không có needs → chạy ngay

  test:
    # Không có needs → chạy ngay (parallel với lint)

  build:
    needs: [lint, test]  # Chờ CẢ 2 xong
```

Timeline parallel:
```
Time: 0s ─────────> 60s ────> 90s

lint:  [━━━━━━━━━━━━] (45s)  ┐
test:  [━━━━━━━━━━━━━━━━] (60s) ┘ Parallel
build:                  [━━━] (30s)

Total: 90s (nhanh hơn 30s so với sequential)
```

**Khi nào dùng sequential vs parallel:**
- **Sequential (needs):** Test phụ thuộc vào lint pass
- **Parallel:** Lint và test độc lập → chạy cùng lúc nhanh hơn

---

## 🎓 Tóm Tắt Ngày 35

✅ **GitHub Actions** là CI/CD platform tích hợp sẵn vào GitHub, không cần setup server
✅ **Workflow files** nằm trong `.github/workflows/` với YAML syntax
✅ **Cấu trúc workflow:** name → on (triggers) → jobs → steps
✅ **Jobs** có thể chạy parallel hoặc sequential với `needs:`
✅ **Steps** dùng `uses:` (pre-built actions) hoặc `run:` (shell commands)
✅ **Runner** là VM (ubuntu/windows/macos) mà workflow chạy trên đó
✅ **Pre-built actions** giúp reuse logic (checkout, setup-node, etc.)
✅ **Caching** tăng tốc workflow bằng cách cache dependencies

**Kỹ năng đạt được:**
- Tạo workflow file đầu tiên từ zero
- Hiểu YAML syntax và workflow structure
- Phân biệt khi nào dùng actions vs commands
- Setup CI pipeline thực tế: checkout → setup → install → lint → test → build
- Debug workflows với logs và troubleshooting
- Tạo job dependencies với `needs:`
- Optimize performance với caching

**Lệnh quan trọng:**
- `gh workflow list` - List tất cả workflows trong repo
- `gh workflow view ci.yml` - Xem chi tiết workflow
- `gh run list` - Xem history của workflow runs
- `gh run view --log` - Xem logs của run gần nhất
- `gh run watch` - Watch real-time logs của run đang chạy

**Best practices:**
- ✅ Pin action versions (`@v4` thay vì `@latest`)
- ✅ Đặt tên rõ ràng cho jobs và steps
- ✅ Dùng `cache:` để tăng tốc npm/pip/gem install
- ✅ Set `timeout-minutes:` để tránh workflows chạy mãi
- ✅ Validate YAML trước khi commit (yamllint.com)
- ✅ Dùng `needs:` để control execution order
- ✅ Checkout code với `actions/checkout@v4` trước mọi step khác

**Kết nối với ngày tiếp theo:**
Ngày 36 sẽ học chi tiết về **Triggers & Events** - cách control khi nào workflow chạy với `push`, `pull_request`, `schedule`, `workflow_dispatch`, path filters, và branch filters.
