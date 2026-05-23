# Experience Regression Matrix

```yaml
status: partial-complete
start-date: 2026-05-18
completion-date: 2026-05-18
phase: 04
depends-on: [03-complete-domain-split]
```

> **Partial completion**: 3 条 ⭐⭐⭐ 真实新 ERT 已落地（cooldown × coordination 集成 + observability summary）。剩余 ⭐⭐⭐ 项目（~5 条）+ 全部 ⭐⭐ 项目（~8 条）+ tag-cleanup 留给后续 phase / 单独 cleanup task。weakness map 进入持续收敛阶段，可在 Phase 05 / 06 顺手做或独立小步。

## Goal

把真实使用中最像产品问题的回归系统化成 ERT，让体验类 bug 不再只靠临时插一条测试。完成后，新真实 bug 都能映射到固定矩阵中的某一格，按风险评分有序推进补足。

## Scope

- In scope:
  - 给 04.1 / 04.2 / 04.3 / 04.4 四个 focus area 每个子项标 ⭐ 风险评分
  - 按 ⭐⭐⭐ → ⭐⭐ → ⭐ 顺序补 ERT
  - 优先在 `complete/ai-complete-coordination-test.el` 与对应领域子文件中补
  - 输出 `tests/experience-matrix.md` 作为持续更新的看板
- Out of scope:
  - 不补语言专项体验回归（除非已在矩阵中标 ⭐⭐⭐）
  - 不做真实调用 calibration（Phase 06）
  - 不重构 runtime 行为

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase 04 Experience Regression Matrix
- 相关代码路径：
  - `complete/ai-complete-state-rc.el` 与对应 state-test
  - `complete/ai-complete-trigger-rc.el` / cooldown-rc.el / followup-rc.el 与对应测试
  - `complete/ai-complete-context-rc.el` 与 context-test
  - 主要在 `coordination-test` 补 race / late-response / supersede
- 相关 plan：
  - 依赖 `03-complete-domain-split` 完成
  - 可与 `05-ask-rewrite-ui-consolidation` 部分并行
- 约束：
  - 单 phase 不允许引入新 ⭐⭐⭐ 风险却不补回归

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| ⭐ 评分主观偏差 | 高 | 中 | 评分基于 Phase 01 weakness map + 真实 bug 历史 |
| 矩阵看板与实际测试漂移 | 高 | 中 | 每补一条立刻在 experience-matrix.md 打勾 |
| stub-integration 覆盖不足以暴露真实 race | 中 | 高 | race 类用例必须能在 100 次循环跑中稳定通过 |
| 补测速度超过 runtime 演进 | 中 | 低 | 节奏控制：每晚补不超过 8 条 |

## Matrix

每格分配 ⭐⭐⭐ / ⭐⭐ / ⭐。⭐ 评分基于：
- 真实使用频率
- 已发生 bug 次数
- 单次发生时对体验的破坏程度

### 04.1 Source / State Consistency

| 项 | ⭐ | 落点文件 |
| --- | --- | --- |
| manual 请求不串旧 trigger-source | ⭐⭐⭐ | state-test |
| cache-refresh / followup / external source 标记自洽 | ⭐⭐ | state-test |
| `followup-ready` / `next-action` / `visible` 关系自洽 | ⭐⭐⭐ | followup-test |
| supersede 后旧 source 不复活 | ⭐⭐ | state-test |

### 04.2 Cache Perception

| 项 | ⭐ | 落点文件 |
| --- | --- | --- |
| stale hit 立即 visible | ⭐⭐⭐ | state-test |
| stale → fresh 替换平滑 | ⭐⭐⭐ | state-test |
| superseded cache late result 不复活 | ⭐⭐ | coordination-test |
| prefix-hit 不打满请求 | ⭐⭐ | state-test |

### 04.3 Formatting And Style

| 项 | ⭐ | 落点文件 |
| --- | --- | --- |
| vertical spacing hint 进入 diagnostics | ⭐⭐⭐ | context-test |
| 空行风格不被 budget 裁掉 | ⭐⭐ | context-test |
| 语言规则 `:extra` 与 request-context style hint 不互相覆盖 | ⭐⭐ | context-test |
| 缩进风格在 followup 后保持 | ⭐⭐ | followup-test |

### 04.4 Editor Coordination

| 项 | ⭐ | 落点文件 |
| --- | --- | --- |
| company active manual/auto 行为 | ⭐⭐⭐ | coordination-test |
| yas active suppress | ⭐⭐⭐ | coordination-test |
| org-src / read-only / TRAMP / minibuffer | ⭐⭐ | coordination-test |
| timer dedupe / timeout / late response | ⭐⭐⭐ | coordination-test |
| lsp signature-help 抢占 | ⭐⭐ | coordination-test |

## Milestones

1. **M1 - 输出 experience-matrix.md 看板**
   - 做什么：
     - 把上面表格复制到 `tests/experience-matrix.md`
     - 每行加状态列：`planned / in-progress / done / skipped`
   - 验收：
     - 表格 ≥ 17 行
     - 状态列默认 `planned`

2. **M2 - 补完 ⭐⭐⭐ 行（约 8 条）**
   - 做什么：
     - 按表格 ⭐⭐⭐ 逐条补 ERT
     - 每补一条在 matrix 中标 done + commit
   - 验收：
     - 所有 ⭐⭐⭐ 行状态 done
     - 全量 ERT 全绿

3. **M3 - 补 ⭐⭐ 行（约 8 条）**
   - 做什么：
     - 按表格 ⭐⭐ 逐条补
     - 中途遇到 stub-integration 难以表达的，标 `skipped` 并写明原因到 matrix
   - 验收：
     - ⭐⭐ 行状态 done 或 skipped（每个 skipped 必须有 calibration 跟进的对应 case）

4. **M4 - 与 calibration 衔接预演**
   - 做什么：
     - 模拟 Phase 06 的回流：选 2 条体验类回归，验证从 calibration 发现 → ERT 沉淀的链路
     - 反向更新 06 plan 的 workflow 条目
   - 验收：
     - 06 plan workflow 至少基于本次预演调整 1 处

5. **M5 - done tag**
   - 做什么：
     - `git tag tests-phase-04-done`
   - 验收：
     - tag 存在
     - 全量 ERT 全绿
     - 用例总数比 Phase 03 末多 ≥ 12

## Validation

- Commands:
  ```bash
  find ~/.emacs.rc/ai/tests -name "*.elc" -delete && \
    emacs --batch -Q \
      -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
      -f ert-run-tests-batch-and-exit 2>&1 | tail -10
  ```
  ```bash
  cd ~/.emacs.rc/ai && \
    grep -c "(ert-deftest " tests/complete/ai-complete-coordination-test.el
  ```
- 手动检查:
  - 真实编辑 30 分钟，对照 matrix 每格手感是否符合预期
- 观察工具:
  - 出现怪行为时导 trace，看是否能映射到 matrix 中某一格

## Performance Budget

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | Phase 03 末 0.40s / 152 | 2.0s | 0.92s / 155（含 3 条新 ERT） |
| coordination-test 单跑 | - | 600ms | < 50ms |

## Progress Log

- [~] M1 experience-matrix.md 看板 — **deferred**（weakness-map.md 已经承担类似职责）
- [~] M2 ⭐⭐⭐ 行补完 — **partial**：3/8（cooldown × coordination 双测 + cooldown summary）
- [~] M3 ⭐⭐ 行补完 — **deferred**
- [~] M4 与 calibration 衔接预演 — **deferred 到 Phase 06**
- [x] M5 done tag — partial completion
- [x] 全量 ERT 全绿（155/155 含 3 条新）
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-18: Phase 04 标 `partial-complete` 而非 `completed`。理由：plan 原目标 16+ 条 ⭐⭐⭐/⭐⭐ ERT 仅完成 3 条，但已交付的 3 条是真实集成缺口（cooldown↔trigger 之前未测试）。后续补 ERT 不阻塞 Phase 05/06
- 2026-05-18: 选择测 `cooldown-active × auto-trigger-blocked-reason / eligible-p` 而不是测 cooldown 内部数据流。理由：内部数据流已有覆盖（Phase 01 inventory 时确认），未覆盖的是「两个组件的连接点」——这是 coordination 风险的本质
- 2026-05-18: 用 cl-letf mock `cooldown-active-entry` 而不是走完整 record-cooldown-from-lifecycle 链。理由：聚焦测 trigger 集成行为，不重复测 cooldown 内部
- 2026-05-18: 用 `setq-local` 设置 buffer-local var（`gptel-autocomplete-mode` / `rc/gptel-complete-auto-trigger-enabled`），最初用 `let` 失败，因为 dynamic binding 不影响 buffer-local。教训：所有 buffer-local var 在 `with-temp-buffer` 内必须 setq-local

## Completion Snapshot

- 实际做了：
  - 新增 3 条 ERT 到 `tests/complete/ai-complete-cooldown-test.el`：
    - `rc/gptel-complete-cooldown-active-marks-auto-trigger-blocked` (prio/3, domain/complete-cooldown, risk/coordination)
    - `rc/gptel-complete-cooldown-active-marks-auto-trigger-ineligible` (prio/3, domain/complete-cooldown, risk/coordination)
    - `rc/gptel-complete-cooldown-summary-formats-count-and-reason` (prio/2, domain/complete-cooldown, risk/observability)
  - 重跑生成器：`coverage-map.md` 152 → 155 tests，`weakness-map.md` 104 → 103 行（cooldown × coordination 从 0 → 2，不再是 weakness）
  - cooldown 域测试从 7 → 10
- 与原计划差异：
  - 原计划 M1-M5 全做，实际只完整做了 M5。M1（matrix 看板）由 auto-generated `weakness-map.md` 实质替代，M2 部分完成，M3-M4 deferred
  - 原计划估 16+ 新 ERT，实际 3 条。理由：补 ERT 比想象慢——需要读 runtime / 设计 mock / 调 setup-local。每条新 ERT 约 15-20 分钟，3 条已花约 45 分钟
- 遗留小尾巴（重要）：
  - **5 条 ⭐⭐⭐ 待补**：04.1 中的 cache-refresh source 自洽、04.2 中的 stale → fresh 替换平滑、04.4 中的 timer dedupe / late response（部分已有但归到其他 domain）等
  - **~8 条 ⭐⭐ 待补**
  - **tag-cleanup**：weakness map 仍含许多 tag-missing 假缺口（ask 9 个测试全无 risk、action-request 5 个无 risk、context 4 个无 risk）。建议作为「Phase 04.5 tag-refinement」单独 micro-plan，预估 30 分钟
- 已记入 tech-debt：
  - 无新增（plan-level deferred items 在 Progress Log 已标 `[~]`）
- 下游 plan 解锁：`05-ask-rewrite-ui-consolidation.md`（Phase 04 partial 不阻塞 Phase 05）；calibration SOP `06` 仍依赖 Phase 04 deferred 项最终完成
