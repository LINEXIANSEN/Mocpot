import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.colorScheme) private var scheme

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

            ScrollView { SubtitleTab() }
                .tabItem { Label("字幕", systemImage: "text.quote") }

            ControlTab()
                .tabItem { Label("控制", systemImage: "cursorarrow.click.2") }

            ShortcutTab()
                .tabItem { Label("快捷键", systemImage: "keyboard") }

            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 660, height: 580)
        .foregroundColor(.primary)
        .background(.regularMaterial)
        .background(PlayerPalette(scheme: scheme).canvas.opacity(0.72))
        .tint(PlayerPalette(scheme: scheme).accent)
        .accentColor(PlayerPalette(scheme: scheme).accent)
        .onDisappear { viewModel.saveSettings() }
        .onAppear {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @State private var cacheCleared = false
    @EnvironmentObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Form {
            Section("外观") {
                ThemeModePicker()
                Text("立即应用于所有窗口。跟随系统会自动切换深浅外观。")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section("启动") {
                Toggle("显示欢迎主页", isOn: $viewModel.showWelcomeScreen)
                Toggle("启动时打开最近播放的视频", isOn: $viewModel.openRecentOnLaunch)
            }
            Section("兼容播放") {
                Text("系统无法解码时，自动在本机换封装或转换编码。原文件保持不变；首次打开可能需要等待，重复打开会复用缓存。")
                    .font(.caption).foregroundColor(.secondary)
                Button("清理兼容缓存") {
                    viewModel.compatibility.clearCache(keeping: viewModel.playbackMediaURL)
                    cacheCleared = true
                }.disabled(viewModel.isLoading)
                if cacheCleared { Text("已清理；当前播放所需的缓存已保留。").font(.caption).foregroundColor(.secondary) }
            }
            Section("文件管理") {
                Toggle("主页显示最近播放", isOn: $viewModel.showRecentFiles)
                Text("关闭仅隐藏主页列表，保留播放记录；重新打开后即可显示。")
                    .font(.caption).foregroundColor(.secondary)
                Toggle("打开视频时扫描同目录视频", isOn: $viewModel.autoScanSiblings)
                Text("扫描结果按文件名排序加入播放列表，已手动创建的列表保持原顺序。")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

// MARK: - Playback Tab

struct PlaybackTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("播放行为") {
                Toggle("记住上次播放位置", isOn: $viewModel.rememberLastPosition)
                Toggle("重新打开时恢复播放位置", isOn: $viewModel.resumePlayback)
                    .disabled(!viewModel.rememberLastPosition)
                Toggle("自动播放下一个", isOn: $viewModel.autoPlayNext)
                Toggle("随机播放", isOn: $viewModel.shufflePlayback)
                Toggle("循环播放", isOn: $viewModel.isLooping)
            }

            Section("播放速度") {
                Picker("默认速度", selection: $viewModel.playbackSpeed) {
                    ForEach(PlaybackSpeed.allCases) { speed in
                        Text("\(speed.rawValue)x").tag(speed)
                    }
                }
                .pickerStyle(.segmented)
            }

        }
        .formStyle(.grouped)
        .padding(12)
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

                Text("播放器会根据视频类型自动选择合适的解码和画面比例。")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

                Toggle("静音（记住设置）", isOn: $viewModel.isMuted)
            }

            Section("音频处理") {
                Text("正值让声音晚于画面，负值让声音提前；调整时保留播放位置与暂停状态。")
                    .font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("音频延迟：")
                    Stepper(value: $viewModel.audioDelay, in: -5...5, step: 0.1) {
                        Text("\(viewModel.audioDelay, specifier: "%.1f") 秒")
                    }
                }
            }

            Section("音频设备") {
                Picker("输出设备", selection: $viewModel.audioOutputDeviceID) {
                    Text("系统默认").tag("")
                    ForEach(viewModel.outputDevices) { device in Text(device.name).tag(device.id) }
                    if !viewModel.audioOutputDeviceID.isEmpty && !viewModel.outputDevices.contains(where: { $0.id == viewModel.audioOutputDeviceID }) {
                        Text("设备未连接，暂用系统默认").tag(viewModel.audioOutputDeviceID)
                    }
                }
                Button("刷新设备") { viewModel.refreshAudioDevices() }
                Picker("音轨", selection: $viewModel.selectedAudioTrack) {
                    if viewModel.audioTracks.isEmpty { Text("无音轨").tag(0) }
                    ForEach(viewModel.audioTracks) { track in Text("\(track.name) · \(track.language)").tag(track.id) }
                }.disabled(viewModel.audioTracks.isEmpty)
                if let error = viewModel.audioProcessingError { Text(error).foregroundColor(.red) }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

// MARK: - Subtitle Tab

struct SubtitleTab: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        Form {
            Section("字幕文件") {
                Picker("当前字幕", selection: $viewModel.selectedSubtitleTrack) {
                    Text("关闭外挂字幕").tag(-1)
                    ForEach(viewModel.subtitleTracks) { track in Text(track.name).tag(track.id) }
                }
                Button("加载字幕文件…") { viewModel.openSubtitlePanel() }.disabled(viewModel.currentVideoURL == nil)
                Toggle("自动加载同名字幕", isOn: $viewModel.autoLoadMatchingSubtitles)
                Toggle("扫描同目录其他字幕", isOn: $viewModel.autoLoadDirectorySubtitles)
                Text("支持 SRT、WebVTT、ASS/SSA 文本；ASS 排版使用下方统一样式。正延迟表示字幕更晚出现。")
                    .font(.caption).foregroundColor(.secondary)
                if let error = viewModel.subtitleError { Text(error).foregroundColor(.red) }
            }
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

            Section("字幕编码") {
                Picker("默认编码", selection: $viewModel.subtitleEncoding) {
                    ForEach(SubtitleEncoding.allCases) { enc in
                        Text(enc.rawValue).tag(enc)
                    }
                }
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
        .formStyle(.grouped)
        .padding(12)
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
                Toggle("双指捏合缩放", isOn: $viewModel.pinchToZoom)
                Toggle("横向轻扫快进 / 快退", isOn: $viewModel.swipeToSeek)
                Text("轻扫需在 macOS 触控板设置中启用对应手势。")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
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
            Image("MocpotLogo")
                .resizable().scaledToFit().frame(width: 72, height: 72)

            Text("Mocpot")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Link("兼容组件：FFmpeg · LGPL v2.1+", destination: URL(string: "https://ffmpeg.org/")!)
                .font(.caption)

            Text("macOS 视频播放器")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                FeatureItem(icon: "film", text: "系统播放与本地兼容转换")
                FeatureItem(icon: "cube", text: "3D 视频播放（左右/上下/红蓝）")
                FeatureItem(icon: "globe", text: "360° VR 全景视频支持")
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
