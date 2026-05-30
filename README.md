# Dotfiles

集中管理我的桌面与开发配置。

## 结构

```text
emacs/
  .emacs
  .emacs.rc/

zsh/
  .config/zsh/

rofi/
  .config/rofi/

hypr/
  .config/hypr/

fastfetch/
  .config/fastfetch/

kitty/
  .config/kitty/

fcitx5/
  .config/fcitx5/
  README.md

rime/
  .local/share/fcitx5/rime/
  README.md

gtk-3.0/
  .config/gtk-3.0/

gtk-4.0/
  .config/gtk-4.0/

autostart/
  .config/autostart/

wlogout/
  .config/wlogout/

mako/
  .config/mako/

btop/
  .config/btop/

mpv/
  .config/mpv/

flameshot/
  .config/flameshot/

browser-flags/
  .config/

pavucontrol/
  .config/

xsettingsd/
  .config/xsettingsd/

xdg-desktop-portal/
  .config/xdg-desktop-portal/

git/
  .config/git/

cava/
  .config/cava/

htop/
  .config/htop/

atuin/
  .config/atuin/

ripgrep-all/
  .config/ripgrep-all/

glow/
  .config/glow/

niri/
  .config/niri/

systemd-user/
  .config/systemd/user/

kvantum/
  .config/Kvantum/

local-bin/
  .local/bin/

local-apps/
  .local/share/applications/
```

## 为什么用 symlink / stow

- 配置散在多个目录时，symlink 最直接
- `stow` 可以把“仓库结构”自动映射回 `$HOME`
- 以后新增模块只要多放一个目录，不用手工到处 `ln -s`

推荐方式：

```text
dotfiles/<package>/.config/...
dotfiles/<package>/.local/...
dotfiles/<package>/.emacs...
```

然后用 `stow` 链回家目录。

## 新机器恢复

1. 安装基础工具：`git`、`stow`
2. 克隆仓库到本地，例如：`~/dotfiles`
3. 先安装第三方依赖：
   `oh-my-zsh`
   `powerlevel10k`
   Emacs 本体
   Hyprland / Waybar / Rofi / Fcitx5 / Kitty / Foot / Kvantum / Qt6ct 等桌面组件
4. 进入仓库后执行：

```bash
./scripts/stow-install.sh
```

5. 对用户服务重新加载：

```bash
systemctl --user daemon-reload
```

6. 重新登录桌面会话，或按模块重启相关程序

建议顺序：

- 先恢复 shell、terminal、editor
- 再恢复 compositor、bar、launcher、input method
- 最后恢复 desktop entry、autostart、theme

## 不用 stow 的日常同步

如果你不想把 `$HOME` 里的 live 配置改成 symlink，也可以把本仓库当成“配置快照仓库”。

推荐工作流：

1. 平时直接修改本机 live 配置
2. 需要入库时，运行同步脚本
3. 看 `git diff` / `git status`
4. 确认后再 `git add` / `git commit`

当前提供三层入口：

- 总控脚本：`./scripts/sync-dotfiles-from-live.sh`
- 通用模块脚本：`./scripts/sync-module-from-live.sh`
- 模块专属 wrapper：`./scripts/sync-rime-from-live.sh`、`./scripts/sync-hypr-from-live.sh`、`./scripts/sync-zsh-from-live.sh` 等

示例：

```bash
./scripts/sync-dotfiles-from-live.sh --list
./scripts/sync-dotfiles-from-live.sh              # 安全默认组：rime zsh local-apps
./scripts/sync-dotfiles-from-live.sh --dry-run    # 预览安全默认组
./scripts/sync-dotfiles-from-live.sh --dry-run rime hypr
./scripts/sync-dotfiles-from-live.sh --all --dry-run
./scripts/sync-rime-from-live.sh
./scripts/sync-hypr-from-live.sh --dry-run
```

默认把 **live 配置视为源头**，但同步策略已经收紧成：

- `sync-dotfiles-from-live.sh` 不带参数时只同步安全默认组：`rime zsh local-apps`
- 真正全量必须显式使用 `--all`
- 大多数模块只同步 **仓库里已跟踪的文件**
- `rime` 这类特殊模块走显式白名单
- `zsh/.config/zsh/modules/environment.zsh` 会保留“加载私有 env 文件”的公共挂钩，但不收真实密钥值
- 常见敏感模式（如 `OBS_PASSWORD=`、`env_key=`、`*_TOKEN=`、`/tmp/.mount_*`）会被拦截并跳过

这意味着脚本默认更偏“安全快照回写”，而不是“把 live 整个目录原样灌回仓库”。

## 收哪些

- `~/.emacs`
- `~/.emacs.rc/`
- `~/.emacs.local/`
- `~/.config/zsh/`
- `~/.config/rofi/`
- `~/.config/hypr/`
- `~/.config/waybar/`
- `~/.config/fastfetch/`
- `~/.config/kitty/`
- `~/.config/fcitx5/`
  `Rime` 的 `custom.yaml` / `gram` 收录策略见 `fcitx5/README.md`
- `~/.local/share/fcitx5/rime/`
  只收 `custom.yaml` 这类自定义层，细则见 `rime/README.md`
- `~/.config/gtk-3.0/`
- `~/.config/gtk-4.0/`
- `~/.config/autostart/`
- `~/.config/wlogout/`
- `~/.config/mako/`
- `~/.config/btop/`
- `~/.config/mpv/`
- `~/.config/flameshot/`
- `~/.config/pavucontrol.ini`
- `~/.config/*-flags.conf`
- `~/.config/xsettingsd/`
- `~/.config/xdg-desktop-portal/`
- `~/.config/git/ignore`
- `~/.config/cava/`
- `~/.config/htop/htoprc`
- `~/.config/atuin/`
- `~/.config/ripgrep-all/`
- `~/.config/glow/`
- `~/.config/niri/`
- `~/.config/systemd/user/`
- `~/.config/Kvantum/`
- `~/.config/foot/`
- `~/.config/qt6ct/`
- `~/.config/nwg-look/`
- `~/.local/bin/` 里的手写脚本
- `~/.local/share/applications/` 里手改过的 `.desktop`

## 不收哪些

- `~/.cache/`
- `~/.local/state/`
- `~/.emacs.d/eln-cache/`
- `~/.emacs.d/auto-save-list/`
- `~/.zsh_history`
- `*.zwc`
- `~/.oh-my-zsh/` 整仓源码
- 各种 session / cookie / 历史 / 缓存数据库
- 机器专属路径、token、密码
- 各种自动生成的 `.desktop`
- 各种日志、崩溃记录、窗口几何状态

## Zsh 与 oh-my-zsh 的关系

这套仓库收的是：

- `~/.config/zsh/.zshenv`
- `~/.config/zsh/.zshrc`
- `~/.config/zsh/modules/*`
- `~/.config/zsh/functions/*`
- `~/.config/zsh/conf.d/*`
- `~/.config/zsh/completions/*`
- `~/.config/zsh/.p10k.zsh`

不收的是：

- `~/.oh-my-zsh/` 主仓库源码
- `~/.oh-my-zsh/cache/*`
- oh-my-zsh 自带插件目录

原因：

- oh-my-zsh 本体是第三方依赖，不是你自己的配置
- 你的自定义主要已经搬进 `~/.config/zsh/`
- 当前 `~/.oh-my-zsh/custom/` 里唯一有价值的东西主要是 `powerlevel10k` 主题克隆，它更适合在新机器上按步骤安装，而不是整仓 vendor 进 dotfiles

## 当前纳入的模块

- `emacs/`：`~/.emacs` + `~/.emacs.rc/`
- `emacs-local/`：`~/.emacs.local/`
- `zsh/`：`~/.config/zsh/`
- `rofi/`：`~/.config/rofi/`
- `hypr/`：`~/.config/hypr/`
- `waybar/`：`~/.config/waybar/`
- `fastfetch/`：`~/.config/fastfetch/`
- `kitty/`：`~/.config/kitty/`
- `fcitx5/`：`~/.config/fcitx5/`
- `rime/`：`~/.local/share/fcitx5/rime/`
- `gtk-3.0/`：`~/.config/gtk-3.0/`
- `gtk-4.0/`：`~/.config/gtk-4.0/`
- `autostart/`：`~/.config/autostart/`
- `wlogout/`：`~/.config/wlogout/`
- `mako/`：`~/.config/mako/`
- `btop/`：`~/.config/btop/`
- `mpv/`：`~/.config/mpv/`
- `flameshot/`：`~/.config/flameshot/`
- `browser-flags/`：`~/.config/*-flags.conf`
- `pavucontrol/`：`~/.config/pavucontrol.ini`
- `xsettingsd/`：`~/.config/xsettingsd/`
- `xdg-desktop-portal/`：`~/.config/xdg-desktop-portal/`
- `git/`：`~/.config/git/ignore`
- `cava/`：`~/.config/cava/`
- `htop/`：`~/.config/htop/htoprc`
- `atuin/`：`~/.config/atuin/`
- `ripgrep-all/`：`~/.config/ripgrep-all/`
- `glow/`：`~/.config/glow/`
- `niri/`：`~/.config/niri/`
- `systemd-user/`：`~/.config/systemd/user/`
- `kvantum/`：`~/.config/Kvantum/`
- `foot/`：`~/.config/foot/`
- `qt6ct/`：`~/.config/qt6ct/`
- `nwg-look/`：`~/.config/nwg-look/`
- `local-bin/`：手写脚本
- `local-apps/`：手改 `.desktop`

## 登录主题链路

当前 SDDM 登录主题不直接由本仓库管理。

当前系统状态：

- `/etc/sddm.conf.d/theme.conf`
- `Current=terraria`

主题源码来源：

- `~/myCode/The_Basic_Conceptions/CommonSense/linux/qylock`

这套主题仓库里包含：

- `sddm.sh`：安装/切换 SDDM 登录主题
- `themes/terraria/`：当前正在使用的 Terraria 登录主题
- `quickshell.sh`：安装 Quickshell 锁屏主题
- `quickshell-lockscreen/`：锁屏适配层

生效链路：

```text
qylock/themes/terraria
    ->
sddm.sh
    ->
/usr/share/sddm/themes/terraria
    ->
/etc/sddm.conf.d/theme.conf
    ->
SDDM 登录界面生效
```

相关但不同层的主题：

- `hyprlock/`：登录后的锁屏层
- `waybar/`、`rofi/`、`wlogout/`、`gtk-*`、`kvantum/`：登录后的桌面主题层

原则：

- `$HOME` 下的用户配置由本仓库管理
- `/usr/share/sddm/themes`、`/etc/sddm.conf.d` 这类系统级目标路径，只记录来源与安装方式，不直接作为本仓库的主要管理对象

## 后续原则

- 公共配置进仓库
- 私有补丁留本地或单独 `.local` 模块
- 每个模块只管自己的目录前缀
- 不把生成垃圾和运行时数据混进 Git

## 待确认项

- `obs-studio/`：配置和日志混在一起，后续若收，只拆纯配置
- `kdeconnect/`：含证书和私钥，不进仓库
- `QtProject/qquickfiledialog.conf`：偏历史状态，不进仓库
