# Agents

Custom AI agent definitions for Kiro.

## Format

Each agent is a `.json` file with the following structure:

```json
{
  "name": "agent-name",
  "description": "What this agent does",
  "model": "claude-opus-4.6",
  "tools": ["list", "of", "tools"],
  "allowedTools": ["auto-approved tools"],
  "resources": ["file patterns to load"],
  "prompt": "file:///path/to/prompt.md or inline prompt",
  "mcpServers": {},
  "hooks": {}
}
```

## Installation

Copy `.json` files to `~/.kiro/agents/`.

If the agent references an external prompt file, ensure that file is also available at the referenced path.

## Agents in this collection

| File | Description |
|------|-------------|
| *(add entries as you add agents)* | |
