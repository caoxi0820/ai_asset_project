# EML Regression Bisector — Skill 指令

## Metadata

- **Name:** eml-regression-bisector
- **Version:** 0.3
- **实现形式:** 纯 agent 指令（无 Python 脚本），agent 读完本文件后直接用工具执行

---

## 执行策略（全局规则）

**默认行为：一路执行到底**（v0.1 → v0.2 → v0.3 全部 Steps），不要中途停下来问用户是否继续。

**唯一例外——Context 容量暂停：** 如果 agent 判断剩余 context 窗口不足以完成后续步骤（例如 HIGH tier 包数量 > 15 且每个包有大量 commit 需要逐一获取），可以在当前 Step 输出完毕后暂停，向用户说明：
1. 当前已完成到哪个 Step
2. 后续步骤预计需要的 API 调用量
3. 询问用户是否继续

除此之外的任何其他原因（包括历史文件存在、已知 root cause 等）都**不构成暂停理由**——历史知识只作为加分因子融入打分，流程仍然完整执行。

---

## 触发条件

用户用自然语言触发，类似：

```
帮我 bisect BOC-2377, good 6438976910, bad 6492635926
```

```
定位 BOC-2377 regression，好版本 6438976910 坏版本 6492635926
```

**三个必填参数：**
1. `JIRA_ID` — JIRA ticket ID（如 BOC-2377）
2. `GOOD_EVENT_ID` — good build 的 event ID（纯数字）
3. `BAD_EVENT_ID` — bad build 的 event ID（纯数字）

**默认值：**
- Version Set: `VegaEchoInt-release/development`（固定）
- LEDA 目录: `/Users/caoxicz/workspace-mac/leda/LedaTriage/output_<JIRA_ID>/`

如果用户漏了参数，追问补全。

---

## 执行流程（v0.1 MVP）

v0.1 范围：解析 LEDA 信号 → subsystem_map 粗筛 → package 名 + keyword 匹配 → 分 tier 输出。
**不包含：** 自动获取 VS diff、commit 级别深度分析。

### Step 1: 解析 LEDA JSON 提取信号

#### 1.1 定位文件

读取 LEDA 输出目录中的核心 JSON 文件：

```
/Users/caoxicz/workspace-mac/leda/LedaTriage/output_<JIRA_ID>/work/issue_triage_<JIRA_ID>.json
```

> 注意：文件名中 JIRA_ID 的格式可能是 `BOC-2377` 或 `BOC2377`（无连字符），两种都尝试。

如果 JSON 不存在，fallback 到：
```
output_<JIRA_ID>/summaries/<JIRA_ID>_triage_results.md
```

#### 1.2 从 JSON 中提取信号

读取 JSON 后，构建以下信号集合：

```
signals = {
    keywords: [],        # 技术关键词
    components: [],      # LEDA 分析过的子系统
    file_paths: [],      # 代码路径
    process_names: [],   # 进程名/二进制名
    jira_id: "",
    jira_title: "",
}
```

**提取来源：**

| 信号类型 | JSON 字段 | 提取方法 |
|----------|-----------|----------|
| keywords | `hypothesis` | 提取大写缩写（DPU, DSI, MIPI, EGL）、技术名词（rfkill, Weston, flicker, panel）、功能区域词（Bluetooth, display, audio） |
| keywords | `description` | 同上 |
| components | `step4_components_to_analyze[].component` | 直接取 component 名称 |
| keywords | `step4_components_to_analyze[].reasoning` | 补充关键词 |
| jira_title | `title` | 直接取值 |

#### 1.3 从 analysis markdown 补充信号

扫描 `summaries/<JIRA_ID>_*_analysis.md` 文件，提取：

- **file_paths:** 匹配 `/[a-zA-Z0-9_/.-]+\.(c|h|cpp|py|sh|so|service|conf)` 的路径
- **process_names:** 出现在 crash 栈或日志上下文中的进程名（如 `Weston`, `surfaceflinger`, `audioserver`）
- **keywords 补充:** 库名 `lib*.so`、service 名

#### 1.4 输出信号

以清晰格式展示提取到的信号，供用户确认：

```
══ LEDA 信号提取结果 ══
JIRA:       BOC-2377 — Screen Flicker after VML merge
Keywords:   [DPU, DSI, panel, flicker, Weston, VSync, compositor, 60Hz]
Components: [Multimodal Graphics, Touch Input, Wi-Fi/Bluetooth Connectivity]
Processes:  [Weston, homelauncher, lwm_service]
File paths: [dpu_core.c, weston-compositor.c, ...]
```

---

### Step 2: 获取 VS Diff Package 列表

使用 `ReadInternalWebsites` 自动获取 VS diff：

**URL 格式：**
```
https://code.amazon.com/version-sets/<VS_NAME>/revisions/<BAD_EVENT_ID>?previous=<GOOD_EVENT_ID>&previous_vs=<VS_NAME_URL_ENCODED>
```

**参数说明：**
- `<VS_NAME>`: Version Set 名称，固定为 `VegaEchoInt-release/development`
- `<BAD_EVENT_ID>`: bad build 的 event ID（数字）
- `<GOOD_EVENT_ID>`: good build 的 event ID（数字）
- `<VS_NAME_URL_ENCODED>`: VS 名称 URL 编码，`VegaEchoInt-release%2Fdevelopment`

**示例 URL：**
```
https://code.amazon.com/version-sets/VegaEchoInt-release/development/revisions/6486201555?previous=6484997320&previous_vs=VegaEchoInt-release%2Fdevelopment
```

**重要说明：**
- 必须使用 `?previous=` + `&previous_vs=` 参数格式，这会做两个 revision 快照的完整对比
- 不要使用 `?diff_with=` 参数——那只返回单个 revision 自身引入的增量变更，会遗漏大量 source changes
- 返回结果包含 added / removed / branch change / source change 的完整列表（不含 version-only changes）

**从返回的 markdown 表格中解析每行获取：**
- `package_name`: Package 列的链接文字
- `from_commit`: From 列的 commit SHA
- `to_commit`: To 列的 commit SHA
- `from_version`: From 列的 version 号
- `to_version`: To 列的 version 号
- `branch`: Branch 列

**Fallback（如自动获取失败）：** 要求用户手动提供 package 列表。

---

### Step 3: Package 粗筛与分 Tier

#### 3.1 排除规则

以下 pattern 的 package 默认标记为 EXCLUDED（除非被 LEDA keyword 直接命中）：

```
排除 pattern（大小写不敏感）：
- Pipeline
- Infra（但不排除 Infrared）
- Tool / Tools / Tooling / Toolchain
- Test / Tests / Testing / TestFramework
- Metric / Metrics
- Dashboard
- Doc / Docs / Documentation
- Linter / Lint
- CICD / CI-CD
- BuildSystem / Build-System
```

**例外：** 如果被排除的包名中恰好包含 LEDA keyword，则不排除，正常参与分 tier。

#### 3.2 Subsystem Map

用于将 LEDA component 映射到具体 package 名称模式：

```json
{
  "graphics": ["VegaGraphics", "Weston", "Mesa", "DRM", "Display", "Orpheus", "GFX", "Compositor", "EGL", "OpenGL"],
  "audio": ["Audio", "Sound", "Alsa", "Pulse", "GstAudio", "Nova", "AudioHome", "AudioPlayer", "Doppler"],
  "connectivity": ["Wifi", "Bluetooth", "BT", "Rfkill", "Wlan", "Network", "Zigbee", "Matter", "Thread"],
  "boot": ["Boot", "Splash", "Animation", "Init", "Systemd", "Startup"],
  "touch": ["Touch", "Input", "Gesture", "HID", "Touchscreen"],
  "display_hw": ["DPU", "DSI", "MIPI", "Panel", "Backlight", "CABC", "HDMI", "DP"],
  "power": ["Power", "Suspend", "Resume", "Sleep", "Wake", "Thermal", "DVFS"],
  "framework": ["Kepler", "Vega", "Framework", "LCM", "VPM", "AppManager"],
  "media": ["Video", "Camera", "Codec", "Decoder", "Encoder", "MediaPlayer"],
  "security": ["Security", "SELinux", "Crypto", "Auth", "Certificate"]
}
```

#### 3.3 LEDA Component → Subsystem 映射

| LEDA component 关键词 | 映射 subsystem |
|---|---|
| Graphics / Display / Compositor | graphics, display_hw |
| Touch / Input | touch |
| Audio / Sound | audio |
| Connectivity / Network / Wi-Fi / Bluetooth | connectivity |
| Boot / Startup | boot |
| Power | power |
| Media / Video / Camera | media |
| Security | security |
| Framework / Kepler / Vega | framework |

#### 3.4 分 Tier 规则

对每个未被排除的 package，按优先级判定 tier：

**HIGH（强关联）——满足任一条即为 HIGH：**
1. Package 名包含任一 LEDA keyword（大小写不敏感子串匹配）
2. Package 名匹配 subsystem_map 中「与 LEDA component 直接关联的 subsystem」的某个 pattern
3. Package 名包含任一 LEDA process_name

**MEDIUM（可能关联）——满足任一条即为 MEDIUM：**
1. Package 名匹配「相邻子系统」中的某个 pattern

**LOW（弱关联）：**
1. 以上都不满足

#### 3.5 相邻子系统定义

```
graphics    → [display_hw, framework, power]
display_hw  → [graphics, power, touch]
audio       → [media, framework]
connectivity→ [power, framework]
touch       → [display_hw, graphics, framework]
boot        → [framework, power]
power       → [boot, display_hw, connectivity, graphics]
media       → [audio, graphics, framework]
framework   → [graphics, audio, touch, boot]
security    → []
```

#### 3.6 匹配逻辑（伪代码）

```
对每个 package:
  1. 检查排除规则 → 如果匹配且无 keyword 覆盖 → EXCLUDED
  2. 对每个 LEDA keyword: 如果 keyword 是 pkg_name 的子串 → HIGH
  3. 找出 LEDA components 对应的 relevant_subsystems
     对每个 relevant_subsystem 的 patterns: 如果 pattern 是 pkg_name 的子串 → HIGH
  4. 对每个 LEDA process_name: 如果 process 是 pkg_name 的子串 → HIGH
  5. 找出 relevant_subsystems 的 adjacent_subsystems
     对每个 adjacent_subsystem 的 patterns: 如果 pattern 是 pkg_name 的子串 → MEDIUM
  6. 其他 → LOW
```

---

### Step 4: 输出结果

#### 4.1 格式

```
═══════════════════════════════════════════════════════════
  EML Regression Bisector (v0.1) — <JIRA_ID> (<jira_title>)
═══════════════════════════════════════════════════════════

Signals extracted from LEDA:
  Keywords:   [...]
  Components: [...]
  Processes:  [...]

───────────────────────────────────────────────────────────
🔴 HIGH (strong match):

  1. <PackageName>  — <match reason>
  2. <PackageName>  — <match reason>
  ...

🟡 MEDIUM (possible match):

  N. <PackageName>  — <match reason>
  ...

⚪ LOW: <count> packages (not shown individually)
🚫 EXCLUDED: <count> packages

───────────────────────────────────────────────────────────
  Total: <total> packages in diff
  HIGH: <n> | MEDIUM: <n> | LOW: <n> | EXCLUDED: <n>
═══════════════════════════════════════════════════════════
```

#### 4.2 继续执行

v0.1 输出后自动继续执行 Step 5（v0.2 commit 级别分析）。
如用户明确说"只做粗筛"或"到此为止"，则停在 Step 4。

**默认行为是一路执行到底（v0.1 → v0.2 → v0.3），不要中途停下来问用户是否继续。**

---

## 测试数据

**用 BOC-2377 测试：**
- LEDA 目录: `/Users/caoxicz/workspace-mac/leda/LedaTriage/output_BOC-2377`
- Good event ID: `6438976910`
- Bad event ID: `6492635926`

**预期信号：**
- keywords: DPU, DSI, panel, flicker, Weston, rfkill, VSync, 60Hz, compositor
- components: Multimodal Graphics, Touch Input, Wi-Fi/Bluetooth Connectivity
- process_names: Weston (PID 1753), homelauncher, lwm_service

**预期分 tier 行为：**
- 含 "Display", "DPU", "Panel", "Weston", "Compositor" 的包 → HIGH
- 含 "Power", "Framework" 的包 → MEDIUM（相邻 graphics/display_hw）
- "SomePipelineTool" → EXCLUDED
- "RandomPackageXYZ" → LOW

---

---

## Step 5 (v0.2): 获取 HIGH Tier Package 的 Commit Detail

v0.2 在 v0.1 输出后继续执行，对 HIGH tier 的包做 commit 级别深度分析。

### 5.1 触发条件

v0.1 输出完成后自动继续。或者用户明确请求：
```
帮我深入分析 HIGH tier 的 commit
```

### 5.2 获取 Commit Detail

对每个 HIGH tier package（限制最多处理 **Top 15** 个最相关的），用 `ReadInternalWebsites` 读取：

**URL 格式（version diff，显示所有 commit）：**
```
https://code.amazon.com/packages/<PACKAGE_NAME>/brazil-version-diff?version_1=<FROM_VERSION>&version_2=<TO_VERSION>
```

**获取到 commit 列表后，对评分高的 commit 进一步获取代码 diff：**
```
https://code.amazon.com/packages/<PACKAGE_NAME>/commits/<COMMIT_SHA>
```

**从返回结果提取每个 commit 的：**
- Commit SHA
- Commit message（标题 + 正文）
- 修改的文件列表
- **代码变更内容（diff hunks）** — 关键：必须读取实际代码变更来判断是否引入了问题

### 5.3 深度分析策略

**两阶段分析：**
1. **粗筛（commit message）：** 先对所有 commit 基于 message 做快速打分
2. **深入（代码 diff）：** 对 message 粗筛后 Top 10 的 commit，获取完整代码变更，在代码层面验证是否真正相关

**代码 diff 分析要点：**
- 新增/修改的函数名、变量名是否包含 LEDA keyword
- 修改的文件路径是否在 LEDA 分析的相关区域
- 代码中是否涉及内存分配/释放（kmalloc, kfree, slab）、驱动初始化/卸载
- 是否涉及 power state transition、suspend/resume 路径
- 是否修改了定时器、超时、idle 处理逻辑

### 5.3 限制策略

- 每个 HIGH tier package 最多分析 **20 个 commit**（超过的截断，取最新的 20 个）
- 总共分析的 commit 数不超过 **200 个**（防止超时）
- 如果某 package 的 version diff 页面返回太多内容，只取 commit message 列表，跳过文件变更

---

## Step 6 (v0.2): 逐 Commit 打分

### 6.1 打分规则

对每个获取到的 commit，按以下规则累加分数：

**阶段 1：基于 commit message 的快速打分**

| 规则 | 条件 | 分数 |
|------|------|------|
| **Keyword 匹配** | commit message 含 LEDA keyword（大小写不敏感） | +10 per keyword |
| **文件路径匹配** | commit 修改的文件路径含 LEDA file_paths 片段 | +15 per match |
| **Component 匹配** | package 名匹配 LEDA component 关联的 subsystem | +5 |
| **可疑模式** | commit message 含 `fix`, `workaround`, `revert`, `hack`, `hotfix` | +3 |
| **新增功能引入** | commit message 含 `add`, `enable`, `introduce`, `support` | +2 |
| **TV-only 负分** | commit message 含 `FTV`, `TV only`, `TV-only`, `callie`, `kanto`, `mercer`, `carnival` | -8 |
| **Test-only 负分** | commit message 含 `test only`, `unit test`, `UT:` | -5 |
| **文档/注释** | commit message 含 `doc`, `comment`, `README`, `typo` | -3 |

**阶段 2：基于代码 diff 的深度打分（仅对阶段 1 Top 10 执行）**

| 规则 | 条件 | 分数 |
|------|------|------|
| **代码中 keyword 出现** | diff 中新增/修改的代码行含 LEDA keyword | +12 per keyword |
| **内存相关变更** | diff 涉及 kmalloc/kfree/slab/alloc/leak/OOM 相关代码 | +15 |
| **驱动初始化/电源路径** | diff 涉及 probe/remove/suspend/resume/power_on/power_off | +10 |
| **定时器/idle 逻辑** | diff 涉及 timer/timeout/idle/sleep/wake 相关代码 | +8 |
| **错误处理变更** | diff 修改了 error path / 异常处理 / recovery 逻辑 | +5 |
| **配置/宏定义变更** | diff 仅修改 config/Makefile/Kconfig/.bb recipe | +2（降权：间接影响） |

### 6.2 打分伪代码

```
对每个 HIGH tier package 的每个 commit:
  score = 0
  reasons = []

  # Keyword 匹配
  for kw in signals.keywords:
    if kw.lower() in commit_message.lower():
      score += 10
      reasons.append(f"keyword: {kw}")

  # 文件路径匹配（如有文件列表）
  for leda_path in signals.file_paths:
    for changed_file in commit.files:
      if leda_path.lower() in changed_file.lower():
        score += 15
        reasons.append(f"file: {leda_path}")
        break

  # Component/subsystem 匹配（包级别已在 v0.1 判定，此处额外 +5）
  score += 5
  reasons.append(f"pkg in HIGH tier")

  # 可疑模式
  if regex_match(r'\b(fix|workaround|revert|hack|hotfix)\b', commit_message):
    score += 3
    reasons.append("suspicious pattern: fix/revert")

  # 新功能引入
  if regex_match(r'\b(add|enable|introduce|support)\b', commit_message):
    score += 2
    reasons.append("new feature introduction")

  # TV-only 负分
  if regex_match(r'\b(FTV|TV.only|callie|kanto|mercer|carnival)\b', commit_message):
    score -= 8
    reasons.append("TV-only marker (negative)")

  # Test-only 负分
  if regex_match(r'\b(test.only|unit.test|UT:)\b', commit_message):
    score -= 5
    reasons.append("test-only (negative)")

  # 文档负分
  if regex_match(r'\b(doc|comment|README|typo)\b', commit_message):
    score -= 3
    reasons.append("doc/comment only (negative)")
```

---

## Step 7 (v0.2): 输出排序结果

### 7.1 输出格式

按 score 降序排列，输出 Top 10 嫌疑 commit：

```
═══════════════════════════════════════════════════════════
  EML Regression Bisector (v0.2) — <JIRA_ID> (<jira_title>)
  Range: <GOOD_EVENT_ID> → <BAD_EVENT_ID>
═══════════════════════════════════════════════════════════

🔴 Top Suspects (Score ≥ 10):

#1 [Score: 35] <PackageName>
   Commit: <SHA> "<commit message first line>"
   Author: <author>
   Match:  keyword(mtk_802154, slab), file(mtk_802154_spi.c), fix pattern
   CR/Gerrit: https://code.amazon.com/reviews/CR-XXXXXXX 或 https://gerrit6.labcollab.net/c/<project>/+/<change_id>
   Link:   https://code.amazon.com/packages/<PKG>/commits/<SHA>

#2 [Score: 25] <PackageName>
   Commit: <SHA> "<commit message first line>"
   Author: <author>
   Match:  keyword(DRM, display), component(Graphics/Display)
   CR/Gerrit: <CR 或 Gerrit6 链接>
   Link:   https://code.amazon.com/packages/<PKG>/commits/<SHA>

#3 [Score: 18] ...

...

🟡 Possible (Score 5-9):
#N [Score: 8] ...

───────────────────────────────────────────────────────────
  Packages analyzed: <n> (HIGH tier)
  Commits analyzed: <total_commits>
  Suspects found: <n> with score ≥ 10
═══════════════════════════════════════════════════════════
```

### 7.2 获取 CR/Gerrit 链接

对每个 Top suspect commit，必须提供 CR 或 Gerrit6 review 链接。获取方式：

**方式 1：从 commit message 提取**
- 很多 commit message 中直接包含 `CR-XXXXXXX` 或 Gerrit change ID
- 正则匹配：`CR-\d+` 或 `Change-Id: I[a-f0-9]{40}`

**方式 2：从 commit detail 页面获取**
- 读取 `https://code.amazon.com/packages/<PKG>/commits/<SHA>`
- 页面中通常会显示关联的 Code Review 链接

**方式 3：构造 Gerrit6 链接**
- 如果 source 来自 `gerrit6.labcollab.net`（如 connectedhomeip），链接格式：
  `https://gerrit6.labcollab.net/q/<commit_sha>`

**方式 4：构造 code.amazon.com review 搜索**
- `https://code.amazon.com/reviews/from-user/<author_login>`

**输出要求：** 每个 suspect 必须附带至少一个可点击的 review 链接（CR 或 Gerrit），方便用户直接跳转查看完整 review 讨论。如果无法获取 CR/Gerrit 链接，至少提供 commit 链接。

### 7.3 结束语

```
以上是基于 commit message + 文件路径匹配的排序结果。
建议：
1. 优先查看 Score ≥ 20 的 commit，点击 Link 查看完整 diff
2. 如果 Top 1 的 score 远高于其他，大概率是 culprit
3. 注意同一 package 的多个 commit 可能共同引发问题

需要我帮你查看某个具体 commit 的详细 diff 吗？
```

---

## Step 8 (v0.3): 候选改动深度枚举与根因分析

### 8.1 目的

v0.2 的 Top Suspects 基于 keyword 匹配打分，但存在以下盲点（BOC-2420 教训）：
- **隐式代码引入：** recipe 文件（如 `acs-base-variables.inc`）中的 SRCREV bump / branch 升级，看起来只是一行 hash 变更，实际引入了整个 upstream branch 的新代码
- **因果链断裂：** OOM 的直接原因可能是 slab leak，但触发 slab leak 的是某个用户态服务的异常行为，而该服务的异常又来自 middleware 升级
- **单一信号过度依赖：** 只看 commit message keyword 可能把真正的 culprit 排在后面

**Step 8 要求 agent 对 Top Suspects 做结构化的候选枚举，回答三个问题：**
1. 这个改动**具体改了什么**（不只是 commit message，要看实际代码/配置变更）
2. 这个改动**为什么可能导致观察到的症状**（建立因果链）
3. **如何验证**它是否是 root cause（具体到 package、文件、revert 方法）

### 8.2 触发条件

Step 7 输出 Top Suspects 后自动继续。或用户明确请求：
```
帮我分析这些候选改动的因果链和验证方法
```

### 8.3 候选改动分类

对 Step 7 输出的 Top Suspects（Score ≥ 10），按照以下类型分类：

| 改动类型 | 描述 | 风险级别 | 典型例子 |
|----------|------|----------|----------|
| **SRCREV bump** | recipe 中 SRCREV/branch 变更，引入 upstream 新代码 | 🔴 极高 | `acs-base-variables.inc` 中 conn_thread 从 rb54→rb55 |
| **驱动/内核模块变更** | kernel module 或 HAL 层代码变更 | 🔴 极高 | mtk_802154_spi driver 修改 |
| **系统服务配置变更** | systemd service、resource budget、启动顺序变更 | 🟡 中等 | `ace_conn_thread.service` 修改 |
| **应用层代码变更** | middleware / framework 的功能逻辑变更 | 🟡 中等 | conn_thread_service.c 新增 telemetry call |
| **构建配置变更** | .bb/.bbappend recipe 的 DEPENDS/RDEPENDS 变更 | 🟢 低 | 新增或移除编译依赖 |
| **纯 infra/test** | Pipeline、CI、unit test 变更 | ⚪ 可忽略 | test_conn_thread.c 修改 |

### 8.4 SRCREV Bump 深度分析（关键改进）

**问题背景：** 当 `acs-base-variables.inc` 或类似 recipe 文件中出现 SRCREV 变更时，VS diff 只显示一行 hash 变化，但实际可能引入了几十个 commit。

**处理流程：**

1. **识别 SRCREV bump：** 在 diff 中查找 `SRCREV_*` 变更行

2. **追踪实际代码变更：** 用 Gerrit6 查看 old_SRCREV → new_SRCREV 之间的所有 commit：
   ```
   https://gerrit6.labcollab.net/q/project:<project>+branch:<branch>+after:<old_date>+before:<new_date>
   ```
   或者：
   ```
   https://gerrit6.labcollab.net/plugins/gitiles/<project>/+log/<old_SRCREV>..<new_SRCREV>
   ```

3. **识别 branch 升级：** 如果 branch 也变了（如 `rb54` → `rb55`），说明是跨 release branch 的升级，风险最高——需要查看整个 release branch 的 changelog

4. **标注为最高优先级嫌疑：** SRCREV bump + branch 升级 = 最可能引入大规模行为变化

### 8.5 因果链分析模板

对每个 Top Suspect，agent 必须输出以下结构：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
候选 #N: <Package> — <简要描述>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 改动内容：
   类型: SRCREV bump / 驱动变更 / 服务配置 / 应用逻辑
   文件: <具体文件路径>
   变更: <具体变了什么（old → new）>

🔗 因果链推理：
   改动 → [中间步骤1] → [中间步骤2] → 观察到的症状
   例: conn_thread rb54→rb55 引入 un-guarded telemetry call
       → otbr-agent crash loop（被 conn_thread 异常 IPC 触发）
       → mtk_802154_spi 反复 open/close
       → slab 对象泄漏
       → OOM

📊 可信度评估：
   [高/中/低] — 理由

🔬 验证方法：（见 Step 9 详细格式）
   Package: <需要操作的 package 名>
   操作: revert / 修改配置 / cherry-pick fix
   具体步骤: ...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 8.6 多候选并列时的排序策略

当有多个候选改动时，按以下优先级排序：

1. **SRCREV bump + branch 升级** — 最高优先级，一次引入大量未验证代码
2. **直接修改了症状中出现的进程/模块的代码** — 如 crash 栈中出现的 driver
3. **修改了与症状相关的配置/启动逻辑** — 如修改了 service 依赖关系
4. **间接关联** — 修改了上下游依赖的 library

### 8.7 常见误判模式（Lessons Learned）

| 误判模式 | 描述 | 如何避免 |
|----------|------|----------|
| **只看表面症状** | OOM → 认为是内存配置问题 | 追问 "什么在泄漏？为什么泄漏？" |
| **忽略 SRCREV bump** | 认为一行 hash 变化不重要 | 对每个 SRCREV 变更追踪实际 commit |
| **过度信任 package 名匹配** | mtk_802154_spi 名字匹配 → 认为是 driver bug | 确认是 driver 自身问题还是被上层触发 |
| **忽略级联效应** | 只看直接变更，不看间接触发 | 画出完整因果链：变更 → 行为变化 → 副作用 → 症状 |
| **排除看似无关的包** | "这只是 middleware 升级，跟 OOM 无关" | 检查该 middleware 是否会触发 kernel 路径 |

---

## Step 9 (v0.3): 验证方法具体指引

### 9.1 目的

告诉用户**具体怎么做**来验证每个候选改动是否是 root cause。不能只说"revert 试试"，必须精确到：
- 哪个 package（git repo）
- 哪个文件
- 改什么（revert 哪个 commit，或修改哪行配置）
- 怎么 build 验证

### 9.2 验证方法输出格式

对每个候选改动，输出以下格式的验证指引：

```
┌─────────────────────────────────────────────────────────┐
│ 验证方案 #N: <候选改动名称>                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 📦 Package: <package 名称>                              │
│ 📁 文件:    <需要修改的文件相对路径>                      │
│ 🔀 操作:    revert SRCREV / revert commit / 修改配置     │
│                                                         │
│ 具体步骤:                                               │
│ 1. cd <workspace_path>/src/<package>/                   │
│ 2. 编辑 <file>:                                         │
│    - 将 SRCREV_xxx = "<new_hash>"                       │
│      改回 SRCREV_xxx = "<old_hash>"                     │
│    - 将 branch=<new_branch>                             │
│      改回 branch=<old_branch>                           │
│ 3. 构建: bitbake <target-image>                         │
│    或: brazil-build release (如果是 brazil package)      │
│ 4. 刷机测试: 观察 <具体指标>                             │
│                                                         │
│ ✅ 预期结果: <如果此改动是 root cause，验证后应看到什么>   │
│ ⚠️  注意事项: <可能的副作用或限制>                        │
└─────────────────────────────────────────────────────────┘
```

### 9.3 不同类型改动的验证方法模板

#### 9.3.1 SRCREV Bump 验证

```
操作: 回退 SRCREV 和 branch
Package: <包含 recipe 的 package，如 EchoDevBrioche>
文件: meta-acs/recipes-core/acs-base/acs-base-variables.inc

步骤:
1. 找到该文件中对应的 SRCREV 行和 SRC_URI 行
2. 将 SRCREV 改回 good build 中的值
   例: SRCREV_ace_experimental_middleware_conn_thread = "<old_hash>"
3. 如果 branch 也变了，同步回退
   例: branch=ace/release/rb54 （从 rb55 改回 rb54）
4. 注意：如果有多个 SRCREV 属于同一组件（如 hal + middleware），需要同时回退
5. bitbake <image-name> 或触发 nightly build
6. 刷机后观察是否还出现原始症状

预期: 如果问题消失 → 确认是此 SRCREV bump 引入
副作用: 回退后可能丢失该 release 中的其他 fix，仅用于验证
```

#### 9.3.2 驱动/内核模块变更验证

```
操作: 在内核 package 中 revert 特定 commit
Package: <kernel package，如 linux-mtk 或 meta-mediatek>
文件: <driver source file path>

步骤:
1. 找到引入问题的 commit SHA
2. cd <workspace>/src/<kernel-package>/
3. git revert <commit_sha> --no-commit
   或手动回退相关代码段
4. rebuild kernel module:
   bitbake -c compile -f <kernel-recipe>
   bitbake <image-name>
5. 如果 driver 是 out-of-tree module，可能只需 rebuild module package

预期: revert 后 driver 行为恢复正常（如 slab 不再泄漏）
替代: 如果不便 revert 整个 commit，可以在 driver 中加入防御性检查
      （如 null pointer check、rate limiter）来验证假设
```

#### 9.3.3 系统服务/配置变更验证

```
操作: 在设备上直接修改配置（无需 rebuild，快速验证）
Package: <meta-layer package>
文件: <service file 或 conf file>

步骤:
1. adb shell / ssh 登录设备
2. 直接修改运行时配置:
   - systemd service: /lib/systemd/system/<service>.service
   - resource budget: /etc/<app-framework>/process-resource-budget*.conf
3. systemctl daemon-reload && systemctl restart <service>
4. 观察是否复现

预期: 如果配置变更导致问题，直接回退配置后症状消失
优势: 无需 rebuild，几分钟内可验证
```

#### 9.3.4 Cherry-pick Fix 验证（正向验证）

```
操作: 将已知 fix cherry-pick 到 bad build 上验证
Package: <fix 所在的 package>
Gerrit/CR: <fix 的 review 链接>

步骤:
1. 获取 fix patch:
   - Gerrit6: git fetch <gerrit_url> <ref> && git cherry-pick FETCH_HEAD
   - CR: 下载 patch 文件并 git apply
2. Rebuild 并刷机
3. 验证问题是否消失

预期: 如果 fix 有效 → 确认 root cause 假设正确
优势: 正向验证比 revert 更精确，且不丢失其他改动
```

### 9.4 验证优先级建议

向用户建议验证顺序时，遵循以下原则：

1. **先试设备上可直接验证的**（修改 config、disable service） — 几分钟
2. **再试 SRCREV revert**（改 recipe 文件 rebuild） — 几小时（build time）
3. **最后试 code-level revert**（需要理解代码细节） — 半天到一天
4. **如果有 fix patch 可用**，优先做正向验证（cherry-pick fix）

### 9.5 输出示例（基于 BOC-2420）

```
┌─────────────────────────────────────────────────────────┐
│ 验证方案 #1: conn_thread SRCREV rb54→rb55 升级           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 📦 Package: EchoDevBrioche                              │
│ 📁 文件:    meta-acs/recipes-core/acs-base/             │
│             acs-base-variables.inc                       │
│ 🔀 操作:    回退 SRCREV + branch                         │
│                                                         │
│ 具体步骤:                                               │
│ 1. cd <workspace>/src/EchoDevBrioche/                   │
│ 2. 编辑 meta-acs/recipes-core/acs-base/                 │
│         acs-base-variables.inc:                          │
│    - SRCREV_ace_experimental_middleware_conn_thread      │
│      从 "61d1dfa2..." 改回 "1e762cc1..."                │
│    - branch 从 ace/release/rb55 改回 ace/release/rb54   │
│    - 同时回退 SRCREV_ace_experimental_dpk_hal_conn_     │
│      thread（如果也升级了）                              │
│ 3. bitbake brioche-image                                │
│ 4. 刷机后观察:                                          │
│    - dmesg | grep -i "oom\|slab\|mtk_802154"            │
│    - systemctl status ace_conn_thread.service           │
│    - systemctl status otbr-agent.service                │
│                                                         │
│ ✅ 预期: OOM 不再出现，otbr-agent 稳定运行              │
│ ⚠️  注意: 回退后 Thread/Zigbee 功能可能缺少 rb55 的     │
│    bug fix，仅用于确认 root cause                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 验证方案 #2: mtk_802154_spi driver 防御修复              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 📦 Package: linux-mtk 或 meta-mediatek kernel module    │
│ 📁 文件:    drivers/ieee802154/mtk_802154_spi.c         │
│ 🔀 操作:    cherry-pick 防御性 fix                       │
│                                                         │
│ 具体步骤:                                               │
│ 1. 获取 fix: gerrit6 +/2303256                          │
│ 2. cherry-pick 到当前 kernel tree                       │
│ 3. rebuild kernel module                                │
│ 4. 刷机观察 slab 使用是否稳定                           │
│                                                         │
│ ✅ 预期: 即使 conn_thread rb55 仍在，driver 不再泄漏     │
│ ⚠️  这是 defense-in-depth fix，不是 root cause fix      │
└─────────────────────────────────────────────────────────┘
```

---

## Step 10 (v0.3): 最终输出报告（严格格式）

### 10.1 输出规则

**所有 bisect 运行必须以此固定格式输出最终报告。** 不允许随机排版或省略任何必填字段。

报告按嫌疑度从高到低列出所有候选改动。每个候选必须包含：推理过程、因果链、验证方法。如有已知 fix 也必须附加。

### 10.2 严格输出模板

```
═══════════════════════════════════════════════════════════════════
  EML Regression Bisector — <JIRA_ID>
  <JIRA title 一句话>
  Range: <GOOD_EVENT_ID> → <BAD_EVENT_ID>
  VS: VegaEchoInt-release/development
═══════════════════════════════════════════════════════════════════

📊 分析摘要:
  - VS diff 总包数: <N>（source change: <N>, added: <N>, removed: <N>）
  - HIGH tier: <N> 包 | MEDIUM: <N> | LOW: <N> | EXCLUDED: <N>
  - 分析 commit 总数: <N>
  - 📚 历史先验匹配: <有/无>（如有，列出匹配的 JIRA ID）

───────────────────────────────────────────────────────────────────
🔴 嫌疑 #1 [Score: <XX>] [可信度: 高/中/低]
───────────────────────────────────────────────────────────────────

📦 Package: <package name>
📁 文件: <changed file path>
🔀 改动类型: SRCREV bump / 驱动变更 / 服务配置 / 应用逻辑
👤 Author: <author> (<alias>)
📅 Date: <commit date>
🔗 Link: <code.amazon.com commit URL or Gerrit6 URL>

📝 改动内容:
   <具体描述改了什么，old → new，如有 SRCREV 写出 old hash → new hash>

🧠 推理过程:
   <为什么怀疑这个改动？keyword 匹配了什么？subsystem 关联是什么？
    如果有历史先验加分，说明来源>

🔗 因果链:
   <改动> → <中间步骤1> → <中间步骤2> → ... → <观察到的症状>

🔬 验证方法:
   Package: <需要操作的 package>
   操作: <revert SRCREV / revert commit / 修改配置 / cherry-pick fix>
   具体步骤:
   1. <step 1>
   2. <step 2>
   3. <step 3>
   预期结果: <如果此改动是 root cause，验证后应看到什么>
   注意事项: <可能的副作用>

🔧 已知 Fix（如有）:
   - <fix 描述>: <Gerrit/CR link>
   - 状态: <已 merge / pending review / 未提交>

───────────────────────────────────────────────────────────────────
🟡 嫌疑 #2 [Score: <XX>] [可信度: 高/中/低]
───────────────────────────────────────────────────────────────────

（同上格式，每个字段都必须填写）

───────────────────────────────────────────────────────────────────
🟢 嫌疑 #3 [Score: <XX>] [可信度: 低]
───────────────────────────────────────────────────────────────────

（同上格式）

... （按嫌疑度递减继续，直到所有 Score ≥ 10 的候选都列完）

═══════════════════════════════════════════════════════════════════
💡 建议验证顺序:
   1. <最快的验证方案>（预计耗时 N 分钟/小时）
   2. <第二方案>（预计耗时 N 分钟/小时）
   3. ...

⚠️ 已知 False Positive 提醒（如有历史数据）:
   - <package/改动>: <为什么不是 root cause>

═══════════════════════════════════════════════════════════════════
```

### 10.3 模板填写规则

1. **每个嫌疑必须有完整的推理过程** — 不能只写"keyword 匹配"，要解释为什么这个匹配有意义
2. **因果链必须从改动出发到达症状** — 中间步骤不能跳跃，每一步都要有逻辑依据
3. **验证方法必须具体到可执行** — 不能只说"revert 试试"，要写清楚改哪个文件、改什么值
4. **已知 Fix 必须附 link** — 如果有 Gerrit/CR 链接就写，没有就写"未找到"
5. **Score ≥ 10 的嫌疑全部输出** — 不能因为 #1 明显就省略 #2、#3
6. **如果只有 1 个嫌疑（如历史已知 root cause），也必须完整填写所有字段**
7. **False Positive 提醒** — 如果历史数据中有 false positive 记录，必须输出提醒防止误判

---

## 测试数据（v0.2）

**继续用 BOC-2420 测试：**
- LEDA 目录: `/Users/caoxicz/workspace-mac/leda/LedaTriage/output_BOC-2420`
- Good event ID: `6484997320`
- Bad event ID: `6486201555`

**已知 culprit：** `mtk_802154_spi` Thread/Zigbee radio 内核 slab 泄漏

**v0.2 验证标准：**
- 在 HIGH tier 的 Mediatek/Connectivity 相关包的 commit 中
- 含 `mtk_802154` / `802154` / `thread` / `zigbee` / `spi` 关键词的 commit 应获得最高分
- 含 `slab` / `memory` / `leak` / `alloc` 的 commit 也应高分
- Top 3 中应出现与 802.15.4 驱动相关的变更

---

## Step 11 (v0.3-full): LLM 语义匹配 — 替代纯 Keyword 打分

### 11.1 目的

Step 6 的打分完全基于字面 keyword 匹配，存在明显盲点：
- "Enable periodic health reporting for connectivity services" 不包含 "OOM" / "slab" / "leak"，但语义上它引入了一个周期性调用，可能在异常场景下导致 crash loop
- "Refactor socket lifecycle management" 不包含 "802154"，但它改变了 UNIX socket 的生命周期，可能影响依赖该 socket 的 otbr-agent

纯 keyword 匹配无法捕捉这些**语义层面**的关联。

### 11.2 核心思路

**本 skill 的执行主体就是 LLM（agent 自身）**，所以不需要调用外部 embedding API。直接让 agent 对 Top 20 commit 做一次**语义重排序**——用自己的理解能力判断 commit 与 regression 的相关度。

### 11.3 执行流程

在 Step 6 keyword 打分完成后，增加一个**语义分析轮次**：

**输入：**
- LEDA hypothesis（完整文本）
- LEDA description（完整的 bug 描述 + 复现步骤）
- 症状摘要（crash 栈、OOM log 等关键片段）
- Step 6 keyword 打分后的 Top 20 commit（含 commit message + 修改的文件列表）

**分析要求：**

Agent 对每个 commit 回答以下三个问题，给出 0-10 的语义相关度评分：

```
对 Top 20 中的每个 commit，评估：

Q1: 这个 commit 的变更内容，是否有可能**直接或间接**导致 LEDA 描述的症状？
    （不限于 keyword 匹配，考虑因果推理）
    评分: 0-10

Q2: 这个 commit 涉及的子系统/模块，在运行时是否与出问题的组件有**交互路径**？
    （如：共享 IPC、相同的 kernel 子系统、上下游调用关系）
    评分: 0-10

Q3: 这个 commit 的变更**模式**（如：修改 timer、改变资源生命周期、新增未保护的调用）
    是否是已知的 regression 引入模式？
    评分: 0-10
```

**输出格式（agent 内部思考）：**

```
── 语义分析: Commit <SHA> "<message>" ──
Q1 (因果可能性): 7/10 — 修改了 socket 生命周期，otbr-agent 依赖此 socket
Q2 (交互路径):   8/10 — conn_thread → otbr-agent → 802154 driver，存在调用链
Q3 (变更模式):   6/10 — 修改了资源释放逻辑，属于高风险模式
语义总分: 21/30 → 换算为 bonus: +14
```

### 11.4 语义分数与 keyword 分数融合

```
final_score = keyword_score + semantic_bonus

semantic_bonus 计算:
  raw_semantic = (Q1 + Q2 + Q3)  # 范围 0-30
  semantic_bonus = round(raw_semantic * 0.7)  # 范围 0-21，与 keyword_score 量级匹配
```

**融合后重排序：** 按 final_score 降序重排 Top Suspects。

### 11.5 语义分析的触发条件

- **默认执行：** 当 commit 数量 ≤ 20 时，对所有 Top commits 做语义分析
- **可选跳过：** 如果 Top 1 的 keyword_score 已经远高于 Top 2（差距 > 20），认为 keyword 匹配已足够确定，可跳过语义分析
- **用户可强制：** 用户说"做深度分析"或"语义匹配"时，即使 Top 1 明显也执行

### 11.6 语义分析注意事项

- **避免 hallucination：** 如果无法确定因果关系，评分应偏低（3-4），不要因为 commit message 中出现了相关词汇就给高分
- **SRCREV bump 特殊处理：** 对 SRCREV bump 类型的变更，语义分析应基于 upstream 的 release notes 或 commit log 概要，而非仅一行 hash 变化
- **context 长度控制：** 如果 commit message 过长（>500 字），截取前 200 字 + 修改文件列表

### 11.7 与 BOC-2420 的验证

在 BOC-2420 场景中，语义分析应该：
- 给 conn_thread SRCREV bump 高分（Q1=8: rb55 引入新功能可能有 bug，Q2=9: conn_thread↔otbr-agent↔802154，Q3=7: branch 升级是高风险模式）
- 给 mtk_802154_spi 相关的小修改中等分（Q1=5: 看起来是 fix 不是引入，Q2=10: 直接相关，Q3=4: 不太像引入 bug 的模式）
- 比纯 keyword 匹配更准确地把 SRCREV bump 排在前面

---

## Step 12 (v0.3-full): 依赖图间接影响分析

### 12.1 目的

某些 regression 的 root cause 不在直接匹配的包里，而是在它的**依赖**或**被依赖者**中。例如：
- Package A 修改了一个 shared library → Package B 链接了该 library → B 出现 crash
- Package C 修改了一个 systemd service 的启动顺序 → 影响了后续启动的 Package D

需要从 recipe 文件中提取依赖关系，发现这些间接影响路径。

### 12.2 依赖信息来源

**优先级 1：VegaLens（如可访问）**

尝试用 `ReadInternalWebsites` 访问：
```
https://vegalens.corp.amazon.com/api/v1/packages/<PACKAGE_NAME>/dependencies
```
或：
```
https://vegalens.corp.amazon.com/packages/<PACKAGE_NAME>
```

如果 VegaLens 可访问，直接获取结构化的依赖树。

**优先级 2：从 recipe 文件提取（Fallback，总是可用）**

对 HIGH tier package，读取其 `.bb` / `.bbappend` 文件，提取：

```
DEPENDS = "..."          # 编译时依赖
RDEPENDS:${PN} = "..."   # 运行时依赖
RRECOMMENDS:${PN} = "..." # 推荐安装
```

**优先级 3：从 systemd service 文件提取服务依赖**

```
After=<service1> <service2>
Before=<service3>
Requires=<service4>
Wants=<service5>
```

### 12.3 分析流程

```
1. 构建 HIGH tier package 的依赖子图:
   对每个 HIGH tier package P:
     - deps(P) = P 的 DEPENDS + RDEPENDS
     - rdeps(P) = 谁依赖了 P（在整个 VS diff 的 package 列表中查找）

2. 检查 "间接影响路径":
   对 VS diff 中的每个 source change package X:
     如果 X ∈ deps(HIGH_tier_package) 或 HIGH_tier_package ∈ deps(X):
       → X 与 HIGH tier 存在依赖关系
       → 如果 X 当前在 LOW/MEDIUM tier，提升到 MEDIUM
       → 在输出中标注 "间接影响: X → HIGH_pkg (via DEPENDS)"

3. 检查 "服务启动链间接影响":
   从 systemd service 文件中提取启动顺序
   如果出问题的 service 在 After= 中依赖了另一个被修改的 service:
     → 标注为 "启动顺序依赖: modified_service → affected_service"
```

### 12.4 输出格式

在 Step 10 的最终汇总中，增加一个"间接影响"小节：

```
🔀 间接影响路径:

  Path 1: meta-acs/acs-base (SRCREV bump)
           → 编译产出 libacehal_conn_thread.so
           → 被 ace_conn_thread_service 加载
           → 通过 IPC 与 otbr-agent 通信
           → otbr-agent 操作 mtk_802154_spi driver
           ⚡ 如果 libacehal_conn_thread.so 行为变化 → 整条链受影响

  Path 2: conn-thread-hal (DEPENDS 变更)
           → dpk-packages DEPENDS += conn-thread-hal
           → 如果 conn-thread-hal 接口变化 → dpk-packages 行为可能变化

  Path 3: systemd 启动顺序
           → ace_conn_thread.service Before= otbr-agent.service
           → 如果 conn_thread 启动异常 → otbr-agent 可能在错误状态下启动
```

### 12.5 依赖图的限制

- **不追踪超过 2 层的间接依赖** — 太远的关联噪音太大
- **不分析 version-only changes** — 只有 source change 的包才可能引入行为变化
- **如果 VegaLens 不可用且 recipe 文件不在 diff 范围内** — 跳过依赖分析，在输出中注明

---

## Step 13 (v0.3-full): 积累学习 — 历史 Bisect 知识库

### 13.1 目的

每次成功的 bisect 都会产生有价值的知识：
- 哪些 package 是"惯犯"（经常引入 regression）
- 哪些变更模式容易出问题（如 SRCREV bump、branch 升级）
- 特定症状通常对应哪些子系统

将这些知识持久化存储，在未来的 bisect 中作为先验信息使用。

### 13.2 存储位置和格式

**目录：** `/Users/caoxicz/workspace-mac/leda/regression-bisector/history/`

**文件命名：** `<JIRA_ID>.json`（如 `BOC-2420.json`）

**JSON Schema：**

```json
{
  "jira_id": "BOC-2420",
  "title": "OOM on Brioche after VML merge",
  "date_resolved": "2025-07-xx",
  "platform": "Brioche",

  "input": {
    "good_event_id": "6484997320",
    "bad_event_id": "6486201555",
    "vs": "VegaEchoInt-release/development"
  },

  "symptoms": {
    "primary": "OOM (Out of Memory)",
    "secondary": ["slab leak", "mtk_802154_spi", "otbr-agent crash loop"],
    "keywords_from_leda": ["OOM", "slab", "802154", "conn_thread", "otbr-agent"]
  },

  "root_cause": {
    "package": "meta-acs (EchoDevBrioche)",
    "file": "meta-acs/recipes-core/acs-base/acs-base-variables.inc",
    "change_type": "SRCREV_bump",
    "description": "conn_thread middleware 从 rb54 升级到 rb55，引入 un-guarded telemetry call",
    "causal_chain": [
      "conn_thread rb55 引入 un-guarded telemetry call",
      "otbr-agent crash loop (被异常 IPC 触发)",
      "mtk_802154_spi driver 反复 open/close",
      "kernel slab 对象泄漏",
      "OOM"
    ]
  },

  "fix": {
    "primary": "gerrit6 +/2301094 (guard telemetry call in conn_thread)",
    "secondary": "gerrit6 +/2303256 (mtk_802154_spi driver defense)"
  },

  "lessons": [
    "SRCREV bump + branch 升级是最危险的隐式变更",
    "OOM 需要追问: 什么在泄漏 → 谁触发泄漏 → 谁改了触发者的行为",
    "middleware 升级可以间接导致 kernel 资源泄漏"
  ],

  "false_positives": [
    {
      "package": "mtk_802154_spi driver 本身",
      "why_suspected": "名字直接匹配 slab leak 的来源",
      "why_wrong": "driver 是受害者不是始作俑者，是被上层 crash loop 触发的"
    }
  ]
}
```

### 13.3 写入时机

Agent 在完成一次 bisect 并得到用户确认 root cause 后，**自动写入**历史记录。

触发条件（满足任一）：
- 用户明确说"root cause 确认了"或"问题找到了"
- 用户提供了 fix 的 gerrit/CR 链接
- 用户说"结案"或"bisect 完成"

Agent 生成 JSON 文件并保存到 `history/` 目录。

### 13.4 读取时机 — 先验知识加成

在 **Step 1（LEDA 信号提取）** 后，agent 扫描 `history/` 目录：

```
1. 读取所有 history/*.json 文件
2. 对每个历史记录，检查与当前 bisect 的相似度:
   - 症状相似: 当前 LEDA keywords ∩ 历史 symptoms.keywords_from_leda
   - 平台相同: 当前 platform == 历史 platform
   - 时间接近: 如果 event ID 范围有重叠

3. 如果找到相似历史案例:
   - 提取 root_cause.package → 在 Step 3 粗筛时给予 +10 bonus
   - 提取 root_cause.change_type → 在 Step 8 分类时优先检查同类型变更
   - 提取 lessons → 在 Step 8 分析时参考
   - 提取 false_positives → 在分析时避免重蹈覆辙
```

### 13.5 先验知识加分规则

| 条件 | 加分 | 原因 |
|------|------|------|
| 当前 diff 中出现了历史"惯犯" package | +15 | 该包曾经引入过 regression |
| 症状 keywords 与历史案例高度重叠（≥3个） | +10 | 可能是相同 pattern 的问题 |
| 相同平台 + 相似时间窗口 + 相同 package | +20 | 极高可能是同一根因 |
| 当前 commit 与历史 false_positive 匹配 | -10 | 曾被证明不是原因 |

### 13.6 输出中的历史引用

当历史知识影响了排序结果时，在输出中注明：

```
#3 [Score: 28] meta-acs (SRCREV bump)
   Match: SRCREV_bump_pattern, semantic(conn_thread → otbr-agent chain)
   📚 历史参考: BOC-2420 中相同 package 的 SRCREV bump 导致了 OOM (+15 history bonus)
   Link: ...
```

### 13.7 初始历史数据

基于已完成的 BOC-2420，创建第一条历史记录作为种子数据。

---

## 版本演进说明

| 版本 | 新增能力 | 本文件状态 |
|------|----------|-----------|
| **v0.1** | 解析 LEDA + subsystem_map 粗筛 + 分 tier 输出 | ✅ 已完成 |
| **v0.2** | commit detail 获取 + 逐 commit 打分 + 排序输出 | ✅ 已完成 |
| **v0.3** | 候选改动枚举 + 因果链 + 验证指引 + LLM 语义匹配 + 依赖图 + 积累学习 | ✅ 当前版本 |
| v0.4 | 自动触发 build 验证 + KBITS 集成 + 更多平台支持 | 待规划 |
