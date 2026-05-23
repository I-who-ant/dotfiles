# Tests Exec Plans

这套 `exec-plans/` 体系把测试 hardening 的工作从「四份规划文档」具体化为「可执行 phase 计划」。

它对齐 `~/myCode/The_Basic_Conceptions/Skills/harness-template/docs/exec-plans/` 的目录约定，工作流如下：

```text
templates/   模板源                ← 复制新建 plan 时用
active/      进行中的 plan         ← 当前正在做的事
completed/   已完成 plan 归档      ← 关单后从 active/ 迁过来
tech-debt-tracker.md               ← 暂不阻塞但需要记一笔的债务
```

## 上下文与上层规划的关系

```text
顶层主规划（tests/ 根目录，描述「测试体系应该长什么样」）
├── README.md
├── 00-test-hardening-master-plan.md      ← 6 phase 总图
├── 01-real-call-calibration-plan.md      ← 真实调用层
└── 02-language-test-matrix.md            ← 语言矩阵

执行体系（本目录，描述「现在要做哪一步」）
└── exec-plans/
    ├── README.md
    ├── tech-debt-tracker.md
    ├── templates/
    │   └── execution-plan.md
    ├── active/                    ← 进行中的 phase；全部完成后应为空
    └── completed/                 ← 00-06 全部归档在这里
```

分工固定：

- 上层主规划 **不变更，只在每次 phase 完成后从 plan 里反向同步关键决定**
- 本目录的 plan **是真正驱动一次次施工的活页**

## 与 docs/exec-plans/ 的关系

仓库内同时存在两套 exec-plans 体系，**协调但独立**：

| 目录 | 范围 | 当前状态 |
| --- | --- | --- |
| `~/.emacs.rc/ai/docs/exec-plans/` | runtime 架构演进（unification / domains / cursor / experience-polish / experience-hardening） | phase 1-4 completed，05/06 in-progress |
| `~/.emacs.rc/ai/tests/exec-plans/` | **测试基建演进**（本目录） | phase 00-06 已完成，active/ 默认应为空 |

边界约定：

- runtime 行为变更走 `docs/exec-plans/`
- 测试结构、helper、coverage、calibration SOP 走本目录
- 两套互不嵌套；当本目录某个 plan 因 runtime 变更而需要调整，记入 Decision Log 并显式引用 `docs/exec-plans/` 的对应 plan
- 顶层主规划文档（`tests/*.md`）只属于本目录

## 设计原则：元数据写在代码里

测试相关的元数据（领域 / 风险类型 / 优先级）的 single source of truth 是 `ert-deftest` 的 `:tags`，**不是**任何 markdown 表格。

具体落地：

- 每个 `ert-deftest` 必带 `:tags`，命名空间固定：
  - `domain/<name>` 必填 1 个（complete-state / complete-trigger / ask / rewrite / ...）
  - `risk/<name>` 可多选（race / coordination / stale-cache / style / source-consistency / ...）
  - `prio/<1|2|3>` 必填 1 个（prio/3 ≈ ⭐⭐⭐）
- `tests/tools/coverage-extract.el` 是扫描器，生成派生物：
  - `tests/generated/coverage-map.md`
  - `tests/generated/weakness-map.md`
- `rc/lint-all-tests-have-tags` 是 ERT 自检，任何无 `:tags` 的测试会让全量 ERT 失败
- 派生物文件头标 `Auto-generated. Do not edit.`，不允许手工修改
- 词表是固定枚举（见 `active/01-inventory-and-coverage-map.md`），新增需改 plan

按 tag 运行测试：

```bash
emacs --batch -Q -l tests/run-all-tests.el \
  --eval '(ert-run-tests-batch-and-exit (quote (tag prio/3)))'
```

## 状态约定

每份 plan 顶部用 frontmatter 标记状态：

```text
status: planned | in-progress | blocked | completed
```

- `planned`：写好但未开工
- `in-progress`：正在做
- `blocked`：等某个前置（在 `## Risks` 标明阻塞来源）
- `completed`：已写 Completion Snapshot，准备移到 `completed/`

## 操作流程

### 新建 plan

1. 复制 `templates/execution-plan.md` 到 `active/NN-<slug>.md`
2. 编号沿用上层 master-plan 的 phase 编号；新增类型的 plan 续编
3. 填 `Goal / Scope / Context / Risks / Milestones / Validation`
4. `status: planned`

### 推进 plan

1. 把 `status` 改为 `in-progress`
2. 每完成一个 milestone 在 `Progress Log` 打勾
3. 任何超出当前 plan 范围但又必须记一笔的事，记到 `tech-debt-tracker.md`
4. 重大判断或方向变更写入 `Decision Log`

### 收尾 plan

1. 跑 `Validation` 列出的所有命令，全部绿
2. 写 `Completion Snapshot`：实际做了什么、和原计划差异、留下的小尾巴
3. `status: completed`
4. `git mv active/NN-<slug>.md completed/NN-<slug>.md`
5. 若有需要的反向同步（如 master-plan 顺序更新），在 commit message 注明

## 与全量回归的硬约束

每个 plan 收尾前必须满足：

- 全量 ERT 全绿
- `~/.emacs.rc/ai/ai-rc.el` load gate 通过
- `~/.emacs` load gate 通过
- 若该 plan 影响 complete 行为，还需一轮真实编辑 smoke

未满足以上任意一项的 plan **不允许** `completed`。

## 命名约定

- 文件名：`NN-<kebab-case-slug>.md`
- plan 内部标题：与 master-plan / calibration-plan 中相应 phase 的英文标题对齐
- 测试函数命名沿用：`rc/gptel-<domain>-<behavior>-<expected-outcome>`
