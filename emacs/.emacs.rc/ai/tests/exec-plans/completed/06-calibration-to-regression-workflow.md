# Calibration To Regression Workflow

```yaml
status: completed
start-date: 2026-05-19
completion-date: 2026-05-19
phase: 06
depends-on: [04-experience-regression-matrix, 05-ask-rewrite-ui-consolidation]
```

## Goal

把「真实调用发现问题 → 沉淀回 ERT」的过程从「靠记忆」变成「有 SOP 的工作流」。完成后任何一个真实 bug 都能沿同一条链路落地，calibration 不再只是手工观察。

## Scope

- In scope:
  - 落实 `01-real-call-calibration-plan` 中需要的 cadence / archiving / checklist
  - 把 SOP 写入 `docs/calibration-guide.md`（必要时新建）
  - 把回流测试规则写入 `tests/exec-plans/README.md` 与 master-plan
  - 用 2 个真实 bug 案例完整走一遍 SOP，作为模板
- Out of scope:
  - 不做真网络自动化
  - 不补 04 / 05 phase 已识别的固定矩阵格子
  - 不引入外部 CI

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase 06 Calibration To Regression Workflow
  - `tests/01-real-call-calibration-plan.md`
- 相关代码路径：
  - `docs/calibration-guide.md`（待建或扩充）
- 相关 plan：
  - 依赖 `04-experience-regression-matrix` 与 `05-ask-rewrite-ui-consolidation` 完成
- 约束：
  - 全部产物都应能在不联网的情况下回看（trace 文件、stats 摘要必须落到磁盘）

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| 真实 bug 数量不足以验证 SOP | 中 | 中 | 必要时主动制造一个真实 race 案例 |
| SOP 写得理想化，落地时仍然靠记忆 | 高 | 高 | 第 1 个真实案例必须严格走流程并产出归档 |
| trace 归档膨胀 | 中 | 低 | calibration-history 按日期归档，30 天前的清掉但保留摘要 |
| 与 master-plan 同步出错 | 中 | 中 | 每次更新先在 plan 落地，再反向 sync 到上层文档 |

## SOP 草案

### Calibration Cadence

- 主战场：complete
- 每语言：约 30 分钟
- 重点轮：每语言每周 1 次（如 C/C++、Python、Elisp）
- 全语言轮：每月 1 次（含 Java / JS / TS / Rust / Go）
- 不强制：单 phase 完成后默认 manual smoke 5-10 分钟

### Prepare Checklist

1. API key / 配额 / 网络
2. 关闭测试 stub（如果有遗留）
3. 记录模型版本与 temperature
4. 关闭 minibuffer 占用
5. 进入目标语言项目，准备真实文件

### Run Checklist

每语言固定跑：
- Common Scenario A 行尾续写
- Common Scenario B 接受/部分接受
- Common Scenario C 缓存重访
- Common Scenario D 分歧/恢复
- Common Scenario E 格式/空行

每出现异常立即：
1. `M-x rc/gptel-export-recent-ai-trace` 导 trace
2. `M-x rc/gptel-stats` 抓 stats 摘要
3. `M-x rc/gptel-describe-current-complete-prompt` 看 prompt diagnostics

### Archive Checklist

- 目录：`docs/calibration-history/YYYY-MM-DD/`
- 必备文件：
  - `summary.md`（5-10 行结论）
  - `stats.txt`（stats snapshot）
  - `trace-XXX.json`（每个异常一份）
- 命名：`<lang>-<scenario>-<seq>`

### Regression Backflow Rule

满足任一即必须回流到 ERT：
- 能稳定复现
- 能提炼最小输入条件
- 属于 runtime bug 而非纯模型随机差异
- 会影响状态自洽 / cache / coordination / style hint / panel inspector 可解释性

回流流程：
1. 在 `tests/experience-matrix.md` 找格子
2. 若属现有格子，在对应子测试文件补一条 ERT
3. 若属新格子，先扩 matrix
4. 跑全量 ERT 验证回归
5. 提交 commit 标记本次 calibration 编号

## Milestones

1. **M1 - calibration-guide.md 成稿**
   - 做什么：
     - 写或扩充 `docs/calibration-guide.md`
     - 包含本 plan 草案中的 4 个 checklist 与回流规则
   - 验收：
     - 文档不依赖记忆能自洽走通

2. **M2 - 试跑 SOP：2 个真实案例**
   - 做什么：
     - 选 2 个最近真实出现过的 bug 或体感问题
     - 严格按 SOP 跑：复现 → 导 trace → 归档 → 补 ERT → 修
     - 每个案例至少产出 1 个 ERT 回归
   - 验收：
     - `docs/calibration-history/` 至少 2 个日期目录
     - matrix 状态有更新
     - tests 内有 2 条新 ERT 标注来源案例

3. **M3 - 反向 sync 主规划**
   - 做什么：
     - 把 SOP 中固化的部分 sync 到 master-plan Phase 06 与 calibration-plan
     - 标记 calibration-plan 中之前的 TODO 为已落地
   - 验收：
     - 上层 3 份文档之间无矛盾
     - 任意一份单独读都能从入口走到 SOP

4. **M4 - 关单 + done tag**
   - 做什么：
     - 跑全量 ERT
     - `git tag tests-phase-06-done`
     - 把所有 active/ plan 标 `completed`
     - `git mv active/*.md completed/`
   - 验收：
     - active/ 为空（除 .gitkeep）
     - completed/ 中含 7 份 plan
     - tag 存在

## Validation

- Commands:
  ```bash
  find ~/.emacs.rc/ai/tests -name "*.elc" -delete && \
    emacs --batch -Q \
      -l /home/seeback/.emacs.rc/ai/tests/run-all-tests.el \
      -f ert-run-tests-batch-and-exit 2>&1 | tail -10
  ```
  ```bash
  cd ~/.emacs.rc/ai && \
    ls docs/calibration-history/ 2>&1
  ```
- 手动检查:
  - 关单后再选 1 个新 bug 走一遍 SOP，验证 SOP 在没有维护者引导下可独立完成
- 观察工具:
  - 实时配合 trace / stats / panel / inspector

## Performance Budget

不影响测试运行时长。

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | Phase 05 末为准 | 2.0s | 0.39s |

## Progress Log

- [x] M1 calibration-guide.md 成稿
- [x] M2 试跑 SOP 2 个真实案例
- [x] M3 反向 sync 主规划
- [x] M4 关单 + done tag
- [x] 全量 ERT 全绿
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-19: `complete-clear-indicator-001` 选择直接修上游 `gptel-autocomplete` 的 guard，而不是只在 rc 层绕开；因为报错点就在 `gptel-clear-completion` 内部，rc 层包一层会掩盖真实缺口。
- 2026-05-19: `ui-panel-rewrite-bleed-001` 当前 runtime 已无法在 batch 里复现原始污染现象，但仍补一条聚合层 ERT，显式约束“inert rewrite locals 不得进入 snapshots”。
- 2026-05-19: `trace-*.json` 允许在无原始导出时保存 `source: reconstructed` 的最小 transcript；比完全不归档更有用，也避免伪造“这是实时导出”的假证据。

## Completion Snapshot

- 实际做了：
  - 扩充 `docs/calibration-guide.md`，补齐归档目录、回流模板与已落地案例。
  - 更新 `tests/README.md`、`tests/exec-plans/README.md`、`tests/00-test-hardening-master-plan.md`、`tests/01-real-call-calibration-plan.md`，把 calibration -> regression SOP 反向 sync 到上层文档。
  - 新增 2 条 calibration case 回归：
    - `rc/gptel-complete-clear-completion-tolerates-unbound-requesting-indicator-timer`
    - `rc/gptel-action-snapshots-skip-inert-rewrite-buffers`
  - 新建 `docs/calibration-history/2026-05-18/` 与 `docs/calibration-history/2026-05-19/` 作为真实 case 模板归档。
  - 修补 `gptel-autocomplete` 中 requesting-indicator timer 未绑定时的 `void-variable` 崩溃。
- 与原计划差异：
  - 两个案例都来自近期真实报错；没有再额外人为制造第三种 race 案例。
  - `trace-*.json` 使用了 `reconstructed` transcript 兜底，而不是强行要求每次都必须拿到实时 trace 导出。
- 遗留小尾巴：
  - 真实日用的多语言长时间 calibration 还要继续做，但那已经是按 SOP 持续执行，不再需要主驱动 phase。
  - runtime 侧 `docs/exec-plans/` 仍有自己的 05/06 计划，与本测试 phase 已闭环但不互相替代。
- 已记入 tech-debt：
  - 无新增；沿用已有 `tag-coverage` 与 `matrix-coverage`。
- 下游 plan 解锁：体系闭环。后续真实 bug 自动按 SOP 沉淀，不再需要主驱动 plan。
