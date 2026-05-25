# Steering

Instruction files that guide agent behavior across all interactions.

## Format

Markdown files with optional YAML frontmatter for conditional inclusion:

```markdown
---
inclusion: fileMatch          # or "manual" or omit for always-included
fileMatchPattern: '*.py'      # required for fileMatch inclusion
---

# Rule Title

Your instructions here...
```

## Inclusion Modes

| Mode | Behavior |
|------|----------|
| *(default)* | Always included in every interaction |
| `fileMatch` | Included when a matching file is read into context |
| `manual` | Included only when user explicitly references via `#` |

## Installation

Copy `.md` files to `~/.kiro/steering/` (user-level) or `.kiro/steering/` (workspace-level).

## Steering rules in this collection

| File | Description |
|------|-------------|
| *(add entries as you add steering rules)* | |
