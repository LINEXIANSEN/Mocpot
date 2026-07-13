# Mocpot

macOS 全功能视频播放器，支持 3D 和 VR 全景视频播放。

[![Release](https://img.shields.io/github/v/release/LINEXIANSEN/Mocpot)](https://github.com/LINEXIANSEN/Mocpot/releases)
[![License](https://img.shields.io/github/license/LINEXIANSEN/Mocpot)](LICENSE)

## 截图

![Mocpot](https://raw.githubusercontent.com/LINEXIANSEN/Mocpot/main/screenshot.png)

## 功能特性

### 核心播放
- 支持所有主流视频格式：MP4, MKV, AVI, MOV, WebM, FLV, WMV 等
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

# 打开 Xcode 项目
open PotPlayer-mac.xcodeproj

# 或命令行构建
xcodebuild -project PotPlayer-mac.xcodeproj -scheme Mocpot -configuration Release build
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
├── PotPlayer-mac.xcodeproj    # Xcode 项目
├── PotPlayer-mac/             # 源代码
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
