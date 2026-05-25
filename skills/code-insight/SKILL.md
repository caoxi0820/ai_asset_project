---
name: code-insight
description: Analyzes the current workspace to produce a comprehensive project report. Automatically detects whether the workspace is a code project, documentation/resource collection, or hybrid, then adapts its analysis accordingly. Outputs a markdown document with Mermaid diagrams saved to the workspace.
---

# Code Insight

Analyze the current workspace and generate a structured project report as a markdown document. This skill **automatically adapts** to the project type — whether it's a software codebase, a documentation/resource collection, a configuration repository, or a hybrid.

## When to Use

- "帮我分析这个项目的架构"
- "帮我分析一下这个工作区"
- "这个 repo 的核心逻辑在哪"
- "给我一个快速上手指南"
- "分析一下这个工作区的代码或者文件"
- "画出这个项目的调用关系"
- "这个项目是干什么的"
- Any request to understand, explore, or document an unfamiliar workspace

## Analysis Process

### Step 0: Project Type Detection (MANDATORY FIRST STEP)

Before any deep analysis, determine the project type:

1. Scan the top-level directory tree (depth 2)
2. Check for code indicators:
   - Source files (`.py`, `.js`, `.ts`, `.java`, `.go`, `.rs`, `.c`, `.cpp`, etc.)
   - Build manifests (`package.json`, `Cargo.toml`, `go.mod`, `pom.xml`, `Makefile`, `CMakeLists.txt`, `setup.py`, etc.)
   - Entry points (`main.*`, `index.*`, `app.*`, `__main__.py`)
3. Check for non-code indicators:
   - Predominantly Markdown files (`.md`)
   - Asset/resource files (fonts, images, templates)
   - No build system or package manifest
   - README describes a collection, list, guide, or documentation set
4. Classify the project into one of:
   - **Code Project** — has runnable source code, build system, dependencies → use Code Analysis Path
   - **Resource/Documentation Project** — primarily Markdown, configs, assets, curated lists → use Resource Analysis Path
   - **Hybrid Project** — mix of both (e.g., docs site with build tooling, skill collection with scripts) → use Hybrid Analysis Path

**Output the classification result clearly before proceeding.**

---

## Code Analysis Path

Use this path when the workspace is primarily a software project with runnable code.

### Step 1: Project Overview

1. Read README, CHANGELOG, or similar top-level documentation
2. Identify the project's purpose, target users, and core capabilities
3. Detect the primary programming languages
4. Count approximate lines of code per language and per top-level directory

### Step 2: Directory Structure and Module Responsibilities

1. List the top-level directory tree (depth 2-3)
2. For each major directory, write a one-line description of its responsibility
3. Identify architectural style (monolith, microservices, layered, plugin-based, monorepo, etc.)

### Step 3: Entry Points and Build/Run

1. Locate entry points: `main()`, `__main__`, `index.*`, `app.*`, CLI entry, server startup
2. Document how to build and run the project
3. List key configuration files and their roles

### Step 4: Dependencies

1. External dependencies from package manifests
2. Internal module dependencies: which modules import/include which
3. Note any vendored or bundled third-party code

### Step 5: Module Communication and Data Flow

1. Identify how modules communicate (function calls, IPC, RPC, REST APIs, events, etc.)
2. Trace the primary data flow from input to output
3. Note any concurrency patterns

### Step 6: Key Design Patterns

1. Identify notable patterns (factory, observer, middleware, pipeline, plugin, MVC, etc.)
2. Note error handling strategy
3. Note testing structure and approach

### Step 7: Call Relationship Diagrams

Generate Mermaid diagrams:
1. **Module Relationship Diagram** (`graph TD`) — top-level module dependencies
2. **Key Call Chain Diagram** (`graph LR`) — main execution path

---

## Resource Analysis Path

Use this path when the workspace is primarily a documentation, resource, or curated collection project (e.g., awesome lists, skill collections, config repos, static content).

### Step 1: Project Overview

1. Read README and top-level documentation
2. Identify the project's purpose, target audience, and scope
3. Determine the content type (curated list, documentation set, template collection, skill/plugin registry, etc.)
4. Count files by type (Markdown, configs, assets, scripts, etc.)

### Step 2: Content Structure and Organization

1. List the top-level directory tree (depth 2-3)
2. For each major directory/section, describe what content it holds
3. Identify the organizational pattern (by category, by tool, alphabetical, hierarchical, etc.)
4. Note the total number of entries/items in the collection

### Step 3: Content Categories and Coverage

1. List all major categories/sections with item counts
2. Identify the most and least populated categories
3. Note any cross-references or relationships between items
4. Summarize what topics/domains are covered

### Step 4: Contribution and Governance

1. Check for CONTRIBUTING.md, CODE_OF_CONDUCT, templates, or CI workflows
2. Describe how new content is added (PR process, templates, validation)
3. Note any automation (GitHub Actions, linters, validators)

### Step 5: Usage and Integration

1. How is this collection meant to be consumed? (browsed on GitHub, installed as packages, copied into projects, etc.)
2. Are there any scripts or tools that help users interact with the content?
3. Note any external service integrations

### Step 6: Content Relationship Diagram

Generate a Mermaid diagram showing:
1. **Content Organization Diagram** (`graph TD`) — how categories and subcategories relate
2. **Usage Flow Diagram** (`graph LR`) — how a user discovers and uses content from this collection

---

## Hybrid Analysis Path

Use this path when the workspace has both significant code and significant documentation/resource content.

1. Perform Step 0 classification to identify which parts are code and which are resources
2. Apply the **Code Analysis Path** to the code portions
3. Apply the **Resource Analysis Path** to the resource portions
4. In the output, clearly separate the two analyses with appropriate headings

---

## Output

1. Read the output template from `references/output-template.md`
2. Select the appropriate template sections based on the detected project type
3. Fill in each relevant section based on the analysis above
4. Save the completed report as `CODE_INSIGHT.md` in the workspace root directory
5. Inform the user where the file was saved

## Guidelines

- Use Chinese for all descriptive text and analysis. Keep code identifiers, file paths, and technical terms in English.
- Use concise language. Prefer bullet points over paragraphs.
- When uncertain about a module's purpose, state the uncertainty rather than guessing.
- For very large projects (>100 files), focus on the most important modules and note what was skipped.
- Adapt analysis depth to project size: small projects get full detail, large projects get focused summaries.
- Always include at least one Mermaid diagram regardless of project type.
- The project type detection in Step 0 is **mandatory** — never skip it. This ensures the analysis approach matches the actual workspace content.
