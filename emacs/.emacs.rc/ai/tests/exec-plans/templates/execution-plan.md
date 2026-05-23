# <Execution Plan Title>

```yaml
status: planned
start-date:
completion-date:
phase: NN
depends-on: []
```

> **设计原则提醒**：测试相关的元数据（领域 / 风险 / 优先级）默认写在 `ert-deftest` 的 `:tags` 里。任何新增 / 拆分测试都必须打 tag，未打 tag 会被 `rc/lint-all-tests-have-tags` 自检在全量 ERT 时失败。
> 派生文档（coverage-map / weakness-map）由 `tests/tools/coverage-extract.el` 生成，不要手工编辑。

## Goal

用一段话讲清楚这份 plan 完成后世界长什么样。结果导向，不要写成「我要做 X」而写「世界会变成 Y」。

## Scope

- In scope:
  - 列出本 plan 真正会改动的文件 / 行为 / 结构
- Out of scope:
  - 列出容易被牵进来但本 plan 不碰的事

## Context

- 上层主规划相关章节：
  - `tests/00-test-hardening-master-plan.md` Phase NN
- 相关代码路径：
  - `path/to/file.el`
- 相关 plan：
  - `active/NN-...md`（如有依赖）
- 约束：
  - 列出 plan 必须遵守的硬约束

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| | | | |

## Milestones

固定按里程碑切片，每个 milestone 自带验收条件。

1. **M1 - <短标题>**
   - 做什么：
   - 验收：
2. **M2 - <短标题>**
   - 做什么：
   - 验收：
3. **M3 - <短标题>**
   - 做什么：
   - 验收：

## Validation

每个 milestone 收尾前要跑完这一组。

- Commands:
  ```bash
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
    -f ert-run-tests-batch-and-exit
  ```
- 手动检查:
  - 例如：随便打开一个 elisp / python / cpp buffer 触发 complete，看 ghost 是否正常
- 观察工具:
  - `C-c a i` inspector
  - `C-c a o` panel
  - `M-x rc/gptel-stats`

## Performance Budget

如果本 plan 影响测试运行时长或加载时长，记录 baseline 与上限。

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | 0.81s / 151 用例 | 2.0s | |
| ai-rc.el load | 待测 | 1.0s | |

## Progress Log

- [ ] M1
- [ ] M2
- [ ] M3
- [ ] 全量 ERT 全绿
- [ ] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [ ] `~/.emacs` load gate 通过

## Decision Log

- YYYY-MM-DD: 决策内容 / 理由 / 影响

## Completion Snapshot

> 关单时填写，写完才能从 `active/` 移到 `completed/`。

- 实际做了：
- 与原计划差异：
- 遗留小尾巴：
- 已记入 tech-debt：
- 下游 plan 解锁：
