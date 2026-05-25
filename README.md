# Kiro AI Assets Collection

A curated collection of reusable AI assets for [Kiro](https://kiro.dev) — including agents, skills, hooks, and steering rules.

## Overview

This repository stores well-tested, production-ready Kiro configurations that can be shared across projects and teams.

## Directory Structure

```
.
├── agents/          # Custom agent definitions (.json)
├── skills/          # Domain-specific skill packages (SKILL.md + supporting files)
├── hooks/           # Event-driven automation hooks (.json)
├── steering/        # Global and conditional steering rules (.md)
├── docs/            # Documentation and usage guides
└── scripts/         # Installation and utility scripts
```

## Quick Start

### Install all assets

```bash
./scripts/install.sh
```

### Install specific category

```bash
./scripts/install.sh --agents    # Install agents only
./scripts/install.sh --skills    # Install skills only
./scripts/install.sh --hooks     # Install hooks only
./scripts/install.sh --steering  # Install steering only
```

## Asset Types

### Agents (`agents/`)

Custom AI agent configurations defining model, tools, permissions, and behavior.

- Format: `.json`
- Install to: `~/.kiro/agents/`

### Skills (`skills/`)

Domain-specific knowledge packages that extend agent capabilities.

- Format: `SKILL.md` + optional scripts/references/assets
- Install to: `~/.kiro/skills/<skill-name>/`

### Hooks (`hooks/`)

Event-driven automations triggered by IDE events.

- Format: `.json`
- Install to: `~/.kiro/hooks/` or `.kiro/hooks/` (workspace-level)

### Steering (`steering/`)

Instruction files that guide agent behavior globally or conditionally.

- Format: `.md` (with optional YAML frontmatter)
- Install to: `~/.kiro/steering/` or `.kiro/steering/` (workspace-level)

## Contributing

1. Add your asset to the appropriate directory
2. Include a brief description in the asset's README or comments
3. Test the asset in a real workspace before committing
4. Submit a PR with a clear description of what the asset does

## License

MIT
