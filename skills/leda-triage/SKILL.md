---
name: leda-triage
description: Run Leda triage on a Jira issue, combine with user-provided resolution, and generate a structured knowledge file for the EFD-China-Knowledge repository.
---

# Leda Triage Knowledge Generator

Run Leda triage on a specified Jira issue, then generate a structured knowledge file and save it to the EFD-China-Knowledge repository.

## When to Use

- "triage BOC-1234"
- "analyze this Jira"
- "triage BOC-XXXX and generate knowledge"
- "summarize BOC-XXXX, the fix was..."
- Any request involving Leda triage + knowledge generation

## Paths

- Leda working directory: `/Users/caoxicz/workspace-mac/leda/LedaTriage`
- Knowledge output directory: `/Users/caoxicz/workspace-mac/leda/source/EFD-China-Knowledge/<component>` (e.g. `graphics`, `boot`, `audio`)
- Knowledge template: `/Users/caoxicz/workspace-mac/leda/source/EFD-China-Knowledge/SKILL_TEMPLATE.md`

## Process

### Step 1: Run Leda Triage

Execute the triage command from the Leda working directory:

```bash
cd /Users/caoxicz/workspace-mac/leda/LedaTriage
leda triage -t <JIRA-ID> --post-report
```

Wait for completion. Results are saved in the `output_<JIRA-ID>/` directory.

If the user indicates triage has already been run (i.e. `output_<JIRA-ID>/` already exists), skip this step.

### Step 2: Read Triage Results

Read the following files from `output_<JIRA-ID>/` (in priority order):

1. `summaries/<JIRA-ID>_triage_results.md` — Root cause analysis, evidence, recommendations (most important)
2. `<JIRA-ID>_analysis.md` — Structured analysis report, log evidence
3. `summaries/<JIRA-ID>_summary.md` — Jira basic info, comments, attachments

### Step 3: Get User Input

Ask the user for the resolution (if not already provided):

- Fix: What was done to resolve the issue
- Related CR/Commit: If available
- Verification method: How to confirm the fix works

If Jira comments already contain clear resolution info, pre-fill and ask the user to confirm.

### Step 4: Generate Knowledge File

Read `SKILL_TEMPLATE.md` and populate each section according to these rules:

| Section | Data Source |
|---------|-------------|
| Front Matter (name/description/component/tags/source_jira) | Extracted from triage_results.md + summary.md |
| Front Matter (created) | Today's date |
| Front Matter (author) | User alias (default: caoxicz, or user-specified) |
| Symptoms | Log snippets + behavior description from Evidence Summary in triage_results.md |
| Root Cause | Root Cause Analysis from triage_results.md |
| Resolution | User-provided fix, CR, and verification method |
| LLM Diagnostic Guide | Synthesized from evidence and root cause: log search patterns + matching conditions + conclusion template |

File naming: Use the `name` field from Front Matter, converted to hyphen-separated English, e.g. `DRM-Modeset-Module-CRC-Mismatch.md`.

### Step 5: Save File

Save the generated knowledge file to:

```
/Users/caoxicz/workspace-mac/leda/source/EFD-China-Knowledge/<component>/<filename>.md
```

Where `<component>` is the component field value from Front Matter (e.g. graphics, boot, audio, ota).

Example: `/Users/caoxicz/workspace-mac/leda/source/EFD-China-Knowledge/graphics/DRM-Modeset-Module-CRC-Mismatch.md`

## Guidelines

- Symptoms section MUST include searchable key log snippets (wrapped in code blocks)
- Root Cause section should distinguish "direct cause" from "underlying cause"
- LLM Diagnostic Guide MUST contain specific log search patterns, not vague descriptions
- If triage found no root cause (Root Cause Found: No), still generate the knowledge file but mark root cause as "TBD"
- Write descriptive content in English; keep technical terms, logs, and code as-is
