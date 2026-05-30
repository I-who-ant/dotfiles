# Rime 技术词库回归清单

这份清单用于每次调整以下内容后快速回归：

- `rime_ice.custom.yaml`
- `tech_phrase.txt`
- `mytech.dict.yaml`
- `rime_ice_seeback.dict.yaml`
- `wanxiang-lts-zh-hans.gram`

---

## 使用方法

1. 重新部署 Rime
2. 依次输入下面测试项
3. 观察三件事：
   - 技术词能不能出来
   - 技术词是不是排在前面
   - 候选是不是被日常口语词抢走

---

## A. 强置顶短语测试（`tech_phrase.txt`）

这些词应当非常靠前，通常在前几候选：

- 线性代数
- 偏微分方程
- 拉格朗日乘子法
- 时间复杂度
- 空间复杂度
- 红黑树
- 单调栈
- 后缀自动机
- 抽象语法树
- 虚拟内存
- 大语言模型
- 提示工程

---

## B. 扩展词库测试（`mytech.dict.yaml`）

这些词不要求像强置顶那样绝对第 1，但应当稳定出现且排序不错：

### 数学 / 数理
- 奇异值分解
- 主成分分析
- 极大似然估计
- 协方差矩阵
- 梯度向量
- 海森矩阵
- 凸优化

### 算法 / 数据结构
- 可持久化线段树
- 树链剖分
- 强连通分量
- 二分图匹配
- 最小生成树
- AC 自动机
- 滚动哈希

### Agent / LLM
- 上下文工程
- 多 Agent 协作
- 工具契约
- 控制面
- 运行时桥接
- 插件生命周期

### 编译器 / IDE
- 预处理器
- 宏展开
- 指定初始化器
- 柔性数组成员
- 位字段
- 红绿树
- 增量分析
- Piece Table
- Gap Buffer

### 系统 / 桌面 / 嵌入式
- 设备树
- Bootloader
- GPIO
- Unix 域套接字
- D-Bus
- socket 激活
- systemd 用户服务

---

## C. 技术写作句子测试

这些句子用于观察“整句排序”和“日常味是否过强”：

- 该算法的核心思想是
- 可以将问题转化为
- 在极端情况下
- 时间复杂度为
- 空间复杂度为
- 工程上通常会采用
- 这里的关键在于
- 需要注意的是

期望：

- 句子能顺畅上屏
- 不要总被生活化短语抢候选
- 语法模型存在感应当减弱，但不至于完全变笨

---

## D. 英文 / 缩写混输测试

- Transformer
- Rope
- Piece Table
- Gap Buffer
- BootROM
- Bootloader
- D-Bus
- QueryEngine
- systemd user
- Unix domain socket

期望：

- 英文词能稳定出来
- 不要被奇怪拼音词严重压制
- 中英混输时不要明显卡顿

---

## E. 反例观察

如果出现下面现象，说明还要继续调：

- 技术词根本不出现 → 先查 `mytech.dict.yaml` / `rime_ice_seeback.dict.yaml`
- 技术词出现但总排很后 → 提升 `mytech` 词频，或放进 `tech_phrase.txt`
- 整句总往口语表达拐 → 继续弱化 grammar，或暂时去掉 grammar 做对照
- 用久了越来越怪 → 检查 `*.userdb/` 的学习偏差

---

## F. 建议节奏

- 高频固定术语：加到 `tech_phrase.txt`
- 一般技术词：加到 `mytech.dict.yaml`
- 先跑一周，再决定要不要继续调 grammar
