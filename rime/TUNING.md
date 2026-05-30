# Rime 调参手册

这份手册只回答三件事：

1. 现在哪些旋钮在生效
2. 日常遇到什么现象时该改哪里
3. 每个改动大概会带来什么体感

---

## 当前默认档位：平衡档

当前核心配置在：

- `.local/share/fcitx5/rime/rime_ice.custom.yaml`

当前默认值：

```yaml
patch:
  translator/dictionary: rime_ice_seeback
  grammar:
    language: wanxiang-lts-zh-hans
    collocation_max_length: 4
    collocation_min_length: 2
  translator/contextual_suggestions: true
  translator/enable_completion: false
  translator/enable_word_completion: false
  translator/max_homophones: 5
  translator/max_homographs: 5
  long_word_filter/count: 1
  long_word_filter/idx: 5
  custom_phrase/user_dict: tech_phrase
```

这套默认目标：

- 单字 / 单音节时别太自作主张
- 普通技术词正常出现
- 句子层仍保留一点上下文排序
- 快捷码继续可用

---

## 三层结构：先判断你该改哪层

### 1. 行为层
文件：`rime_ice.custom.yaml`

负责：

- 上下文排序
- 自动补全
- 候选发散程度
- 长词优先强度

一句话：

> 候选太主动、太死板、太乱、太爱推长词，都先看这里。

---

### 2. 快捷码层
文件：`tech_phrase.txt`

负责：

- 自定义缩写
- 必杀快捷码
- 我明确想秒出的词

一句话：

> 想让某个长技术词用缩写一把打出来，就改这里。

注意：

- 这里不要再放“完整拼音”的普通术语
- 否则又容易回到“打一小段就霸位”的老问题

---

### 3. 普通技术词层
文件：`mytech.dict.yaml`

负责：

- 数学术语
- 算法术语
- 编译器术语
- 系统 / 桌面 / 嵌入式术语
- Agent / LLM / Tooling 术语
- 技术写作用句

一句话：

> 某个专业词应该正常出现，但现在不好打，就改这里。

---

## 旋钮总表

### A. 上下文排序
文件：`rime_ice.custom.yaml`

```yaml
translator/contextual_suggestions: true
```

#### 开 `true`
- 句子更顺
- 更像懂上下文
- 但稍微更主动

#### 关 `false`
- 更朴素
- 更听话
- 但整句会笨一点

#### 什么时候动
- 觉得整句太死板 → 开
- 觉得它还是老想替你做主 → 关

---

### B. 短前缀补全
文件：`rime_ice.custom.yaml`

```yaml
translator/enable_completion: false
translator/enable_word_completion: false
```

#### 当前建议
默认都关。

#### 为什么
这是最容易导致下面这种现象的来源：

- 我只打了一个字 / 一个音节
- 它就把长词塞到第 1 位
- 还逼我去选第 2 个

#### 什么时候动
只有当你明确想恢复“更智能的前缀补全”时再开。

---

### C. 候选发散程度
文件：`rime_ice.custom.yaml`

```yaml
translator/max_homophones: 5
translator/max_homographs: 5
```

#### 调大，比如 6 / 7
- 候选更多
- 更容易碰到冷门词
- 但更乱

#### 调小，比如 4
- 候选更收敛
- 更省选择成本
- 但有时会漏词

#### 当前建议
- 默认：`5`
- 觉得乱：降到 `4`
- 觉得不够：升到 `6`

---

### D. 长词优先
文件：`rime_ice.custom.yaml`

```yaml
long_word_filter/count: 1
long_word_filter/idx: 5
```

#### 当前含义
- 只轻微提升少量长词
- 尽量别干扰前几候选

#### 更保守
```yaml
long_word_filter/count: 0
```

#### 更积极
```yaml
long_word_filter/count: 2
long_word_filter/idx: 4
```

#### 什么时候动
- 还是觉得长词爱往前拱 → 再减
- 觉得长技术词太难上来 → 稍微加

---

### E. grammar 介入强度
文件：`rime_ice.custom.yaml`

```yaml
grammar:
  language: wanxiang-lts-zh-hans
  collocation_max_length: 4
  collocation_min_length: 2
```

#### `collocation_max_length`
- 大一点：更看重整句搭配
- 小一点：更偏局部词

#### 当前建议
- 默认 `4`
- 如果还是觉得太像“替你脑补句子”，可降到 `3`

#### `collocation_min_length`
- `2` 已经比较稳妥
- 一般不用乱动

---

## 什么放进 `tech_phrase.txt`

适合放：

- 自定义缩写
- 高频长词快捷码
- 私人定制输入码

例如：

```text
时间复杂度	sjfzd	100
抽象语法树	cxyfs	100
后缀自动机	hzzdj	100
```

不适合放：

```text
强化学习	qiang hua xue xi	100
抽象语法树	chou xiang yu fa shu	100
```

因为这些完整拼音词条会重新造成霸位。

---

## 什么放进 `mytech.dict.yaml`

适合放：

- 你日常正常全拼会输入的专业词
- 技术写作常用句
- 学科术语
- 框架 / 系统术语

例如：

```text
增量分析	zeng liang fen xi	1000
设备树	she bei shu	1000
上下文工程	shang xia wen gong cheng	1100
```

经验：

- 想“正常出现” → 放 `mytech`
- 想“缩写秒出” → 放 `tech_phrase`

---

## 常见症状 -> 怎么调

### 症状 1：打一两个字，长词又开始抢第一
优先检查：

- `translator/enable_completion`
- `translator/enable_word_completion`
- `tech_phrase.txt` 里是不是又塞回了完整拼音词条

必要时：

- `long_word_filter/count` 再往下减

---

### 症状 2：整句太死板
优先改：

```yaml
translator/contextual_suggestions: true
```

如果还嫌死板，可保守地把 `collocation_max_length` 从 `4` 试到 `5`。

---

### 症状 3：候选太乱
优先改：

```yaml
translator/max_homophones: 4
translator/max_homographs: 4
```

---

### 症状 4：专业词出不来或太靠后
先判断：

- 这是“普通词”还是“我要秒出”

处理：

- 普通词 → `mytech.dict.yaml`
- 秒出词 → `tech_phrase.txt`

---

### 症状 5：技术写作句子不顺
先保持：

- `contextual_suggestions: true`

再观察：

- `grammar.collocation_max_length`
- `mytech.dict.yaml` 里是否缺少技术写作用句

---

## 推荐工作流

### 加一个普通术语
1. 改 `mytech.dict.yaml`
2. 重新部署 Rime
3. 用 `REGRESSION.md` 测一轮

### 加一个快捷码
1. 改 `tech_phrase.txt`
2. 重新部署 Rime
3. 直接测缩写码

### 调整体手感
1. 改 `rime_ice.custom.yaml`
2. 重新部署 Rime
3. 重点测：
   - 单字 / 单音节
   - 技术词
   - 技术句子

---

## 建议保守顺序

当你想继续调时，建议顺序：

1. 先改 `mytech.dict.yaml`
2. 再改 `tech_phrase.txt`
3. 最后才改 `rime_ice.custom.yaml` 的行为旋钮

因为：

- 词库层最可控
- 快捷码层收益最高
- 行为层影响最大，容易一改全局手感都变

---

## 最后一句口诀

- 候选太主动 → 改 `custom.yaml`
- 缺普通专业词 → 改 `mytech.dict.yaml`
- 想给词配缩写 → 改 `tech_phrase.txt`
- 改完怕翻车 → 跑 `REGRESSION.md`
