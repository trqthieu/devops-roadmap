# 📘 Ngày 59: Review & Documentation

## 🎯 Mục Tiêu Ngày Hôm Nay

Viết documentation đầy đủ cho DevOps pipeline: runbooks, architecture diagrams, post-mortems, và handoff documentation. Documentation tốt là chìa khóa để team có thể maintain và improve system trong tương lai.

---

## Tại Sao Documentation Quan Trọng?

### Vấn Đề: Undocumented Systems

```
Scenario: On-call engineer receives alert at 2 AM

WITHOUT documentation:
❌ 02:00 - Alert fires: "API down"
❌ 02:05 - On-call wakes up, confused
❌ 02:10 - Doesn't know where to start
❌ 02:30 - SSH to server, grep logs randomly
❌ 03:00 - Tries random fixes
❌ 03:30 - Finally finds issue (database down)
❌ 04:00 - Service restored
→ 2 hours of stress, trial-and-error

WITH documentation (runbook):
✅ 02:00 - Alert fires: "API down"
✅ 02:05 - On-call checks runbook
✅ 02:10 - Follows troubleshooting steps
✅ 02:15 - Identifies database connection issue
✅ 02:20 - Restarts database (per runbook)
✅ 02:25 - Service restored
→ 25 minutes, systematic approach, less stress
```

---

### The Cost of Poor Documentation

```
Real costs:

1. Longer incident resolution
   - No docs: 2-4 hours MTTR
   - Good docs: 30 minutes MTTR
   → 4-8x faster resolution

2. Knowledge silos
   - Only 1 person knows how to deploy
   - That person on vacation = blocked team
   → Bus factor = 1 (risky!)

3. Onboarding time
   - New engineer: 2 weeks to understand system
   - With docs: 2 days
   → 5x faster onboarding

4. Repeated mistakes
   - Same incident happens multiple times
   - No post-mortem = no learning
   → Groundhog day of incidents
```

---

## Types of Documentation

### 1. Runbook (Operational Guide)

```
PURPOSE: Step-by-step instructions for common operations

AUDIENCE: On-call engineers, ops team

CONTENT:
- Quick reference (URLs, contacts)
- Common operations (deploy, rollback, scale)
- Troubleshooting (symptoms → investigation → resolution)
- Emergency procedures

WHEN TO USE:
- During incidents (2 AM emergencies)
- For routine tasks (deployments)
- Training new team members

EXAMPLE STRUCTURE:
1. Quick Reference
   - Service URLs
   - Monitoring dashboards
   - Emergency contacts

2. Common Operations
   - Deploy new version
   - Rollback
   - Scale service
   - Restart containers

3. Troubleshooting
   - Service down
   - High error rate
   - High latency
   - Database issues

4. Escalation
   - When to escalate
   - Who to contact
   - Communication templates
```

**Runbook best practices:**

```
✅ DO:
- Use command-line examples (copy-paste ready)
- Include expected output
- Add verification steps
- Keep updated (review quarterly)
- Test runbook during incidents

❌ DON'T:
- Assume prior knowledge
- Use jargon without explanation
- Skip verification steps
- Let it get outdated
```

---

### 2. Architecture Diagrams

```
PURPOSE: Visual representation of system components

AUDIENCE: Developers, ops, stakeholders

TYPES:

1. High-Level Architecture
   - Shows major components (API, DB, cache)
   - Data flow between components
   - External dependencies

2. CI/CD Pipeline
   - Code → build → test → deploy flow
   - Tools used at each stage
   - Environments (staging, production)

3. Network Diagram
   - Servers, load balancers, firewalls
   - Port numbers, protocols
   - Security zones

4. Data Flow
   - How data moves through system
   - APIs, databases, caches
   - Request/response sequence
```

**Diagram tools:**

```
Mermaid (code-based, version-controlled):
✅ Text-based (easy to diff in Git)
✅ Renders in GitHub/GitLab
✅ Can be automated
❌ Limited styling options

Draw.io / Diagrams.net (visual):
✅ Rich visuals
✅ Drag-and-drop
✅ Export to PNG/PDF
❌ Binary format (hard to version control)

Lucidchart (SaaS):
✅ Collaborative
✅ Templates
❌ Paid
❌ Not version controlled

Recommendation:
- Use Mermaid for simple diagrams (keep in Git)
- Use Draw.io for complex diagrams (export to PNG)
```

---

### 3. Post-Mortems (Incident Reports)

```
PURPOSE: Learn from incidents, prevent recurrence

AUDIENCE: Entire engineering team, management

WHEN TO WRITE:
- After every production incident
- After major deployments (if issues occurred)
- Near-misses (almost caused outage)

STRUCTURE:

1. Summary (1-2 paragraphs)
   - What happened?
   - When?
   - Impact?
   - Resolution?

2. Timeline
   - Chronological events
   - Who did what when

3. Root Cause
   - Why did it happen?
   - Contributing factors
   - Not a "who" (blameless!)

4. Impact
   - Users affected
   - Revenue lost
   - Reputation damage

5. Resolution
   - What fixed it?
   - How was it verified?

6. Action Items
   - Preventive measures
   - Owner + deadline
   - Track to completion

7. Lessons Learned
   - What went well?
   - What didn't?
   - What will we do differently?
```

**Blameless post-mortem culture:**

```
❌ BAD: "John deployed bad code and broke production"
✅ GOOD: "Deployment lacked automated tests, allowing bug to reach production"

Focus on SYSTEMS, not PEOPLE:
- Why did CI not catch the bug? → Add more tests
- Why was rollback manual? → Automate rollback
- Why did alert fire late? → Improve alert threshold

Result:
- Team feels safe to report issues
- Honest discussion of problems
- System improvements
- Fewer repeat incidents
```

---

### 4. Handoff Documentation

```
PURPOSE: Transfer knowledge when team member leaves

AUDIENCE: New team member taking over

CONTENT:

1. Project Overview
   - What does it do?
   - Tech stack
   - Repositories

2. Access & Credentials
   - Where are secrets stored?
   - How to access servers?
   - Login to monitoring tools

3. Architecture
   - Link to diagrams
   - Component descriptions

4. Deployment
   - How to deploy?
   - Environments
   - Rollback procedure

5. Monitoring
   - Dashboards
   - Key metrics
   - Alert channels

6. On-call
   - Link to runbook
   - Common issues
   - Escalation path

7. Key Contacts
   - Who knows what?
   - Team structure

8. Quarterly Tasks
   - Security updates
   - Certificate renewals
   - Backup verification

9. Known Issues
   - Accepted limitations
   - Future improvements
```

---

## Documentation Best Practices

### Keep Documentation Close to Code

```
Documentation should live WITH the code:

project/
├── README.md                  # Quick start, overview
├── ARCHITECTURE.md            # System architecture
├── RUNBOOK.md                 # Operational guide
├── HANDOFF.md                 # Handoff documentation
├── docs/
│   ├── deployment.md          # Deployment guide
│   ├── monitoring.md          # Monitoring guide
│   ├── post-mortems/          # Incident reports
│   │   ├── 2025-05-09-db-outage.md
│   │   └── 2025-05-15-high-latency.md
│   └── diagrams/
│       ├── architecture.mmd   # Mermaid diagrams
│       └── network.png        # Network diagram

Benefits:
✅ Version controlled (see history)
✅ Updated with code (part of PR review)
✅ Always in sync
✅ Easy to find
```

---

### Documentation as Code

```
Treat documentation like code:

1. Version control (Git)
   - Track changes
   - Review in PRs
   - Rollback if needed

2. Automation
   - Generate diagrams from code
   - Auto-generate API docs (OpenAPI)
   - Link checks (detect broken links)

3. CI/CD for docs
   - Lint markdown
   - Build diagrams
   - Deploy to wiki/website

4. Code review
   - Require docs update in PRs
   - Review docs like code
   - Approve before merge
```

**Example PR checklist:**

```markdown
## Pull Request Checklist

### Code
- [ ] Tests added/updated
- [ ] Linter passes
- [ ] No security vulnerabilities

### Documentation
- [ ] README updated (if public API changed)
- [ ] RUNBOOK updated (if ops changed)
- [ ] ARCHITECTURE updated (if system changed)
- [ ] Deployment guide updated (if deploy changed)
```

---

### Keep It Up to Date

```
Documentation decay:

Week 1: Perfect docs
Month 1: Slightly outdated (minor changes)
Month 3: Moderately outdated (missing features)
Month 6: Completely outdated (misleading)
→ Team stops trusting docs, doesn't update them
→ Vicious cycle

Prevention:

1. Quarterly review
   - Schedule docs review (like security audits)
   - Assign owner
   - Update outdated sections

2. On-call feedback
   - After incident, update runbook
   - "This step was confusing" → Clarify
   - "This command didn't work" → Fix

3. PR requirement
   - Can't merge code without docs update
   - CI fails if docs are inconsistent

4. Ownership
   - Each doc has an owner
   - Owner responsible for accuracy
   - Rotate ownership quarterly
```

---

## Post-Mortem Writing

### The Five Whys Technique

```
Root cause analysis using "5 Whys":

Incident: API returned 500 errors

Why? Database connection failed
↓
Why? Connection pool exhausted
↓
Why? Too many concurrent requests
↓
Why? Traffic spike from marketing campaign
↓
Why? We didn't plan for traffic increase
↓
ROOT CAUSE: Lack of capacity planning

Action items:
1. Add alert for connection pool >80%
2. Implement auto-scaling
3. Coordination between marketing and engineering
4. Load testing before campaigns
```

---

### Action Item Tracking

```
Good action items are SMART:

S - Specific: "Add alert" (not "improve monitoring")
M - Measurable: "Alert when pool >80%"
A - Assignable: @sarah owns it
R - Realistic: Can be done in 1 week
T - Time-bound: Deadline: 2025-05-15

Track in:
- GitHub Issues
- Jira
- Project management tool

Review in:
- Weekly team meeting
- Next post-mortem (reference previous)
```

---

## Documentation for Different Audiences

### Runbook: On-call Engineer

```
Scenario: 2 AM incident

Needs:
- Quick reference (no scrolling)
- Command-line examples (copy-paste)
- Expected output (know if it worked)
- Escalation path (when to page manager)

Style:
- Short sentences
- Bullet points
- Code blocks
- No fluff
```

---

### Architecture Docs: New Developer

```
Scenario: First day on team

Needs:
- Big picture (how does system work?)
- Component relationships (what talks to what?)
- Data flow (where does data come from/go?)
- Technology choices (why PostgreSQL, not MySQL?)

Style:
- Visual diagrams
- Explanatory text
- External links (tech docs)
- Examples
```

---

### Post-Mortem: Management

```
Scenario: Quarterly review

Needs:
- Impact (revenue, users, reputation)
- Trends (are we improving?)
- Cost of incidents
- ROI of improvements

Style:
- Executive summary
- Metrics/charts
- Business impact
- Action items + status
```

---

## Tóm Tắt

### Documentation Types

```
RUNBOOK:
- For: On-call engineers
- When: During incidents, operations
- Content: Step-by-step instructions
- Update: After every incident

ARCHITECTURE:
- For: Developers, ops, stakeholders
- When: Onboarding, planning changes
- Content: Diagrams, component descriptions
- Update: When system changes

POST-MORTEM:
- For: Entire team, management
- When: After incidents
- Content: What happened, why, action items
- Update: Track action items to completion

HANDOFF:
- For: New team member
- When: Team transitions
- Content: Access, architecture, operations
- Update: Quarterly
```

---

### Best Practices Checklist

```
✅ Documentation:
- [ ] README.md exists (quick start)
- [ ] RUNBOOK.md exists (ops guide)
- [ ] ARCHITECTURE.md exists (diagrams)
- [ ] Post-mortems written (after incidents)
- [ ] Handoff docs ready (if needed)

✅ Quality:
- [ ] Clear, concise writing
- [ ] Code examples are correct
- [ ] Diagrams are up-to-date
- [ ] Links work (no 404s)
- [ ] Reviewed by teammate

✅ Maintenance:
- [ ] Documentation in Git (version controlled)
- [ ] Updated in PRs (not separate)
- [ ] Quarterly review scheduled
- [ ] Owner assigned
- [ ] On-call feedback incorporated
```

---

### Key Learnings

```
1. Good documentation saves time
   - Faster incident resolution (4-8x)
   - Faster onboarding (5x)
   - Fewer repeat incidents

2. Keep docs close to code
   - In Git repository
   - Updated in PRs
   - Version controlled

3. Different audiences, different docs
   - Runbook → On-call (operational)
   - Architecture → Developers (technical)
   - Post-mortem → Team (learning)
   - Handoff → New members (transfer)

4. Documentation is never done
   - Systems change, docs must too
   - Quarterly reviews
   - After every incident
   - Part of PR checklist
```

---

### Next Steps

```
✅ Day 59: Documentation (today)
→ Day 60: Month 2 final review and self-assessment
→ Month 3: Kubernetes & production scaling
```

Remember: Good documentation is a gift to your future self and your team. When you're woken up at 2 AM, you'll be grateful for that runbook you wrote!
