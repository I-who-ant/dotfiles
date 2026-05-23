# Zsh 配置架构

## 当前加载链

```text
终端启动
│
├─ zsh 读 ~/.zshenv
│    └─ 设置 ZDOTDIR=~/.config/zsh
│
├─ zsh 读 ~/.config/zsh/.zshenv
│    └─ 只设置环境变量
│
├─ zsh 读 ~/.config/zsh/.zshrc
│    ├─ 先判断当前 shell 是否有真实 TTY
│    ├─ 有 TTY：
│    │    ├─ 加载 oh-my-zsh
│    │    ├─ 加载 p10k 配置
│    │    ├─ 加载 fzf 补全与自定义按键
│    │    ├─ 加载 functions/*.zsh
│    │    └─ 加载 startup.zsh 等纯交互模块
│    └─ 无 TTY：
│         └─ 跳过 prompt / gitstatus / bindkey / zle / fastfetch
│
├─ 按固定顺序 source modules/*.zsh
│    ├─ environment.zsh
│    ├─ toolchains.zsh
│    ├─ aliases-and-functions.zsh
│    ├─ conda.zsh
│    ├─ atuin.zsh
│    ├─ syntax-highlighting.zsh
│    └─ startup.zsh（仅真 TTY）
│
└─ 终端就绪
```

## 启动分层图

```text
┌────────────────────────────┐
│ /usr/bin/zsh               │
│ zsh 本体                   │
└─────────────┬──────────────┘
              │
              ▼
┌────────────────────────────┐
│ ~/.zshenv                  │
│ 入口转发层                 │
│ export ZDOTDIR=~/.config/zsh│
└─────────────┬──────────────┘
              │
              ▼
┌────────────────────────────┐
│ ~/.config/zsh/.zshenv      │
│ 原生环境层                 │
│ PATH / XDG_* / HISTFILE    │
└─────────────┬──────────────┘
              │
              ▼
┌────────────────────────────┐
│ ~/.config/zsh/.zshrc       │
│ 交互装配层                 │
│ 判断是否有 TTY             │
└───────┬────────────────────┘
        │
        ├──────────────────────────┐
        │ 有 TTY                   │ 无 TTY
        ▼                          ▼
┌──────────────────────┐   ┌──────────────────────┐
│ oh-my-zsh / p10k     │   │ 跳过 UI 与编辑器态   │
│ bindkey / zle / UI   │   │ 只保留必要初始化     │
└──────────┬───────────┘   └──────────────────────┘
           │
           ▼
┌────────────────────────────┐
│ modules/ 与 functions/     │
│ 你的本地增强层             │
└────────────────────────────┘
```

## 文件职责

| 文件 | 作用 |
|------|------|
| `~/.zshenv` | 唯一入口，只负责把 `ZDOTDIR` 指到 `~/.config/zsh` |
| `.zshenv` | 轻量环境层：`XDG_*`、history、`PATH`、终端基础变量 |
| `.zshrc` | 交互入口：TTY 检测、oh-my-zsh、prompt、补全、函数、模块装配 |
| `.p10k.zsh` | powerlevel10k 提示符配置 |
| `conf.d/binds.zsh` | 纯按键绑定，只适合真 TTY |
| `functions/*.zsh` | 可复用函数与 zle widget；其中部分只能在真 TTY 中加载 |
| `modules/environment.zsh` | 通用环境变量、编辑器、askpass |
| `modules/toolchains.zsh` | NVM、JetBrains 等工具链初始化 |
| `modules/aliases-and-functions.zsh` | 别名与交互函数 |
| `modules/conda.zsh` | Conda 初始化 |
| `modules/atuin.zsh` | Atuin 历史集成 |
| `modules/syntax-highlighting.zsh` | zsh-syntax-highlighting |
| `modules/startup.zsh` | 终端启动展示，只适合真 TTY |
| `my-config.zsh` | 退役说明文件，不参与启动 |

## 为什么之前会报错

典型报错：

- `can't change option: monitor`
- `gitstatus failed to initialize`
- `can't change option: zle`

根因不是 `oh-my-zsh` 安装坏了，而是“交互 shell”和“真实终端交互 shell”不是一回事。

例如下面这种命令：

```sh
zsh -i -c 'echo hello'
```

它有 `-i`，所以会走 `.zshrc`，但不一定有真实 TTY。此时如果继续加载：

- `powerlevel10k`
- `gitstatus`
- `bindkey`
- `zle -N`
- `fastfetch`

这些依赖真实终端的组件，就容易炸。

当前修复原则：

1. `.zshrc` 先判断 `[[ -t 0 && -t 1 ]]`。
2. 没有 TTY 时，跳过 prompt、gitstatus、bindkey、zle widget、启动展示。
3. 有 TTY 时，再加载完整交互体验。

这就是为什么现在：

- 真终端里 `zsh` 正常工作。
- 无 TTY 的 `zsh -i -c '...'` 也不会再乱报错。

## 真实执行路径

```text
图形终端（Ghostty / TTY）
  -> /usr/bin/zsh
  -> ~/.zshenv
  -> ~/.config/zsh/.zshenv
  -> ~/.config/zsh/.zshrc
  -> 有 TTY，加载 oh-my-zsh + p10k + functions + modules

脚本式交互调用（例如 zsh -i -c '...'）
  -> /usr/bin/zsh
  -> ~/.zshenv
  -> ~/.config/zsh/.zshenv
  -> ~/.config/zsh/.zshrc
  -> 无 TTY，跳过纯交互层，只保留必要初始化
```

## Hyprland 如何协作

```text
图形登录
  -> Hyprland 读取 ~/.config/hypr/hyprland.conf
  -> source conf.d/environment.conf
  -> source conf.d/autostart.conf
  -> 启动 waybar / fcitx5 / ghostty / QQ / 微信 等 GUI 程序

打开终端
  -> 终端继承 Hyprland 会话环境
  -> zsh 再叠加 shell 自己的变量、alias、hook
```

变量分工：

1. `~/.config/hypr/conf.d/environment.conf`
   图形会话级变量，影响 GUI 程序和从桌面启动的应用。
2. `~/.config/zsh/.zshenv` 与 `modules/*.zsh`
   shell 级变量，只影响当前 shell 及其子进程。
3. 各应用自己的 `~/.config/...`
   应用私有配置，例如 Ghostty、Waybar、Fastfetch、Atuin。

维护规则：

- 桌面会话变量放 Hyprland，例如输入法、Wayland、`SUDO_ASKPASS`。
- shell 交互变量放 zsh，例如 `EDITOR`、`NVM_DIR`、别名和函数。
- 纯 TTY 依赖功能放 `.zshrc` 的 TTY 分支里，不要污染无终端场景。
- 不再通过第三方壳层重复 source `.zshrc` 或延迟注入插件。
