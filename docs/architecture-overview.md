# Dotfiles Sync Architecture Overview

## 30 秒心智模型

```text
live($HOME) 是平时真正修改的配置
        |
        |  from-live
        v
dotfiles repo 是版本化快照
        ^
        |  to-live
        |
repo 可以再恢复回 live
```

一句话：这套仓库不是 symlink / stow 部署，而是 `live <-> repo` 的双向同步。

## 核心角色

### 1. live 配置

平时直接编辑的真实配置，例如：

- `~/.config/zsh/`
- `~/.config/hypr/`
- `~/.config/yazi/`

### 2. dotfiles repo

用于版本管理、迁移和回放的仓库副本，路径形状是：

```text
dotfiles/<module>/<home-relative-path>
```

例如：

```text
dotfiles/zsh/.config/zsh/
dotfiles/yazi/.config/yazi/
dotfiles/rime/.local/share/fcitx5/rime/
```

## 多机同步时各自负责什么

```text
Git           : 在机器 A / B 之间同步 dotfiles 仓库
sync 脚本      : 在 repo 和 live($HOME) 之间同步真实配置
包管理器/手装   : 安装程序本体
```

所以“新机器恢复失败”通常分三类：

1. 仓库没拉到最新
2. 配置已经拉到，但还没 `to-live`
3. 程序本体根本没安装

## 两个方向

### from-live

```text
$HOME -> repo
```

适合：

- 本机刚改完配置，准备入库
- 想先看 `git diff` 再决定提交

典型命令：

```bash
./scripts/sync-yazi-from-live.sh
./scripts/sync-zsh-from-live.sh
```

### to-live

```text
repo -> $HOME
```

适合：

- 新机器恢复
- 本机配置被改乱后回滚
- 多机器对齐

典型命令：

```bash
./scripts/sync-yazi-to-live.sh
./scripts/sync-zsh-to-live.sh
```

## 脚本分层

### A. 总控脚本

- `scripts/sync-dotfiles-from-live.sh`
- `scripts/sync-dotfiles-to-live.sh`

用于批量同步默认安全组或 `--all`。

### B. 通用模块脚本

- `scripts/sync-module-from-live.sh`
- `scripts/sync-module-to-live.sh`

负责：

- 模块列表
- 模块分发
- 普通模块 / 特殊模块边界
- 敏感项保护

### C. 模块 wrapper

- `scripts/sync-yazi-from-live.sh`
- `scripts/sync-yazi-to-live.sh`
- `scripts/sync-zsh-from-live.sh`
- `scripts/sync-zsh-to-live.sh`

日常使用优先这一层，最省事。

### D. 收编脚本

- `scripts/adopt-live-config.sh`
- `scripts/scaffold-sync-module.sh`

用于把“还没纳入仓库”的新文件或新模块正式接进同步体系。

## 模块类型

### 普通模块

典型：`zsh`、`hypr`、`ghostty`、`yazi`

规则：

- 默认只同步 Git 已跟踪文件
- 新文件不会自动被长期管理

优点：

- 风险小
- 不容易把缓存或运行态垃圾卷进仓库

### 特殊模块

典型：`rime`、`git`、`htop`、`browser-flags`

规则：

- 不是整模块 tracked-file 同步
- 而是脚本里显式白名单路径

适合目录里机器态内容多、只想同步部分文件的模块。

## 三种收编判断

### 情况 1：已有模块 + 已有文件

直接同步：

```bash
./scripts/sync-yazi-from-live.sh
```

### 情况 2：已有模块 + 新文件

先收编，再长期同步：

```bash
./scripts/adopt-live-config.sh yazi .config/yazi/foo.toml
```

### 情况 3：全新模块

先脚手架：

```bash
./scripts/scaffold-sync-module.sh yazi .config/yazi
```

然后注册主脚本、测试 dry-run、再 git add。

## 日常操作顺序

### 入库链路

```text
改 live -> sync from-live -> git diff -> git add / commit
```

### 恢复链路

```text
repo 有版本 -> sync to-live -> 本机生效
```

## 常见坑

### 1. `.gitignore` 不能保护已跟踪敏感文件

如果文件已经进 Git，仅写 `.gitignore` 不会阻止它继续出现在 diff 里。

### 2. 普通模块不会自动纳管新文件

你在 `~/.config/yazi/` 新增 `theme.toml`，如果仓库里没有先收编并 `git add` 过，它不会自动进入长期同步。

### 3. 先看 dry-run 再动手更稳

```bash
./scripts/sync-yazi-from-live.sh --dry-run
./scripts/sync-yazi-to-live.sh --dry-run
```

## 推荐阅读顺序

1. 本文：`docs/architecture-overview.md`
2. 操作手册：`docs/operator-cookbook.md`
3. 原理长文：`../The_Basic_Conceptions/.../dotfiles-双向同步仓库与配置收编.md`
4. 需要最终证据时再看脚本
