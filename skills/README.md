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
| `skill-creator/` | 创建和迭代新 skill 的指导工具。包含 skill 结构规范、创建流程、打包验证脚本。 |
| `regression-bisect/` | EML Regression Bisector。通过 LEDA 信号 + VS diff 分析，自动定位两个 build 之间引入 regression 的嫌疑 commit。 |

---

## 触发方法总结

### code-insight

**触发方式：** 在聊天中用自然语言请求分析当前工作区。

**触发示例：**
- "帮我分析这个项目的架构"
- "帮我分析一下这个工作区"
- "这个 repo 的核心逻辑在哪"
- "给我一个快速上手指南"
- "分析一下这个工作区的代码或者文件"
- "画出这个项目的调用关系"
- "这个项目是干什么的"
- 任何关于理解、探索或文档化一个不熟悉工作区的请求

**输出：** 在工作区根目录生成 `CODE_INSIGHT.md` 报告。

---

### leda-triage

**触发方式：** 在聊天中提到 triage + Jira ID，或要求分析某个 Jira issue。

**触发示例：**
- "triage BOC-1234"
- "analyze this Jira"
- "triage BOC-XXXX and generate knowledge"
- "summarize BOC-XXXX, the fix was..."
- 任何涉及 Leda triage + 知识生成的请求

**必填参数：** Jira ID（如 BOC-1234）

**输出：** 在 `/Users/caoxicz/workspace-mac/leda/source/EFD-China-Knowledge/<component>/` 目录下生成结构化知识文件（英文）。

---

### skill-creator

**触发方式：** 当用户想创建一个新 skill 或更新已有 skill 时触发。

**触发示例：**
- "帮我创建一个新 skill"
- "我想做一个 skill 来处理 XXX"
- "帮我更新这个 skill"
- "如何打包这个 skill"
- 任何关于 skill 创建、结构设计、打包分发的请求

**流程：** 理解需求 → 规划内容 → 初始化目录（`init_skill.py`）→ 编写 SKILL.md + 资源 → 打包验证（`package_skill.py`）→ 迭代改进

**输出：** 完整的 skill 目录结构 + 可分发的 zip 包。

---

### regression-bisect

**触发方式：** 用户提供 Jira ID + good/bad build event ID，请求定位 regression。

**触发示例：**
- "帮我 bisect BOC-2377, good 6438976910, bad 6492635926"
- "定位 BOC-2377 regression，好版本 6438976910 坏版本 6492635926"

**必填参数：**
1. `JIRA_ID` — Jira ticket ID（如 BOC-2377）
2. `GOOD_EVENT_ID` — good build 的 event ID（纯数字）
3. `BAD_EVENT_ID` — bad build 的 event ID（纯数字）

**执行流程：** 解析 LEDA 信号 → 获取 VS diff → Package 粗筛分 tier → 获取 HIGH tier commit detail → 逐 commit 打分（keyword + 语义）→ 因果链分析 → 输出验证方法

**输出：** 按嫌疑度排序的候选改动报告，含因果链推理和具体验证步骤。
