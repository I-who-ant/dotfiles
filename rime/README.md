# Rime

这个模块只收 `Rime` 的自定义层，不收机器态数据。

当前策略：

- 收 `default.custom.yaml`
- 收 `rime_ice.custom.yaml`
- 可选收 `wanxiang-lts-zh-hans.gram`
- 不收 `build/`、`*.userdb/`、`sync/`、`installation.yaml`、`user.yaml`

## 模块结构

```text
rime/
  .local/share/fcitx5/rime/
    .gitignore
    default.custom.yaml
    rime_ice.custom.yaml
    wanxiang-lts-zh-hans.gram   # optional
```

## 为什么只收这些

因为 `custom.yaml` 是你真正手改、并且跨机器值得复用的部分：

- `default.custom.yaml`
  负责全局 patch，比如中英切换键、翻页键
- `rime_ice.custom.yaml`
  负责当前方案的行为 patch，比如 grammar 和 contextual suggestions

这些文件小、稳定、可读，最适合进 dotfiles。

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

## 不该进仓库的内容

不要把下面这些扔进来：

- `build/`
- `*.userdb/`
- `sync/`
- `user.yaml`
- `installation.yaml`
- `rime-ice/.git`

这些分别对应：

- 编译产物
- 用户词频与学习状态
- 同步缓存
- 机器唯一状态
- 第三方仓库元数据

## 当前 patch 入口

当前模块里最重要的是这两份文件：

- `default.custom.yaml`
- `rime_ice.custom.yaml`

## 新机器恢复

1. 安装 `fcitx5-rime` 和 `librime`
2. 复制本模块到对应位置
3. 放入可选的 `wanxiang-lts-zh-hans.gram`
4. 重新部署 `Rime`
5. 重启 `fcitx5`

它们对应你当前机器上的核心自定义层。
