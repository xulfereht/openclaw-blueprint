# HEARTBEAT.md — Template

> Autonomous check loop. Runs every N minutes.

---

## Routine

### 0. Process Management
```
process list → categorize → act
```

| Type | Pattern | Action |
|------|---------|--------|
| Server | Ports, launchd-managed | Skip |
| Coding Agent | Claude Code, background | Poll → check → decide |
| One-shot | Completed/failed scripts | Clean up |

### 1. Check Tasks
```bash
# In-progress tasks (highest priority)
grep "@agent @now" memory/tasks.md

# If found → execute immediately (don't reply HEARTBEAT_OK)
# If not → check queue
grep "@agent @next" memory/tasks.md

# If found → pick top one → change to @now → execute
```

### 2. Battery Check
```bash
# Read current tier from polled usage data
cat dashboard/anthropic-usage.json | jq '.battery.tier'

# If orange/red → notify user
# Adjust model selection for any spawned work
```

### 3. System Health
```bash
# Check monitoring endpoint
curl -s http://localhost:3001/api/monitoring/overview | jq '.health'
```

**Notify when**:
- Gateway down → immediately
- Budget critical → warn user
- Embeddings down → warn

**Ignore**:
- Search API rate limits (normal for free plans)
- Server not running (doesn't need to always be up)

### 4. Proactive Work (quiet)
- Organize memory, update MEMORY.md
- Check git status
- Commit and push changes

---

## Notification Criteria

**Notify**:
- 🚨 System down
- ⚠️ Budget critical
- 💡 Important finding
- 📭 Work queue empty (once per 24h)

**Proceed quietly**:
- Routine tasks, log cleanup, memory updates, pattern tracking

---

## Principles

- **Simple**: No complex pipelines
- **As needed**: Skip unnecessary checks
- **Transparent**: Notify important findings only
- **Autonomous**: Safe tasks run automatically
