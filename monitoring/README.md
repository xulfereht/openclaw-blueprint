# Monitoring Dashboard

A lightweight monitoring system built on Hono (server) + React (frontend).

## What It Shows

1. **System Health**: Gateway, embeddings, search, messaging status
2. **Model Chain**: Primary + fallback models with live session/token counts
3. **Battery**: Real-time Anthropic Max usage with tier visualization
4. **Sessions**: Per-model session counts and token usage
5. **Knowledge Base**: Document and embedding counts

## Architecture

```
┌─────────────────────┐       ┌──────────────────────┐
│  Knowledge API      │       │  Frontend (React)    │
│  (Hono, port 3001)  │ ◄──── │  MonitoringView.tsx  │
│                     │       │  30s polling         │
│  GET /api/monitoring│       └──────────────────────┘
│     /overview       │
│                     │
│  Reads:             │
│  - Gateway config   │
│  - Session store    │
│  - anthropic-usage  │
│  - Service health   │
└─────────────────────┘
```

## API Response Shape

```typescript
interface Overview {
  health: Record<string, {
    status: 'healthy' | 'degraded' | 'down'
    detail?: string
    latencyMs?: number
  }>
  
  model: {
    primary: { id: string; sessions: number; tokens: number }
    fallbacks: Array<{ id: string; sessions: number; tokens: number }>
  }
  
  battery: {
    configured: boolean
    anthropic: {
      session: { percent: number; resetsAt: string }
      weekAll: { percent: number; resetsAt: string }
      weekSonnet: { percent: number; resetsAt: string }
      extraUsage: { enabled: boolean; percent: number; spent: number; limit: number }
      battery: { tier: 'green' | 'yellow' | 'orange' | 'red'; weeklyPercent: number }
      timestamp: string
    }
    tiers: Record<string, { max: number; label: string; routing: string }>
  }
  
  usage: {
    date: string
    models: Record<string, { sessions: number; tokens: number }>
    totalSessions: number
    totalTokens: number
  }
  
  corpus: { totalDocs: number; totalEmbeddings: number }
}
```

## Battery Visualization

The battery section shows:

- **Main bar**: Weekly all-models usage (0-100%) with tier markers at 50/70/85%
- **Color-coded**: Green → Yellow → Orange → Red as usage increases
- **Secondary meters**: 5-hour window, Sonnet-only usage, Extra usage spend
- **Tier legend**: Shows which tier is currently active
- **Reset time**: Countdown to weekly reset

## Health Checks

The monitoring endpoint checks these services:

| Service | Method | Healthy | Degraded |
|---------|--------|---------|----------|
| Gateway | HTTP to port 18789 | 200 OK | timeout/error |
| Embeddings | Check index directory | Files exist | Empty dir |
| Brave Search | Parse gateway logs | No 429s | Rate limited |
| Telegram | Piggybacks on gateway | Gateway up | Gateway down |

## Setup

1. The monitoring route is part of the Knowledge API server
2. Frontend is a React component polling every 30 seconds
3. Battery data comes from the polling cron job (see [battery/](../battery/))
4. Session data comes from OpenClaw's session store (`sessions.json`)

## Key Files

- **Server**: `knowledge-app/server/src/routes/monitoring.ts`
- **Frontend**: `crabwalk-custom/src/components/monitoring/MonitoringView.tsx`
- **Styles**: `MonitoringView.module.css`
- **Data**: `dashboard/anthropic-usage.json`, `dashboard/budget-config.json`
