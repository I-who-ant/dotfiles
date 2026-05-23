# Pre-Flight Alignment

```yaml
status: completed
start-date: 2026-05-18
completion-date: 2026-05-18
phase: 00
depends-on: []
```

## Goal

在动测试结构之前，把所有「拖了但没做」的前置事项一次清掉，并把 4 份顶层规划文档之间的不一致同步好。完成后 Phase 01 inventory 才能在干净地基上开工。

## Scope

- In scope:
  - 把 `~/.emacs.rc/ai/` 初始化为 git 仓库
  - 写 `.gitignore` 屏蔽 `*.elc` 等编译产物
  - 在主分支建立 baseline tag `tests-phase-00-done`
  - 对齐 4 个核心抉择（拆分维度 / mock 层级 / 优先级驱动 / 回退保护）
  - 同步上层 4 份主规划文档之间的差异
- Out of scope:
  - 任何实际测试文件的拆分
  - 任何 helper 抽离
  - 任何新增 ERT 用例

## Context

- 上层主规划相关章节：
  - `tests/README.md` 第 3 节、第 5 节、第 10 节（待同步）
  - `tests/00-test-hardening-master-plan.md` 全文（基准）
  - `tests/01-real-call-calibration-plan.md`（待加 cadence/archiving 节）
  - `tests/02-language-test-matrix.md`（待补 Rust/Go 通用路径行为预期）
- 相关代码路径：
  - 无代码改动
- 相关 plan：
  - 是 `01-inventory-and-coverage-map.md` 的硬前置
- 约束：
  - 不破坏现有 ERT 全绿
  - 不改 runtime 代码

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| git init 触发既有 `~/.emacs.rc` 父级 git 的 submodule 警告 | 中 | 低 | 先确认父目录 git 状态再决定独立 init |
| 文档同步过程中误删 master-plan 段落 | 低 | 中 | 改前 `cp` 一份临时备份 |
| 4 抉择决定后又反悔 | 中 | 中 | 在 Decision Log 写明回退条件 |

## 4 个核心抉择

每个抉择给出选定方向 + 取舍 + 锁定时机。

### 抉择 1: 拆分维度

- 决定：**A3 - 领域为主目录，文件内用 `;;;;` section 标记风险类型**
- 理由：runtime 已经按领域拆好，测试与 runtime 对齐找代码最快；风险维度通过 section 保留可见性
- 回退条件：若 section 标记后仍无法定位 race / coordination 类 bug，再退到 A2 风险维度拆分

### 抉择 2: mock / stub / real-call 三层分工

- 决定：**新增 stub-integration 层**
  - 纯单元 mock → 状态机、协议、回归（当前已充分）
  - stub-integration → race / coordination / cooldown 时序（新增独立测试文件）
  - real-call calibration → 手感、格式、节奏（按 01-real-call-calibration-plan）
- 落地方式：03 phase 拆 complete 时建 `ai-complete-coordination-test.el` 作为 stub-integration 层
- 回退条件：若 coordination 用例长期写不出新的真实回归，则合并回 trigger-test

### 抉择 3: 优先级驱动

- 决定：**C2 风险驱动主导，C3 真实 bug 驱动持续，C1 矩阵长期兜底**
- 落地方式：04 phase 体验矩阵每个格子标 ⭐⭐⭐ / ⭐⭐ / ⭐ 风险等级，按等级排执行顺序
- 回退条件：若 ⭐⭐⭐ 全部补完后仍频繁出现新 bug，转 C1 全格补足

### 抉择 4: 失败回退与性能保护

- 决定：**每 phase 开始前打 git tag + 每 phase 结束记录 ERT 运行时长**
- Tag 命名：`tests-phase-NN-start` / `tests-phase-NN-done`
- 性能 baseline：147 用例 1.37s（2026-05-18 测得）
- 红线：单文件 > 500ms 触发再拆 / 全量 > 2.0s 触发性能调查

## Milestones

1. **M1 - git init 与基线 tag**
   - 做什么：
     - `cd ~/.emacs.rc/ai && git init -b main`
     - 写 `.gitignore`（`*.elc`、`.DS_Store`、`*~`、`#*#`、`.#*`）
     - `git add -A && git commit -m "chore: initial commit of AI runtime"`
     - `git tag tests-phase-00-start`
   - 验收：
     - `git status` clean
     - `git tag -l` 显示 `tests-phase-00-start`

2. **M2 - 抉择写入主规划**
   - 做什么：
     - 在 `tests/00-test-hardening-master-plan.md` 的 `## Defaults` 区前插入新章节 `## Locked Decisions`
     - 写入 4 个抉择的决定项与回退条件
   - 验收：
     - `grep -n "Locked Decisions" tests/00-test-hardening-master-plan.md` 命中

3. **M3 - 同步 4 份顶层文档**
   - 做什么：
     - `tests/README.md` 第 10 节改为指向 `00-master-plan` 而不是给独立施工顺序
     - `tests/README.md` 第 5 节加 P1-P4 与 master-plan 04.1-4 的映射表
     - `tests/00-master-plan` Phase 03 子文件列表添加 `ai-complete-coordination-test.el`
     - `tests/00-master-plan` Phase 04 每个 04.X 子项前加 ⭐ 风险等级
     - `tests/01-real-call-calibration-plan.md` 末尾加 `## Calibration Cadence & Archiving` 节
     - `tests/02-language-test-matrix.md` Rust/Go 段落补「通用路径预期 trigger 行为」与「升级到定制规则的判定标准」
   - 验收：
     - 4 份文档之间 grep 互查不再相互冲突
     - README 第 5 节与 master-plan 04.1-4 之间存在显式映射

4. **M4 - 基线 tag 与债务表清账**
   - 做什么：
     - 跑全量 ERT 确认仍绿
     - `git add -A && git commit -m "docs: align tests planning docs after pre-flight"`
     - `git tag tests-phase-00-done`
     - 把 `tech-debt-tracker.md` 中已在本 plan 解决的条目标记为 resolved
   - 验收：
     - ERT 全绿
     - `tests-phase-00-done` tag 存在
     - tech-debt-tracker 表格被同步过

## Validation

- Commands:
  ```bash
  emacs --batch -Q \
    -l /home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el \
    -f ert-run-tests-batch-and-exit 2>&1 | tail -5
  ```
  ```bash
  emacs --batch -Q -l /home/seeback/.emacs.rc/ai-rc.el \
    --eval '(message "load-ok")' 2>&1 | tail -3
  ```
- 手动检查:
  - 打开任意 elisp buffer，正常编辑，确认 complete 行为不退化
- 观察工具:
  - 跑前后 `M-x rc/gptel-stats` 看统计是否归零并正常累积

## Performance Budget

| Metric | Baseline | Upper Bound | Measured |
| --- | --- | --- | --- |
| 全量 ERT | 1.37s / 147 用例（旧基准，含 .elc） | 2.0s | **0.81s / 151 用例**（2026-05-18，新基准） |
| ai-rc.el load | 待测 | 1.0s | < 0.5s（瞬时返回 load-ok） |
| .emacs load | 待测 | - | 一次性返回 dot-emacs-load-ok |

> baseline 更新：之前 147 / 1.37s 是带 elc 缓存测得的旧值；本次清 elc 后真实值为 151 / 0.81s。后续 plan 以 151 / 0.81s 为基准。

## Progress Log

- [x] M1 git init + baseline tag
- [x] M2 4 抉择写入主规划
- [x] M3 4 份文档同步
- [x] M4 全量 ERT + done tag + debt 清账
- [x] 全量 ERT 全绿（151/151，0.81s）
- [x] `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- [x] `~/.emacs` load gate 通过

## Decision Log

- 2026-05-18: 选择 A3 拆分维度而不是 A1 纯领域，理由是 runtime 已经领域拆分，纯领域拆分会重复约束；用 section 保留风险视角即可
- 2026-05-18: 决定新增 stub-integration 层而不是隐式归入 ERT，理由是 race/coordination 无法用纯 mock 覆盖也不值得每次走真实调用
- 2026-05-18: 选择风险驱动而不是覆盖矩阵作为体验回归主策略，理由是 C2 在当前覆盖密度下性价比最高
- 2026-05-18: 决定打 tag 而不是开 branch 隔离每个 phase，理由是测试 hardening 流程线性，分支隔离反而增加心智成本

## Completion Snapshot

- 实际做了：
  - 修正 5 份 plan + 1 份 template 中错误的 `run-all-tests.el` 引用（计划之外的 P0 修正）
  - 在 `exec-plans/README.md` 补 `~/.emacs.rc/ai/docs/exec-plans/` 关系说明
  - `git init -b main` + `.gitignore` + 83 文件首次 commit（5ebcede）+ `tests-phase-00-start` tag
  - master-plan 插入 `## Locked Decisions` 章节（4 抉择 + 回退条件）
  - master-plan Phase 03 拆分粒度从 5 个文件改为 7 个（加 cooldown/followup/coordination）
  - master-plan Phase 04 每个 04.X 项加 ⭐ 风险评分（16 项）
  - calibration-plan 加 `Calibration Cadence & Archiving` 节（Cadence/Prepare/Archive Layout/Retention/Acceptance）
  - language-matrix Rust/Go 段补 `Default Behavior On Generic Path` + `Promotion Criteria`
  - README 第 5 节加 P1-P4 与 master-plan 04.1-4 映射表；第 10 节删施工顺序、指向 master-plan
  - 全量 ERT 151/151 / 0.81s（baseline 更新）
  - ai-rc.el + .emacs load gate 通过
  - tech-debt-tracker 中已解决条目标记 resolved
- 与原计划差异：
  - 计划假设了 `tests/run-all-tests.el` 入口，实际不存在，已修正为 `ai-action-runtime-test.el` 直加载；新建 `run-all-tests.el` 的工作下放到 Phase 03 M5
  - 计划写的 baseline 是 147 / 1.37s，实际清 elc 后是 151 / 0.81s，已在 plan 中更新
  - 计划没料到 `~/.emacs.rc/ai/docs/exec-plans/` 已经存在，已在 README 中显式标明两套 exec-plans 协调但独立
- 遗留小尾巴：
  - .emacs load 实际经过 emacs 全套配置加载（lsp / org / keys / shadow 等），不算严格的 P0 验证；后续 phase 若 plan 影响加载顺序需重测
- 已记入 tech-debt：
  - 无新增（M3 期间没引入新债务）
- 下游 plan 解锁：`01-inventory-and-coverage-map.md`
