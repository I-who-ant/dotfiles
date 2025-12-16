# Hyprland Dotfiles

我的 Hyprland 桌面环境配置文件。

## 配置内容

### Hyprland
- **hyprland.conf**: 主配置文件
  - 显示器设置（1920x1200@60）
  - 输入设备配置（键盘、触摸板）
  - 窗口规则和动画
  - 快捷键绑定（Emacs 风格 + Vim 风格）
  - 自动启动程序

- **hypridle.conf**: 空闲管理配置
- **hyprlock.conf**: 锁屏配置
- **hyprpaper.conf**: 壁纸配置
- **hyprsunset.conf**: 蓝光过滤器配置

### Waybar
- 简洁的状态栏配置
- Catppuccin Mocha 暗色主题
- 模块化设计

### Rofi
- 应用启动器配置
- 窗口切换器
- 文件查找器

### Wlogout
- 电源管理菜单
- 支持锁屏、注销、挂起、关机、重启

### Qt6ct
- Qt6 应用主题配置
- Catppuccin Mocha 暗色主题

### Nwg-look
- GTK 主题配置工具

### Zsh
- Hyprland 环境变量配置

## 安装

```bash
# 克隆仓库
git clone git@github.com:I-who-ant/dots.git ~/dotfiles

# 备份现有配置
cp -r ~/.config/hypr ~/.config/hypr.backup
cp -r ~/.config/waybar ~/.config/waybar.backup

# 复制配置文件
cp -r ~/dotfiles/.config/* ~/.config/
```

## 依赖

- hyprland
- waybar
- rofi
- wlogout
- qt6ct
- nwg-look
- hypridle
- hyprlock
- hyprpaper
- hyprsunset
- mako (通知)
- fcitx5 (输入法)
- kitty (终端)
- nautilus (文件管理器)

## 快捷键

- `Super + R`: 打开终端
- `Super + Q`: 关闭窗口
- `Super + D`: 应用启动器
- `Super + E`: 文件管理器
- `Super + L`: 锁屏
- `Super + U`: 电源菜单
- `Super + F/B/N/P`: Emacs 风格窗口焦点移动
- `Print`: 截图

## 主题

- 颜色方案: Catppuccin Mocha
- 字体: JetBrainsMono Nerd Font
- 图标: Tela-circle-dracula

## 截图

（待添加）
