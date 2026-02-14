# Provider Setup Guide

How to connect multiple AI providers to OpenClaw. Each provider needs two things: **authentication** and **model registration** in `openclaw.json`.

---

## Overview

| Provider | Auth Mode | API Protocol | Subscription | Use Case |
|----------|-----------|-------------|-------------|----------|
| **Anthropic** | `token` (built-in) | `anthropic-messages` | Max plan | Primary (Opus, Sonnet) |
| **OpenAI Codex** | `oauth` | `openai-responses` | ChatGPT Plus/Pro | Sub-agents (5.2), CLI (5.3) |
| **Z.ai** | `token` (API key) | `anthropic-messages` | Z.ai Max | Coding (GLM-5, GLM-4.7) |
| **Google Gemini** | `oauth` (CLI plugin) | varies | Gemini Advanced | Fallback, Flash tasks |

---

## 1. Anthropic (Claude Opus / Sonnet)

**Prerequisites**: Anthropic Max subscription

### Auth profile

```jsonc
// openclaw.json → auth.profiles
"anthropic:default": {
  "provider": "anthropic",
  "mode": "token"
}
```

OpenClaw manages the Anthropic token internally via its subscription system. No manual API key needed.

### Model registration

```jsonc
// openclaw.json → models.providers
"anthropic": {
  "baseUrl": "https://api.anthropic.com",
  "api": "anthropic-messages",
  "models": [
    {
      "id": "claude-opus-4-6",
      "name": "Claude Opus 4.6",
      "reasoning": true,
      "input": ["text", "image"],
      "contextWindow": 1000000,
      "maxTokens": 128000
    }
  ]
}
```

### Usage in config

```jsonc
// Primary model
"agents.defaults.model.primary": "anthropic/claude-opus-4-6"

// Available as sub-agent model
"agents.defaults.models": {
  "anthropic/claude-sonnet-4-5": { "alias": "sonnet" },
  "anthropic/claude-opus-4-6": { "alias": "opus" }
}
```

### Gotchas
- Sonnet and Opus share the same Anthropic quota — use Sonnet sparingly when protecting Opus
- Usage polling requires Claude Code's OAuth token in macOS Keychain (see [battery/](../battery/))
- Token auto-refreshes when Claude Code is used; expires after ~24h of inactivity

---

## 2. OpenAI Codex (GPT-5.2 / 5.3)

**Prerequisites**: ChatGPT Plus or Pro subscription with Codex access

### Auth profile

```jsonc
"openai-codex:default": {
  "provider": "openai-codex",
  "mode": "oauth"
}
```

Run `openclaw auth login openai-codex` to complete OAuth flow in browser.

### Model registration

```jsonc
"openai-codex": {
  "baseUrl": "https://chatgpt.com/backend-api",
  "api": "openai-responses",
  "models": [
    {
      "id": "gpt-5.3-codex",
      "name": "GPT-5.3 Codex",
      "reasoning": true,
      "input": ["text", "image"],
      "contextWindow": 266000,
      "maxTokens": 65536
    },
    {
      "id": "gpt-5.3-codex-spark",
      "name": "GPT-5.3 Codex Spark",
      "reasoning": false,
      "input": ["text", "image"],
      "contextWindow": 266000,
      "maxTokens": 65536
    }
  ]
}
```

### Usage

```jsonc
// Sub-agent default
"agents.defaults.subagents.model": "openai-codex/gpt-5.2"

// Aliases
"openai-codex/gpt-5.3-codex": { "alias": "codex" },
"openai-codex/gpt-5.3-codex-spark": { "alias": "spark" }
```

### ⚠️ Critical: GPT-5.3 Codex limitations

**GPT-5.3 does NOT work as an OpenClaw sub-agent.** Cloudflare WAF blocks OpenClaw's request pattern to the Codex endpoint.

| Model | OpenClaw sub-agent | Codex CLI | Claude Code PTY |
|-------|-------------------|-----------|-----------------|
| GPT-5.2 | ✅ | ✅ | N/A |
| GPT-5.3 Codex | ❌ (CF WAF) | ✅ | N/A |
| GPT-5.3 Spark | ❌ (CF WAF) | ✅ | N/A |

**Workaround**: Use GPT-5.3 via Codex CLI only:
```bash
codex -s danger-full-access "implement feature X"
```

Codex and Spark share OAuth — never run them concurrently.

---

## 3. Z.ai (GLM-5 / GLM-4.7)

**Prerequisites**: Z.ai Max subscription, API key from https://open.z.ai

### Auth profile

```jsonc
"zai:default": {
  "provider": "zai",
  "mode": "token"
}
```

Set the API key in `openclaw.json`:
```jsonc
"env": {
  "ZAI_API_KEY": "your-zai-api-key"
}
```

### Model registration

Z.ai exposes an **Anthropic-compatible API**, so use `anthropic-messages` protocol:

```jsonc
"zai": {
  "baseUrl": "https://api.z.ai/api/anthropic",
  "api": "anthropic-messages",
  "models": [
    {
      "id": "glm-5",
      "name": "GLM-5",
      "reasoning": false,
      "input": ["text", "image"],
      "contextWindow": 128000,
      "maxTokens": 16384
    },
    {
      "id": "glm-4.7",
      "name": "GLM-4.7",
      "reasoning": false,
      "input": ["text"],          // no vision
      "contextWindow": 128000,
      "maxTokens": 16384
    }
  ]
}
```

### Usage

Best used via **Claude Code PTY** (provides diff editing, CLAUDE.md context, git, bash sandbox):

```jsonc
"zai/glm-5": { "alias": "glm5" },
"zai/glm-4.7": { "alias": "glm" }
```

### Concurrency limits (measured)

| Model | Max concurrent | What happens |
|-------|---------------|--------------|
| GLM-5 | 3 | 4th request → error 1302 |
| GLM-4.7 | 5+ | Account-level limit |
| GLM-5 + GLM-4.7 mixed | OK | Different pools |

### Gotchas
- Multiple API keys from the same Z.ai account share the same rate pool
- GLM-4.7 has **no vision** — text only
- Do NOT use GLM as a direct OpenClaw sub-agent for coding — always wrap in Claude Code PTY

---

## 4. Google Gemini (Gemini 2.5 / 3 Pro)

**Prerequisites**: Google AI Studio access or Gemini Advanced subscription

### Auth profile (via Gemini CLI plugin)

```jsonc
// openclaw.json → auth.profiles
"google-gemini-cli:your-email@gmail.com": {
  "provider": "google-gemini-cli",
  "mode": "oauth"
}
```

Enable the plugin:
```jsonc
// openclaw.json → plugins.entries
"google-gemini-cli-auth": {
  "enabled": true
}
```

Run `gemini` CLI once to complete OAuth in browser. OpenClaw syncs the token via the plugin.

### Usage

```jsonc
// As fallback
"agents.defaults.model.fallbacks": [
  "google/gemini-3-pro-preview",
  "google-gemini-cli/gemini-3-pro-preview"
]

// Aliases
"gemini/gemini-2.5-flash": { "alias": "flash" },
"gemini/gemini-2.5-pro": { "alias": "pro" },
"google/gemini-3-pro-preview": { "alias": "gemini3" }
```

### Gotchas
- Two provider strings exist: `google/` (API key) and `google-gemini-cli/` (OAuth) — treat as same logical fallback
- Gemini CLI requires separate install: `npm install -g @anthropic-ai/gemini-cli` or equivalent
- Flash is fast + cheap, good for high-volume spawns

---

## Full Routing Example

```jsonc
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-6",
        "fallbacks": [
          "openai-codex/gpt-5.2",
          "zai/glm-5",
          "google/gemini-3-pro-preview"
        ]
      },
      "subagents": {
        "maxConcurrent": 8,
        "model": "openai-codex/gpt-5.2"
      },
      "models": {
        "anthropic/claude-sonnet-4-5": { "alias": "sonnet" },
        "zai/glm-5": { "alias": "glm5" },
        "zai/glm-4.7": { "alias": "glm" },
        "openai-codex/gpt-5.3-codex": { "alias": "codex" },
        "gemini/gemini-2.5-flash": { "alias": "flash" }
      }
    }
  }
}
```

### Role Assignment

| Role | Provider/Model | Why |
|------|---------------|-----|
| Main session | Opus 4.6 | Orchestration + conversation |
| Sub-agent default | GPT-5.2 | Specs, research, judgment |
| Document gen | Sonnet 4.5 | Quality writing (shares Anthropic quota) |
| Coding (primary) | GLM-5 via Claude Code | Fast, parallel (max 3) |
| Coding (overflow) | GLM-4.7 via Claude Code | More slots (max 5+) |
| Hard tasks | GPT-5.3 via Codex CLI | Deep reasoning, single-thread |
| Fallback | Gemini 3 Pro | When primary providers fail |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Anthropic token expired | Run `claude` in terminal → browser re-auth |
| Codex OAuth expired | `openclaw auth login openai-codex` |
| Z.ai 1302 error | Too many concurrent GLM-5 requests. Wait or use GLM-4.7 |
| GPT-5.3 via sub-agent fails | Expected — CF WAF blocks it. Use Codex CLI only |
| Gemini auth fails | Run `gemini` CLI to re-auth, check plugin enabled |
| Cooldown after errors | Set `auth.cooldowns.failureWindowHours: 0.5` (resets after 30min) |
