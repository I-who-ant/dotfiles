# Dotfiles

这是一个“**配置快照仓库**”：
- 本机 `$HOME` 里的 live 配置可以回写到仓库
- 仓库里的配置也可以再同步回本机
- 默认采用纯同步，不靠符号链接部署

## 目录约定

每个模块都按“仓库根目录 = 模块名”的方式存放：

```text
zsh/
  .config/zsh/

rime/
  .local/share/fcitx5/rime/
```

常见模块：`emacs/`、`zsh/`、`hypr/`、`waybar/`、`rime/`、`local-bin/`、`local-apps/` 等。
完整模块列表以脚本 `--list` 输出为准。

## 同步模型

```text
live($HOME)  <->  repo
```

- **live -> repo**：把本机改动收进仓库
- **repo -> live**：把仓库里的配置恢复到本机

两边都支持：
- `--dry-run`
- `--list`
- `--all`
- `--delete`（谨慎）

## 脚本分层

### 1) 总控脚本

- `./scripts/sync-dotfiles-from-live.sh`
- `./scripts/sync-dotfiles-to-live.sh`

不带参数时，只处理安全默认组：
- `rime`
- `zsh`
- `local-apps`

### 2) 通用模块脚本

- `./scripts/sync-module-from-live.sh`
- `./scripts/sync-module-to-live.sh`

### 3) 模块 wrapper

例如：
- `./scripts/sync-rime-from-live.sh`
- `./scripts/sync-rime-to-live.sh`
- `./scripts/sync-zsh-from-live.sh`
- `./scripts/sync-zsh-to-live.sh`

### 4) 纳入仓库辅助脚本

- `./scripts/adopt-live-config.sh`

它用于把“当前只存在于本机、还没进入仓库”的配置，先收进仓库。

## 常用命令

### 从本机同步到仓库

```bash
./scripts/sync-dotfiles-from-live.sh --list
./scripts/sync-dotfiles-from-live.sh
./scripts/sync-dotfiles-from-live.sh --dry-run
./scripts/sync-dotfiles-from-live.sh rime zsh
./scripts/sync-dotfiles-from-live.sh --all --dry-run
```

### 从仓库同步到本机

```bash
./scripts/sync-dotfiles-to-live.sh --list
./scripts/sync-dotfiles-to-live.sh
./scripts/sync-dotfiles-to-live.sh --dry-run
./scripts/sync-dotfiles-to-live.sh rime zsh
./scripts/sync-dotfiles-to-live.sh --all --dry-run
```

## 默认策略

### live -> repo

- 普通模块：只回写 **仓库里已跟踪的文件**
- `rime`：走显式白名单
- 敏感模式会被跳过：
  - `*_PASSWORD=`
  - `*_TOKEN=`
  - `env_key=`
  - `/tmp/.mount_*`

### repo -> live

- 同样默认只动安全默认组
- 仍然会跳过 repo 里看起来像敏感值的文件
- 适合：
  - 新机器恢复
  - 机器间对齐
  - 重新覆盖本机被改乱的配置

## 怎么把本机新配置纳入仓库

先记一个总原则：

- **普通模块**：靠“已跟踪文件”同步
- **特殊模块**：靠脚本里的显式规则同步

当前特殊模块主要有：
- `rime`
- `browser-flags`
- `pavucontrol`
- `git`
- `htop`

其余大多数模块都属于普通模块。

### 情况 A：已有模块里的“已跟踪文件”

直接：
1. 改本机 live 文件
2. 跑 `./scripts/sync-dotfiles-from-live.sh <module>`
3. 看 `git diff`
4. `git add` / `git commit`

### 情况 B：已有模块里的“新文件”

因为大多数模块默认只同步已跟踪文件，所以你需要先把新文件纳入仓库：

#### 最方便的做法

```bash
./scripts/adopt-live-config.sh zsh .config/zsh/modules/foo.zsh
./scripts/adopt-live-config.sh local-apps .local/share/applications/foo.desktop
./scripts/adopt-live-config.sh -d hypr .config/hypr/plugins
```

这个脚本会把 live 路径复制到仓库对应模块里，并告诉你下一步怎么 `git add`。

#### 完成收编后

1. 检查 diff
2. `git add` 一次
3. 之后这条路径就会被普通同步脚本持续管理

#### 手工做法

如果你不想用辅助脚本，也可以手动：

1. 在仓库里创建对应路径
2. 把 live 文件复制进来
3. `git add` 一次
4. 后续继续用同步脚本维护

### 情况 C：特殊模块

像 `rime` 这种有白名单的模块：

1. 先用 `adopt-live-config.sh` 或手工把文件收进仓库
2. 再把该路径补进：
   - `scripts/sync-module-from-live.sh`
   - `scripts/sync-module-to-live.sh`
3. 跑双向 `--dry-run`
4. 最后再 `git add` / `git commit`

### 情况 D：新模块

比如你想新收一个 `foo` 模块，管理 `~/.config/foo/`：

1. 新建目录：

```bash
mkdir -p foo/.config/foo
```

2. 先把本机 live 内容放进仓库：

```bash
rsync -av ~/.config/foo/ foo/.config/foo/
```

3. 把模块名加进：
   - `scripts/sync-module-from-live.sh` 的 `all_modules`
   - `scripts/sync-module-to-live.sh` 的 `all_modules`

4. 在两个脚本的 `case` 里各加一条：

```bash
foo)
  sync_tracked_module 'foo'
  ;;
```

和：

```bash
foo)
  copy_tracked_module 'foo'
  ;;
```

5. 新建 wrapper：

```bash
cp scripts/sync-zsh-from-live.sh scripts/sync-foo-from-live.sh
cp scripts/sync-zsh-to-live.sh   scripts/sync-foo-to-live.sh
```

然后把里面的模块名改成 `foo`。

6. 跑测试：

```bash
./scripts/sync-foo-from-live.sh --dry-run
./scripts/sync-foo-to-live.sh --dry-run
```

7. README 里补一行模块说明
8. `git add` / `git commit`

### 一句话判断法

- 只是**已有模块新增一个普通文件**：用 `adopt-live-config.sh`
- 是 **Rime / browser-flags 这种特殊模块新增路径**：除了收文件，还要补脚本规则
- 是 **全新目录前缀**：新增模块

## 模块说明

### Zsh

- 仓库管理 `~/.config/zsh/`
- `environment.zsh` 里保留公共 loader
- 真密钥放：
  - `~/learingProject/seeback/some-keys/zsh.env`
  - `~/.config/zsh/private.env`

### Rime

- `rime_ice.custom.yaml`：行为参数
- `tech_phrase.txt`：强置顶短语
- `mytech.dict.yaml`：技术词库
- `rime_ice_seeback.dict.yaml`：把个人词库接到主链路
- `TUNING.md`：怎么调
- `REGRESSION.md`：怎么验

### local-apps

- 管 `.desktop`
- 敏感或临时路径会被脚本拦截

## 不收什么

- 缓存、历史、日志、崩溃文件
- 机器专属 token / password
- 学习状态数据库
- 自动生成物
- system / systemd 这种机器态文件（除非明确纳入）

## 新机器恢复

1. 克隆仓库
2. 安装依赖程序
3. 跑：

```bash
./scripts/sync-dotfiles-to-live.sh --all
```

4. 必要时重载用户服务：

```bash
systemctl --user daemon-reload
```

5. 重新登录或重启相关组件

## 先后顺序

建议先恢复：
1. shell / terminal / editor
2. input method / launcher / compositor
3. desktop entries / theme / services

## 当前原则

- 公共配置进仓库
- 私有数据留本地
- 同步前先 `--dry-run`
- 看到 `git diff` 再提交
