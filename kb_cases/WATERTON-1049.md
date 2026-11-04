---
id: WATERTON-1049
title: 为非法 RGB gain（gain=0 / CCT 越界）设计端到端可观测性指标，打通现场显示故障与客诉关联
platform: [Waterton]
soc_display: Amazon PQ (libamazonpq) 显示管线（AAD / CCORR 阶段）；SoC 型号待确认；对照组 = 共享 picturequality 源但不启用本指标的其他 Echo 设备（madeleine / electra / miramar）
subsystem: [display, picture-quality, metrics, ace-minerva, AAD]
symptoms_keywords:
  - illegal RGB gain / 非法 RGB 增益
  - RGB gain == 0 / zero gain / 三通道增益全为 0
  - CCT out of allowed range / 色温越界（CCT_MIN 1667 / CCT_MAX 25000）
  - wrong display output / 画面异常 / blank screen / black screen / 黑屏
  - DIAG-BLACKSCREEN probe / AAD::getRGBgains() ~line 692 / displayCCT
  - RgbGainViolationMetrics / ACE Minerva / DSN (ACE_MINERVA_PREDEFINED_DEVICE_ID)
role: Owner（JIRA reporter + assignee 均为 Xi Cao / caoxicz）
status: 根因 = 本票不负责定位 illegal-gain 产生根因（属 block-write 等其他 pillar）；修复 = 设计完成（spec 形式），实现未开始；JIRA 状态「开放」（截至 2026-10-29）
fix_nature: 检测 / 可观测性设计（既非 root-fix，也非 mitigation；mitigation 由 block-write pillar 负责）
period: 2026-09-20 建票 → 2026-09-28 设计 spec 成稿 → 仍「开放」（未合入 / 未关票）
links:
  jira: https://issues.labcollab.net/browse/WATERTON-1049
  design_doc: https://chorus.aws.dev/doc/SjhwsXSQpLtb/Waterton-blank-frame-mitigation-design （Chorus）
  cr_or_gerrit: 暂无（实现未开始）；参考 Gerrit 2157267 曾整体关闭 with_metrics
  related:
    - WATERTON-962：父任务，三支柱（metric / block-write / log-push），本票 = metric 支柱；交付本指标不关闭 962
    - WATERTON-842：Epic「Black screen monitoring and management plan」
    - WATERTON-745：AAD 路径插桩，本票检测点复用其 instrumentation
    - WATERTON-381：AAD 路径已知问题（与检测范围相关）
    - PROJVEGA-363534：with_metrics 内存回归，本设计中延后处理（deferred）
---

> **说明（阅读前）**：本票为**设计任务**（非 bug 排障），当前 JIRA 仍「开放」、实现未合入。本卡片按「案例总结模板」改编：bug 模板里的「排查过程」在此为**设计决策 / 开放问题收敛**过程。内容依据 `.kiro/specs/rgb-gain-violation-metrics/`（requirements / design / tasks）与 JIRA 票面重建；**本人口述的真实决策路径、量化影响、Lessons 定稿**均需本人补正。每条结论已标注【实机验证】/【推断】/【设计决策】/【待确认】。

## 现象 (Symptom)

- **观察到的问题**：Waterton Echo 的 Picture Quality（PQ）服务逐帧计算 RGB gain，在某些条件下会算出**非法增益**：(a) 增益值为 0，或 (b) 增益对应的色温（CCT）落在允许范围 `[1667, 25000]` 之外。结果是显示输出错误（画面异常 / 黑屏类）。
- **关键缺口**：现场发生此类事件时，**没有任何字段信号**可与客诉关联——无法判断某台设备是否真的发生、发生过多少次。本票要补的就是这个可观测性缺口。
- **触发条件（与根因分开）**：三通道增益全为 0；或 `displayCCT < 1667` / `> 25000`。均发生在 AAD 路径、PQ 逐帧计算时。AAD 主循环约每 17 ms（每 4 帧刷新）一次，持续性故障下一秒可触发数十至数百次。
- **测试钩子**：`amazonpq-test --setRGBGains 0 0 0` 可注入 gain=0。【实机验证，JIRA P2.5】
- **影响范围**：Waterton（本票范围）；picturequality 源为全 Echo 共享。
- **现场复现率 / 发生频次**：待确认（无量化数据）。

## 排查过程 (Investigation)

> 本票无 bug 实机复现叙述；以下为**设计决策 / 开放问题收敛**路径，真实决策顺序请本人校订。

1. **证伪复用旧指标**：现有 `BlackFrameMetrics`（基于 CRC）不可复用——它在 CCORR **上游**采样，且**实机验证「增益为 0 不改变 CRC」**，抓不到 zero-gain。结论：需新建 gain-aware 检测点。【实机验证】
2. **选检测点**：JIRA 初始建议 `amazonpq.cpp:847`（AAD 与 MWS 两路汇合，票面注明 "needs confirmation"）。设计最终选 `AAD::getRGBgains()` 的 DIAG-BLACKSCREEN 探针（`AAD.cpp` ~line 692，复用 WATERTON-745 插桩），理由是此处**同一帧**的最终增益（`rarr[0][0]/[1][1]/[2][2]`）与 committed `displayCCT` 可**原子获得**；范围限 AAD 路径（`SourcePath=0`），MWS / 最终写 `amazonpq.cpp:847` 的 zero-gain 检查列为可选 / 延后。【设计决策；偏离票面初始建议】
3. **分类标准与顺序**：先判 zero-gain（三通道全 0 → `ZERO_GAIN`）；否则在 `!isLastFrame_disabled` 时按 `displayCCT` 判 `CCT_BELOW_MIN(<1667)` / `CCT_ABOVE_MAX(>25000)`；当 `isLastFrame_disabled` 把增益强制为中性 `GAIN(4096)` 时**跳过 CCT 判定**以避免误报。CCT 边界取自 `AAD.h`。
4. **字段集（Minerva schema 的输入）**：7 字段 `EventTime / ViolationType / RGain / GGain / BGain / DerivedCct / SourcePath`；`DerivedCct` 恒等于实际 `displayCCT`（与分类无关）；**设备身份不作字段**，经 ACE Minerva 预定义键 `ACE_MINERVA_PREDEFINED_DEVICE_ID` 携带 DSN。
5. **跨库桥接 + 共享状态归属（票面 P1.5「核心难点」）**：检测在 `libamazonpq`，指标库只链入服务可执行文件。设计用**独立共享队列单例 `RgbGainViolationQueue`** 解耦 writer / reader；7 字段快照含 string，单个 `std::atomic` 装不下，故 writer 在**短锁**下 push 一个快照，reader 侧 `collectData` 每轮 `drain()` 全部弹出。
6. **异步 record-then-emit**：AAD 帧线程（~17 ms）**只 push、不 emit**；排放交给 `ReportStats` worker（`collectData` drain）+ `MetricTimer`（`handleTimer` 计 event 数）。【线程归属：design 标注 verified】
7. **flood / dedup 与节奏（票面 P1.6「dedup mandatory」、P1.4 偏向 immediate-emit）**：设计改为**不去重、捕获每个事件**，靠 drain + 「≥20 事件 或 120s」批量触发自然限幅，**复用完整 `ReportStats` / `MetricTimer` / `MetricCacher` 管线**；由此带回的内存开销（PROJVEGA-363534）**延后处理**。【偏离票面：票面将 dedup 列为 mandatory、内存列为 prerequisite；本设计未去重且将内存延后 —— 需向 stakeholder 确认认可】
8. **跨设备泄漏防护（新增正确性约束）**：`push` 在「`RgbGainViolationMetrics` consumer 注册前」为 **no-op**（consumer 在 `init()` 注册）。避免别的设备仅为别的指标开 `with_metrics` 时，共享源的 push 照跑而无人 drain，导致共享队列只进不出、无界增长。
9. **单 conf / 单指标限制（票面 P2.4）**：`ReportStats` 只加载首个 `*.conf`、只实例化一个指标。**经验证** Waterton 只装 `RgbGainViolationStats.conf`（不装 `BlackFrameStats.conf`）→ 唯一选中 `RgbGainViolationMetrics`。【verified】
10. **构建范围（票面 P2.3）**：`with_metrics` 为 meson 选项（默认 false）→ 置真时加全局 `-DWITH_METRICS` 并编译 `subdir('metric')`；**仅** Waterton `picturequality.bbappend` 开启；共享源 `AAD.cpp` 的检测块用 `#ifdef WITH_METRICS` 包裹。参考 Gerrit 2157267 曾整体关闭 `with_metrics`。

**被排除 / 推翻项**：复用 `BlackFrameMetrics`（CRC）被实机证伪；票面「immediate-emit + 强制 dedup」方向被改为「批量 + 不去重」（此改动需确认）。

## 根因 (Root Cause)

- **本票定位的是「可观测性缺口」根因**：现有指标（`BlackFrameMetrics` / CRC）在 CCORR 上游采样且对 zero-gain 不敏感（**实机验证 CRC 不变**），因此现场非法增益事件没有任何可与客诉关联的信号。【实机验证】
- **illegal gain 本身的产生根因 / 次因**：待确认（**本票范围外**，属 WATERTON-962 的 block-write 等 pillar）。
- **触发条件（与根因分开）**：三通道增益全 0；或 `displayCCT` 越界 `[1667, 25000]`；均在 AAD 路径、PQ 逐帧计算时出现。

## 解决方法 (Fix)

- **性质**：检测 / 可观测性**设计**，非根治、非 mitigation。
- **交付物**：spec 三件套（requirements / design / tasks）+ 已创建的 `RgbGainViolationStats.conf`（位于 `meta-vega-waterton/recipes-display/picturequality/files/`）。实现拆为 **4 个 review-sized stacked patches**（见 `tasks.md`：P1 声明共享类型与指标类 / P2 声明共享队列接口 / P3 实现队列+检测分类+框架接线 / P4 构建打包与实机验证），**当前全部未勾选（未开工）**。
- **核心设计要点**：
  - 检测点 `AAD::getRGBgains()` ~line 692，AAD 路径（`SourcePath=0`），同帧原子取增益与 `displayCCT`。
  - 分类：zero-gain 优先 → CCT 越界；`isLastFrame_disabled` 跳过 CCT。
  - 7 字段指标；DSN 经 `ACE_MINERVA_PREDEFINED_DEVICE_ID` 预定义键携带，不作字段。
  - 异步 record-then-emit：帧线程只 push 到独立共享队列单例；`collectData` drain all、`handleTimer` 计 event；「≥20 事件 或 120s」触发 emit。
  - no-consumer 安全门控；`#ifdef WITH_METRICS` 守卫；仅 Waterton 启用、仅装一个 conf。
  - 对 `BaseMetric` 接口零改动；三处框架改动（drain 循环、按 event 计数、新增共享队列模块）向后兼容 `BlackFrameMetrics`。
- **合入 / 版本**：无 CR、未合入；JIRA 开放。
- **评审遗留 open questions**：
  - 申请**真实 Minerva `GroupId` / `SchemaId`**（当前复用 BlackFrame 占位符 → 端到端无法真正验证，记录会被拒或错挂 BlackFrame 看板）。
  - **内存预算（PROJVEGA-363534）延后** —— 与票面「prerequisite」定位不一致，需确认。
  - 共享队列模块**放置与跨库链接方式延后**（deferred）。
  - **已接受残余风险**：emit 管线卡住时队列无硬上限、可能无界增长。
  - MWS 路径 / `amazonpq.cpp:847` 的 zero-gain 检查未纳入（可选 / 延后）。

## 影响 (Impact)

- **打通能力**：一旦实现并接入真实 schema，PQ 每次算出非法 RGB gain 时将发出一条**携带 DSN** 的 ACE Minerva 指标，使现场显示故障可与具体设备、进而与客诉关联（当前为零字段信号）。
- **对其他 Echo 设备零影响**（设计层面）：`with_metrics` 默认 false + `#ifdef` 守卫 + no-consumer 门控 + 单 conf 仅 Waterton 安装；框架改动向后兼容 `BlackFrameMetrics`。
- **量化数据**（现场事件数 / 受影响设备数 / 内存回归大小 / 是否发布门）：待确认（无数据来源）。
- **下游使用**：作为 WATERTON-962 三支柱之一，与 block-write、log-push 并行；**交付本指标不关闭 962**。

## Lessons Learned

> agent 起草，待本人定稿。

- 复用既有指标前先**实机证伪其敏感性**（CRC 对 zero-gain 不敏感的教训）：别假设旧探针能覆盖新故障。
- 跨库共享状态优先用**独立单例 + 短锁快照**，而非往稳定接口（`BaseMetric`）里塞，保持 writer / reader 解耦。
- 共享源 + 多设备场景下，**编译开关（`WITH_METRICS`）不足以防泄漏**，需运行期「consumer 注册才生效」的门控。
- 当票面把某约束列为 mandatory / prerequisite（此处 dedup / 内存）而设计要改变方向时，应**显式回到 stakeholder 确认**，别让偏离隐入实现。
- 热路径（~17 ms 帧线程）只做**最小记录**，排放移出环外。

## 简历要点 (Resume)

> 已脱敏（代号 → "Amazon Echo smart-display device"；无 JIRA / CR / 内部系统名 / 未发布信息）。STAR，1-2 句，中英各一供取用。

- **中文**：为一款 Amazon Echo 智能屏设备设计并规划了一套显示异常（非法图像增益 / 色温越界）的端到端可观测性指标方案——在约 17 ms 的帧热路径上只做最短的无锁记录、经独立共享队列异步批量上报到遥测后端并携带设备序列号，使现场显示故障首次可与客诉关联；同时以运行期消费者门控避免共享源在多设备间的遥测泄漏。
- **English**: Designed and planned an end-to-end display-anomaly telemetry metric (illegal image gain / out-of-range color temperature) for an Amazon Echo smart-display device, keeping the ~17 ms frame hot-path to a minimal lock-free record-only push and draining asynchronously to the telemetry backend with a per-device serial, so field display faults could be correlated with customer tickets for the first time; added a runtime consumer-gate to prevent telemetry leakage across devices sharing the same source.
