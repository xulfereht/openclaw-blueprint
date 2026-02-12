# Battery Management System

Real-time quota monitoring for Anthropic Max subscription with automatic model routing.

## Problem

Anthropic Max has weekly usage limits that reset on a rolling basis. If you hit 100%, the system stops working. There's no official API to query usage — but there is an undocumented OAuth endpoint.

## Discovery

Claude Code (Anthropic's CLI) stores OAuth credentials in macOS Keychain under `Claude Code-credentials`. These credentials include scopes `user:inference`, `user:mcp_servers`, and `user:profile`.

The usage data comes from:

```
GET https://api.anthropic.com/api/oauth/usage
Headers:
  Authorization: Bearer <access_token>
  anthropic-beta: oauth-2025-04-20
  anthropic-version: 2023-06-01
```

### Response Format

```json
{
  "five_hour": {
    "utilization": 43.0,
    "resets_at": "2026-02-12T04:00:00+00:00"
  },
  "seven_day": {
    "utilization": 45.0,
    "resets_at": "2026-02-17T08:00:00+00:00"
  },
  "seven_day_sonnet": {
    "utilization": 1.0,
    "resets_at": "2026-02-17T16:00:00+00:00"
  },
  "extra_usage": {
    "is_enabled": true,
    "monthly_limit": 11500,
    "used_credits": 11608.0,
    "utilization": 100.0
  }
}
```

## Architecture

```
┌──────────────┐    every 30min    ┌──────────────────┐
│  macOS       │ ──────────────>   │ poll script       │
│  Keychain    │   read token      │ poll-anthropic-   │
│              │                   │ usage.sh          │
└──────────────┘                   └────────┬─────────┘
                                            │
                                   call API │
                                            ▼
                              ┌──────────────────────┐
                              │ api.anthropic.com     │
                              │ /api/oauth/usage      │
                              └──────────┬───────────┘
                                         │
                                write    │
                                         ▼
                              ┌──────────────────────┐
                              │ anthropic-usage.json  │
                              │                       │
                              │ { tier: "green",      │
                              │   weeklyPercent: 45 } │
                              └──────────┬───────────┘
                                         │
                          ┌──────────────┼──────────────┐
                          │              │              │
                          ▼              ▼              ▼
                   ┌───────────┐  ┌───────────┐  ┌───────────┐
                   │ Dashboard │  │ Heartbeat │  │ Sub-agent │
                   │ (visual)  │  │ (check)   │  │ (routing) │
                   └───────────┘  └───────────┘  └───────────┘
```

## Tiers

| Tier | Weekly % | Behavior |
|------|----------|----------|
| 🟢 Green (0-50%) | Normal | Primary model for everything |
| 🟡 Yellow (50-70%) | Conservative | Simple tasks (heartbeat, search) → Flash/GLM |
| 🟠 Orange (70-85%) | Aggressive | Primary only for user requests + complex judgment |
| 🔴 Red (85-100%) | Emergency | Primary minimum; most work → Gemini/GLM |

## Model Routing by Tier

When spawning sub-agents (`sessions_spawn`):

- **Green**: No `model` param (uses default primary)
- **Yellow**: Non-critical spawns → `model: "flash"`
- **Orange**: All spawns except user-explicit → `model: "flash"` or `model: "glm"`
- **Red**: All spawns → `model: "pro"` or `model: "flash"`

**Critical rule**: Never fully stop. Always route to fallback if primary is unavailable.

## Setup

### Prerequisites
- Claude Code installed and authenticated (Max subscription)
- macOS with Keychain access
- OpenClaw cron system

### 1. Install the polling script

Copy `poll-anthropic-usage.sh` to your workspace `scripts/` directory.

### 2. Register cron job

```
cron add {
  name: "poll-anthropic-usage",
  schedule: { kind: "cron", expr: "*/30 * * * *", tz: "Your/Timezone" },
  sessionTarget: "isolated",
  payload: {
    kind: "agentTurn",
    message: "Run: bash scripts/poll-anthropic-usage.sh"
  },
  delivery: { mode: "none" }
}
```

### 3. Add battery rules to AGENTS.md

See the Battery Management section in [agents.md](../agents.md).

### 4. (Optional) Dashboard visualization

See [monitoring/README.md](../monitoring/README.md) for the web dashboard setup.

## Files

- [`poll-anthropic-usage.sh`](poll-anthropic-usage.sh) — Polling script
- [`budget-config.json`](budget-config.json) — Tier configuration
