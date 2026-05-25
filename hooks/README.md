# Hooks

Event-driven automations triggered by IDE events.

## Format

Each hook is a `.json` file:

```json
{
  "name": "Hook Name",
  "version": "1.0.0",
  "description": "What this hook does",
  "when": {
    "type": "fileEdited|fileCreated|fileDeleted|userTriggered|promptSubmit|agentStop|preToolUse|postToolUse|preTaskExecution|postTaskExecution",
    "patterns": ["*.ts"],
    "toolTypes": ["write"]
  },
  "then": {
    "type": "askAgent|runCommand",
    "prompt": "for askAgent",
    "command": "for runCommand"
  }
}
```

## Event Types

| Event | Trigger |
|-------|---------|
| `fileEdited` | User saves a file |
| `fileCreated` | New file created |
| `fileDeleted` | File deleted |
| `userTriggered` | Manual button click |
| `promptSubmit` | Message sent to agent |
| `agentStop` | Agent execution completes |
| `preToolUse` | Before tool execution |
| `postToolUse` | After tool execution |
| `preTaskExecution` | Before spec task starts |
| `postTaskExecution` | After spec task completes |

## Installation

Copy `.json` files to `~/.kiro/hooks/` (user-level) or `.kiro/hooks/` (workspace-level).

## Hooks in this collection

| File | Description |
|------|-------------|
| *(add entries as you add hooks)* | |
