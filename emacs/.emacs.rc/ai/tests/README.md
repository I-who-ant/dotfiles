# AI Tests Plan

这份文档不是讲"怎么跑一次 ERT"，而是讲后面如何持续完善这套 AI runtime 的测试。

当前状态：

- 聚合入口：[`run-all-tests.el`](/home/seeback/.emacs.rc/ai/tests/run-all-tests.el)
- 工具：[`tools/coverage-extract.el`](/home/seeback/.emacs.rc/ai/tests/tools/coverage-extract.el) 扫描 `:tags` 生成派生物
- 派生物（auto-generated，勿手改）：
  - [`generated/coverage-map.md`](/home/seeback/.emacs.rc/ai/tests/generated/coverage-map.md)
  - [`generated/weakness-map.md`](/home/seeback/.emacs.rc/ai/tests/generated/weakness-map.md)
- 当前特点：
  - 覆盖面已经不小（157 ERT 含 lint）
  - complete / ask / rewrite / ui 已按领域拆分
  - 后续如果继续补体验回归、真实场景回归、语言规则回归，会越来越难找

一句话：

```text
现在不是"没有测试"，而是"测试规划需要成形"。
```

## 0. 跑测试

### 全量 ERT

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
  -f ert-run-tests-batch-and-exit
```

### 按 tag 跑

每个 `ert-deftest` 都带 `:tags`，可按 tag 过滤：

```bash
# 只跑 ⭐⭐⭐ 高风险 gate
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
  --eval '(ert-run-tests-batch-and-exit (quote (tag prio/3)))'

# 只跑 cooldown 域
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
  --eval '(ert-run-tests-batch-and-exit (quote (tag domain/complete-cooldown)))'

# 只跑 race 风险类
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
  --eval '(ert-run-tests-batch-and-exit (quote (tag risk/race)))'

# 组合：cooldown 域里的高风险
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
  --eval '(ert-run-tests-batch-and-exit (quote (and (tag domain/complete-cooldown) (tag prio/3))))'
```

### 重新生成 coverage-map 和 weakness-map

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
  --eval '(rc/test-generate-coverage-map)' \
  --eval '(rc/test-generate-weakness-map)'
```

每次 plan 收尾前重跑一次，让 PR diff 反映 coverage 变化。

## 0.5 Calibration 文档自动回填

Phase 07 之后，真实调用文档不要再整篇手写。

固定工作流：

1. scaffold
2. scripted probe
3. auto-fill
4. 人工只补 `Manual` 区

刷新命令：

```bash
emacs --batch \
  -l /home/seeback/.emacs.rc/ai/tests/tools/fill-calibration-summaries.el \
  --eval '(rc/test-calibration-fill-date "2026-05-20" "phase-07-wave-02")'
```

约定：

- `summary-<lang>-<scenario>.md`
- `phase-07-wave-XX-index.md`
- `weekly-summary.md`

都必须保留 `<!-- AUTO:BEGIN --> ... <!-- AUTO:END -->`。

自动脚本只更新这块；`Manual` 区里的主观结论、参数建议、backflow judgment 不应被覆盖。

### Tag 词表

定义在 [`tools/coverage-extract.el`](/home/seeback/.emacs.rc/ai/tests/tools/coverage-extract.el) 顶部：

- `domain/<name>` 必填 1 个：action-request / ask / complete-state / complete-trigger / complete-cooldown / complete-followup / complete-context / complete-language-rules / complete-observe / complete-coordination / rewrite / ui-panel / ui-inspector / replay / toggle / describe / meta
- `risk/<name>` 可多选：race / coordination / stale-cache / style / source-consistency / protocol / observability / supersede / accept-intent / cache-hit
- `prio/<N>` 必填 1 个：prio/3 ≈ ⭐⭐⭐ / prio/2 ≈ ⭐⭐ / prio/1 ≈ ⭐

`rc/lint-all-tests-have-tags` 是 ERT 自检：任何无合法 :tags 的测试都会让全量失败。

## 1. 测试目标

后续测试完善，固定围绕四层：

1. 领域正确性
   - ask / complete / rewrite 的状态与生命周期是否正确
2. 运行时协作
   - cache / cooldown / continuation / company / LSP / yas / org-src 是否协作正常
3. 体验回归
   - panel / inspector / prompt diagnostics / trace / replay 是否能解释行为
4. 真实调用校准支撑
   - 虽然 ERT 不直接证明“手感”，但要为手感问题补最小可复现回归

## 2. 现有大文件的职责

历史上 [`ai-action-runtime-test.el`](/home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el) 曾经承担这些测试：

- shared action request / lifecycle
- ask snapshot / rollback / source
- complete state normalization
- complete cache / stale / supersede / timeout
- complete trigger / cooldown / continuation
- complete prompt/context diagnostics
- complete language rules
- panel / inspector / replay / trace
- rewrite snapshot

这说明它已经接近“测试总汇编文件”，继续往里塞会变重。

## 3. 下一步推荐拆分结构

默认先规划，不急着一口气拆完。后面新增测试时优先按下面的边界新建文件。

建议目录形状：

```text
tests/
├── README.md
├── helpers/
│   └── ai-test-helpers.el
├── ai-action-request-test.el
├── ai-ask-runtime-test.el
├── ai-complete-state-test.el
├── ai-complete-trigger-test.el
├── ai-complete-observe-test.el
├── ai-complete-context-test.el
├── ai-complete-language-rules-test.el
├── ai-ui-panel-inspector-test.el
├── ai-rewrite-runtime-test.el
└── ai-integration-smoke-test.el
```

边界原则：

- `request/lifecycle` 一组
- `ask` 一组
- `complete state/cache/supersede` 一组
- `complete trigger/cooldown/continuation` 一组
- `prompt/context/style` 一组
- `language rules` 一组
- `UI/inspector/panel` 一组
- `rewrite` 一组

## 4. helpers 层该做什么

后面优先抽出一个 `helpers/ai-test-helpers.el`，把现在大文件顶部那些通用 helper 收进去：

- `rc/test-gptel-ensure-autocomplete`
- `rc/test-gptel-reset-runtime`
- `rc/test-gptel-reset-observe-global`
- `rc/test-gptel-visible-completion`
- `rc/test-gptel-last-lifecycle-event`
- `rc/test-gptel-last-end-reason`
- `rc/test-gptel-stub-request-context`

这样做的价值：

- 新测试文件不必重复抄 helper
- 每次改测试基建时，不用同时动一堆文件
- 真实 bug 回归测试会更容易写

## 5. 后续新增测试的优先级

> 与 master-plan Phase 04 的对应关系：
>
> | README 这里的 P 级 | master-plan 04.X focus area |
> | --- | --- |
> | P1 体验回归 | 04.1 Source/State Consistency + 04.2 Cache Perception |
> | P2 editor coordination / suppress / race | 04.4 Editor Coordination |
> | P3 prompt/context/style diagnostics | 04.3 Formatting And Style |
> | P4 ask / rewrite 产品层回归 | Phase 05 Ask / Rewrite / UI Consolidation |
>
> 实际 ⭐⭐⭐ 评分见 `exec-plans/completed/04-experience-regression-matrix.md` 的 Matrix 章节。

### P1. 继续补 complete 的真实体验回归

这类最值钱，因为最容易在真实使用里踩到。

优先补这些：

- 手动请求时 `request-source / trigger-source` 不串值
- stale cache 命中时是否立即 visible
- stale -> fresh 替换时是否平滑
- vertical spacing / blank line 风格继承
- `followup-ready` 与 `next-action` 是否自洽
- `current-visible-text` 与 remainder 是否一致

### P2. editor coordination / suppress / race

虽然 06 phase 已经落地，但这层最容易后面又回归。

优先补这些：

- company active 时 manual / auto 的 allow/deny
- yas active 时 auto suppress
- org-src context 标记正确
- read-only / minibuffer / TRAMP deny 正常
- timer 重入 / 乱序回包 / timeout 后 late response 丢弃

### P3. prompt/context/style diagnostics

这层现在刚刚开始有“局部风格继承”，后面必须补。

优先补这些：

- local formatting style 被记录进 diagnostics
- budget 裁剪不该把关键 style hint 全裁掉
- mode-specific `:extra` 与 request-context style hint 同时存在时不冲突
- prompt diagnostics 能解释“为什么这次变紧凑了”

### P4. ask / rewrite 的产品层回归

虽然当前主战场是 complete，但 ask / rewrite 也要跟上共享观察层。

优先补这些：

- ask snapshot 在 panel / inspector 中字段稳定
- ask source fallback 行为稳定
- rewrite meaningful snapshot 判定稳定
- rewrite history 只显示相关 rewrite request

## 6. 真正缺的测试矩阵

后面补测时，不要只按功能加，还要按“风险类型”看。

### 6.1 状态机矩阵

- requesting -> visible
- visible -> partial-accepted
- visible -> accepted
- visible -> ignored
- visible -> temporarily-diverged
- temporarily-diverged -> restored-after-delete
- superseded -> cache -> reused

### 6.2 来源矩阵

- manual
- auto
- followup
- cache-refresh
- post-jump-retrigger
- lsp-suggestions
- signature-help
- flymake-diagnostics

### 6.3 语言矩阵

至少持续盯这几类：

- C / C++
- Python
- Java / Java TS
- JS / TS
- Emacs Lisp

后面如果 Rust/Go 有定制规则，再加专门回归。

### 6.4 体验矩阵

- 空行风格
- 缩进风格
- next-edit / followup 节奏
- cache 命中体感
- cooldown 误伤
- panel / inspector 可解释性

## 7. 测试命名约定

后续统一保持：

```text
rc/gptel-<domain>-<behavior>-<expected-outcome>
```

例如：

- `rc/gptel-complete-sync-session-state-does-not-leak-trigger-source-into-manual`
- `rc/gptel-complete-request-context-detects-vertical-spacing-style`
- `rc/gptel-rewrite-snapshot-ignores-empty-buffer-locals`

原则：

- 名字里写出行为
- 名字里写出结果
- 不写模糊词，比如 `works` / `basic` / `handles`

## 8. 每次发现真实 bug 后怎么补测试

统一按这条链路走：

1. 先用真实编辑复现
2. 导一次 trace
3. 看 inspector / prompt diagnostics
4. 找到最小复现条件
5. 先补 ERT，再修实现
6. 修完后跑全量

补充硬约束：

- 每个真实 case 都要落到 `docs/calibration-history/YYYY-MM-DD/`
- 至少有 `summary.md` 与 `stats.txt`
- 如果没有原始 trace，就放一份标记为 `reconstructed` 的最小 transcript JSON
- 对应 ERT 前写 case 注释，例如：
  - `Calibration case: 2026-05-19 / complete-clear-indicator-001`

不要反过来：

- 先凭印象修
- 再事后补一个和原 bug 不完全对应的测试

## 9. 哪些情况应该新开测试文件

满足任意两条，就该考虑拆：

- 同一主题测试超过 15~20 条
- 需要独立 helper 或 fixture
- 阅读时已经必须靠搜索跳转
- 修改某一领域代码时，总要在大文件里来回翻

## 10. 当前建议的施工顺序

具体的施工顺序由 [`00-test-hardening-master-plan.md`](./00-test-hardening-master-plan.md) 的 6 个 Phase 与 [`exec-plans/completed/`](./exec-plans/completed/) 的归档 plan 描述，本文件不再单独维护一份顺序，避免与 master-plan 不一致。

入口：

- 总图：`00-test-hardening-master-plan.md` 的 `Construction Order` 与 `Dependency Rules`
- 当前状态：phase 00-06 已全部归档，后续新增工作默认从 `exec-plans/templates/execution-plan.md` 复制新 plan 再推进

## 11. 和 calibration 的关系

[`docs/calibration-guide.md`](/home/seeback/.emacs.rc/ai/docs/calibration-guide.md) 负责告诉你：

- 真实调用时该观察什么
- stats / trace / prompt diagnostics 怎么用
- 哪些现象说明参数该调

这份测试规划负责告诉你：

- 一旦真实调用发现了问题
- 应该怎样把它沉淀成稳定回归测试
- 多语言真实校准波次应该如何分阶段推进

一句话分工：

```text
calibration-guide 发现问题，
tests/README.md 负责把问题固化成长期约束。
```

## 12. calibration-history 归档规则

归档目录固定是：

```text
docs/calibration-history/YYYY-MM-DD/
├── summary.md
├── stats.txt
└── trace-<lang>-<scenario>-<seq>.json
```

约束：

- `summary.md` 写结论、语言、模型、是否回流 ERT
- `stats.txt` 写 `rc/gptel-stats` 摘要；如果不适用，明确写 `N/A`
- trace 文件优先保存真实导出；否则保存最小复现 transcript，并注明 `source: reconstructed`
- commit message 最好显式引用 calibration 日期，避免 case 和代码脱节

## 13. 当前下一步

测试 hardening 的 `00-06` 已经封单。下一步不是继续堆零散 ERT，而是执行：

- [07-multi-language-live-calibration-wave.md](/home/seeback/.emacs.rc/ai/tests/exec-plans/active/07-multi-language-live-calibration-wave.md)

这一步专门负责：

- `C++ / Python / Rust / TypeScript / Emacs Lisp` 的真实 buffer 校准
- 每语言 run log / stats / trace / summary
- 能回流的继续补 ERT，不能回流的也要明确归档原因

职责边界别读反：

- `Phase 06`
  - 是 calibration -> regression 的 SOP 封单
- `Phase 07`
  - 才是 5 门语言真实 buffer live run 的波次执行
- `不做真网络自动化`
  - 指不做无人值守、自动判分的 CI 式批跑
  - 不等于“不做真实调用”

当前已就位的 run pack：

- [language-run-summary.md](/home/seeback/.emacs.rc/ai/docs/calibration-history/templates/language-run-summary.md)
- [stats.txt](/home/seeback/.emacs.rc/ai/docs/calibration-history/templates/stats.txt)
- [weekly-summary.md](/home/seeback/.emacs.rc/ai/docs/calibration-history/templates/weekly-summary.md)
- [wave-index.md](/home/seeback/.emacs.rc/ai/docs/calibration-history/templates/wave-index.md)
- [create-calibration-run.el](/home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el)
- [live-calibration-driver.el](/home/seeback/.emacs.rc/ai/tests/tools/live-calibration-driver.el)
- [fill-calibration-summaries.el](/home/seeback/.emacs.rc/ai/tests/tools/fill-calibration-summaries.el)

可以直接脚手架一轮 run：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(rc/test-create-calibration-run "2026-05-20" "cpp" "general")'
```

也可以直接脚手架整轮 wave：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(rc/test-create-calibration-wave "2026-05-20" "phase-07-wave-02")'
```

如果要跑跨语言的真实 probe pack：

```bash
emacs --batch \
  -l /home/seeback/.emacs.rc/ai/tests/tools/live-calibration-driver.el \
  --eval '(rc/test-live-write-wave-02-common-pack "2026-05-20" 45.0)'
```

如果要跑语言特化 probe pack：

```bash
emacs --batch \
  -l /home/seeback/.emacs.rc/ai/tests/tools/live-calibration-driver.el \
  --eval '(let ((rc/test-calibration-allow-real-history-write t))
             (rc/test-live-write-wave-02-specialized-pack "2026-05-20" 45.0))'
```

如果要自动预填 markdown：

```bash
emacs --batch \
  -l /home/seeback/.emacs.rc/ai/tests/tools/fill-calibration-summaries.el \
  --eval '(let ((rc/test-calibration-allow-real-history-write t))
             (rc/test-calibration-fill-date "2026-05-20" "phase-07-wave-02"))'
```

如果某门语言的人工校准已经跑完，直接更新 manual 状态并刷新汇总：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(let ((rc/test-calibration-allow-real-history-write t))
             (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))'
```

这条命令会自动：

- 更新对应 summary 的 `manual-status`
- 写入 `manual-updated-at`
- 写入 `真实运行时长(分钟)`
- 刷新 `phase-07-wave-02-index.md`
- 刷新 `weekly-summary.md`

这一步会自动回填：

- `summary-<lang>-<scenario>.md`
- `phase-07-wave-XX-index.md`
- `weekly-summary.md`

安全边界：

- calibration 工具现在默认拒绝直写真实 `docs/calibration-history/`
- 只有显式绑定 `rc/test-calibration-allow-real-history-write` 为 `t`，或者设置环境变量 `AI_TEST_ALLOW_REAL_CALIBRATION_WRITE=1`，才允许写真实树
- 想先演练工具逻辑，应该把 `rc/test-calibration-history-root` 绑定到临时目录

如果只想看 Phase 07 当前还欠哪些人工校准：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(princ (rc/test-calibration-status-report "2026-05-20"))'
```

如果还想直接拿到“下一条该跑谁、跑完后怎么改状态”的命令队列：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(princ (rc/test-calibration-manual-command-queue "2026-05-20" "phase-07-wave-02"))'
```

如果只想盯某一门语言，直接出单语言 brief：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(princ (rc/test-calibration-manual-brief "2026-05-20" "ts" "phase-07-wave-02"))'
```

如果你想一次把所有 pending 语言的 brief 拉成一个工作台：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(princ (rc/test-calibration-manual-workbook "2026-05-20" "phase-07-wave-02"))'
```

如果你想直接拿到“可填写版”工作台模板：

```bash
emacs --batch -Q \
  -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
  --eval '(princ (rc/test-calibration-manual-workbook-template "2026-05-20" "phase-07-wave-02"))'
```

但不会替你自动判断：

- 手感是否顺手
- followup 是否烦人
- 空行风格是否贴近当前文件
- 是否应该回流成 ERT
