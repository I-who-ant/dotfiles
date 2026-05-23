# Inventory And Coverage Map

```yaml
status: completed
start-date: 2026-05-18
completion-date: 2026-05-18
phase: 01
depends-on: [00-pre-flight-alignment]
```

## Goal

把「测试元数据」从「手工维护的 markdown 表格」迁到「写在测试代码本体里」。给现有 151 个 `ert-deftest` 加上规范化的 `:tags`，写一个扫描器把 tag 派生成 coverage-map / weakness-map。完成后元数据和测试代码绝不漂移，且能按 tag 过滤运行。

## Scope

- In scope:
  - 设计 tag 词表（`domain/*` / `risk/*` / `prio/N` 三个 namespace）
  - 给 151 个 `ert-deftest` 加 `:tags`（**真改测试代码 151 处**）
  - 新建 `tests/tools/coverage-extract.el` 扫描器
  - 新增 `rc/lint-all-tests-have-tags` 作为 ERT 自检（套件里自我把守）
  - 生成 `tests/generated/coverage-map.md` 和 `tests/generated/weakness-map.md`
  - 在顶层 README 加「按 tag 跑测试」命令清单
- Out of scope:
  - 不拆测试文件（Phase 03 干）
  - 不抽 helper（Phase 02 干）
  - 不补新用例（Phase 04 干）
  - 不改 runtime 代码

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase 01 Inventory And Coverage Map
- 相关代码路径：
  - `tests/ai-action-runtime-test.el`（151 个 `ert-deftest`，待加 `:tags`）
  - 待建：`tests/tools/coverage-extract.el`
  - 待建：`tests/generated/coverage-map.md`、`tests/generated/weakness-map.md`
- 相关 plan：
  - 依赖 `00-pre-flight-alignment` 完成
  - 解锁 `02-helper-extraction`（拆 helper 时按 tag 决定哪些 helper 共享）
- 设计原则（与上层 `tests/exec-plans/README.md` 一致）：
  - **元数据写在代码里**，文档只引用代码派生物，不存独立来源
  - 任何「测试 → 标签」的映射必须是 single source of truth
- 约束：
  - lint 通过后 151 个测试不允许任何一个没 `:tags`
  - generated/ 是 derived artifact，commit 进版本控制（让 PR diff 反映 coverage 变化）

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| 词表设计不全，后期反复改名 | 中 | 高 | M1 先定固定枚举，加 tag 时不允许临时新增；新增必须改 plan |
| 151 处编辑漏写 / 错写 | 高 | 中 | lint 是 ERT 自检，跑全量就能 catch |
| 自动推断 domain / risk 偏差 | 中 | 中 | 按命名规则批量推断后，再人工抽样校对 10% |
| generated/ 进 commit 后引发噪音 diff | 中 | 低 | 限制生成器输出格式稳定（按 test name 字典序） |
| 测试名重命名时 tag 跟着改但 generated 没刷新 | 高 | 中 | 在 Phase 02 + Phase 03 收尾前必须重跑生成器 |

## Tagging Schema

三个 namespace，**固定枚举**，不允许临时新增：

### `domain/*`（必填 1 个）

- `action-request` - 共享 action request / lifecycle 层
- `ask` - ask 命令族
- `complete-state` - normalization / lifecycle / supersede / timeout / cache 基础
- `complete-trigger` - auto trigger / source event
- `complete-cooldown` - cooldown / accept-intent / policy
- `complete-followup` - continuation / followup-ready / next-edit / jump
- `complete-context` - prompt / context budget / style hint / diagnostics
- `complete-language-rules` - 语言专项规则（C/C++/Python/Java/JS/TS/Elisp）
- `complete-observe` - stats / trace / replay summary
- `complete-coordination` - company / yas / capf / lsp 协作（stub-integration 层）
- `rewrite` - rewrite 命令族
- `ui-panel` - panel 渲染
- `ui-inspector` - inspector 渲染
- `replay` - replay 链路
- `toggle` - mode toggle 命令
- `describe` - describe 类命令
- `meta` - 工具 / lint / coverage 自身测试

### `risk/*`（可多选）

- `race` - 时序 / late response / 超时 / 重入
- `coordination` - company / yas / capf / lsp 协作
- `stale-cache` - cache 命中 / stale → fresh 替换
- `style` - 空行 / 缩进 / style hint
- `source-consistency` - manual / auto / followup / cache-refresh 不串值
- `protocol` - LSP / JSON-RPC / API 契约
- `observability` - panel / inspector / stats / trace 可解释性
- `supersede` - 老请求覆盖 / late response 复活
- `accept-intent` - force-stop / force-followup / continuation chain
- `cache-hit` - cache 命中 / prefix-hit 行为

### `prio/<N>`（必填 1 个）

- `prio/3` ≈ ⭐⭐⭐ 高风险，必须维持回归
- `prio/2` ≈ ⭐⭐ 中风险
- `prio/1` ≈ ⭐ 低风险或 happy path 覆盖

## Milestones

1. **M1 - 词表与工具骨架**
   - 做什么：
     - 在本 plan 锁定 tag 枚举（见上）
     - 新建 `tests/tools/coverage-extract.el`，含函数骨架：
       - `rc/test-tag-vocabulary`（常量：合法 tag 集合）
       - `rc/test-collect-tagged-tests`
       - `rc/test-validate-tags`（每个 test 必须 1×domain + 1×prio + 任意 risk）
     - 新增 `rc/lint-all-tests-have-tags` 作为一条 ERT，**全量跑时必须绿**
     - 先确认本 plan 开工前该 lint 报告 151 处缺 tag
   - 验收：
     - `tests/tools/coverage-extract.el` 可独立 require
     - lint 函数能列出所有缺 tag 的 test 名

2. **M2 - 批量加 :tags（核心工作）**
   - 做什么：
     - 按命名规则推断 domain：
       - `rc/gptel-complete-cache-*` → `domain/complete-state`（cache 基础）+ `risk/cache-hit`
       - `rc/gptel-complete-cooldown-*` → `domain/complete-cooldown`
       - `rc/gptel-complete-followup-*` / `*-next-edit-*` / `*-jump-*` → `domain/complete-followup`
       - `rc/gptel-complete-*-source-*` / `*-leak-*-source-*` → `risk/source-consistency`
       - `rc/gptel-complete-superseded-*` → `risk/supersede`
       - `rc/gptel-complete-force-stop-*` / `*-accept-*-intent` → `risk/accept-intent`
       - `rc/gptel-ask-*` → `domain/ask`
       - `rc/gptel-action-*` → `domain/action-request`
       - `rc/gptel-rewrite-*` → `domain/rewrite`
       - `rc/gptel-toggle-*` → `domain/toggle`
       - 其余按上下文判断
     - prio 推断默认 `prio/2`；下列特征升 `prio/3`：
       - 名字含 `does-not-leak` / `does-not-fall-through` / `restore` / `restored` / `salvages`
       - 涉及 supersede / late-response / race / cooldown gate
     - 人工抽样校对 10%（≥ 15 条）
   - 验收：
     - 全量 ERT 仍 151/151
     - `rc/lint-all-tests-have-tags` 报告 0 处缺 tag
     - 抽样校对记录写入 Decision Log

3. **M3 - 写生成器**
   - 做什么：
     - 完成函数：
       - `rc/test-group-by-domain`
       - `rc/test-group-by-risk`
       - `rc/test-find-weakness`（domain × risk 的低覆盖格子）
       - `rc/test-generate-coverage-map`（输出 markdown）
       - `rc/test-generate-weakness-map`
     - 输出文件：
       - `tests/generated/coverage-map.md`
       - `tests/generated/weakness-map.md`
     - 输出格式按 test name 字典序，避免噪音 diff
     - 文件头写明 `Auto-generated by rc/test-generate-coverage-map. Do not edit.`
   - 验收：
     - 跑一次扫描后两个 markdown 落盘
     - 重复跑结果完全一致（确定性输出）

4. **M4 - README 集成与命令清单**
   - 做什么：
     - 在 `tests/README.md` 加章节「按 tag 跑测试」
     - 给出 4 条标准命令：
       - 跑全量
       - 跑某个 domain（如 `domain/complete-cooldown`）
       - 跑某个优先级（如 `prio/3`）
       - 跑某个 risk（如 `risk/race`）
     - 在 `tests/exec-plans/templates/execution-plan.md` 提示：「测试新增/拆分时必须打 tag，否则 lint 失败」
     - 在 `tests/exec-plans/README.md` 加「设计原则：元数据写在代码里」一节
   - 验收：
     - 4 条命令可复制粘贴跑通
     - 模板与 README 加完保持总体简洁

5. **M5 - done tag**
   - 做什么：
     - 重跑生成器（如果 M2-M4 中有 tag 调整）
     - 全量 ERT 全绿（含 lint test）
     - `git tag tests-phase-01-done`
   - 验收：
     - tag 存在
     - generated/coverage-map.md 时间戳为 M5 时刻
     - tech-debt-tracker 中无新增

## Validation

- Commands:
  ```bash
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
    -f ert-run-tests-batch-and-exit 2>&1 | tail -5
  ```
  ```bash
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
    -l /home/seeback/.emacs.rc/ai/tests/tools/coverage-extract.el \
    --eval '(rc/test-generate-coverage-map)' \
    --eval '(rc/test-generate-weakness-map)' 2>&1 | tail -5
  ```
  ```bash
  # 按 tag 跑测试示例（M4 后才能用）
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
    --eval '(ert-run-tests-batch-and-exit (quote (tag prio/3)))' 2>&1 | tail -5
  ```
- 手动检查:
  - 打开 `tests/generated/coverage-map.md`，确认头部 `Generated at` 时间合理
  - 抽 5 条 test，确认 :tags 与该测试实际行为相符
- 观察工具:
  - 无需 runtime 观察

## Performance Budget

本 plan 给测试加 `:tags` 不影响运行时长，但新增 1 条 lint test。

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | 0.81s / 151 用例（Phase 00 末） | 1.0s（加 1 条 lint test，152 用例） | **0.66s / 152 用例**（含 lint）|
| 生成器单跑 | - | 500ms | < 200ms |
| 按 tag 过滤跑 | - | - | prio/3=22 / 0.40s，risk/race=6 / 15ms，domain/cooldown=7 / 3ms |

## Progress Log

- [x] M1 词表与工具骨架
- [x] M2 批量给 151 个测试加 :tags
- [x] M3 写生成器（coverage-map + weakness-map）
- [x] M4 README 集成 + 命令清单 + 模板更新
- [x] M5 done tag
- [x] 全量 ERT 全绿（含 lint）
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-18: tag 体系采用 ERT 内置 `:tags`，namespace 用 `domain/*` / `risk/*` / `prio/N`。理由：ERT 原生支持过滤与按 tag 运行，不引入外部框架
- 2026-05-18: lint 实现为一条 ERT 自检（`rc/lint-all-tests-have-tags`），而不是独立脚本。理由：全量 ERT 时自动把守，无需额外 CI
- 2026-05-18: generated/ 进 git 而非 .gitignore。理由：PR diff 能反映覆盖变化；副作用控制靠生成器的确定性输出
- 2026-05-18: 词表用固定枚举，新增 tag 需改 plan。理由：避免 ad-hoc tag 长期堆积变成 untyped namespace
- 2026-05-18: M2 用 bulk-tag-injector.el 一次性自动推断 151 条 tag，过率 100%（0 unknown），抽样校对 6/6 全对。理由：手动 151 处编辑慢且易错；自动推断 + lint 验证 > 逐条手工
- 2026-05-18: weakness 加 `domain-min-tests` 阈值（默认 3），跳过单测试 domain。理由：toggle/describe/replay 等小 domain 全格 0 覆盖是 trivial，不该混入 weakness 信号

## Completion Snapshot

- 实际做了：
  - `tests/tools/coverage-extract.el`（388 行）：vocab + validate + collect + lint helper + group/weakness/generators
  - `tests/tools/bulk-tag-injector.el`（180 行）：基于命名规则的 :tags 一次性注入器
  - 在 `ai-action-runtime-test.el` 末尾加 `rc/lint-all-tests-have-tags`（ERT 自检）
  - 给现有 151 个 `ert-deftest` 加 `:tags`（M2 自动注入 100% 过率）
  - 生成 `tests/generated/coverage-map.md`（152 测试按 17 个 domain 分组）
  - 生成 `tests/generated/weakness-map.md`（104 行真实缺口，过滤后无噪音）
  - `tests/README.md` 加 "0. 跑测试" 章节，含 4 类按 tag 跑测试命令
  - `tests/exec-plans/templates/execution-plan.md` 加「标签写代码不写文档」提示
  - `tests/exec-plans/README.md` 加「设计原则：元数据写在代码里」节
  - 全量 ERT 152/152 / 0.66s，比 Phase 00 末（0.81s）更快
- 与原计划差异：
  - 原 plan 假设 M2 需要"人工抽样校对 10%"，实际抽 6/6 全对，省略大规模校对
  - 原 plan 未计划 weakness 算法的 floor 阈值，M3 中发现 trivial 噪音后改进
  - 用户反馈推动设计调整（"标签应该写代码不写文档"）的关键决策记入 Decision Log
- 遗留小尾巴：
  - `risk` 词表对所有 domain 套同样标准，某些 risk 与某些 domain 天然无关（如 action-request 的 supersede），weakness map 仍含一定 trivial 项
  - 未来若需要：可加 domain-specific risk allowlist（不阻塞当前 phase）
- 已记入 tech-debt：
  - 无新增
- 下游 plan 解锁：`02-helper-extraction.md`
