# AI Language Test Matrix

`status: planned`

## Summary

这份文档回答：

```text
各种语言当前到底测了什么、缺什么、哪些只靠 ERT 不够。
```

目的不是列清单凑热闹，而是防止后面出现这种假象：

- “我们已经测过 complete 了”
- 但实际上只测了通用状态机
- 并没有真正测某个语言的触发、followup、格式、局部风格继承

当前对应施工入口：

- 真正的多语言真实校准波次，走
  [07-multi-language-live-calibration-wave.md](/home/seeback/.emacs.rc/ai/tests/exec-plans/active/07-multi-language-live-calibration-wave.md)
- 本文件继续负责回答“每个语言现在缺什么、哪些必须 real-call”

## Dimensions

每个语言固定按三层看：

1. Rule Layer
   - trigger chars
   - line-end predicate
   - followup split style
   - mode-specific extra
2. Runtime Layer
   - request-source / trigger-source
   - cache / stale / followup / cooldown / coordination
3. Experience Layer
   - 格式
   - 空行
   - 缩进
   - 体感触发
   - 与本地代码风格一致性

## Matrix

### C / C++

#### Current Rule Coverage

- 已有：
  - `::` / `->` direct-char 规则
  - `=` trigger
  - control condition / call tail line-end 规则
  - blank-or-terminator followup
  - vertical spacing 相关 `:extra`

#### Current ERT Coverage

- 已覆盖：
  - direct-char trigger
  - line-end trigger
  - equals trigger
  - vertical spacing hint diagnostics

#### Remaining Gaps

- 缺：
  - 竞赛风 vs 工程风真实调用对比
  - 本地空行风格继承是否稳定
  - cache 命中后 C++ 块续写是否仍压扁
  - `followup-ready -> next-edit` 在 C++ 多行块场景是否稳定

#### Must Be Real-Call

- 空行风格是否贴近局部代码
- 模板/链式调用后的体感触发
- cache 命中时是否像“无需等待”

### Python

#### Current Rule Coverage

- 已有：
  - `:` line-end trigger
  - `else / finally`
  - indent-block followup
  - sibling clause / dedent split

#### Current ERT Coverage

- 已覆盖：
  - line-end trigger
  - indent followup split
  - except/finally chain split
  - python-ts parity

#### Remaining Gaps

- 缺：
  - 真实调用中缩进块 remainder 手感
  - cache/stale 对 Python block 的体验影响
  - diagnostics 是否足够解释为什么某次 dedent 被切开

#### Must Be Real-Call

- block 续写是否自然
- partial accept 后 remainder 是否符合 Python 书写节奏

### Java

#### Current Rule Coverage

- 已有：
  - `new`
  - `@Override`
  - `throws`
  - stream / lambda / method chain

#### Current ERT Coverage

- 已覆盖：
  - line-end trigger
  - java-ts parity
  - annotation/lambda/new 场景

#### Remaining Gaps

- 缺：
  - 真实 Java 文件中的类体 / 方法体触发节奏
  - 类型上下文较重时 prompt 质量
  - followup 在 Java 块结构中是否过于紧凑

#### Must Be Real-Call

- stream / lambda 续写顺手度
- class/method 风格继承

### JS / TS

#### Current Rule Coverage

- 已有：
  - web 规则
  - blank-or-terminator followup
  - concise TS/JS extra

#### Current ERT Coverage

- 当前偏少：
  - 通用 runtime 有覆盖
  - 语言专项断言密度仍不够

#### Remaining Gaps

- 缺：
  - `.` / `=>` / object literal 的专项断言
  - TS 类型上下文真实调用观察
  - concise extra 是否让结构过扁

#### Must Be Real-Call

- TS 类型上下文对体验是帮助还是噪音
- cache/stale 在 web 项目里的主观连贯性

### Emacs Lisp

#### Current Rule Coverage

- 已有：
  - `=` trigger
  - sexp-tail followup
  - local style extra

#### Current ERT Coverage

- 已覆盖：
  - equals trigger
  - followup splitter 暗含覆盖

#### Remaining Gaps

- 缺：
  - `let / when / cond` 场景专项
  - sexp tail 真实调用体感
  - prompt/context 在 Elisp 配置文件里的局部风格继承

#### Must Be Real-Call

- 当前 sexp 的顺滑续写
- 是否乱造 abstraction / helper

### Rust / Go

#### Current State

- 目前没有正式 mode-specific 规则文件
- 仍主要吃通用 runtime

#### Meaning

- 这不代表「已经支持」
- 只代表「可以先用通用路径」

#### Default Behavior On Generic Path

走通用路径时，预期行为对齐 C/C++ 矩阵但更保守：

| 维度 | 预期 |
| --- | --- |
| trigger char | 行尾 / `.` / `=` / 控制结构后 |
| followup split | blank-or-terminator |
| style hint | 仅通用 vertical spacing，不带语言专项 `:extra` |
| 真实调用预期 | 触发频率可能偏低，followup 可能切得过紧凑 |

#### Promotion Criteria

升级为定制规则前必须满足 ≥ 2 条：

- 通用路径下连续 3 次 calibration 出现同一类体感问题
- 已能写出最小可复现 ERT
- 在 calibration history 中沉淀了 ≥ 1 份 trace + summary
- 语言生态本身有 ts-mode + 流行项目支持（保证 calibration 样本数）

#### Next Step

- 先做真实调用观察（按 calibration plan 全语言轮节奏）
- 把观察结果写入 `docs/calibration-history/`
- 累计满足 Promotion Criteria 后再开独立 plan 加规则
- 加规则后才进入语言专项 ERT

## Cross-Language Shared Risks

这些是所有语言都要盯的，不是某一门专属：

- manual / auto / followup / cache-refresh source consistency
- stale cache 感知不自然
- cooldown 误伤
- company / LSP / yas 协调
- panel / inspector 看不出重点
- prompt budget 裁掉关键 slice
- style hint 存在但输出仍不贴近局部风格

## Coverage Strategy

默认策略：

- 通用状态机问题：
  - 先补通用 ERT
- 语言触发点问题：
  - 先补语言专项 ERT
- 风格 / 空行 / 局部一致性问题：
  - 先做真实调用，再提炼最小 ERT

## Acceptance Gates

这份矩阵有效的标准是：

- 你能说清某种语言问题应该去哪里补
- 你能说清某种语言当前哪些只靠 mock 不够
- 你能说清 Rust/Go 这类“未定制语言”现在处于什么支持层级

## Defaults

- 默认 C/C++、Python、Java、JS/TS、Elisp 是第一优先级
- 默认 Rust/Go 先观察真实调用，再决定是否定制规则
- 默认任何语言专项结论都应区分：
  - 规则问题
  - runtime 问题
  - 体验问题
