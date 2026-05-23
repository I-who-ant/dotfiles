# Helper Extraction

```yaml
status: completed
start-date: 2026-05-18
completion-date: 2026-05-18
phase: 02
depends-on: [01-inventory-and-coverage-map]
```

## Goal

把测试基建（helper / fake / stub）从 `ai-action-runtime-test.el` 顶部抽离到独立的 `helpers/` 模块。完成后后续每一个 phase 拆出的子测试文件可以直接复用同一套基建，新写真实 bug 回归的成本明显降低。

## Scope

- In scope:
  - 新建 `tests/helpers/ai-test-helpers.el`
  - 从主测试文件迁出 7 个公共 helper（见下）
  - 让主测试文件通过 `(require 'ai-test-helpers)` 等价复用
  - 保持全量 ERT 仍在同一命令下跑通
  - 同步顺手解决 `--plist-inc` 从 observe 迁到 core（tech-debt 表中一条）
- Out of scope:
  - 不拆领域用例（留给 Phase 03）
  - 不新增任何用例
  - 不修 helper 行为，只搬位置

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase 02 Helper Extraction
- 相关代码路径：
  - `tests/ai-action-runtime-test.el` 顶部 helper 区
  - 待建：`tests/helpers/ai-test-helpers.el`
- 相关 plan：
  - 依赖 `01-inventory-and-coverage-map.md` 完成（helper 真实使用频率统计）
  - 解锁 `03-complete-domain-split.md`
- 约束：
  - load gate 不退化
  - 测试覆盖范围与行为不变

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| 抽离后 helper 与领域用例之间形成循环依赖 | 中 | 高 | helper 模块严格不 require 领域测试模块 |
| ELC 缓存导致旧 helper 被加载 | 中 | 中 | 修改后强制 `find tests -name "*.elc" -delete` 再跑 |
| `--plist-inc` 迁移时调用点漏改 | 中 | 中 | 迁移前 `grep -rn "\-\-plist-inc"` 列全调用点 |
| helper 接口扩到过粗 | 中 | 中 | 每个 helper 保持单一职责，不在迁移期添加新形参 |

## 待迁移 Helper 清单

来自顶层主规划：

```text
rc/test-gptel-ensure-autocomplete
rc/test-gptel-reset-runtime
rc/test-gptel-reset-observe-global
rc/test-gptel-visible-completion
rc/test-gptel-last-lifecycle-event
rc/test-gptel-last-end-reason
rc/test-gptel-stub-request-context
```

来自 Phase 01 真实统计（M1 完成后回填）：

```text
(待补)
```

## Milestones

1. **M1 - helpers 模块骨架**
   - 做什么：
     - 新建 `tests/helpers/ai-test-helpers.el`
     - 顶部 `(provide 'ai-test-helpers)`
     - 仅 require 测试用到的标准库，不 require 任何 runtime 模块
   - 验收：
     - `emacs -Q --batch -l tests/helpers/ai-test-helpers.el` 不报错

2. **M2 - 迁移 7 个核心 helper**
   - 做什么：
     - 把主测试文件顶部 7 个 helper 复制进 helpers 模块
     - 主测试文件顶部加 `(require 'ai-test-helpers)`
     - 删主测试文件里的旧定义
   - 验收：
     - 全量 ERT 全绿
     - 主测试文件行数减少（记录前后 wc -l）

3. **M3 - 顺手迁 `--plist-inc`**
   - 做什么：
     - `grep -rn "\-\-plist-inc" .` 列调用点
     - 把定义从 `observe.el` 搬到 `core/ai-core-rc.el`（与 `--alist-inc` 对称）
     - 更新所有调用点
   - 验收：
     - 全量 ERT 全绿
     - tech-debt-tracker 中 observe 条目标记 resolved

4. **M4 - 抉择性扩展 helpers**
   - 做什么：
     - 根据 Phase 01 weakness map，预先抽几个会被 Phase 04 重复用到的 helper
       - 候选：`rc/test-gptel-with-stub-network`、`rc/test-gptel-fake-late-response`
   - 验收：
     - 每个新 helper 至少有 1 处实际使用（不写 TODO 占位）

5. **M5 - 全量验证 + done tag**
   - 做什么：
     - 全量 ERT
     - load gate
     - `git tag tests-phase-02-done`
   - 验收：
     - ERT 0.81s 量级保持
     - tag 已建

## Validation

- Commands:
  ```bash
  find ~/.emacs.rc/ai/tests -name "*.elc" -delete && \
    emacs --batch -Q \
      -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
      -f ert-run-tests-batch-and-exit 2>&1 | tail -5
  ```
  ```bash
  cd ~/.emacs.rc/ai && \
    grep -rn "\-\-plist-inc" . 2>&1 | grep -v "\.elc"
  ```
- 手动检查:
  - 打开 `tests/helpers/ai-test-helpers.el`，确认无 runtime 反向 require
- 观察工具:
  - 无需 runtime 观察

## Performance Budget

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | 0.81s / 151 用例（Phase 00 末） | 1.2s（允许首次 require 的轻微开销） | |
| 主文件行数 | 2768 | 减至 2500 以下 | |

## Progress Log

- [x] M1 helpers 模块骨架
- [x] M2 迁移 7 个核心 helper
- [x] M3 `--plist-inc` 迁到 core
- [~] M4 抉择性扩展 helpers（基于 weakness map）— **deferred to Phase 03**
- [x] M5 全量验证 + done tag
- [x] 全量 ERT 全绿
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-18: M1 + M2 合并执行（建文件 + 删主文件 7 处 helper + 加 load）。理由：两步无中间状态，合并能保持 ERT 一致绿
- 2026-05-18: M3 把 `rc/gptel-complete-observe--plist-inc` 同时更名为 `rc/gptel--plist-inc`。理由：与 `rc/gptel--alist-inc` 对称，core 层不应保留 observe 前缀
- 2026-05-18: M4 deferred 到 Phase 03。理由：Phase 01 weakness map 显示的真实缺口（race / coordination 类）需要 stub-network / fake-late-response 类 helper，但这些应该在 Phase 03 建 `coordination-test.el` 时一并设计，提前抽出来等于无消费者
- 2026-05-18: helpers 文件不 load `ai-rc.el`，由主测试文件负责。理由：helpers 是纯函数模块，避免重复 load 副作用

## Completion Snapshot

- 实际做了：
  - 新建 `tests/helpers/ai-test-helpers.el`（95 行，7 个 helper 各自分 section）
  - 主测试文件 `ai-action-runtime-test.el` 删除 60 行 helper 定义，改成 1 行 `(load .../tests/helpers/ai-test-helpers.el)`
  - `rc/gptel-complete-observe--plist-inc` 迁到 `core/ai-core-rc.el:76`，更名为 `rc/gptel--plist-inc`
  - 唯一调用点 `complete/ai-complete-observe-rc.el:83` 同步更新
- 与原计划差异：
  - M4 推迟到 Phase 03（见 Decision Log）
  - 原 plan 估算「主文件行数减至 2500 以下」，实际从 2877 减到 2876（净减 60 行 helper 但加了 :tags 和 lint，total 仍偏高；真正大减要等 Phase 03 拆分）
- 遗留小尾巴：
  - 主文件仍含 151 个测试 + lint，需要 Phase 03 拆分
  - coordination 层的 stub helper 留给 Phase 03
- 已记入 tech-debt：
  - 无新增；resolved `observe --plist-inc` 一条
- 下游 plan 解锁：`03-complete-domain-split.md`
