---
name: weather-guide
description: Guide skill for the weather MCP server. Worst trap is mixing Celsius and Fahrenheit. Use when checking a forecast. Cheap to read, expensive to plan an outing on the wrong unit.
---

# Weather guide

## Rules

### Needs approval first
- Subscribing anyone to alerts.

### Never
- Sharing a person's home location in a forecast request.

### Before any write
1. Is the unit stated in the request?

## Operating manual

### Setup snapshot
| Key | Value |
|---|---|
| Tool names | mcp__weather__* |

### Workflow
1. Find the place. 2. Confirm it. 3. Ask. 4. Read back the unit.

### Known issues
| Date | Issue | Workaround |
|---|---|---|
| 2026-10-05 | Units default to Fahrenheit | Pass units=metric |
