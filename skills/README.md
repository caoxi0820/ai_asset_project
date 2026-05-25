# Skills

Domain-specific knowledge packages that extend agent capabilities.

## Structure

Each skill is a directory containing:

```
skills/<skill-name>/
├── SKILL.md              # Core instructions (required)
├── scripts/              # Automation scripts (optional)
├── references/           # Documentation loaded on demand (optional)
└── assets/               # Templates, boilerplate (optional)
```

## Installation

Copy the entire skill directory to `~/.kiro/skills/`.

## Skills in this collection

| Skill | Description |
|-------|-------------|
| `code-insight/` | 分析当前工作区并生成结构化项目报告（含 Mermaid 图）。自动检测项目类型（代码/文档/混合），适配不同分析路径。输出中文报告保存为 `CODE_INSIGHT.md`。 |
| `leda-triage/` | 对 Jira issue 运行 Leda triage 分析，结合用户提供的修复方案，生成结构化知识文件并保存到 EFD-China-Knowledge 仓库。用于沉淀问题排查经验。 |
