# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Vietnamese-language DevOps learning repository** containing a structured 90-day roadmap for learning DevOps fundamentals. The content is designed for Vietnamese speakers learning Linux, Docker, CI/CD, Kubernetes, and Networking.

**Language Note:** All documentation, cheatsheets, and learning materials are in Vietnamese. When contributing or modifying content, maintain Vietnamese language throughout.

## Repository Structure

```
roadmap/
├── devops_roadmap_3months.md    # Master 90-day curriculum (Vietnamese)
├── README.md                     # Minimal project description
├── CLAUDE.md                     # This file - guidance for Claude Code
├── GENERATE_LESSONS.md           # Instructions for generating lesson files
└── dayX/                         # Daily learning modules (X = 1-90)
    ├── cheatsheet-dayX.md        # Command reference (quick lookup)
    └── lesson-dayX.md            # Conceptual explanation (deep learning)
```

### Day Folder Structure

Each learning day has **two types of files**:

**1. Cheatsheet (cheatsheet-dayX.md)**
- **Purpose:** Quick command reference
- **Format:** One-line command + Vietnamese comment
- **Use case:** Fast lookup when working

Example from day2:
```bash
pwd                     # đang ở đâu
ls -la                  # xem file + thư mục + ẩn + chi tiết
cd ~                    # về home
```

**2. Lesson (lesson-dayX.md)**
- **Purpose:** Conceptual understanding and context
- **Format:** Detailed explanations with diagrams, workflows, troubleshooting
- **Use case:** Deep learning and understanding "why"

Example structure:
- Mục tiêu ngày hôm nay
- Tại sao topic này quan trọng?
- Concepts với sơ đồ ASCII
- Workflow thực tế
- Troubleshooting
- Tóm tắt

**Pattern:** Cheatsheet = "HOW", Lesson = "WHY"

## 90-Day Curriculum Breakdown

**Month 1 (Days 1-30):** Linux & Docker Foundation
- Week 1: Linux Command Line basics
- Week 2: Advanced Linux (text processing, networking, bash scripting)
- Week 3: SSH, Security, Docker introduction
- Week 4: Docker Compose & Container Management

**Month 2 (Days 31-60):** CI/CD & GitHub Actions
- Week 5-6: Git workflows, GitHub Actions, CI pipelines
- Week 7: CD pipelines and deployment strategies
- Week 8: Infrastructure as Code, monitoring with Prometheus/Grafana

**Month 3 (Days 61-90):** Kubernetes & Networking
- Week 9-10: Kubernetes fundamentals and advanced concepts
- Week 11: Nginx and networking fundamentals
- Week 12: Kubernetes Ingress, Helm, final production project

## Working with This Repository

### Generating Lesson Files

**For creating both cheatsheet and lesson files for multiple days at once**, see `GENERATE_LESSONS.md` for detailed instructions.

**Quick command format:**
```
Tạo lesson files cho tuần <X>, từ ngày <Y> đến ngày <Z>
```

Example:
```
Tạo lesson files cho tuần 3, từ ngày 15 đến ngày 21
```

**What happens:**
1. Kiểm tra từng ngày có cheatsheet chưa
2. Nếu thiếu cheatsheet → tạo mới (tổng hợp commands của ngày đó)
3. Nếu đã có cheatsheet → giữ nguyên, không thay đổi
4. Tạo lesson files cho tất cả các ngày
5. Báo cáo files nào tạo mới, files nào giữ nguyên

### Adding a New Day (Manual)

When creating content for a new day manually:

1. **Check the roadmap:** Reference `devops_roadmap_3months.md` for the day's topic and learning objectives
2. **Create day folder:** `mkdir dayX` (use the correct day number)
3. **Create cheatsheet:** `touch dayX/cheatsheet-dayX.md`
4. **Create lesson (optional):** `touch dayX/lesson-dayX.md`
5. **Content format:**
   - Use Vietnamese for all explanations and comments
   - Cheatsheet: Keep commands concise and practical
   - Lesson: Explain concepts, workflows, and context
   - Include inline comments explaining each command's purpose
   - Focus on commands/concepts relevant to that day's topic

### Updating the Master Roadmap

When marking days as complete:
- Add ✅ checkbox to the day in `devops_roadmap_3months.md`
- Ensure the checkmark appears in the appropriate week's table

### Git Workflow

Current branch: `main`
- Commit changes with descriptive Vietnamese or English messages
- Current status shows ongoing work on day 27

## Content Guidelines

### Cheatsheet Style
- **Brevity:** One-line command + Vietnamese comment
- **Practical focus:** Commands that would be used in real DevOps scenarios
- **No theory:** Save detailed explanations for lesson files
- **Progressive complexity:** Match the difficulty to the day number

### Lesson File Style
- **Conceptual focus:** Explain "why" and "how it works", not just "how to do"
- **Structure:** Mục tiêu → Tại sao? → Khái niệm → Workflow → Troubleshooting → Tóm tắt
- **Diagrams:** Use ASCII diagrams to visualize systems and workflows
- **Real scenarios:** Include production use cases and debugging workflows
- **No commands:** Focus on explanation (commands are in cheatsheet)
- **Integration:** Reference previous lessons, build progressive understanding

### Vietnamese Language Conventions
- Use informal but professional Vietnamese
- Technical terms can remain in English (Docker, Kubernetes, CI/CD)
- Command flags and options stay in English
- Comments explain "what" the command does for quick reference

## Repository Purpose

This is a **learning documentation repository**, not a code project:
- No build system required
- No tests to run
- No dependencies to install
- Focus is on creating clear, progressive learning materials

The repository serves as:
1. A structured 90-day learning path for Vietnamese DevOps learners
2. A quick reference collection of commands organized by topic (cheatsheets)
3. A deep learning resource with conceptual explanations (lessons)
4. A personal learning journal tracking progress through checkmarks

## Progress Tracking

**Completed:**
- ✅ Week 1 (Days 1-7): Linux basics
- ✅ Week 2 (Days 8-14): Linux advanced + bash scripting

**To do:**
- ⏳ Week 3 (Days 15-21): SSH, security, Docker intro
- ⏳ Week 4 (Days 22-30): Docker Compose & management
- ⏳ Weeks 5-12: CI/CD, Kubernetes, Networking

Use `GENERATE_LESSONS.md` to create lessons for remaining weeks.
