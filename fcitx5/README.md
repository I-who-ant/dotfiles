# Fcitx5 And Rime

这部分仓库当前主要收：

- `~/.config/fcitx5/config`
- `~/.config/fcitx5/profile`
- `~/.config/fcitx5/conf/*.conf`

也就是：

- `fcitx5` 框架级快捷键、行为、候选框主题
- 当前启用的输入法列表
- `pinyin` / `classicui` / `clipboard` 等插件配置

## 当前机器的实际结构

当前机器上，输入法不是只有一层：

```text
fcitx5
├── ~/.config/fcitx5/
│   ├── config
│   ├── profile
│   └── conf/*.conf
│
└── ~/.local/share/fcitx5/
    ├── pinyin/
    │   ├── user.dict
    │   └── user.history
    │
    └── rime/
        ├── default.custom.yaml
        ├── rime_ice.custom.yaml
        ├── wanxiang-lts-zh-hans.gram
        ├── build/
        ├── *.userdb/
        ├── sync/
        └── rime-ice/
```

当前默认输入法是 `rime`，不是普通 `fcitx5-pinyin`。

## Rime 文件分工

### `dict`

`dict.yaml` 是词典。

它负责：

- 有哪些词可以被打出来
- 单词、词组、短语的基础候选来源

可以把它理解成“词库内容本体”。

### `schema`

`schema.yaml` 是方案。

它负责把很多部件组起来，例如：

- 用哪套编码规则
- 走哪些 translator / filter
- 候选怎么处理
- 按键怎么绑定

可以把它理解成“输入法运行蓝图”。

### `custom.yaml`

`*.custom.yaml` 是你自己的补丁层。

它负责：

- 不直接改上游方案
- 用 patch 覆盖默认设置
- 定制按键、候选数、grammar、联想等行为

这是最适合进 dotfiles 的 `Rime` 文件类型。

### `userdb`

`*.userdb/` 是用户数据库。

它负责：

- 记录用户词频
- 记录学习出来的排序
- 保存机器使用过程中积累的动态状态

这类文件不应该进 dotfiles，因为它们属于机器态和个人输入历史。

### `.gram`

`.gram` 是 grammar 语言模型，不是普通词典。

它主要负责：

- 长句上下文下的候选重排
- 词语搭配打分
- 提升“更像人话”的候选排序

它和 `dict` 的区别是：

```text
dict
  解决：有哪些词

gram
  解决：这些词在当前上下文里谁更该排前面
```

当前机器里用到的文件是：

- `~/.local/share/fcitx5/rime/wanxiang-lts-zh-hans.gram`

它通过 `rime_ice.custom.yaml` 里的：

```yaml
patch:
  grammar:
    language: wanxiang-lts-zh-hans
```

被 `Rime` 载入。

## `rime-ice` 和 `wanxiang` 的关系

当前机器更接近下面这条链：

```text
fcitx5
  -> rime
    -> rime-ice 方案
      -> 接入 wanxiang grammar 模型
```

也就是：

- 输入方案主体是 `rime-ice`
- grammar 排序增强来自 `wanxiang-lts-zh-hans.gram`

所以这不是“整套切到万象方案”，而是“雾凇拼音 + 万象 grammar 模型”。

## 什么该进 dotfiles

建议收：

- `~/.config/fcitx5/config`
- `~/.config/fcitx5/profile`
- `~/.config/fcitx5/conf/*.conf`
- `~/.local/share/fcitx5/rime/default.custom.yaml`
- `~/.local/share/fcitx5/rime/rime_ice.custom.yaml`

可选收：

- `~/.local/share/fcitx5/rime/wanxiang-lts-zh-hans.gram`

是否收 `gram`，看你怎么权衡：

- 收：新机器恢复简单，行为一致
- 不收：仓库更轻，模型文件单独管理

当前这颗 `gram` 文件接近 200 MB，所以更推荐单独管理，或者在 README 里记录下载来源和放置路径。

## 什么不该进 dotfiles

不要收：

- `~/.local/share/fcitx5/pinyin/user.dict`
- `~/.local/share/fcitx5/pinyin/user.history`
- `~/.local/share/fcitx5/rime/build/`
- `~/.local/share/fcitx5/rime/*.userdb/`
- `~/.local/share/fcitx5/rime/sync/`
- `~/.local/share/fcitx5/rime/user.yaml`
- `~/.local/share/fcitx5/rime/installation.yaml`
- `~/.local/share/fcitx5/rime/rime-ice/.git`

原因：

- 这些属于缓存、编译产物、学习数据、同步中间态、机器唯一状态
- 放进 dotfiles 会变脏，而且会越来越重

## 恢复时要点

如果以后把 `Rime` 也纳入 dotfiles，推荐单独拆一个 `rime/` 模块，只收自定义层：

```text
rime/
  .local/share/fcitx5/rime/
    default.custom.yaml
    rime_ice.custom.yaml
    wanxiang-lts-zh-hans.gram   # 可选
```

如果不收 `gram`，至少要在 README 里记住两件事：

- 文件名：`wanxiang-lts-zh-hans.gram`
- 放置路径：`~/.local/share/fcitx5/rime/`

另外，当前机器已经安装了 `octagram` 插件，`fcitx5-rime` 才能真正使用这类 grammar 模型。
