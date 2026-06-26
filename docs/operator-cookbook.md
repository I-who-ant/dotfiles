# Dotfiles Sync Operator Cookbook

按“我现在想干嘛”来查，不用先读完整脚本。

## 0. 先记最小规则

- `from-live` = 本机配置回写仓库
- `to-live` = 仓库配置恢复本机
- 普通模块默认只同步已跟踪文件
- 新文件 / 新模块要先收编

## 0.5 我想在另一台机器首次恢复

建议顺序：

```bash
git clone git@github.com:I-who-ant/dotfiles.git
cd dotfiles
./scripts/sync-dotfiles-to-live.sh --dry-run
./scripts/sync-dotfiles-to-live.sh
```

然后再按需逐个模块恢复：

```bash
./scripts/sync-dotfiles-to-live.sh yazi ghostty hypr waybar
```

恢复桌面模块前，先确认对应软件已经安装。

## 1. 我刚改完本机配置，想入库

### 单模块

```bash
cd /home/seeback/learingProject/seeback/dotfiles
./scripts/sync-yazi-from-live.sh
git diff
```

### 先预演

```bash
./scripts/sync-yazi-from-live.sh --dry-run
```

适合模块：`yazi`、`zsh`、`hypr`、`ghostty` 这类普通模块。

## 2. 我想把仓库版本恢复回本机

```bash
cd /home/seeback/learingProject/seeback/dotfiles
./scripts/sync-yazi-to-live.sh
```

先预演：

```bash
./scripts/sync-yazi-to-live.sh --dry-run
```

适合：

- 新机器恢复
- 本机配置被改乱
- 多机对齐

## 3. 我在已有模块里新增了一个文件

例如新增：

```text
~/.config/yazi/theme.toml
```

如果 `yazi` 是普通模块，这个新文件不会自动长期纳管。

先收编：

```bash
cd /home/seeback/learingProject/seeback/dotfiles
./scripts/adopt-live-config.sh yazi .config/yazi/theme.toml
```

然后：

```bash
git add yazi/.config/yazi/theme.toml
./scripts/sync-yazi-from-live.sh --dry-run
```

## 4. 我想新增一个全新模块

例如管理 `~/.config/foo/`：

```bash
cd /home/seeback/learingProject/seeback/dotfiles
./scripts/scaffold-sync-module.sh foo .config/foo
```

接着做：

1. 把 live 内容复制进 repo 路径
2. 把 `foo` 注册进两个 `sync-module-*.sh`
3. 跑 dry-run
4. `git add`

## 5. 我不确定这是普通模块还是特殊模块

### 普通模块特征

- 大多数文件都适合进仓库
- 适合 tracked-file 同步
- 例子：`yazi`、`zsh`、`hypr`

### 特殊模块特征

- 只想同步少量白名单文件
- 目录里混着缓存、状态、机器态内容
- 例子：`rime`、`git`、`htop`、`browser-flags`

如果不确定，默认按保守思路：先普通文件收编，小范围 dry-run。

## 6. 我怕把敏感值同步进仓库

先做：

```bash
git diff
git status --short
```

再记住：

- `.gitignore` 不保护已跟踪文件
- 公共 loader + 私有 env 文件拆分，比把秘密直接写进 tracked 文件稳

重点敏感例子：

- `*_TOKEN=`
- `*_PASSWORD=`
- `OPENAI_API_KEY=`
- `/tmp/.mount_*` 这类临时路径

## 7. 我只想看支持哪些模块

```bash
./scripts/sync-module-from-live.sh --list
./scripts/sync-module-to-live.sh --list
```

## 8. 我想用总控脚本而不是单模块 wrapper

```bash
./scripts/sync-dotfiles-from-live.sh --dry-run
./scripts/sync-dotfiles-to-live.sh --dry-run
```

注意：默认总控脚本只跑安全默认组，不等于所有模块。

## 9. Yazi 现在怎么同步

### 本机 -> 仓库

```bash
cd /home/seeback/learingProject/seeback/dotfiles
./scripts/sync-yazi-from-live.sh
```

### 仓库 -> 本机

```bash
cd /home/seeback/learingProject/seeback/dotfiles
./scripts/sync-yazi-to-live.sh
```

Yazi 目前是普通模块，已纳管文件包括：

- `yazi/.config/yazi/yazi.toml`
- `yazi/.config/yazi/keymap.toml`

## 10. 推荐排错顺序

如果同步结果不符合预期，按这个顺序排：

1. 先看是不是方向搞反了：`from-live` / `to-live`
2. 看是不是普通模块里的“新文件还没收编”
3. 看模块是不是特殊模块，需要补脚本白名单
4. 看 dry-run 输出
5. 最后才进 `sync-module-from-live.sh` / `sync-module-to-live.sh` 看细节
