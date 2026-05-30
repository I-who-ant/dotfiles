# Rime

这个模块只收 `Rime` 的自定义层，不收机器态数据。

当前策略：

- 收 `default.custom.yaml`
- 收 `rime_ice.custom.yaml`
- 收 `tech_phrase.txt`
- 收 `mytech.dict.yaml`
- 收 `rime_ice_seeback.dict.yaml`
- 可选收 `wanxiang-lts-zh-hans.gram`
- 不收 `build/`、`*.userdb/`、`sync/`、`installation.yaml`、`user.yaml`

## 模块结构

```text
rime/
  README.md
  .local/share/fcitx5/rime/
    .gitignore
    default.custom.yaml
    rime_ice.custom.yaml
    tech_phrase.txt
    mytech.dict.yaml
    rime_ice_seeback.dict.yaml
    wanxiang-lts-zh-hans.gram   # optional
```

## 分层思路

当前把自定义拆成三层：

- `rime_ice.custom.yaml`
  - 负责行为 patch
  - 例如 grammar、contextual suggestions、主词典切换
- `tech_phrase.txt`
  - 负责“强置顶”的个人高频术语
  - 适合数学、算法、LLM、系统等固定短语
- `mytech.dict.yaml`
  - 负责“可参与正常候选与造词”的扩展技术词库
  - 适合更大规模的技术词与技术写作短句
- `rime_ice_seeback.dict.yaml`
  - 负责把 `mytech` 挂到 `rime_ice` 的主词典链路里
  - 相当于个人 overlay

这样做的好处是：

- 高频专业词走 `tech_phrase.txt`，直接置顶
- 更广的技术词走 `mytech.dict.yaml`，不必全塞进短语表
- 行为和词库分开，后续调参更清楚

## 为什么收这些文件

因为这些文件都满足几个特点：

- 手工维护
- 体积小
- 可读
- 跨机器可复用
- 不依赖本机学习状态

相比之下，下面这些不适合进仓库：

- `build/`
- `*.userdb/`
- `sync/`
- `user.yaml`
- `installation.yaml`
- `rime-ice/.git`

它们分别对应：

- 编译产物
- 用户词频与学习状态
- 同步缓存
- 机器唯一状态
- 第三方仓库元数据

## `gram` 怎么处理

当前机器的 `wanxiang-lts-zh-hans.gram` 大约 200 MB。

所以它是可选项：

- 想要完整复现候选排序效果：收它
- 想让仓库保持轻量：不收它，只在 README 里记录来源和放置路径

当前默认选择是：

- 先不纳入仓库
- 由本地手工放到 `~/.local/share/fcitx5/rime/`

下载链接：

- https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram

## 调参与维护

- `TUNING.md`：当前这套 Rime 的调参手册，说明各个旋钮怎么影响体感、什么时候该改哪层。
- `REGRESSION.md`：每次调整词库、grammar、custom phrase 后，用它做一轮快速回归。


## 当前调参档位

当前默认是“平衡档”：

- `translator/contextual_suggestions: true`
  - 保留一定上下文排序能力
- `translator/enable_completion: false`
  - 禁止短前缀自动补全抢位
- `translator/enable_word_completion: false`
  - 禁止长词自动补全抢位
- `long_word_filter/count: 1`
- `long_word_filter/idx: 5`
  - 仅轻微提升长词，尽量不干扰前几候选

适合当前目标：

- 单字 / 单音节时别太自作主张
- 技术词仍能正常出现
- 完整句子仍保留一点上下文排序

## 当前 patch 入口

当前模块里最重要的是这几份文件：

- `default.custom.yaml`
- `rime_ice.custom.yaml`
- `tech_phrase.txt`
- `mytech.dict.yaml`
- `rime_ice_seeback.dict.yaml`

## 从本机 live 配置同步回仓库

如果当前机器没有用 `stow`，推荐把本机 live 配置当作源头，再手动同步回仓库：

```bash
./scripts/sync-rime-from-live.sh
```

只预览不落盘：

```bash
./scripts/sync-rime-from-live.sh --dry-run
./scripts/sync-module-from-live.sh rime
```

默认只同步这些文件：

- `default.custom.yaml`
- `rime_ice.custom.yaml`
- `tech_phrase.txt`
- `mytech.dict.yaml`
- `rime_ice_seeback.dict.yaml`

不会同步：

- `build/`
- `*.userdb/`
- `sync/`
- `installation.yaml`
- `user.yaml`

同步后脚本会自动输出当前 `git status` 和 `git diff`。

补充：

- 总控脚本现在默认对多数模块采用“只回写仓库已跟踪文件”的保守策略
- `rime` 仍然使用显式白名单，不会把 `build/`、`*.userdb/` 这类运行态内容带进来
- 如果文件里出现明显敏感信息或临时挂载路径，同步脚本会直接跳过并报警

## 新机器恢复

1. 安装 `fcitx5-rime` 和 `librime`
2. 复制本模块到对应位置
3. 放入可选的 `wanxiang-lts-zh-hans.gram`
4. 重新部署 `Rime`
5. 重启 `fcitx5`

它们对应你当前机器上的核心自定义层。
