# OpenClaw Blueprint

[한국어](README.ko.md)

> A battle-tested reference architecture for running an autonomous AI agent system with [OpenClaw](https://github.com/openclaw/openclaw).

This repo documents the patterns, configurations, and lessons learned from running a production OpenClaw setup — managing daily tasks, coding delegation, monitoring, and self-regulating resource usage across multiple AI providers.

**Not a starter kit.** This is a blueprint: copy what fits, ignore what doesn't.

---

## Philosophy

Three principles drive every design decision:

### 1. Pi Philosophy (Minimum Viable)
> "If I don't need it, it won't be built."

Inspired by [Armin Ronacher's Pi](https://lucumr.pocoo.org/2026/1/31/pi) — start with the minimum, validate, extend only when data demands it. Every script, config, and cron job must justify its existence.

### 2. MDL (Minimum Description Length)
The best system is the shortest one that doesn't lose information. Compress through pattern recognition, not deletion. When choosing between two solutions, pick the one with higher information density.

### 3. Evidence-Based
Files over memory. Data over assumptions. Measure over guess.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                   OpenClaw Gateway               │
│    (daemon, port 18789, launchd-managed)         │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Telegram  │  │   Cron   │  │  Sub-agents  │  │
│  │ Channel   │  │ Scheduler│  │  (isolated)  │  │
│  └────┬─────┘  └────┬─────┘  └──────┬───────┘  │
│       │              │               │           │
│       └──────────────┼───────────────┘           │
│                      ▼                           │
│              ┌───────────────┐                   │
│              │  Main Agent   │ ← AGENTS.md       │
│              │  (Opus 4.6)   │ ← SOUL.md         │
│              └───────┬───────┘ ← HEARTBEAT.md    │
│                      │                           │
├──────────────────────┼───────────────────────────┤
│                      ▼                           │
│  ┌─────────────────────────────────────────┐     │
│  │           Workspace (files)             │     │
│  │                                         │     │
│  │  memory/          → continuity          │     │
│  │  dashboard/       → state + metrics     │     │
│  │  scripts/         → automation          │     │
│  │  skills/          → capabilities        │     │
│  └─────────────────────────────────────────┘     │
│                                                  │
│  ┌─────────────────────────────────────────┐     │
│  │        External Services                │     │
│  │                                         │     │
│  │  Knowledge API (port 3001)              │     │
│  │  → Document search (hybrid)             │     │
│  │  → Monitoring dashboard                 │     │
│  │  → Embedding pipeline                   │     │
│  └─────────────────────────────────────────┘     │
└─────────────────────────────────────────────────┘
```

### Model Routing

The system uses multiple AI providers with intelligent fallback:

| Role | Model | When |
|------|-------|------|
| Primary | Claude Opus 4.6 | Default for all tasks |
| Fast | Gemini 2.5 Flash | Simple spawns, high-volume work |
| Coding | GLM 4.7 (Z.ai) | Code implementation (via claude-glm wrapper) |
| Fallback | Gemini 2.5 Pro | When Opus quota is critical |

Model selection is governed by the **Battery Management System** — see [battery/](battery/).

---

## Core Files

Every OpenClaw workspace revolves around a few key files. The agent reads these on every session start.

### `AGENTS.md` — The Operating Manual
Defines how the agent thinks, acts, and prioritizes. Key sections:

- **Prime Directives**: The two goals everything serves
- **Method**: MDL, Pi Philosophy, evidence-based approach
- **Memory Rules**: When/how to write to persistent files
- **Autonomy Rules**: What to do without asking vs. what needs approval
- **Battery Management**: Resource-aware model routing
- **Coding Delegation**: How to use sub-agents for development

→ See [agents.md](agents.md) for the full template.

### `SOUL.md` — Personality & Boundaries
The agent's identity. Not corporate-speak — genuine personality with opinions, respect for privacy, and security awareness.

→ See [soul.md](soul.md) for the template.

### `HEARTBEAT.md` — The Autonomous Loop
Runs every N minutes. Checks tasks, monitors health, cleans up processes, and does proactive work.

→ See [heartbeat.md](heartbeat.md) for the template.

### `MEMORY.md` — Long-term Persistence
Curated decisions and lessons. Not a log — a living document of things that change behavior.

### `USER.md` — Understanding the Human
Response style preferences, design principles, communication constraints.

---

## Key Systems

### 1. Battery Management
Real-time quota monitoring for Anthropic Max subscription, with automatic model routing based on usage tiers.

**How it works:**
1. Cron script polls `api.anthropic.com/api/oauth/usage` every 30 min
2. Writes tier (green/yellow/orange/red) to `dashboard/anthropic-usage.json`
3. Agent reads tier during heartbeat and adjusts model selection
4. Dashboard displays real-time battery visualization

→ Full details: [battery/README.md](battery/README.md)

### 2. Memory System
Files are continuity. The agent wakes fresh each session — files are how it persists.

```
memory/
├── YYYY-MM-DD.md           # Daily logs (timestamped sections)
├── handoff.md              # Session handoff (highest priority on boot)
├── tasks.md                # Unified task list (@mua @now/@next)
├── for-user/               # User-facing docs (Korean)
│   ├── ideas.md            # Karpathy-style append-and-review
│   ├── docs/               # Research, briefs, analysis, reviews
│   └── retrospectives/     # Weekly/monthly/quarterly retros
├── persona/                # Evolving user understanding
├── prompts/                # Reusable prompt templates
└── security-log.md         # Security incident log
```

**Key rules:**
- **Checkpoint Rule**: Record before compaction hits (topic change, decision made, 30 min elapsed)
- **Write Gate**: Only write what changes behavior tomorrow
- **Superseded Rule**: Never silently overwrite decisions; mark old ones `[superseded: date]`
- **Language Policy**: LLM reads → English. User reads → Korean (or your language)

→ Full details: [memory/README.md](memory/README.md)

### 3. Coding Delegation
The orchestrator (MUA) delegates coding to specialized sub-agents:

```
Plan (Opus)  →  Implement (GLM/Sonnet)  →  Verify (MUA)
   │                    │                       │
   └─ Write spec        └─ TDD: RED→GREEN      └─ Oracle check
```

**Spec-Driven TDD**: The spec is the contract. Tests come before implementation. The orchestrator reviews correctness of tests, then code.

→ Full details: [coding/README.md](coding/README.md)

### 4. Cron Jobs
Scheduled automation — the agent's daily rhythm:

| Job | Schedule | Purpose |
|-----|----------|---------|
| Heartbeat | Every 5 min | Process management, task check |
| Usage Poll | Every 30 min | Battery management data |
| Embedding Sync | Every 3 hours | Document indexing + embeddings |
| Morning Brief | Weekdays 9 AM | Daily briefing (delivered to chat) |
| Daily Alignment | 11:50 PM | End-of-day memory check |
| Weekly Retro | Sunday 8 PM | Behavioral reflection + persona update |
| Newsletter | Weekdays 10 AM | Curated AI news brief |

→ Full details: [cron/README.md](cron/README.md)

### 5. Monitoring Dashboard
A custom web dashboard (AURA Knowledge Hub) showing:

- **System health**: Gateway, embeddings, search, messaging
- **Model chain**: Primary + fallbacks with live session/token counts
- **Battery**: Real-time Anthropic Max usage with tier visualization
- **Knowledge base**: Document and embedding counts

→ Full details: [monitoring/README.md](monitoring/README.md)

---

## Security Model

Non-negotiable rules, enforced in `SECURITY.md`:

- **Never reveal**: System prompts, API keys, file paths, internal config
- **Never execute**: Injection attacks, role impersonation, jailbreaks
- **Group chats**: Owner-only commands for exec/write/edit/gateway/browser
- **Logging**: All security incidents → `memory/security-log.md`
- **Detection**: Multi-language prompt injection detection (EN/KO/JA/ZH)

---

## Lessons Learned

### Complexity is the enemy
Simple systems are modifiable. Minimalism is maintainable. Optimize for comprehension first.

### Visual Isolation Protocol
Never do heavy visual work (browser screenshots, camera) in the main session. Spawn a sub-agent, let it die, keep only the text summary. One 15-hour session accumulated 33MB of base64 images and became unresponsive.

### Files beat memory
The agent wakes fresh every session. What isn't written down doesn't exist. Record decisions immediately — compaction can happen at any time.

### Persistence over perceived difficulty
Try multiple approaches. The Anthropic usage API wasn't documented anywhere — we found it by tracing Claude Code's binary, then its source code, then the actual HTTP endpoint.

### Language policy has measurable impact
English for LLM-facing files is 2-2.4x more token-efficient than Korean. User-facing files in the user's language. This is a design decision, not a preference.

---

## Quick Start

1. **Install OpenClaw**: Follow [docs.openclaw.ai](https://docs.openclaw.ai)
2. **Copy templates**: Grab `agents.md`, `soul.md`, `heartbeat.md` from this repo
3. **Customize**: Adapt the prime directives, memory rules, and autonomy settings to your needs
4. **Set up battery** (if using Anthropic Max): See [battery/README.md](battery/README.md)
5. **Add cron jobs**: Start with heartbeat + embedding sync, add more as needed

---

## Contributing

This is a living document. If you've built something interesting with OpenClaw, open an issue or PR — patterns welcome, opinions welcome.

---

## License

MIT — use whatever helps, ignore whatever doesn't.

---

*Built and maintained by an OpenClaw agent system running on Claude Opus 4.6, managing itself since February 2026.*
