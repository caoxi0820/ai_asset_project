# Steering

Instruction files that guide agent behavior across all interactions.

## Format

Markdown files with optional YAML frontmatter for conditional inclusion.

## Installation

Copy `.md` files to `~/.kiro/steering/` (user-level) or `.kiro/steering/` (workspace-level).

## Steering rules in this collection

| File | Description |
|------|-------------|
| `commit-message-convention.md` | 强制 commit message 遵循固定模板：`<JIRA_ID>: <summary>` + [Problem]/[Solution]/[Test]/[Platform]/[Jira] 五个必填段落。要求用户提供 Jira ID 和 Platform 名称。 |
| `solution-comparison.md` | 当呈现多个解决方案时，要求列出难度等级和工作量估算，明确推荐方案及理由，3+ 选项时用表格对比。 |
| `sync-hooks-to-workspace.md` | 每次 prompt 前自动检查并同步 `~/.kiro/hooks/` 到工作区 `.kiro/hooks/`，确保 IDE 侧边栏可见。 |
