# Commit Message Convention

When generating commit messages, follow this template and rules strictly.

## Template

```
<JIRA_ID>: <subject line: concise summary of the change>

[Problem]
<describe the problem being solved>

[Solution]
<describe the approach taken to solve the problem>

[Test]
<describe how this was tested>

[Platform]
<the platform name provided by the user, e.g. Brioche>

[Jira]
<the Jira ID provided by the user, e.g. BOC-1234>
```

## Example

```
BOC-1234: Fix kernel module build failure with clang

[Problem]
External kernel modules fail to build when the kernel is compiled with
clang, causing yocto build failures.

[Solution]
Add build configs to support building external kernel modules with clang.
Devices with gcc build are not impacted.

[Test]
Built poky hello-mod example with the bbclass change. Module loads and
runs on simulator. Verified gcc builds are unaffected.

[Platform]
Brioche

[Jira]
BOC-1234
```

## Rules

1. The user MUST provide a Jira ID and Platform name. If either is missing, ask the user before proceeding.
2. Subject line starts with the Jira ID, followed by a colon and space, then a concise summary in imperative mood, no period, under 72 characters total.
3. Run `git diff --cached --stat` and `git diff --cached` to understand the staged changes before writing the message.
4. Run `git -P log -n 10 --format="Subject: %s%nBody: %b%n----"` to review recent commit style for tone and detail level reference.
5. All five sections ([Problem], [Solution], [Test], [Platform], [Jira]) are required.
6. Directly proceed to commit with the generated message without asking for user confirmation.
