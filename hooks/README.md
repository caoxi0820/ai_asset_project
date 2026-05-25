# Hooks

Event-driven automations triggered by IDE events.

## Format

Each hook is a `.kiro.hook` (or `.json`) file defining a trigger event and an action.

## Installation

Copy hook files to `~/.kiro/hooks/` (user-level) or `.kiro/hooks/` (workspace-level).

## Hooks in this collection

| Hook | Event | Description |
|------|-------|-------------|
| `print-tools-summary.kiro.hook` | `agentStop` | Agent 执行结束后，自动打印本轮使用的 steering、hooks、tools、MCP servers、skills 的摘要。方便调试和了解 agent 行为。 |
| `sync-kiro-workspace.kiro.hook` | `promptSubmit` | 每次发送消息时，自动将 `~/.kiro/hooks/` 同步到当前工作区的 `.kiro/hooks/`，确保 IDE 侧边栏能看到所有 hooks。 |
