#!/bin/bash
# poll-anthropic-usage.sh — Fetch Anthropic Max usage via OAuth API
# Reads Claude Code's OAuth token from macOS Keychain
# Writes structured JSON to dashboard/anthropic-usage.json
#
# Usage: ./poll-anthropic-usage.sh
# Cron: every 30min via OpenClaw cron

set -euo pipefail

OUTFILE="${HOME}/.openclaw/workspace/dashboard/anthropic-usage.json"

# 1. Read access token from macOS Keychain (Claude Code stores it there)
ACCESS_TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d['claudeAiOauth']['accessToken'])
except:
    sys.exit(1)
" 2>/dev/null) || {
  echo '{"error":"keychain_read_failed","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$OUTFILE"
  exit 1
}

# 2. Call the OAuth usage endpoint
RESPONSE=$(curl -sS --max-time 10 \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "User-Agent: openclaw" \
  -H "Accept: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null) || {
  echo '{"error":"api_request_failed","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$OUTFILE"
  exit 1
}

# 3. Parse + determine battery tier + write output
python3 -c "
import json, sys
from datetime import datetime, timezone

raw = '''$RESPONSE'''
try:
    data = json.loads(raw)
except:
    json.dump({'error': 'json_parse_failed', 'raw': raw[:200], 'timestamp': datetime.now(timezone.utc).isoformat()}, open('$OUTFILE', 'w'), indent=2)
    sys.exit(1)

# Check for API error
if data.get('type') == 'error':
    json.dump({'error': data['error'].get('message', 'unknown'), 'timestamp': datetime.now(timezone.utc).isoformat()}, open('$OUTFILE', 'w'), indent=2)
    sys.exit(1)

# Extract key metrics
week_all = data.get('seven_day', {})
week_sonnet = data.get('seven_day_sonnet', {})
session_5h = data.get('five_hour', {})
extra = data.get('extra_usage', {})

week_pct = week_all.get('utilization', 0)

# Determine battery tier
if week_pct < 50:
    tier = 'green'
elif week_pct < 70:
    tier = 'yellow'
elif week_pct < 85:
    tier = 'orange'
else:
    tier = 'red'

result = {
    'session': {
        'percent': session_5h.get('utilization', 0),
        'resetsAt': session_5h.get('resets_at'),
    },
    'weekAll': {
        'percent': week_pct,
        'resetsAt': week_all.get('resets_at'),
    },
    'weekSonnet': {
        'percent': week_sonnet.get('utilization', 0) if week_sonnet else None,
        'resetsAt': week_sonnet.get('resets_at') if week_sonnet else None,
    },
    'extraUsage': {
        'enabled': extra.get('is_enabled', False),
        'percent': extra.get('utilization', 0),
        'spent': extra.get('used_credits', 0) / 100 if extra.get('used_credits') else 0,
        'limit': extra.get('monthly_limit', 0) / 100 if extra.get('monthly_limit') else 0,
    },
    'battery': {
        'tier': tier,
        'weeklyPercent': week_pct,
    },
    'timestamp': datetime.now(timezone.utc).isoformat(),
    'source': 'api.anthropic.com/api/oauth/usage',
}

with open('$OUTFILE', 'w') as f:
    json.dump(result, f, indent=2)

print(f'OK tier={tier} week={week_pct}% session={session_5h.get(\"utilization\", 0)}%')
" || {
  echo '{"error":"parse_failed","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$OUTFILE"
  exit 1
}
