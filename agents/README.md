# Agents

Custom AI agent definitions for Kiro.

## Format

Each agent is a directory containing:
- `.json` config file — defines model, tools, permissions, hooks, MCP servers
- `kiro_hook_assets/` — sound files or other assets referenced by hooks (optional)

## Installation

Copy the agent directory to `~/.kiro/agents/`, or copy just the `.json` file if no assets are needed.

## Agents in this collection

| Agent | Description |
|-------|-------------|
| `caoxi-agent/` | 带音效通知的默认 agent。在 agent 启动、完成、写文件、执行命令时播放塞尔达风格音效。包含完整的安全 deniedCommands 列表，阻止危险操作（删除 AWS 资源、泄露凭证、force push 等）。 |
