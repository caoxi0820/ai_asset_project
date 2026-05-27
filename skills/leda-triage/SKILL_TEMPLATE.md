---
name: [Short name, e.g. "OTA Version Mismatch" or "Touch Ghost Input"]
description: [One-sentence description of the issue, used by LLM to determine if it matches the current Jira]
component: [Component name: ota/touch/audio/boot/camera/graphics/kernel/lpm/mcu/security/storage/thermal/inputd/automation]
source_jira: [Original Jira ID, e.g. BOC-1211]
tags: [Keyword list for search matching, e.g. "version mismatch, OTA, firmware"]
created: [YYYY-MM-DD]
author: [Engineer alias]
---

<!--
=== Usage Instructions ===
This template is used with leda triage. Workflow:

1. Run: leda triage -t <JIRA-ID> --post-report
2. User provides: Resolution (fix approach, CR, verification method)
3. LLM auto-completes: Reads triage results from output_<JIRA-ID>/, fills all sections marked [AUTO] below
4. Output: Generates knowledge/<component>/<issue-name>.md

Data sources:
- [AUTO] Symptoms → Extracted from Evidence Summary in triage_results.md / analysis.md
- [AUTO/USER] Root Cause → Extracted from Root Cause Analysis in triage_results.md, OR provided/supplemented by user
- [AUTO] LLM Diagnostic Guide → Synthesized from Recommendations + Evidence in analysis.md
- [AUTO] Front Matter → Synthesized from Basic Information in summary.md + triage analysis
- [USER] Resolution → Provided by user, or extracted from Jira comments and confirmed by user

NOTE: If the user provides a root cause, it takes priority and should be integrated into the
Root Cause section. The LLM should merge user-provided root cause with any auto-extracted
findings to produce the most accurate and complete explanation.
-->

# [Issue Title]

## Symptoms

<!-- [AUTO] Extracted from Leda triage output -->

Describe how the issue manifests in logs or device behavior. LLM uses these characteristics to determine if this knowledge matches when analyzing a Jira.

- Key log snippets (wrapped in code blocks)
- Observable abnormal device behavior
- Trigger conditions or reproduction frequency

```
[Key log example]
```

## Root Cause

<!-- [AUTO/USER] Extracted from Leda triage output, or provided by user. User-provided root cause takes priority. -->

Technical reason for the issue.

- Direct cause: [e.g. "OTA package version number does not match device's current version"]
- Underlying cause: [e.g. "Server-side delivery logic does not validate device variant"]

## Resolution

<!-- [USER] Provided by user. If Jira comments already contain resolution info, LLM may pre-fill and ask user to confirm. -->

### Fix Approach

1. [Step 1]
2. [Step 2]

### Related CR/Commit

- [CR link or commit hash, write N/A if none]

### Verification Method

- [Verification steps or test cases]

## LLM Diagnostic Guide

<!-- [AUTO] Synthesized from Leda triage output -->

When Leda detects similar symptoms in a new Jira, it should:

1. Search logs for: `[key log pattern]`
2. Confirm conditions: [e.g. "Check if OTA version field matches build fingerprint"]
3. If matched, suggested conclusion template:

```
This issue is the same as [source_jira], root cause is [brief root cause].
Suggested fix: [brief fix approach].
```
