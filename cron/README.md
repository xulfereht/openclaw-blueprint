# Cron Job Recipes

OpenClaw's cron system runs jobs in isolated sessions. Each job is independent — it spawns, executes, and dies.

## Job Types

| Target | Payload | Use Case |
|--------|---------|----------|
| `main` | `systemEvent` | Heartbeat, reminders (triggers in active session) |
| `isolated` | `agentTurn` | Background tasks (separate session, no context pollution) |

## Recommended Setup

### Heartbeat (Essential)

```json
{
  "name": "heartbeat",
  "schedule": { "kind": "cron", "expr": "*/5 * * * *", "tz": "Asia/Seoul" },
  "sessionTarget": "main",
  "payload": {
    "kind": "systemEvent",
    "text": "HEARTBEAT: Check processes, tasks, and system health"
  }
}
```

**Note**: This fires into the main session as a system event. The agent's HEARTBEAT.md defines what to do.

### Usage Polling (If using Battery Management)

```json
{
  "name": "poll-anthropic-usage",
  "schedule": { "kind": "cron", "expr": "*/30 * * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Run: bash scripts/poll-anthropic-usage.sh",
    "timeoutSeconds": 30
  },
  "delivery": { "mode": "none" }
}
```

### Embedding Sync (If using Knowledge Base)

```json
{
  "name": "embedding-sync",
  "schedule": { "kind": "cron", "expr": "0 */3 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Run document indexing pipeline, then restart knowledge API.",
    "timeoutSeconds": 120
  },
  "delivery": { "mode": "none" }
}
```

### Morning Brief (Daily Briefing)

```json
{
  "name": "morning-brief",
  "schedule": { "kind": "cron", "expr": "0 9 * * 1-5", "tz": "Asia/Seoul" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Generate morning brief: yesterday summary, today's focus, key insights.",
    "timeoutSeconds": 600
  },
  "delivery": { "mode": "announce", "channel": "telegram" }
}
```

### Weekly Retrospective

```json
{
  "name": "weekly-retro",
  "schedule": { "kind": "cron", "expr": "0 20 * * 0", "tz": "Asia/Seoul" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Weekly retrospective: scan daily logs, patterns, task changes. Save to retrospectives/weekly/.",
    "timeoutSeconds": 300
  },
  "delivery": { "mode": "announce", "channel": "telegram" }
}
```

### Daily Alignment (End of Day)

```json
{
  "name": "daily-alignment",
  "schedule": { "kind": "cron", "expr": "50 23 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Daily alignment check: verify memory consistency, clean up stale files.",
    "timeoutSeconds": 300
  },
  "delivery": { "mode": "none" }
}
```

## Delivery Modes

| Mode | Behavior |
|------|----------|
| `none` | Silent — no notification |
| `announce` | Send summary to specified channel when done |

## Tips

- **Weekday check**: Include "check if Mon-Fri, skip weekends" in the prompt for jobs that shouldn't run on weekends
- **Timeout**: Always set `timeoutSeconds` — runaway jobs consume quota
- **Idempotent**: Jobs should be safe to re-run (cron may fire twice in edge cases)
- **State files**: Use JSON state files for jobs that need to track last-run time
