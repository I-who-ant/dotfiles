# AI Test Hardening Master Plan

`status: completed`

## Summary

当前 AI runtime 的测试已经不是“薄弱”，而是进入了第二类问题：

- 覆盖已经不算少
- 真实 bug 也在持续被补回归
- 但结构仍然过于集中
- 测试意图、风险矩阵、拆分顺序、真实调用回归策略还没有正式成文

这份计划的目标不是立刻重写测试体系，而是把后续测试完善变成一条可执行路线：

1. 先把测试资产的边界讲清楚
2. 再把 helper / 文件结构拆出来
3. 再按风险优先级补足真实体验回归
4. 最后让 calibration 发现的问题能稳定沉淀成 ERT

一句话：

```text
后面不是“多写一点测试”，而是把测试体系做成可持续进化的基础设施。
```

## Current State

截至 2026-05-19：

- 聚合入口：
  - [`run-all-tests.el`](/home/seeback/.emacs.rc/ai/tests/run-all-tests.el)
- 当前规模：
  - 全量 `157` ERT
  - 已覆盖 ask / complete / rewrite / panel / inspector / trace / replay / prompt diagnostics
- 当前优点：
  - 能快速补单点回归
  - 全量跑通成本低
  - 真实 bug 已经能沉淀回 ERT
- 当前问题：
  - 用例全堆在一个文件
  - helper 与领域用例混在一起
  - “按领域查找”与“按风险查找”都不够顺
  - 后续继续补 race / style / calibration 回归会越来越重

## Objectives

这轮测试 hardening 固定只做 5 件事：

1. 把测试结构正式分层
2. 把 helper/fake/stub 基建独立出来
3. 把 complete 的真实体验回归做成正式测试矩阵
4. 把 calibration 问题沉淀成标准补测流程
5. 保持现有全量 ERT 与 load gate 不退化

默认不做：

- 不引入复杂测试框架
- 不把测试跑法切成外部脚本系统
- 不追求一次性拆完所有现有测试
- 不在这轮里构建网络真调用自动化

## Why Now

现在开始做测试规划，而不是继续裸加用例，原因很直接：

- runtime 已进入“体验 hardening”阶段
- 这类阶段产生的 bug 更多是：
  - 状态串值
  - stale/fresh 交互别扭
  - style hint 丢失
  - company/LSP/yas 协作回归
  - panel / inspector 可解释性退化
- 如果没有正式测试结构，新增回归会越来越像：
  - 临时插一条测试
  - 过几天再插一条
  - 最后没人记得哪类风险覆盖了，哪类没覆盖

## Construction Order

固定施工顺序如下：

1. `01` 测试资产盘点与分组规划
2. `02` helper / fake / stub 抽离
3. `03` complete 主战场拆分
4. `04` 真实体验回归矩阵补足
5. `05` ask / rewrite / UI 收口
6. `06` calibration -> regression 工作流定稿

不跳步。

## Dependency Rules

依赖关系固定如下：

- `01` 是所有后续步骤的硬前置
- `02` 是 `03~06` 的硬前置
- `03` 先于 `04/05`
  - 因为 complete 是当前测试最活跃、最重的主战场
- `04` 与 `05` 可以部分并行，但默认先做 `04`
- `06` 最后做
  - 因为要建立在新结构和新增矩阵都落地之后

简单图：

`01 -> 02 -> 03 -> 04 -> 06`

`03 -> 05 -> 06`

## Phase 01: Inventory And Coverage Map

### Goal

把「测试 → 元数据」的映射做成 single source of truth：标签写在 `ert-deftest` 的 `:tags` 里，coverage-map 由扫描器派生。完成后任何关于「这条测试属于哪个域 / 哪个风险 / 优先级多少」的问题都从代码本体回答，markdown 表格仅作为 auto-generated 派生物存在。

### Design Principle

- **元数据写在代码里**，文档只引用代码派生物
- 任何「测试 → 标签」的映射必须有唯一来源
- 派生物（coverage-map / weakness-map）每次 phase 关单前由生成器刷新

### Work

按三个 namespace 给每条 `ert-deftest` 加 `:tags`：

- `domain/<name>` 必填 1 个：
  - action-request / ask / complete-state / complete-trigger / complete-cooldown / complete-followup / complete-context / complete-language-rules / complete-observe / complete-coordination / rewrite / ui-panel / ui-inspector / replay / toggle / describe / meta
- `risk/<name>` 可多选：
  - race / coordination / stale-cache / style / source-consistency / protocol / observability / supersede / accept-intent / cache-hit
- `prio/<1|2|3>` 必填 1 个：
  - prio/3 ≈ ⭐⭐⭐ / prio/2 ≈ ⭐⭐ / prio/1 ≈ ⭐

配套工程：

- `tests/tools/coverage-extract.el` 扫描器（含 `rc/test-collect-tagged-tests` / `rc/test-generate-coverage-map` / `rc/test-find-weakness`）
- `rc/lint-all-tests-have-tags` 作为 ERT 自检（无 :tags 的测试将 fail 全量）
- `tests/generated/coverage-map.md` + `tests/generated/weakness-map.md`（auto-generated）
- 顶层 `tests/README.md` 加「按 tag 跑测试」命令清单

### Acceptance

- 全量 ERT 含 lint 全绿，每条 ert-deftest 都有合法 :tags
- 「某类 bug 应该补到哪组测试」由 `(ert-select-tests '(tag domain/X) t)` 回答
- 「现在最薄的是哪一层」由 `weakness-map.md`（auto-generated）回答
- 派生物不允许手工修改，文件头标 `Auto-generated. Do not edit.`

## Phase 02: Helper Extraction

### Goal

把测试基建从领域断言里抽出来。

### Target Files

- 新建：
  - `tests/helpers/ai-test-helpers.el`
- 抽离内容：
  - `rc/test-gptel-ensure-autocomplete`
  - `rc/test-gptel-reset-runtime`
  - `rc/test-gptel-reset-observe-global`
  - `rc/test-gptel-visible-completion`
  - `rc/test-gptel-last-lifecycle-event`
  - `rc/test-gptel-last-end-reason`
  - `rc/test-gptel-stub-request-context`

### Benefits

- 新测试文件更短
- helper 改动不再污染领域 diff
- 真实 bug 回归更容易快速写

### Acceptance

- 主测试文件顶部 helper 明显收缩
- 至少一个拆出的测试文件复用 helper 成功
- 全量 ERT 仍全绿

## Phase 03: Complete Domain Split

### Goal

先拆最重、最容易继续增长的 complete 测试。

### Recommended Split

按 `Locked Decisions` 抉择 1 与抉择 2，complete 拆为 6 个领域子文件 + 1 个 stub-integration 文件：

- `ai-complete-state-test.el`
  - normalization
  - lifecycle
  - supersede
  - timeout
  - cache basic
- `ai-complete-trigger-test.el`
  - auto trigger
  - source event
- `ai-complete-cooldown-test.el`
  - cooldown bucket / decay
  - accept-intent / policy
- `ai-complete-followup-test.el`
  - continuation chain
  - followup-ready / followup-delay
- `ai-complete-context-test.el`
  - prompt diagnostics
  - context budget
  - style hint
  - local formatting inheritance
- `ai-complete-language-rules-test.el`
  - C/C++
  - Python
  - Java
  - JS/TS
  - Elisp
- `ai-complete-observe-test.el`
  - stats
  - trace
  - replay summary
- `ai-complete-coordination-test.el` ★ stub-integration 层
  - company / yas / capf / lsp 协作
  - race / late response / timer 重入
  - timeout 后 late response 不复活

★ coordination-test 与 trigger / cooldown / followup 三个文件对齐了 runtime 同期拆分（`trigger.el` / `cooldown-rc.el` / `followup-rc.el`），不允许混入彼此用例。

### Rules

- 不要求一轮把旧文件清空
- 采用“迁一组，跑一次”的方式
- 每迁一组，旧文件中同主题内容同步删除

### Acceptance

- `ai-action-runtime-test.el` 不再继续膨胀成 complete 杂货铺
- complete 相关新增回归默认进入对应子文件

## Phase 04: Experience Regression Matrix

### Goal

把真实使用里最烦、最像产品问题的 bug，系统化成 ERT。

### Focus Areas

按 `Locked Decisions` 抉择 3，每条按 ⭐⭐⭐ / ⭐⭐ / ⭐ 评分驱动补测顺序。完整评分矩阵见 `exec-plans/completed/04-experience-regression-matrix.md`。

#### 04.1 Source/State Consistency

- ⭐⭐⭐ manual 请求不应串旧 trigger-source
- ⭐⭐ cache-refresh / followup / external source 标记应自洽
- ⭐⭐⭐ `followup-ready` / `next-action` / `visible` 关系应自洽

#### 04.2 Cache Perception

- ⭐⭐⭐ stale hit 是否立即 visible
- ⭐⭐⭐ stale -> fresh 替换是否平滑
- ⭐⭐ superseded cache late result 是否不会错误复活

#### 04.3 Formatting And Style

- ⭐⭐⭐ vertical spacing hint 能记录进 diagnostics
- ⭐⭐ 空行风格继承不被 budget 意外裁掉
- ⭐⭐ 语言规则 `:extra` 与 request-context style hint 不互相覆盖

#### 04.4 Editor Coordination

- ⭐⭐⭐ company active manual/auto 行为
- ⭐⭐⭐ yas active suppress
- ⭐⭐ org-src / read-only / TRAMP / minibuffer 行为
- ⭐⭐⭐ timer dedupe / timeout / late response

### Acceptance

- 新增的真实 bug 可以快速映射到固定矩阵中的某一格
- 体验类 bug 不再只靠临时插入一条测试解决

## Phase 05: Ask / Rewrite / UI Consolidation

### Goal

不要让 complete 一枝独大，而 ask / rewrite / UI 继续处于“顺手补一点”的状态。

### Work

- `ai-action-request-test.el`
  - shared request helper
  - success/failure/abort/supersede
- `ai-ask-runtime-test.el`
  - source fallback
  - snapshot fields
  - rollback
  - session/panel exposure
- `ai-rewrite-runtime-test.el`
  - meaningful snapshot
  - history filtering
  - state / result / region fields
- `ai-ui-panel-inspector-test.el`
  - panel labels
  - current snapshot priority
  - inspector shared sections
  - active snapshot rendering

### Acceptance

- ask / rewrite / UI 的新增回归也有清晰归属
- 统一观察层的产品回归不再挤在 complete 测试边上

## Phase 06: Calibration To Regression Workflow

### Goal

把“真实调用发现问题”变成标准测试工作流，而不是靠记忆。

### Workflow

1. 真实编辑复现
2. 导出 trace
3. 看 inspector / panel / prompt diagnostics
4. 提炼最小复现
5. 先补 ERT
6. 再修实现
7. 更新 calibration 文档中的对应案例

### Required Documentation

- [`docs/calibration-guide.md`](/home/seeback/.emacs.rc/ai/docs/calibration-guide.md)
  补“哪些情况必须落回测试”与归档 SOP
- [`tests/README.md`](/home/seeback/.emacs.rc/ai/tests/README.md)
  补“回归测试归档规则”
- [`docs/calibration-history/`](/home/seeback/.emacs.rc/ai/docs/calibration-history/)
  至少有 2 个真实 case 目录，证明 SOP 不是空壳

### Acceptance

- 后续任何一个真实 bug 都能沿这条链路落地
- 不再出现“修了，但没留下稳定回归”的情况
- 已有真实 case 可作为模板复用

## Phase 07: Multi-Language Live Calibration Wave

### Goal

在已经有 SOP 的前提下，真正把 `C++ / Python / Rust / TypeScript / Emacs Lisp` 跑出一轮真实 buffer 校准记录，而不是停留在“未来应该这样做”。

### Why It Is Separate

Phase 06 解决的是：

- 真实问题怎么归档
- 归档怎么回流 ERT

Phase 07 解决的是：

- 各语言真实使用里到底会踩什么
- 哪些是参数问题
- 哪些是 prompt/style 问题
- 哪些已经值得升格成 runtime / language-rule 变更

### Required Outputs

- 每门语言至少 1 份 calibration run 记录
- 每门语言至少 1 份 `summary.md`
- 每门语言至少 1 份 `stats.txt`
- 如遇稳定异常则补 ERT，否则明确写“本轮无 backflow”
- 一份 cross-language weekly summary

### Acceptance

- 不再只有 SOP，而是真有 5 门语言的落盘样本
- 可以回答“哪门语言当前最稳、哪门最容易误伤、哪类 blocked reason 最常见”
- 后续参数 / rule 调优有真实证据，不再纯靠体感

## Acceptance Gates

整轮测试 hardening 的总验收门固定为：

- helper 基建独立出来
- complete 至少拆成 3 个以上子测试文件
- 体验回归矩阵成文且开始落地
- calibration -> regression 流程成文
- 全量 ERT 全绿
- `~/.emacs.rc/ai-rc.el` load pass
- `~/.emacs` load pass

## Timeboxing

默认规模判断如下：

- `01`: 半晚
- `02`: 半晚到 1 晚
- `03`: 1~2 晚
- `04`: 1~2 晚
- `05`: 1 晚
- `06`: 半晚

重点不是快，而是每一步都能保持全量测试稳定。

## Regression Rhythm

每完成一个 phase，固定执行：

1. 跑全量 ERT
2. 过 `ai-rc.el` load gate
3. 过 `.emacs` load gate
4. 如果这一步影响 complete 行为：
   - 用真实编辑再做一轮最小 smoke
5. 再进入下一 phase

## Known Risks

- 如果先拆文件、后抽 helper，会导致重复劳动
- 如果不先定义边界，拆完之后仍会继续乱长
- 如果只拆结构、不补矩阵，测试仍然会“看起来整齐，实则漏关键体验”
- 如果 calibration 不回灌到测试，真实调用仍然只是一次次人工观察
- 如果 complete 拆分过细，反而会让阅读和运行成本上升

## Boundaries

- 这轮只做 AI runtime 自己的测试体系
- 不扩展到其他 Emacs 配置目录
- 不引入外部 CI 平台设计
- 不在这轮内做网络真调用自动化测试
- 真实调用校准仍主要由文档与人工工作流承担，ERT 负责沉淀最小复现

## Locked Decisions

以下决定在 `tests/exec-plans/completed/00-pre-flight-alignment.md` 中锁定，本轮 hardening 期间不再讨论。

### 拆分维度: 领域为主，风险作 section 标记

- 选定：A3 - 领域主目录 + 文件内 `;;;;` section 标记风险类型
- 理由：runtime 已按领域拆好，测试与 runtime 对齐找代码最快；风险维度通过 section 保留可见性
- 回退条件：若 section 标记后仍无法定位 race / coordination 类 bug，再退到纯风险维度拆分

### Mock / Stub / Real-call 三层分工

- 选定：在 ERT 内显式引入 stub-integration 层
  - 纯单元 mock → 状态机、协议、回归（当前已充分）
  - stub-integration → race / coordination / cooldown 时序（Phase 03 新建 `complete/ai-complete-coordination-test.el`）
  - real-call calibration → 手感、格式、节奏（按 `01-real-call-calibration-plan`）
- 回退条件：若 coordination 用例长期写不出新的真实回归，则合并回 trigger-test

### 优先级驱动方式

- 选定：C2 风险驱动主导，C3 真实 bug 驱动持续，C1 矩阵长期兜底
- 落地：Phase 04 体验矩阵 17 格每格标 ⭐ 风险评分，按 ⭐⭐⭐ → ⭐⭐ → ⭐ 顺序执行
- 回退条件：若 ⭐⭐⭐ 全部补完后仍频繁出现新 bug，转 C1 全格补足

### 失败回退与性能保护

- 选定：每 phase 打 git tag + 跟踪 ERT 运行时长
- Tag 命名：`tests-phase-NN-start` / `tests-phase-NN-done`
- 性能 baseline：147 用例 1.37s（2026-05-18 测得）
- 红线：单文件 > 500ms 触发再拆 / 全量 > 2.0s 触发性能调查

## Defaults

- 默认继续使用 ERT
- 默认保持“单命令全量跑通”能力
- 默认先拆 complete，再补 ask/rewrite/UI
- 默认任何新增真实 bug 回归都优先找已有子文件归属，而不是回塞总文件
