# Mocpot

macOS 全功能视频播放器，支持 3D 和 VR 全景视频播放。

[![Release](https://img.shields.io/github/v/release/LINEXIANSEN/Mocpot)](https://github.com/LINEXIANSEN/Mocpot/releases)
[![License](https://img.shields.io/github/license/LINEXIANSEN/Mocpot)](LICENSE)

## 截图

![Mocpot](https://raw.githubusercontent.com/LINEXIANSEN/Mocpot/main/screenshot.png)

## 功能特性

### 核心播放
- 系统可解码的文件直接播放；MKV、AVI、WebM、WMV 等不兼容组合使用内置 FFmpeg 在本机换封装或转换编码，首次转换需要等待，原文件不变。
- 保留多音轨，提取转换文件中的文本字幕；支持进度显示、取消和缓存清理。详见 [格式兼容性与限制](docs/format-compatibility.md)。
- 硬件加速解码
- 播放速度调节：0.25x - 4x
- 循环播放、随机播放
- 播放列表排序（名称/时间/自然顺序）
- 记住上次播放位置

### 3D 视频
- 左右格式 (Side-by-Side)
- 上下格式 (Over/Under)
- 红蓝 3D (Anaglyph)
- 红黄 3D

### VR 全景
- 360° 全景视频播放
- 360° 立体视频
- 180° 半球视频
- 鼠标拖拽旋转视角

### 字幕支持
- 外挂字幕自动加载
- 多种编码支持：UTF-8, GBK, Big5, Shift JIS
- 字幕样式自定义
- 字幕延迟调节

### 高级功能
- 画中画模式
- 截图功能
- A-B 循环播放
- 快速设置面板
- 播放列表管理
- 最近播放记录
- 音频延迟调节

## 下载

### 直接下载

[最新版本](https://github.com/LINEXIANSEN/Mocpot/releases/latest)

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/LINEXIANSEN/Mocpot.git
cd Mocpot

# 首次构建兼容组件（下载并校验 FFmpeg 源码）
Scripts/build-compatibility-tools.sh

# 打开 Xcode 项目
open Mocpot.xcodeproj

# 或命令行构建
xcodebuild -project Mocpot.xcodeproj -scheme Mocpot -configuration Release build
```

## 快捷键

| 按键 | 功能 |
|------|------|
| Space / Return | 播放 / 暂停 |
| Esc | 停止 / 退出全屏 |
| ← | 快退 10 秒 |
| → | 快进 10 秒 |
| ⌘ + ←/→ | 快退/快进 5 秒 |
| ⌘ + ↑/↓ | 增大/减小音量 |
| M | 静音切换 |
| F | 全屏切换 |
| ⌘ + O | 打开文件 |
| ⌘ + L | 播放列表 |
| ⌘ + I | 显示信息 |
| ⌘ + [ / ] | 上一个/下一个 |
| ⌘ + R | 循环播放 |
| ⌘ + S | 截图 |
| ⌘ + D | 3D 模式 |
| ⌘ + V | VR 模式 |
| A | 设置 A 点 (A-B 循环) |
| B | 设置 B 点 |
| Delete | 清除 A-B 循环 |

## 设置

打开偏好设置 (⌘ + ,) 可以配置：

- **通用**：启动行为、文件管理
- **播放**：播放行为、速度、快进快退
- **视频**：布局、硬件解码、色彩调整、截图
- **音频**：音量、静音、音频延迟
- **字幕**：字幕样式、编码、延迟
- **控制**：鼠标操作、触控板手势
- **快捷键**：完整快捷键列表

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 支持 ARM64 (Apple Silicon) 和 x86_64 (Intel)

## 开发

### 项目结构

```
Mocpot/
├── Mocpot.xcodeproj    # Xcode 项目
├── Mocpot/Sources/             # 源代码
│   ├── PotPlayerMacApp.swift  # 应用入口
│   ├── ContentView.swift      # 主界面
│   ├── PlayerViewModel.swift  # 核心逻辑
│   ├── VRPlayerView.swift     # VR 播放器
│   ├── ThreeDPlayerView.swift # 3D 播放器
│   ├── PlaylistView.swift     # 播放列表
│   ├── SettingsView.swift     # 设置界面
│   ├── VideoInfoView.swift    # 视频信息
│   └── Assets.xcassets/       # 资源文件
├── package.sh                 # 打包脚本
└── README.md
```

### 构建要求

- Xcode 15.0+
- macOS 13.0+ SDK

## 许可证

MIT License

## 致谢

- [IINA](https://iina.io/) - 参考了部分功能设计
- [AVFoundation](https://developer.apple.com/av-foundation/) - Apple 媒体框架
- [SceneKit](https://developer.apple.com/scenekit/) - 3D 渲染框架

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

- GitHub: [@LINEXIANSEN](https://github.com/LINEXIANSEN)

## 本轮优化与验证

- 视频就绪后启动，隔离旧文件回调，显示加载状态及播放失败信息。
- 全景相机拖拽直接在 SceneKit 内更新；仅更换播放器时重绑纹理，暂停时停止持续渲染；支持滚轮缩放。
- 进度显示每 0.25 秒更新，播放位置每 5 秒保存，暂停、换片和退出时补存。
- 修复音量、倍速、停止后续播、播放结束、单曲循环和快速跳转状态。
- 统一三种模式的控制栏，支持移动鼠标重新显示、暂停时保持显示；播放列表排序结果不再随时钟反复计算。

运行播放回归测试（需要 Xcode 命令行工具和 ffmpeg）：

```bash
./Tests/run.sh
```

测试生成临时样片，使用独立 UserDefaults 域，不改动个人播放记录。测试覆盖就绪启动、音量倍速同步、连续跳转、停止续播、快速切换、循环和错误处理。

当前仍需注意：既有的 180°、立体全景、红蓝 3D、外挂字幕和部分画面/音频调节存在未完整实现的处理路径。本轮重点优化播放生命周期、360° 单目全景性能和控制交互，并未补齐这些解码与投影功能。未提供真实高码率全景素材，因此不能把代码优化直接等同于已测得的帧率提升。

### 深浅主题更新

首页、播放控制栏、快速设置和播放列表使用统一的不透明界面配色，避免浅色文字或深色文字与视频底色混合。主窗口工具栏和「设置 → 通用 → 外观」均可切换浅色、深色、跟随系统；设置会持久保存并通知所有窗口。视频画面及其留黑区域仍保持原样。

`./Tests/render-themes.sh` 会测试三种主题的变更通知和持久化，并将深浅组件快照输出到 `/tmp/mocpot-theme-snapshots`。快照由应用自身的视图离屏渲染，不涉及桌面截屏；原生列表容器的离屏渲染不包含懒加载行，因此另外生成独立行快照检查文字配色。

### 安全加固

- 文件打开、拖放、外部打开和最近记录统一限制为存在的本地普通文件，拒绝目录、非文件 URL 和失效路径。
- 文件夹导入使用安全作用域资源访问，并只加入允许的视频扩展名和普通文件。
- 截图文件名会清理路径字符并追加随机后缀，避免覆盖已有截图。
- Release 上传脚本改为隐藏输入 GitHub Token，避免令牌在终端回显。
