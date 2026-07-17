import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "gear") }

            PlaybackTab()
                .tabItem { Label("播放", systemImage: "play.circle") }

            VideoTab()
                .tabItem { Label("视频", systemImage: "film") }

            AudioTab()
                .tabItem { Label("音频", systemImage: "speaker.wave.2") }

            SubtitleTab()
                .tabItem { Label("字幕", systemImage: "text.quote") }

            ControlTab()
                .tabItem { Label("控制", systemImage: "cursorarrow.click.2") }

            ShortcutTab()
                .tabItem { Label("快捷键", systemImage: "keyboard") }

            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 580, height: 480)
        .onAppear {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @AppStorage("launchBehavior") private var launchBehavior = "显示欢迎界面"
    @AppStorage("showWelcomeScreen") private var showWelcomeScreen = true
    @AppStorage("checkUpdateOnLaunch") private var checkUpdateOnLaunch = true
    @AppStorage("openPanelDirectory") private var openPanelDirectory = "上次打开的目录"
    @AppStorage("showRecentFiles") private var showRecentFiles = true
    @AppStorage("autoScanSiblings") private var autoScanSiblings = true
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题模式", selection: $themeManager.themeMode) {
                    ForEach(ThemeManager.ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("启动") {
                Picker("启动时", selection: $launchBehavior) {
                    Text("显示欢迎界面").tag("显示欢迎界面")
                    Text("打开最近文件").tag("打开最近文件")
                    Text("空白界面").tag("空白界面")
                }

                Toggle("显示欢迎界面", isOn: $showWelcomeScreen)
                Toggle("自动检查更新", isOn: $checkUpdateOnLaunch)
            }

            Section("文件管理") {
                Picker("打开面板初始目录", selection: $openPanelDirectory) {
                    Text("上次打开的目录").tag("上次打开的目录")
                    Text("桌面").tag("桌面")
                    Text("下载").tag("下载")
                    Text("影片").tag("影片")
                    Text("自定义...").tag("自定义...")
                }

                Toggle("显示最近打开的文件", isOn: $showRecentFiles)
                Toggle("自动扫描同目录视频文件", isOn: $autoScanSiblings)
            }
        }
        .padding(20)
    }
}

// MARK: - Playback Tab

struct PlaybackTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("播放行为") {
                Toggle("记住上次播放位置", isOn: $viewModel.rememberLastPosition)
                Toggle("恢复播放位置", isOn: $viewModel.resumePlayback)
                Toggle("自动播放下一个", isOn: $viewModel.autoPlayNext)
                Toggle("随机播放", isOn: $viewModel.shufflePlayback)
                Toggle("循环播放", isOn: $viewModel.isLooping)
            }

            Section("画中画") {
                Toggle("退出全屏时自动进入画中画", isOn: $viewModel.autoStartPiP)
                Toggle("最小化时自动进入画中画", isOn: $viewModel.pauseWhenMinimized)
            }

            Section("播放速度") {
                Picker("默认速度", selection: $viewModel.playbackSpeed) {
                    ForEach(PlaybackSpeed.allCases) { speed in
                        Text("\(speed.rawValue)x").tag(speed)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("快进快退") {
                HStack {
                    Text("快进步长：")
                    Stepper("\(Int(viewModel.currentTime)) → +10s", value: .constant(10), in: 1...60)
                        .disabled(true)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Video Tab

struct VideoTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("画面") {
                Picker("默认布局", selection: $viewModel.videoLayout) {
                    ForEach(VideoLayout.allCases) { layout in
                        Text(layout.rawValue).tag(layout)
                    }
                }

                Toggle("自动适应窗口大小", isOn: $viewModel.autoFit)
                Toggle("硬件解码", isOn: $viewModel.hardwareDecoding)
                Toggle("反交错", isOn: $viewModel.deinterlace)
            }

            Section("色彩调整") {
                VStack(alignment: .leading, spacing: 12) {
                    ColorSlider(label: "亮度", value: $viewModel.brightness, range: -1...1)
                    ColorSlider(label: "对比度", value: $viewModel.contrast, range: -1...1)
                    ColorSlider(label: "饱和度", value: $viewModel.saturation, range: -1...1)
                    ColorSlider(label: "色相", value: $viewModel.hue, range: -180...180)
                    ColorSlider(label: "锐度", value: $viewModel.sharpness, range: -1...1)
                }

                Button("重置所有") {
                    viewModel.brightness = 0
                    viewModel.contrast = 0
                    viewModel.saturation = 0
                    viewModel.hue = 0
                    viewModel.sharpness = 0
                }
            }

            Section("截图") {
                HStack {
                    Text("保存位置：")
                    Text(viewModel.screenshotDirectory.path)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("更改...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.directoryURL = viewModel.screenshotDirectory
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.screenshotDirectory = url
                        }
                    }
                }

                Button("立即截图") {
                    viewModel.takeScreenshot()
                }
            }
        }
        .padding(20)
    }
}

struct ColorSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 50, alignment: .leading)
                .font(.caption)
            Slider(value: $value, in: range)
            Text(String(format: "%.1f", value))
                .font(.caption)
                .frame(width: 35, alignment: .trailing)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Audio Tab

struct AudioTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("音量") {
                HStack {
                    Text("默认音量：")
                    Slider(value: $viewModel.volume, in: 0...1)
                    Text("\(Int(viewModel.volume * 100))%")
                        .frame(width: 40)
                }

                Toggle("启动时静音", isOn: $viewModel.isMuted)
            }

            Section("音频处理") {
                Toggle("音频直通（Passthrough）", isOn: $viewModel.audioPassthrough)

                HStack {
                    Text("音频延迟：")
                    Stepper(value: $viewModel.audioDelay, in: -5...5, step: 0.1) {
                        Text("\(viewModel.audioDelay, specifier: "%.1f") 秒")
                    }
                }
            }

            Section("音频设备") {
                Picker("输出设备", selection: .constant("系统默认")) {
                    Text("系统默认").tag("系统默认")
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Subtitle Tab

struct SubtitleTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("字幕显示") {
                Toggle("显示字幕背景", isOn: $viewModel.showSubtitleBackground)

                HStack {
                    Text("字体大小：")
                    Slider(value: $viewModel.subtitleFontSize, in: 12...72, step: 2)
                    Text("\(Int(viewModel.subtitleFontSize))pt")
                        .frame(width: 40)
                }

                ColorPicker("字幕颜色", selection: $viewModel.subtitleColor)
                ColorPicker("背景颜色", selection: $viewModel.subtitleBackgroundColor)
            }

            Section("字幕加载") {
                Picker("默认编码", selection: $viewModel.subtitleEncoding) {
                    ForEach(SubtitleEncoding.allCases) { enc in
                        Text(enc.rawValue).tag(enc)
                    }
                }

                Toggle("自动加载同名字幕文件", isOn: .constant(true))
                Toggle("自动加载同目录字幕文件", isOn: .constant(true))
            }

            Section("字幕延迟") {
                HStack {
                    Text("字幕延迟：")
                    Stepper(value: $viewModel.subtitleDelay, in: -5...5, step: 0.1) {
                        Text("\(viewModel.subtitleDelay, specifier: "%.1f") 秒")
                    }
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Control Tab

struct ControlTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("鼠标操作") {
                Picker("单击", selection: $viewModel.singleClickAction) {
                    Text("播放/暂停").tag("播放/暂停")
                    Text("无操作").tag("无操作")
                }
                Picker("双击", selection: $viewModel.doubleClickAction) {
                    Text("全屏").tag("全屏")
                    Text("播放/暂停").tag("播放/暂停")
                    Text("无操作").tag("无操作")
                }
                Picker("右键", selection: $viewModel.rightClickAction) {
                    Text("显示菜单").tag("显示菜单")
                    Text("全屏").tag("全屏")
                    Text("无操作").tag("无操作")
                }
                Picker("滚轮", selection: $viewModel.scrollAction) {
                    Text("快进/快退").tag("快进/快退")
                    Text("音量调节").tag("音量调节")
                    Text("缩放").tag("缩放")
                }
            }

            Section("触控板手势") {
                Toggle("双指缩放", isOn: .constant(true))
                Toggle("三指滑动", isOn: .constant(true))
            }
        }
        .padding(20)
    }
}

// MARK: - Shortcut Tab

struct ShortcutTab: View {
    let shortcuts: [(String, String)] = [
        ("Space / Return", "播放 / 暂停"),
        ("Esc", "停止 / 退出全屏"),
        ("←", "快退 10 秒"),
        ("→", "快进 10 秒"),
        ("⌘ + ←", "快退 5 秒"),
        ("⌘ + →", "快进 5 秒"),
        ("⌘ + ↑", "增大音量"),
        ("⌘ + ↓", "减小音量"),
        ("M", "静音切换"),
        ("F", "全屏切换"),
        ("⌘ + O", "打开文件"),
        ("⌘ + U", "打开 URL"),
        ("⌘ + L", "播放列表"),
        ("⌘ + I", "显示信息"),
        ("⌘ + [", "上一个"),
        ("⌘ + ]", "下一个"),
        ("⌘ + R", "循环播放"),
        ("⌘ + S", "截图"),
        ("⌘ + D", "3D 模式"),
        ("⌘ + V", "VR 模式"),
        ("⌘ + P", "画中画"),
        ("⌘ + ,", "偏好设置"),
        ("⌘ + +", "播放速度 +"),
        ("⌘ + -", "播放速度 -"),
        ("A", "设置 A 点"),
        ("B", "设置 B 点"),
        ("⌘ + W", "关闭窗口"),
        ("⌘ + Q", "退出"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("快捷键列表")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(shortcuts, id: \.0) { key, action in
                        HStack {
                            Text(key)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 140, alignment: .leading)
                            Text(action)
                                .font(.body)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)

                        if key != shortcuts.last?.0 {
                            Divider().padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Mocpot")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("macOS 全功能视频播放器")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                FeatureItem(icon: "film", text: "支持所有主流视频格式")
                FeatureItem(icon: "3d", text: "3D 视频播放（左右/上下/红蓝）")
                FeatureItem(icon: "visionpro", text: "360° VR 全景视频支持")
                FeatureItem(icon: "pip", text: "画中画模式")
                FeatureItem(icon: "photo.on.rectangle", text: "截图功能")
                FeatureItem(icon: "repeat", text: "A-B 循环")
                FeatureItem(icon: "text.quote", text: "外挂字幕支持")
                FeatureItem(icon: "list.bullet", text: "播放列表管理")
                FeatureItem(icon: "keyboard", text: "完整快捷键支持")
                FeatureItem(icon: "photo", text: "记住播放位置")
            }
            .frame(maxWidth: 320, alignment: .leading)

            Spacer()
        }
        .padding(20)
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.caption)
        }
    }
}
