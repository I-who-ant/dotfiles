# Ask / Rewrite / UI Consolidation

```yaml
status: completed
start-date: 2026-05-19
completion-date: 2026-05-19
phase: 05
depends-on: [03-complete-domain-split]
```

## Goal

不要让 complete 一枝独大、ask / rewrite / UI 长期只靠「顺手补一点」。这 phase 把这三块的回归从主文件迁出到独立子文件，并补足共享观察层的稳定性回归。

## Scope

- In scope:
  - 新建 4 个子测试文件（见结构）
  - 从主文件迁出对应用例
  - 补 ask snapshot 字段稳定性、rewrite meaningful snapshot、panel 共享字段等关键缺口
  - 与 Phase 04 并行可行，但默认让 04 先 ⭐⭐⭐ 行补完
- Out of scope:
  - 不补 ask / rewrite 的真实手感回归（这是 calibration 的事）
  - 不重构 ask-command.el（已在 tech-debt，单独 plan 处理）
  - 不动 complete 子文件

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase 05 Ask / Rewrite / UI Consolidation
- 相关代码路径：
  - `ask/ai-ask-command-rc.el`
  - `ask/ai-ask-snapshot-rc.el`
  - `rewrite/ai-rewrite-*`
  - `ui/ai-action-panel-rc.el`
  - `ui/ai-complete-inspect-rc.el`
- 相关 plan：
  - 依赖 `03-complete-domain-split` 完成
  - 与 `04-experience-regression-matrix` 部分并行
- 约束：
  - 不动共享 helper
  - 不引入跨子文件 require

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| ask / rewrite / UI 边界模糊 | 中 | 中 | 严格按 runtime 模块拆，UI 类只测 panel/inspector 渲染 |
| panel 共享字段断言不稳定（label 文本变化） | 中 | 中 | 优先断言结构（plist key 存在），其次断言文本 |
| rewrite history 用例依赖完整 session | 中 | 高 | helper 中提供 `with-fake-session` 包装 |

## 目标文件结构

```text
tests/
├── ai-action-request-test.el            shared request helper / success/failure/abort/supersede
├── ask/
│   └── ai-ask-runtime-test.el           source fallback / snapshot fields / rollback / session/panel exposure
├── rewrite/
│   └── ai-rewrite-runtime-test.el       meaningful snapshot / history filtering / state / result / region
└── ui/
    └── ai-ui-panel-inspector-test.el    panel labels / current snapshot priority / inspector shared sections / active snapshot rendering
```

## Milestones

1. **M1 - action-request-test 拆出**
   - 做什么：
     - 把主文件 action-request / lifecycle 共享层用例迁入 `ai-action-request-test.el`
   - 验收：
     - 主文件不再有 shared action request 用例
     - 全量 ERT 全绿

2. **M2 - ask 子文件**
   - 做什么：
     - 新建 `tests/ask/ai-ask-runtime-test.el`
     - 迁入 ask 相关用例
     - 补 ask snapshot 字段稳定性（panel / inspector 共享字段）
   - 验收：
     - ask 子文件用例 ≥ 现有 ask 用例数
     - 全量 ERT 全绿

3. **M3 - rewrite 子文件**
   - 做什么：
     - 新建 `tests/rewrite/ai-rewrite-runtime-test.el`
     - 迁入并补 meaningful snapshot 判定 / history filtering
   - 验收：
     - rewrite 子文件用例 ≥ 现有 rewrite 用例数 + 2
     - 全量 ERT 全绿

4. **M4 - panel / inspector 子文件**
   - 做什么：
     - 新建 `tests/ui/ai-ui-panel-inspector-test.el`
     - 迁入 panel / inspector / replay / trace 类用例
     - 补 active snapshot 字段稳定性
   - 验收：
     - 主文件已基本清空（只剩极少跨域用例）
     - 全量 ERT 全绿

5. **M5 - 主文件命运决定**
   - 做什么：
     - 评估主文件是否还需要存在
     - 若仍有用例，明确写在文件头注释中「本文件残留的内容为什么留下」
     - 若可全部迁出，则删主文件并更新 `run-all-tests.el`
   - 验收：
     - 决策写入 Decision Log
     - 全量 ERT 全绿

6. **M6 - done tag**
   - 做什么：
     - `git tag tests-phase-05-done`
   - 验收：
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
    for f in tests/ask/*.el tests/rewrite/*.el tests/ui/*.el tests/ai-action-request-test.el; do \
      echo "=== $f ==="; \
      emacs --batch -Q \
        -l ./tests/helpers/ai-test-helpers.el \
        -l "$f" \
        -f ert-run-tests-batch-and-exit 2>&1 | tail -3; \
    done
  ```
- 手动检查:
  - 触发一次 ask + 一次 rewrite，确认 panel / inspector 显示无回归
- 观察工具:
  - `C-c a i` / `C-c a o` 对照 ask 与 rewrite session

## Performance Budget

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | Phase 04 末为准 | 2.0s | |
| 子文件单跑 | - | 500ms | |

## Progress Log

- [x] M1 action-request-test 拆出
- [x] M2 ask 子文件
- [x] M3 rewrite 子文件
- [x] M4 panel / inspector 子文件
- [x] M5 主文件命运决定
- [x] M6 done tag
- [x] 全量 ERT 全绿
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-19: `domain/replay` 并入 `tests/ui/ai-ui-panel-inspector-test.el`，因为它更接近共享观察层，而不是单独的 ask/rewrite 领域。
- 2026-05-19: `domain/toggle` 与 `domain/meta` 暂留主文件，不新建独立子文件，避免为了两三条残量测试再造文件噪音。
- 2026-05-19: M1 视为由 Phase 03 的既有结果提前满足；Phase 05 不重复迁 action-request，只把其状态记入本 plan 进度。

## Completion Snapshot

- 实际做了：
  - 新增 `tests/ask/ai-ask-runtime-test.el`、`tests/rewrite/ai-rewrite-runtime-test.el`、`tests/ui/ai-ui-panel-inspector-test.el` 三个子文件。
  - 扩 `tests/tools/split-by-domain.el` 路由，覆盖 ask / rewrite / ui / describe / replay 域。
  - 更新 `tests/run-all-tests.el` 聚合顺序，显式加载 residual main file、action-request、ask / rewrite / ui 与 complete 分域文件。
  - 主文件 `tests/ai-action-runtime-test.el` 缩成 residual file，只保留 `domain/toggle` 与 `domain/meta`。
  - 验证通过：全量 ERT、`ai-rc.el` load gate、`.emacs` load gate。
- 与原计划差异：
  - `domain/replay` 未单开文件，而是并入 UI 子文件。
  - M1 沿用 Phase 03 已拆出的 `tests/ai-action-request-test.el`，本 phase 不重复拆。
  - 主文件未删除，而是保留为 residual file 并在文件头写明保留原因。
- 遗留小尾巴：
  - `tag-coverage` 假缺口仍在，后续需清一次 ask / action-request / context 的 risk tag。
  - `matrix-coverage` 仍待 Phase 06 按真实 calibration bug 继续反推补测。
- 已记入 tech-debt：
  - 无新增；沿用已有 `tag-coverage` 与 `matrix-coverage`。
- 下游 plan 解锁：`06-calibration-to-regression-workflow.md`
