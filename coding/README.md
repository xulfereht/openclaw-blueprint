# Coding Delegation Patterns

How to use the orchestrator agent (MUA) to manage coding sub-agents effectively.

## Core Pattern: Spec-Driven TDD

```
           MUA (Orchestrator)
           ┌───────────────┐
           │  1. Plan       │ ← Expensive model (Opus)
           │     Write spec │
           └───────┬───────┘
                   │
                   ▼
           ┌───────────────┐
           │  2. Implement  │ ← Cheap model (GLM/Flash)
           │     RED→GREEN  │
           └───────┬───────┘
                   │
                   ▼
           ┌───────────────┐
           │  3. Verify     │ ← MUA checks correctness
           │     Tests OK?  │
           │     Code OK?   │
           └───────────────┘
```

### Why This Works

- **Planning** requires high reasoning → expensive model is worth it
- **Implementation** is mechanical once spec exists → cheap model suffices
- **Verification** is the orchestrator's core job → no extra cost
- **Tests come first** (RED) — they are the oracle that validates implementation

## Execution Modes

### Interactive Session (preferred for multi-step)

```bash
# Start Claude Code in PTY + background
exec pty:true background:true command:"claude --dangerously-skip-permissions 'Task description'"

# Send follow-up instructions
process send-keys sessionId:XXX literal:"Follow-up" keys:["Enter"]

# Check output (strip ANSI for clean text)
process log sessionId:XXX

# Clean up
process kill sessionId:XXX
```

### One-Shot (simple tasks)

```bash
echo "Single task description" | claude --print
```

**When to use one-shot**: Single file, clear change, no context accumulation needed.

## Model Assignment

| Phase | Model | Rationale |
|-------|-------|-----------|
| Plan | Opus (or best available) | High reasoning for architecture decisions |
| Implement | GLM / Sonnet / Flash | Cost-effective for mechanical coding |
| Verify | MUA (orchestrator) | Already in context, judges correctness |

### GLM Wrapper Example

```bash
# scripts/claude-glm — wrapper that routes through Z.ai API
echo "Read spec and implement" | claude-glm --dangerously-skip-permissions --print
```

## Spec Template

```markdown
# Feature: [Name]

## Context
What exists, what needs to change, why.

## Requirements (EARS format)
- Ubiquitous: The system SHALL [always do X]
- Event-driven: WHEN [event] THE system SHALL [response]
- State-driven: WHILE [state] THE system SHALL [behavior]
- Optional: WHERE [condition] THE system SHALL [feature]
- Unwanted: IF [bad state] THEN THE system SHALL [prevention]

## Test Criteria (RED phase)
- [ ] Test 1: Given X, when Y, then Z
- [ ] Test 2: Given A, when B, then C
- [ ] Edge case: When invalid input, then graceful failure

## Changes (GREEN phase)
Files to modify and what changes in each.

## Boundaries
What is IN scope and OUT of scope. This section = pre-approved permissions.

## Verify
How to confirm the implementation works (commands to run).
```

## Monitoring Coding Sessions

During heartbeat, check active coding sessions:

| Situation | Decision |
|-----------|----------|
| File modification + build passes | ✅ Mark complete |
| Files modified but tests fail | 🔄 Re-instruct |
| Wrong direction | ❌ Kill and restart |
| Complex judgment needed | 🤔 Escalate to user |

## Lessons

1. **`--dangerously-skip-permissions`** is required for autonomous operation. The spec's Boundaries section serves as pre-approved scope.
2. **`send-keys` not `submit`** for PTY sessions — `submit` doesn't work with Claude Code's PTY.
3. **ANSI noise** in PTY output — use strip-ansi parsing for clean text extraction.
4. **Pipe for one-shot** — `echo "..." | claude --print` (direct inline arg hangs in some versions).
