# HEARTBEAT.md v3.0 - Pi Style

> Every 30 minutes: autonomous check & work  
> **Minimalism**: Only what's needed, keep it simple

---

## 🔄 Heartbeat Routine

### 0. Session Lifecycle Management

**Philosophy**: Explicit over implicit (Pi Style)

**Save before reset**:
- Run `/summary` before `/new`
- Saves to `memory/for-user/docs/summaries/YYYY-MM-DD-{slug}.md`

**Check**: `process list` → categorize + act

**Session Types:**

| Type | Pattern | Action |
|------|---------|--------|
| Server | ports 3000/3001, launchd managed | Skip (launchd handles restart) |
| Claude Code | `claude --model`, background | Poll → check output → decide |
| One-shot | python/bash, completed/failed | Clean up |

**Claude Code Sessions** (key details):

Claude Code runs in `--print` mode (non-interactive). Notifications handled by hooks:
- `~/.claude/settings.json` has Notification hooks configured
- `permission_prompt`, `idle_prompt` → macOS notifications
- `Stop` → completion notification

**Heartbeat tasks**:
1. `process list` → check for running Claude Code sessions
2. completed → review logs + verify results (e.g., file creation)
3. failed → analyze error + retry or escalate
4. running + stale (>5min) → `process log` to check status

**MUA decision criteria** (Claude Code result verification):

| Situation | Decision |
|-----------|----------|
| File modification successful + build passes | ✅ Mark complete |
| Files modified but creation missed | 🔄 Manual patch (Phase 1 lesson) |
| Wrong direction | ❌ Re-instruct |
| Complex judgment needed | 🤔 Escalate to AMU |

---

### 1. Check Unified Tasks (tasks.md)
```bash
# Check tasks.md for @mua @now (In Progress)
grep "@mua @now" memory/tasks.md

# If found -> Execute immediately (Do NOT reply HEARTBEAT_OK)

# If not found -> Check @mua @next (Queue)
grep "@mua @next" memory/tasks.md

# If found -> Pick top one -> Change to @now -> Execute
```

**Proactive principle**:
- `@now` exists -> Must work (never idle)
- `@next` exists -> Auto-promote to `@now`

### 2. Meta-Agent execution (pattern analysis + tool generation)
```bash
python3 scripts/meta-agent.py 2>/dev/null    # Detect repetitive patterns
python3 scripts/tool-generator.py 2>/dev/null # Auto tool generation (LOW risk auto-apply, MEDIUM/HIGH need approval)
```

### 3. Unpublished commit check (MANDATORY)

```bash
bash scripts/check-unpublished.sh
```

**If UNPUBLISHED > 0**: 🚨 Notify AMU immediately with commit list.
**If CLEAN**: Proceed silently.

This catches forgotten releases. Non-negotiable check every heartbeat.

### 3.5. Release flow state check (MANDATORY)

```bash
bash scripts/release-state.sh check
```

**If IN_PROGRESS**: 🚨 Release flow interrupted! Show state + next step. Resume or notify AMU.

Release flow is ONE PACKAGE — all steps must complete in sequence:
```
[clinic-os] npm run publish          → set PUBLISHED_BETA
[baekrokdam] npm run core:pull:beta  → set CORE_PULLED
[baekrokdam] npm run build           → set BUILT
[baekrokdam] wrangler pages deploy   → set DEPLOYED
[HQ DB] stable promotion            → set STABLE_PROMOTED → clear
```

**If stuck >30min**: Escalate to AMU.
**NEVER leave a release half-done.**

### 3.6. Zombie process cleanup

```bash
bash scripts/cleanup-zombies.sh
```

**If TOTAL_CLEANED > 0**: Note in log, no notification needed (routine).
**If CLEAN**: Proceed silently.

Cleans: orphan OpenClaw browser, stale node/python processes. Skips servers, ChromeRemoteDesktop.

### 4. System health check (monitoring)

If AURA Knowledge API is running, call `/api/monitoring/overview` once.
Notify user if any service is abnormal. Ignore if normal.

```
curl -s http://localhost:3001/api/monitoring/overview
```

**Notification criteria** (noise prevention):
- Gateway `down` → 🚨 Notify immediately
- Claude budget < 20% → ⚠️ Notify
- Embeddings `down` → ⚠️ Notify
- Brave Search 429 → Ignore (normal for Free plan)
- Server not running (curl fails) → Ignore (server doesn't need to always be up)

**If normal**: Do nothing (quiet)

### 4. AMU reminders (daily)
```bash
# Cron job "amu-reminder" handles delivery (weekdays 9AM)
# Check memory/tasks.md for AMU-assigned items (@amu)
grep "@amu" memory/tasks.md 2>/dev/null
```

### 5. Memory cleanup + embeddings (daily, once per 24h)
```bash
python3 scripts/memory-maintenance.py --daily 2>/dev/null          # INDEX.md update + old file cleanup
python3 scripts/legacy/index-memory.py 2>/dev/null                 # Index memory docs
python3 scripts/legacy/generate-memory-embeddings.py 2>/dev/null   # Incremental embeddings for vector search
```

### 6. Persona change detection (daily once)
```bash
# Check if persona_latest.md changed in last 24h
PERSONA_FILE="memory/persona/persona_latest.md"
if [ -f "$PERSONA_FILE" ]; then
  LAST_MODIFIED=$(stat -f %m "$PERSONA_FILE" 2>/dev/null || stat -c %Y "$PERSONA_FILE" 2>/dev/null)
  NOW=$(date +%s)
  AGE=$((NOW - LAST_MODIFIED))
  
  if [ $AGE -lt 86400 ]; then
    # Changed in last 24h → read and notify
    echo "🔄 Persona updated in last 24h"
    # Read persona_latest.md
    # Extract changed layers from changelog
    # Notify user
  fi
fi
```

---

## 📊 Notification criteria

**Notify when**:
- 🚨 Gateway down (monitoring health check)
- ⚠️ Claude budget < 20% (monitoring health check)
- ⚠️ Embeddings down (monitoring health check)
- 🔔 Tool candidate found (repetitive pattern 3+ times)
- ⚠️ Error occurred
- 📭 Work queue empty (new tasks needed) - see Idle Check below
- 💡 Important finding

**Proceed quietly**:
- Routine tasks
- Log cleanup
- Pattern tracking
- Memory updates

### Idle Check

**Condition**: now.md empty + next.md has only "(Optional)" tasks

**Notification frequency**:
- First idle detection → Notify immediately
- Subsequent → Notify once per 24h (morning preferred)
- Track last notification in `memory/heartbeat-state.json`

**Message template**:
> 📭 Work queue is empty. All remaining tasks are optional.
> 
> Ready for new work. Need anything?

**State tracking**:
```json
{
  "last_idle_notification": "2026-02-05T10:30:00+09:00",
  "idle_since": "2026-02-05T09:00:00+09:00"
}
```

---

## 🎯 Principles

- **Simple**: No complex pipelines
- **As needed**: Skip unnecessary checks
- **Transparent**: Notify important findings only
- **Autonomous**: Safe tasks run automatically

---

## 🗑️ Deprecated (ignore)

Old Pipeline v4 system:
- ❌ task-queue.md (→ agent-todos/)
- ❌ orchestrator, circuit-breaker
- ❌ board approval system
- ❌ checkpoint system

→ All moved to `memory/_deprecated/`

---

## 🌅 Morning Brief (Cron)

**Separate execution** (independent from HEARTBEAT):
- **Schedule**: Weekdays 9AM (Mon-Fri)
- **Method**: isolated session → Telegram delivery
- **Content**:
  - Yesterday summary (work/patterns/tools)
  - Major events
  - Today's focus
  - Insights
  - Ideas resurface: mention 1-2 ideas from the bottom of `ideas.md` related to today's work (only when relevant)
- **State**: `memory/morning-brief-state.json`
- **Save**: `memory/for-user/morning-briefs/YYYY-MM-DD.md`
- **Language**: Korean (user-facing)

---

**Version**: 3.0 (Pi Style)  
**Created**: 2026-02-05  
**Philosophy**: Minimalism + Autonomy + Transparency
