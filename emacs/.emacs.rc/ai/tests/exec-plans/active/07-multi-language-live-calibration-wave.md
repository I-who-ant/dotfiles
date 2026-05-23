# Multi-Language Live Calibration Wave

```yaml
status: in-progress
start-date: 2026-05-19
completion-date:
phase: 07
depends-on: [06-calibration-to-regression-workflow]
```

> **设计原则提醒**：这一 phase 的主交付不是“再写一批纸上 ERT”，而是把真实编辑中的多语言体验差异系统化采样、归档、回流。ERT 仍然重要，但必须由真实 case 反推，而不是凭想象扩表。

## Goal

完成后，`C++ / Python / Rust / TypeScript / Emacs Lisp` 这 5 门语言都至少有一轮真实 buffer 校准记录，且每门语言都能回答 4 件事：

1. 触发 / followup / cache / cooldown 的真实体感如何
2. 空行 / 缩进 / 局部风格继承是否贴近该语言实际代码
3. 观测工具（panel / inspector / stats / trace / prompt diagnostics）是否足以解释异常
4. 哪些问题应该继续回流成 ERT，哪些只是参数或 prompt 校准问题

一句话：

```text
Phase 06 解决“怎么回流”，Phase 07 解决“真实多语言到底发生了什么”。
```

## Scope

- In scope:
  - 选 5 门语言：`C++ / Python / Rust / TypeScript / Emacs Lisp`
  - 每门语言至少 1 个真实项目 / 真实 buffer / 30 分钟左右 calibration run
  - 每门语言固定覆盖 Common Scenario A~E
  - 每门语言至少产出：
    - `docs/calibration-history/YYYY-MM-DD/summary.md`
    - `docs/calibration-history/YYYY-MM-DD/stats.txt`
    - 如有异常则补 `trace-*.json`
  - 每门语言至少给出 1 个“是否需要回流 ERT”的明确判断
  - 对能稳定复现的问题，继续补最小 ERT
  - 汇总一份 cross-language weekly summary
- Out of scope:
  - 不做“无人值守 + 真网络 + 自动判分”的 CI 式批跑
  - 不在这一 phase 里直接重写 prompt / language rules / runtime 默认值
  - 不为了凑数给每门语言硬补 1 条 ERT；不能稳定复现就只归档，不造伪回归

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Post-Phase follow-up / Phase 07
  - `tests/01-real-call-calibration-plan.md`
  - `tests/02-language-test-matrix.md`
- 相关代码路径：
  - `docs/calibration-guide.md`
  - `docs/calibration-history/`
  - `tests/complete/*.el`
  - `tests/ui/*.el`
  - `tests/ask/*.el`
  - `tests/rewrite/*.el`
- 相关 plan：
  - `tests/exec-plans/completed/06-calibration-to-regression-workflow.md`
- 约束：
  - 全部真实 run 必须落盘，不接受“我记得大概怎样”
  - 这里的“真实 run”指人在真实 buffer 中实际使用，不是只生成模板或伪造 transcript
  - 不允许用玩具 buffer 代替真实语言项目
  - 每门语言只改 0~2 个参数；先观察再调
  - 如果某门语言没有稳定异常，也要写“本轮无 ERT backflow”

## Test Architecture

这一 phase 不是单靠一种测试形态完成，而是固定分 4 层：

1. `ERT / mock / stub-integration`
   - 解决确定性问题
   - 覆盖状态机、trace 连接点、policy / cooldown / accept / followup 等逻辑
2. `scripted real-call probe`
   - 解决“真实 provider + 真实文件 + 真实 prompt/context”是否跑得通
   - 负责自动采集 `stats / trace / prompt diagnostics / visible text`
   - 不负责给“手感”自动判分
   - probe 完成后，应由自动回填器生成 `summary / wave-index / weekly-summary` 的客观字段
3. `manual calibration run`
   - 解决真实编辑里的体感、节奏、格式、协作问题
   - 负责判断“顺不顺手”“烦不烦人”“空行是否被压扁”
4. `backflow`
   - 只把能稳定复现的问题压回 ERT
   - 不能稳定复现的 case 只归档，不造伪回归

一句话：

```text
ERT 保骨架，scripted probe 保真实链路，manual run 校准手感，backflow 负责沉淀。
```

## What Each Layer Can Prove

别再把这四层混着用。每层都只能证明自己那一小块：

| Layer | 能证明什么 | 不能证明什么 |
| --- | --- | --- |
| `ERT / mock / stub-integration` | 状态机、连接点、最小复现、回归门 | 真实写代码时顺不顺手 |
| `scripted real-call probe` | 真 provider / 真 prompt / 真文件链路跑通；artifact 可落盘 | 体验已经合格；默认参数已经合理 |
| `manual calibration run` | 节奏、手感、空行风格、协作干扰是否别扭 | 问题一定能稳定复现 |
| `backflow` | 已知 live 问题已沉淀成长期守门 | 所有体验问题都已经被量化 |

规则很简单：

- `probe` 负责“真实性证据”
- `manual` 负责“体验判断”
- `ERT` 负责“长期回归保护”

谁越权，结论就会假。

## Scripted Probe Contract

Phase 07 里的半自动真实调用工具，固定不是“迷你 CI”，而是采证器。

每个 probe case 最少包含这些字段：

- `language`
- `scenario`
- `project`
- `file`
- `snippet`
- `timeout`
- `accept-mode`
- `expected-observation-focus`

每次 probe 固定产出这些工件：

- `stats-<lang>-<scenario>.txt`
- `trace-<lang>-<scenario>-001.json`
- `probe-<lang>-<scenario>.el`
- `summary-<lang>-<scenario>.md` 先由 auto-fill 预填 `AUTO` 区，再由人工补 `Manual` 区

约束：

- `trace-*.json` 只保存可稳定序列化的观测层数据
- 完整 Emacs/Elisp 运行时对象保存在 `probe-*.el`
- scripted probe 可以证明“链路真跑过”，不能直接证明“手感已经合格”
- `summary / wave-index / weekly-summary` 的客观字段应尽量由脚本自动预填，不再手工搬运
- 自动脚本只允许更新 `<!-- AUTO:BEGIN --> ... <!-- AUTO:END -->`；人工 judgment 只能写在 `Manual` 区

## Scenario Taxonomy

不要把所有真实调用都堆到一个模糊的 `general` 里。

固定分两类：

1. 通用 scenario
   - `line-end-continuation`
   - `full-accept`
   - `word-accept`
   - `line-accept`
   - `cache-revisit`
   - `diverge-and-restore`
2. 语言特化 scenario
   - `cpp-tight-loop`
   - `python-indent-block`
   - `rust-borrowish-block`
   - `ts-object-literal`
   - `elisp-sexp-tail`

含义：

- 通用 scenario 用来横向比较 5 门语言
- 语言特化 scenario 用来定位语言规则缺口

Wave 01 允许先从 `general` 起步，但关单前至少要明确：

- 哪些 `general` 结果已经足够
- 哪些语言需要在 Wave 02 拆出特化 scenario

## Issue Classification

每次真实调用发现问题后，先分类，再决定要不要写代码：

1. `runtime bug`
   - 共享状态、事件流、snapshot、panel / inspector 行为错误
   - 处理：修 runtime，并补 ERT
2. `prompt/context bug`
   - prompt slice、style hint、budget、上下文拼接失真
   - 处理：改 prompt/context 规则；是否补 ERT 取决于是否有稳定输入输出条件
3. `language-rule gap`
   - 某语言局部风格、空行、缩进、触发点明显缺少定制规则
   - 处理：改 language rule，并补最小 ERT 或 context test
4. `parameter tuning issue`
   - cooldown 阈值、delay、chain-limit、profile 倾向不理想
   - 处理：先归档校准结论，不急着补 ERT
5. `manual-only feel issue`
   - 主观别扭，但暂时没有稳定最小复现
   - 处理：只写 summary，等多轮统计后再决定

禁止直接从“看着不爽”跳到“立刻补测试”。

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| 真正跑 5 门语言很耗时，容易半途而废 | 高 | 高 | 先按语言分里程碑，每门语言独立关账，允许分多天推进 |
| calibration 结果变成一堆口头印象 | 高 | 高 | 每门语言 run 后立即写 `summary.md` / `stats.txt`，不允许拖到最后 |
| 为了“有产出”强行造 ERT | 中 | 高 | 明确允许“归档但不回流 ERT”；不能稳定复现就别补伪回归 |
| Rust / Go 没有专门规则，容易把“通用路径保守”误判成 bug | 中 | 中 | Rust 本 phase 以 generic path 观察为主，先分“需要定制规则”还是“只是参数问题” |
| 多语言比较缺乏统一标准 | 中 | 中 | 每门语言都固定跑 Common Scenario A~E，并用同一份 summary 模板 |

## Milestones

1. **M1 - Run Pack & Summary Template**
   - 做什么：
     - 把多语言真实校准的统一模板写清楚
     - 固化每门语言的必跑场景、记录格式、结论结构
     - 在 `docs/calibration-guide.md` 或新附录里补一份 wave 专用模板
   - 验收：
     - 任意一门语言都能拿模板直接开跑，不靠维护者口述

2. **M2 - Systems Languages Wave**
   - 做什么：
     - 跑 `C++ / Rust`
     - 每门语言至少 1 轮真实 calibration
     - 重点看：触发、cache 体感、块间空行、followup 紧凑度
   - 验收：
     - 至少 2 份 `summary.md`
     - 至少 2 份 `stats.txt`
     - 如有稳定异常，补对应 ERT 或明确写“未回流”

3. **M3 - Scripting Languages Wave**
   - 做什么：
     - 跑 `Python / Emacs Lisp`
     - 重点看：缩进块、partial accept 后 remainder、sexp / block 续写顺滑度
   - 验收：
     - 至少 2 份 `summary.md`
     - 至少 2 份 `stats.txt`
     - 至少 1 个“观测工具是否解释得通”的结论

4. **M4 - Web / Typed Language Wave**
   - 做什么：
     - 跑 `TypeScript`
     - 重点看：`.` / `=>` / object literal / type-heavy context / concise 倾向
   - 验收：
     - 至少 1 份 `summary.md`
     - 至少 1 份 `stats.txt`
     - 明确判断 TS 类型上下文是在帮忙还是添乱

5. **M5 - Cross-Language Backflow & Summary**
   - 做什么：
     - 汇总 5 门语言结果
     - 能稳定复现的问题补回 ERT
     - 产出一份 weekly summary，比较哪些语言最稳、哪些误伤最多、哪些 blocked reason 最常见
   - 验收：
     - `docs/calibration-history/` 至少新增 5 份语言 run 记录
     - 至少 0~5 条真实 case ERT 回流（允许为 0，但必须有理由）
     - 文档里明确列出参数 / prompt / rule / runtime 四类后续动作建议

6. **M6 - 关单 + done tag**
   - 做什么：
     - 跑全量 ERT
     - `git tag tests-phase-07-done`
     - 把本 plan 从 `active/` 归档到 `completed/`
   - 验收：
     - tag 存在
     - active/ 恢复为空

## Validation

- Commands:
  ```bash
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
    -f ert-run-tests-batch-and-exit
  ```
  ```bash
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
    --eval '(princ (rc/test-calibration-status-report "2026-05-20" "phase-07-wave-02"))'
  ```
  ```bash
  find /home/seeback/.emacs.rc/ai/docs/calibration-history -mindepth 1 -maxdepth 2 -type f | sort
  ```
- 手动检查:
  - 每门语言至少完成 1 次真实 buffer 使用，覆盖 Common Scenario A~E
  - 每门语言 run 后立刻打开 `C-c a i` / `C-c a o` / `M-x rc/gptel-stats`
- 分层验收:
  - `scripted probe completed`
    - 5 门语言都有 artifact
    - 每门语言至少能证明 request 实际发出且链路跑通
  - `manual calibration completed`
    - 5 门语言的 specialized summary 都从 `manual-status: pending` 推进到 `partial|completed`
    - 5 门语言都有人工 summary
    - 每门语言都至少有 1 条“是否 backflow”的明确判断
    - 每门语言都至少填写：
      - `总体顺手程度（1-5）`
      - `最大优点`
      - `最大问题`
      - `建议调的参数`
      - `建议新增测试`
  - `phase completed`
    - scripted probe 与 manual calibration 都完成
    - 能稳定复现的问题已回流成 ERT，不能稳定复现的问题已明确归档
- 观察工具:
  - `C-c a i`
  - `C-c a o`
  - `M-x rc/gptel-stats`
  - `M-x rc/gptel-export-recent-ai-trace`
  - `M-x rc/gptel-replay-ai-trace`
  - `M-x rc/gptel-describe-current-complete-prompt`

## Performance Budget

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | 0.40s / 157 用例 | 2.0s | 0.52s / 176 用例 |
| 单语言 calibration 记录整理 | 30 min | 45 min | |
| ai-rc.el load | 已绿 | 1.0s | |

## Progress Log

- [x] M1 Run Pack & Summary Template
- [x] Wave 01 scripted probes for `cpp / python / rust / ts / elisp`
- [x] Wave 02 common scenario scaffold for `line-end-continuation / full-accept / cache-revisit / diverge-and-restore / coordination`
- [x] Wave 02 specialized scenario scaffold for `cpp-tight-loop / python-indent-block / rust-borrowish-block / ts-object-literal / elisp-sexp-tail`
- [x] Wave 02 line-end scripted probes for `cpp / python / rust / ts / elisp`
- [x] Wave 02 `full-accept / cache-revisit / diverge-and-restore / coordination` scripted probes for `cpp / python / rust / ts / elisp`
- [x] manual calibration status 自动汇总已接通（`manual-status / manual-updated-at / 真实运行时长` -> `wave-index / weekly-summary`）
- [x] calibration 工具默认真实树写保护已接通（需显式允许才写 `docs/calibration-history/`）
- [x] manual pending 状态报告命令已接通（`rc/test-calibration-status-report`）
- [ ] M2 Systems Languages Wave
- [ ] M3 Scripting Languages Wave
- [ ] M4 Web / Typed Language Wave
- [ ] M5 Cross-Language Backflow & Summary
- [ ] M6 done tag
- [x] 全量 ERT 全绿
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-19: Phase 07 单独立项，而不是把“多语言真实使用波次”硬塞进 Phase 06；因为 Phase 06 的目标是流程闭环，不是语言覆盖闭环。
- 2026-05-19: M1 先落 `templates/`，而不是把模板散写在 guide 中间；因为后面真实跑波次时，直接复制文件比从长文里抠片段更稳。
- 2026-05-19: Wave 01 的默认目标文件先固定为 `tool_runtime.cpp / runtime.py / session.rs / WebFetchTool.ts / ai-complete-state-rc.el`，优先保证跨语言样本可比较，而不是每轮都临时换文件。
- 2026-05-19: 先补 scripted probe，再补 manual calibration；因为当前最缺的是“真实 provider 证据”，不是主观结论模板。
- 2026-05-19: scripted probe 的 wave wrapper 改成“每门语言单独起 Emacs 子进程”；因为同进程批量跑会让后一个 probe 污染前一个仍在飞的请求，制造假 superseded。
- 2026-05-19: TypeScript 先接 `js-mode` fallback，而不是硬绑 `typescript-ts-mode`；因为当前机器没有 TypeScript grammar，也没有 classic `typescript-mode` 包，先保证 `.ts` 至少进入 `prog-mode`。
- 2026-05-19: Wave 02 先做 common scenario pack 脚手架，再只真实跑 `line-end-continuation`；因为当前缺的不是更多空模板，而是“跨语言同一 scenario 的真实链路基线”。
- 2026-05-19: Rust 在 Wave 02 批跑里出现过一次 timeout，但 20s 单独复跑同 case 成功；因此先归类为偶发链路抖动，不把它草率升级成 runtime bug。
- 2026-05-19: calibration 文档改为 `AUTO/MANUAL` 分区；因为整文件 auto-fill 会覆盖人工体验判断，而整文件手填又太蠢太重。
- 2026-05-20: Wave 02 的语言特化 scenario 先统一生成空白 `summary-<lang>-<scenario>.md` 脚手架，再由人工把 `manual-status` 从 `pending` 往前推进；因为 Phase 07 当前真正缺的是“真实人工校准进度的可见性”，不是继续凭空补 scripted artifact。
- 2026-05-20: manual calibration 进度不再手写到 wave summary，而是让脚本从 summary 里的 `manual-status / manual-updated-at / 真实运行时长(分钟)` 自动读回；因为这几项是事实字段，应该机器汇总而不是人工搬运。
- 2026-05-21: calibration 工具默认拒绝直写真实 `docs/calibration-history/`，只有显式绑定 `rc/test-calibration-allow-real-history-write` 或环境变量放行时才允许写；因为这套工具既服务真实波次，也服务本地测试，默认直写真实树风险太高。
- 2026-05-21: Phase 07 的真正阻塞点不再是 scripted artifact，而是 5 门语言 specialized manual calibration 尚未开始；因此关单标准明确收紧到 `manual-status 5/5 completed 或至少进入 partial 并有最终 backflow judgement` 之后才允许讨论 completed。

## Completion Snapshot

> 关单时填写，写完才能从 `active/` 移到 `completed/`。

- 实际做了：
- 2026-05-20 当前增量：
  - Wave 02 的 5 个语言特化 scenario 脚手架已落到 `docs/calibration-history/2026-05-20/`
  - `phase-07-wave-02-index.md` 已开始自动显示 `manual calibration 0/5 completed / pending=5`
  - `weekly-summary.md` 已开始自动显示 `manual calibration 进度 / pending`
  - 全量 ERT 已更新验证为 `176/176`
- 2026-05-21 当前增量：
  - calibration 工具已加真实树写保护，默认不会再误写 live history
  - 已新增 `rc/test-calibration-status-report`，可以直接打印 specialized manual calibration 进度
  - 全量 ERT 已更新验证为 `182/182`
- 与原计划差异：
- 先把 `manual calibration` 的状态骨架补齐，再继续真实人工跑语言特化 case；因为如果没有这层自动统计，后面跑了多少也会继续散落在 summary 里，看不出整体进度。
- 遗留小尾巴：
- 5 门语言的语言特化 scenario 仍全部是 `manual-pending`
- M2 / M3 / M4 / M5 还没有因为真实人工校准而进入 completed
- 已记入 tech-debt：
- 暂无新增代码债；当前缺的是人工校准执行，不是新的实现债
- 下游 plan 解锁：真实多语言校准进入持续节奏，后续可以再开 Phase 08 参数 / 规则调优。

## Manual Specialized Run Checklist

关单前，5 门语言都必须各自走完一次下面这条链，不允许只改 `manual-status`：

1. 在真实任务 buffer 里至少连续使用 20~30 分钟
2. 至少覆盖一次：
   - `line-end-continuation`
   - `full-accept` 或 `partial accept`
   - `cache-revisit`
   - `diverge-and-restore`
   - `coordination`
3. 至少导出并查看一次：
   - `C-c a i`
   - `C-c a o`
   - `M-x rc/gptel-stats`
   - `M-x rc/gptel-export-recent-ai-trace`
4. 回填对应 specialized summary 的 Manual 区
5. 运行：
   ```bash
   emacs --batch -Q \
     -l /home/seeback/.emacs.rc/ai/tests/tools/create-calibration-run.el \
     --eval '(let ((rc/test-calibration-allow-real-history-write t))
                (rc/test-update-calibration-manual-status "2026-05-20" "cpp" "completed" 31))'
   ```
6. 再运行状态报告，确认 wave 汇总已变化

当前未完成事实（2026-05-21）：

- `cpp / python / rust / ts / elisp` 的 specialized manual calibration 仍然全部 `pending`
- 因此 Phase 07 绝不能宣称 completed
- 逐语言执行清单见：
  - [phase-07-specialized-manual-checklist.md](/home/seeback/.emacs.rc/ai/docs/phase-07-specialized-manual-checklist.md:1)
