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
└── dayX/                         # Daily learning modules (X = 1-90)
    └── cheatsheet-dayX.md       # Command reference for that day
```

### Day Folder Structure

Each learning day follows this pattern:
- **Folder naming:** `dayX` (e.g., `day2`, `day15`, `day27`)
- **Cheatsheet naming:** `cheatsheet-dayX.md` inside each day folder
- **Content format:** Concise command references with Vietnamese comments

Example from day2:
```bash
pwd                     # đang ở đâu
ls -la                  # xem file + thư mục + ẩn + chi tiết
cd ~                    # về home
```

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

### Adding a New Day

When creating content for a new day:

1. **Check the roadmap:** Reference `devops_roadmap_3months.md` for the day's topic and learning objectives
2. **Create day folder:** `mkdir dayX` (use the correct day number)
3. **Create cheatsheet:** `touch dayX/cheatsheet-dayX.md`
4. **Content format:**
   - Use Vietnamese for all explanations and comments
   - Keep commands concise and practical
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
- **No theory:** Save detailed explanations for the main roadmap
- **Progressive complexity:** Match the difficulty to the day number

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
2. A quick reference collection of commands organized by topic
3. A personal learning journal tracking progress through checkmarks
