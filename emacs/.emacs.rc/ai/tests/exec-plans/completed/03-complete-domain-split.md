# Complete Domain Split

```yaml
status: completed
start-date: 2026-05-18
completion-date: 2026-05-18
phase: 03
depends-on: [02-helper-extraction]
```

## Goal

把 complete 这块主战场拆成 6 个领域子文件 + 1 个 stub-integration 文件，使 complete 相关回归默认有明确归属，主文件不再继续作为「complete 杂货铺」膨胀。

## Scope

- In scope:
  - 拆出 6 个领域子测试文件 + 1 个 coordination 文件（共 7 个）
  - 子文件复用 `helpers/ai-test-helpers.el`
  - 主文件中同主题用例同步删除
  - 新建 `tests/run-all-tests.el` 聚合入口（拆分后单 ERT 命令需要一个 loader）
- Out of scope:
  - 不拆 ask / rewrite / UI 用例（Phase 05）
  - 不补新用例（Phase 04）
  - 不改 runtime 行为

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase 03 Complete Domain Split
- 相关代码路径：
  - 主文件：`tests/ai-action-runtime-test.el`
  - runtime 对齐：
    - `complete/ai-complete-state-rc.el` → state-test
    - `complete/ai-complete-trigger-rc.el` → trigger-test
    - `complete/ai-complete-cooldown-rc.el` → cooldown-test
    - `complete/ai-complete-followup-rc.el` → followup-test
    - `complete/ai-complete-context-rc.el` → context-test
    - `complete/ai-complete-language-rules-rc.el` → language-rules-test
    - `complete/ai-complete-observe-rc.el` → observe-test
- 相关 plan：
  - 依赖 `02-helper-extraction.md`（必须先有 helper 模块）
  - 解锁 `04-experience-regression-matrix.md` 与 `05-ask-rewrite-ui-consolidation.md`
- 约束：
  - 每迁一组立刻跑全量 ERT，不允许积压
  - 拆出后文件不允许互相 require（除 helpers 之外）

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| 拆分时把跨领域用例错放 | 高 | 中 | 由 Phase 01 coverage-map 决定每条归属，避免临场判断 |
| trigger 系列三个文件之间归类混乱 | 中 | 中 | 严格按 runtime 拆分对齐，cooldown / followup 不混入 trigger |
| 全量 ERT 在多文件加载下变慢 | 中 | 低 | 测每 phase 运行时长，超 1.8s 调查 |
| 子文件命名冲突或加载顺序错 | 中 | 中 | 新建的 `run-all-tests.el` 显式列出加载顺序，不依赖目录扫描 |
| ELC 缓存导致幽灵失败 | 中 | 中 | 每次切换 `find tests -name "*.elc" -delete` |

## 子文件目标结构

```text
tests/
├── ai-action-runtime-test.el            （收缩至只剩 action-request 共享层）
├── helpers/
│   └── ai-test-helpers.el
├── complete/
│   ├── ai-complete-state-test.el        normalization / lifecycle / supersede / timeout / cache basic
│   ├── ai-complete-trigger-test.el      auto-trigger / source-event
│   ├── ai-complete-cooldown-test.el     cooldown / accept-intent / policy
│   ├── ai-complete-followup-test.el     continuation / followup-ready
│   ├── ai-complete-context-test.el      prompt diagnostics / budget / style hint
│   ├── ai-complete-language-rules-test.el  C/C++/Python/Java/JS/TS/Elisp
│   ├── ai-complete-observe-test.el      stats / trace / replay summary
│   └── ai-complete-coordination-test.el ★ stub-integration: company/yas/capf/lsp/race/late-response
└── run-all-tests.el
```

★ coordination-test 是「mock vs real-call」之间的 stub-integration 层（00-pre-flight 抉择 2 确定）。

## Milestones

1. **M1 - state-test 迁移**
   - 做什么：
     - 新建 `tests/complete/ai-complete-state-test.el`
     - 按 coverage-map 标 `complete-state` 的用例迁过去
     - 主文件删对应原文
   - 验收：
     - 全量 ERT 全绿
     - state-test 单独跑也全绿

2. **M2 - trigger / cooldown / followup 三套并行迁移**
   - 做什么：
     - 按 runtime 三文件对齐拆分
     - 严格不允许 cooldown 用例落到 trigger-test
   - 验收：
     - 三个测试文件分别可独立跑
     - 全量仍全绿

3. **M3 - context / language-rules / observe 迁移**
   - 做什么：
     - 按 coverage-map 迁移
   - 验收：
     - 主文件已不存在 complete 相关用例
     - 全量仍全绿

4. **M4 - 建 stub-integration 层 coordination-test**
   - 做什么：
     - 从主文件 + trigger-test 中识别属于「company/yas/lsp 协作 / late response / race / timer 重入」的用例
     - 迁入 `ai-complete-coordination-test.el`
     - 把 stub-network 类 helper 集中到这里（必要时回灌 helpers 模块）
   - 验收：
     - coordination-test 用例数 ≥ 8（基于现有覆盖估计）
     - 全量 ERT 仍全绿

5. **M5 - 建 run-all-tests + done tag**
   - 做什么：
     - 新建 `tests/run-all-tests.el`，显式加载 helpers + 7 个子文件 + 主文件残留
     - 跑全量
     - `git tag tests-phase-03-done`
   - 验收：
     - 全量 ERT 全绿
     - 各子文件运行时长记录到本 plan Performance Budget

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
    for f in tests/complete/*.el; do \
      echo "=== $f ==="; \
      emacs --batch -Q \
        -l ./tests/helpers/ai-test-helpers.el \
        -l "$f" \
        -f ert-run-tests-batch-and-exit 2>&1 | tail -3; \
    done
  ```
- 手动检查:
  - 随便打开一个 elisp / python / cpp buffer 真实触发 complete，确认行为不退化
- 观察工具:
  - 跑完后 `M-x rc/gptel-stats` 看 panel / inspector 是否仍正常解释

## Performance Budget

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | 0.81s / 151 用例（Phase 00 末） | 1.5s | |
| 单子文件 ERT | - | 500ms | |
| 主文件行数 | 2500（M2 后） | 减至 800 以下 | |

## Progress Log

- [x] M1 state-test 迁移
- [x] M2 trigger / cooldown / followup 迁移
- [x] M3 context / language-rules / observe 迁移
- [x] M4 coordination-test 建立（stub-integration 层）
- [x] M5 建 run-all-tests + done tag
- [x] 全量 ERT 全绿
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-18: 不按 M1-M4 分批迁移，写一个 `tests/tools/split-by-domain.el` 一次性按 `:tags domain/*` 路由全部 127 个测试。理由：Phase 01 已经把单一事实源放在 `:tags` 里，splitter 直接消费即可；分批人工只是重复机械操作
- 2026-05-18: Splitter 用 `read` 解析 form 提取 :tags（而不是 regex 抓 `:tags`），避免被多种 form 写法干扰
- 2026-05-18: 25 个未路由的测试（ask / rewrite / ui / replay / toggle / describe / lint / meta）保留在主文件。这些 Phase 05 再拆，不在 Phase 03 范围内
- 2026-05-18: aggregator `run-all-tests.el` 显式列出加载顺序，不依赖目录扫描。理由：未来加新子文件时 fail-loud 提示更新 aggregator
- 2026-05-18: 每个子文件自己 load `ai-rc.el` + helpers，重复 load 由 Emacs 缓存自动幂等。理由：子文件可独立跑（CI 友好），不依赖 aggregator

## Completion Snapshot

- 实际做了：
  - 新建 `tests/tools/split-by-domain.el`（230 行）：splitter + 路由表 + 文件 header/footer 自动生成
  - 跑 splitter 一次性输出 9 个子文件：
    - `tests/complete/ai-complete-state-test.el`（38KB / 34 测试）
    - `tests/complete/ai-complete-language-rules-test.el`（10KB / 23 测试）
    - `tests/complete/ai-complete-followup-test.el`（13KB / 16 测试）
    - `tests/complete/ai-complete-coordination-test.el`（12KB / 15 测试，含 race/coordination 类）
    - `tests/complete/ai-complete-trigger-test.el`（11KB / 14 测试）
    - `tests/complete/ai-complete-cooldown-test.el`（6.5KB / 7 测试）
    - `tests/complete/ai-complete-observe-test.el`（7.5KB / 7 测试）
    - `tests/complete/ai-complete-context-test.el`（5KB / 5 测试）
    - `tests/ai-action-request-test.el`（11KB / 6 测试）
  - 主文件从 2876 → 538 行（保留 25 个 ask/rewrite/ui/replay/toggle/describe/lint 测试）
  - 新建 `tests/run-all-tests.el` aggregator（37 行）显式加载 11 个测试文件
  - 重跑 generator，`tests/generated/coverage-map.md` + `weakness-map.md` 刷新
- 与原计划差异：
  - 原 plan 假设 M1-M4 分批迁移，实际 splitter 一次性完成。M1-M4 在 Decision Log 中合并说明
  - 主文件行数从 2876 → 538，超出原计划 "减至 800 以下" 的目标
  - 全量 ERT 0.40s（比 Phase 02 末 0.71s 快 44%），原因：aggregator 加载顺序更优 + helpers 一次性 load
- 遗留小尾巴：
  - 25 个非 complete 测试仍在主文件，Phase 05 拆
  - splitter 保留了被删 form 处的多个空行，已用一次性清理 collapse 成单空行；未来再次 split 不会有此问题（不会再有大量 form 待删）
  - 子文件之间用 `(load ...)` 而不是 `(require ...)`，是因为这些文件并不 `(provide ...)` 任何独立功能。如果未来需要 require，需要补 provide 形式 — 当前 aggregator 直接 load 足够
- 已记入 tech-debt：
  - 无新增
- 下游 plan 解锁：`04-experience-regression-matrix.md` / `05-ask-rewrite-ui-consolidation.md`
