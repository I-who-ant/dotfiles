# AI Real-Call Calibration Plan

`status: completed`

## Summary

这份计划只回答一件事：

```text
真实模型调用应该怎么测，才能帮助我们发现体验问题，
并把这些问题稳定沉淀回测试体系。
```

它不是 ERT 替代品。

它和 ERT 的分工固定如下：

- ERT:
  - 保证状态机、协议、回归路径稳定
- real-call calibration:
  - 发现 mock 测不出来的手感、格式、节奏、协作问题

## Why It Must Exist

以下问题，只有真实调用最容易暴露：

- ghost 出现得对不对劲
- stale -> fresh 主观上是否闪
- cache 命中了，体感却像重新等了一轮
- 空行、缩进、局部格式是否被压扁
- company / LSP / yas 同时活着时，complete 是否烦人
- prompt diagnostics 看起来合理，但模型真实输出还是别扭

如果没有真实调用层，就会出现两种假稳定：

- `ERT 全绿，但日用还是别扭`
- `偶尔手工测一下，但问题没法沉淀回归`

## Scope

这份计划固定只覆盖：

- complete 主战场
- 必要时观察 ask / rewrite 对共享观察层的影响
- 真实项目中的真实调用

默认不做：

- 真网络自动化
- 长时间无人值守批量调用
- 依赖外部 CI 的线上 smoke

## Why It Is Not A CI Layer

很多人看到“真实调用层”就会顺手问一句：

```text
既然真实调用最重要，为什么不直接做成 CI 里的自动化真调用测试？
```

答案是：因为这两层解决的问题根本不同。

- ERT / stub-integration 要解决的是：
  - 状态机是否正确
  - 已知回归是否再次出现
  - 某个连接点在确定输入下是否稳定输出确定状态
- real-call calibration 要解决的是：
  - 真实 buffer 里这段 ghost 看起来顺不顺
  - 空行、缩进、局部风格是不是被压扁
  - company / LSP / yas 同时活着时是不是烦人
  - inspector / panel / trace 到底能不能解释刚才那一下怪行为

后面这些问题并不适合直接做成“无人值守 + 真网络 + 自动判分”的 CI，原因固定有 4 个：

1. 输出文本天然带波动
   - 同一个 prompt 可能给出不同但都合理的补全
   - 你真正想评估的往往不是“字面完全一致”，而是节奏、风格、压缩感
2. 外部依赖不稳定
   - provider、模型版本、网络、限流、账号状态都会引入外部噪音
   - 这类噪音会把“runtime 退化”与“外部环境波动”搅成一团
3. 很多体验判断需要人眼
   - `stale -> fresh` 到底是平滑还是闪
   - cooldown 是“合理克制”还是“误伤”
   - 这些很难靠一个 batch 断言说死
4. 成本模型不同
   - 真调用要耗 token、耗时间、耗外部配额
   - 适合做波次校准，不适合作为每次提交的硬门

所以这套设计故意分层：

- ERT / stub-integration：
  - 负责可重复、可自动判分、可作为 gate 的确定性回归
- manual smoke / calibration run：
  - 负责真实 buffer 里的体感与观测闭环
- bug reproduction run：
  - 负责把某次真实异常压缩成最小 live 证据，再反推 ERT

一句话：

```text
真实调用必须做，但不该伪装成“全自动、可稳定判分”的 CI 主层。
```

## Test Layers

真实调用层内再分三类：

### 1. Manual Smoke

最轻的层。

目的：

- 每次关键改动后，快速确认没把日用体验搞烂

特点：

- 5~10 分钟
- 只挑 1~2 个语言
- 只看最关键路径

### 2. Calibration Run

主力层。

目的：

- 用真实编辑工作流发现体验问题

特点：

- 每门语言约 30 分钟
- 带 stats / trace / panel / inspector / prompt diagnostics
- 会产出结论和后续回归候选

### 3. Bug Reproduction Run

定点层。

目的：

- 已知怪行为出现后，做最小真实复现

特点：

- 只针对一个 bug
- 要求导 trace
- 最后要反推一个最小 ERT 候选

## Construction Order

固定顺序：

1. 先定义真实调用记录模板
2. 再定义每语言最小场景集
3. 再定义“哪些异常必须回流到 ERT”
4. 最后把结果写回 calibration / tests 文档

## Required Observation Tools

真实调用时，默认配套这些工具：

- `C-c a i`
  - 看当前 action inspector
- `C-c a o`
  - 看统一 panel
- `M-x rc/gptel-stats`
  - 看当前 buffer + global 统计
- `M-x rc/gptel-export-recent-ai-trace`
  - 导最近 trace
- `M-x rc/gptel-replay-ai-trace`
  - 重放摘要
- `M-x rc/gptel-describe-current-complete-prompt`
  - 看 prompt/context/style hint

## Per-Language Minimum Scenarios

每个语言真实调用，至少都跑下面这些。

### Common Scenario A: Normal Line-End Continuation

- 在函数体里写到一半
- 在调用链尾部停住
- 在 `if / for / while / lambda / return` 后续写

看：

- trigger 是否自然
- ghost 是否像“本来就该出现在这里”
- 是否过度等待

### Common Scenario B: Accept / Partial Accept

- `TAB`
- `M-f`
- `M-l`
- `S-<return>`
- `C-S-<return>`

看：

- full / partial accept 是否符合预期
- remainder 是否顺
- continuation 是否太烦或太弱

### Common Scenario C: Cache / Revisit

- 在一个位置触发
- 离开
- 回到相近上下文
- 再触发

看：

- exact / prefix hit 是否明显
- 是否还是等整轮请求
- stale -> fresh 替换是否平滑

### Common Scenario D: Divergence / Restore

- ghost 出来后继续打字
- 输入兼容前缀
- 输入不兼容前缀
- 再删除回来

看：

- visible 是否保留
- restore 是否自然
- end-reason 是否合理

### Common Scenario E: Formatting / Vertical Spacing

- 在本地代码附近本来就有块间空行的位置触发
- 在本地代码本来很紧凑的位置触发

看：

- 是否压扁空行
- 是否乱加空行
- `prompt diagnostics` 是否有 style hint

## Language-Specific Focus

### C / C++

重点：

- `=`
- `::`
- `->`
- `if / for / while`
- 竞赛风紧凑代码
- 工程风分段代码

特别观察：

- 空行风格是否被压扁
- 模板 / 调用链触发是否自然

### Python

重点：

- `:`
- `else / finally`
- 缩进块续写
- dedent followup

特别观察：

- followup 是否保住块边界
- sibling clause 是否切分合理

### Java

重点：

- `new`
- `@Override`
- `throws`
- stream / lambda / method chain

特别观察：

- 触发点是否太保守
- 块结构是否贴近本地 Java 风格

### JS / TS

重点：

- `.`
- `=>`
- object literal / call tail
- type-heavy TS 场景

特别观察：

- concise 倾向是否把结构压得太紧
- TS 类型上下文有没有帮助而不是干扰

### Emacs Lisp

重点：

- `(`
- `let / when / cond`
- sexp tail continuation

特别观察：

- 是否顺着当前 sexp 续
- 是否乱造 abstraction

## Required Outputs Per Run

每次 calibration run 后，至少要产出：

1. 一段 5~10 行结论
2. 一份 stats 摘要
3. 至少一个 trace（如果出现怪行为）
4. 至少一个“是否需要补 ERT”的判断

## When A Real-Call Finding Must Flow Back To ERT

满足任意一条，就不能只留在手工观察里：

- 能稳定复现
- 能提炼出最小输入条件
- 属于 runtime bug，而不是纯模型随机差异
- 会影响状态、自洽性、cache、coordination、style hint、panel/inspector 可解释性

典型例子：

- manual 请求串上旧 `trigger-source`
- stale cache 该命中却明显重等
- vertical spacing hint 已存在，但 prompt/context 没带进去
- late response 在 timeout 之后错误复活

## Acceptance Gates

这层规划落地后，必须能做到：

- 每个语言有最小真实调用场景
- 每次真实调用知道该看哪些工具
- 出现异常时知道何时必须回流到 ERT
- calibration 结果能写回文档而不是停留在口头

## Defaults

- 默认 complete 是真实调用主战场
- 默认每轮只选 1~2 个最值得怀疑的语言重点盯
- 默认任何体验问题优先先导 trace，再下结论

## Calibration Cadence & Archiving

> 这一节将「真实调用」从「凭记忆做」固化为「按节奏做、按格式归档」。SOP 已落地，见 `exec-plans/completed/06-calibration-to-regression-workflow.md` 与 `docs/calibration-history/`。

### Cadence

| 节奏 | 内容 | 时机 |
| --- | --- | --- |
| Manual Smoke | 5~10 分钟，1~2 个语言，最关键路径 | 每次 phase 完成、每次 runtime 改动后 |
| 重点语言轮 | 单语言 30 分钟，跑完 Common Scenario A~E | 每周对 C/C++、Python、Elisp 至少 1 次 |
| 全语言轮 | 全 5 大语言 + Rust/Go 通用路径 | 每月 1 次 |
| Bug Reproduction | 单 bug 定点，导 trace + 抓 stats + 最小复现 | 出现怪行为时立即 |

### Prepare Checklist

calibration 开始前确认：

1. API key / 网络 / 配额可用
2. 关闭测试 stub（`gptel-use-curl` 等 stub 变量不在 override 状态）
3. 记录模型版本与 temperature（写入本次 summary）
4. 关闭 minibuffer 占用
5. 进入目标语言的真实项目，准备真实文件

### Archive Layout

每轮 calibration 落到 `docs/calibration-history/YYYY-MM-DD/` 下：

```text
docs/calibration-history/
└── 2026-05-18/
    ├── summary.md                # 5-10 行结论 + 模型版本 + temperature
    ├── stats.txt                 # rc/gptel-stats snapshot
    ├── trace-c++-cache-001.json  # 每个异常导一份 trace
    └── trace-python-followup-002.json
```

命名规则：
- 摘要文件固定 `summary.md` / `stats.txt`
- trace 文件 `trace-<lang>-<scenario>-<seq>.json`

`.gitignore` 已排除原始 trace dump（避免污染 commit），但 `summary.md` / `stats.txt` 要进版本控制。

### Retention

- 30 天内的 calibration 完整保留
- 30 天前只保留 `summary.md`，trace JSON 清理
- 任何已经回流到 ERT 的 bug，其 trace 可立即清理（ERT 已经是稳定证据）

### Acceptance Gates

- 每月至少 1 份完整 `docs/calibration-history/YYYY-MM-DD/`
- 每份 summary 都给出「是否需要回流 ERT」的判断
- 回流到 ERT 的用例在 commit message 中显式引用 calibration 日期
- 当前已落地模板案例：
  - `2026-05-18 / ui-panel-rewrite-bleed-001`
  - `2026-05-19 / complete-clear-indicator-001`
