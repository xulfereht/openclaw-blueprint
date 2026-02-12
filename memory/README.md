# Memory System

The agent wakes fresh every session. Files are how it persists.

## Directory Structure

```
memory/
├── YYYY-MM-DD.md              # Daily logs
│   └── ### (HH:MM) Title      # Timestamped sections (mandatory)
│
├── handoff.md                 # Session handoff (read first on boot)
│   └── 5 sections, <50 lines, overwrite each time
│
├── tasks.md                   # Unified task list
│   └── - [ ] Task @agent @now/@next
│
├── MEMORY.md                  # Curated long-term decisions + lessons
│
├── for-user/                  # User-facing (in user's language)
│   ├── ideas.md               # Append-and-review idea log
│   ├── docs/                  # Generated documents
│   │   ├── research/          # Research reports
│   │   ├── briefs/            # Briefings
│   │   ├── analysis/          # Analysis documents
│   │   ├── reviews/           # Reviews
│   │   └── newsletter/        # Automated newsletters
│   └── retrospectives/        # Weekly/monthly/quarterly retros
│       ├── templates/
│       ├── weekly/
│       ├── monthly/
│       └── quarterly/
│
├── persona/                   # Evolving understanding of the user
│   ├── README.md              # 4-layer system explained
│   └── persona_latest.md      # Current snapshot
│
├── prompts/                   # Reusable prompt templates
│   ├── handoff.md
│   ├── spec.md
│   └── newsletter.md
│
└── security-log.md            # Security incident log
```

## Key Rules

### Checkpoint Rule (Compaction Safety)

The agent's context gets compacted unpredictably. Record critical information proactively:

| Trigger | Action |
|---------|--------|
| Topic change | Record 1-2 lines of previous topic's conclusion |
| Decision made | "Decided to ~" with rationale — immediately |
| 30 min elapsed | Save key context mid-conversation |

**Principle**: Record before compaction hits. What isn't recorded doesn't exist.

### Write Gate (Quality Filter)

Before writing to any memory file, check:

- Does this change behavior tomorrow? (action-altering)
- Is this a commitment or promise? (obligation)
- Is this a decision with rationale? (decision+why)

If none → don't write. Let it stay in daily log only. This prevents memory pollution.

### Superseded Rule

When updating a decision in MEMORY.md:

```markdown
[superseded: 2026-02-08] Old decision: Use file watchers for embeddings
New decision: Use 3-hourly cron job for embeddings (simpler, sufficient)
```

Never silently delete — preserve decision history.

### Language Policy

| Audience | Language |
|----------|----------|
| LLM reads (AGENTS.md, prompts, specs) | English |
| User reads (docs, briefs, ideas) | User's language |
| Code comments | English |

English is 2-2.4x more token-efficient for LLM processing.

## Ideas System (Karpathy Append-and-Review)

Single file: `for-user/ideas.md`

- Trigger words ("memo:", "idea:", "note:") → append at top with timestamp
- Gravity: top = newest/active, bottom = oldest/inactive
- No deletion — gravity serves as natural archiving
- Review: when related topic comes up, mention old related notes
- Rescue: user says "올려줘" → move from bottom to top with rescue count

## Persona System

4-layer evolving model of the user:

| Layer | Update Frequency | What |
|-------|-----------------|------|
| CORE | Annual | Values, style, boundaries |
| STRATEGIC | Quarterly | Interests, long-term goals |
| TACTICAL | Monthly | Current focus areas (max 3) |
| SIGNALS | Weekly | Patterns, lessons, shifts |

Auto-updated from retrospectives. Helps align daily work with what matters.
