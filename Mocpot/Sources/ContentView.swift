import AVFoundation
import AVKit
import SwiftUI

struct SimpleVideoPlayer: NSViewRepresentable {
    @EnvironmentObject var viewModel: PlayerViewModel
    let player: AVPlayer
    var layout: VideoLayout = .fit

    func makeNSView(context: Context) -> AVPlayerView {
        let pv = InteractivePlayerView()
        pv.viewModel = viewModel
        pv.player = player
        pv.controlsStyle = .none
        pv.videoGravity = .resizeAspect
        pv.layer?.backgroundColor = NSColor.black.cgColor
        return pv
    }

    func updateNSView(_ pv: AVPlayerView, context: Context) {
        if pv.player !== player { pv.player = player }
        switch layout {
        case .fill, .centerCrop: pv.videoGravity = .resizeAspectFill
        case .stretch: pv.videoGravity = .resize
        case .original, .fit: pv.videoGravity = .resizeAspect
        }
    }

    static func dismantleNSView(_ pv: AVPlayerView, coordinator: ()) {
        pv.player = nil
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var isDragOver = false

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if viewModel.currentVideoURL == nil {
                    if viewModel.showWelcomeScreen {
                        WelcomeView()
                    } else {
                        Button("打开视频…") { viewModel.openFilePanel() }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    if let direct = viewModel.directPlayback {
                        DirectPlayerView(playback: direct).id(ObjectIdentifier(direct))
                    } else if viewModel.vrMode != .none {
                        VRPlayerView()
                            .environmentObject(viewModel)
                    } else if viewModel.threeDMode != .none {
                        ThreeDPlayerView()
                            .environmentObject(viewModel)
                    } else {
                        StandardPlayerView()
                            .environmentObject(viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }

            if viewModel.showPlaylist {
                PlaylistView()
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(PlayerPalette(scheme: scheme).canvas)
        .tint(PlayerPalette(scheme: scheme).accent)
        .accentColor(PlayerPalette(scheme: scheme).accent)
        .frame(minWidth: viewModel.showPlaylist ? 960 : 800, minHeight: 500)
        .toolbar(viewModel.isFullscreen ? .hidden : .visible, for: .windowToolbar)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isDragOver ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { viewModel.openFilePanel() }) {
                    Image(systemName: "folder").help("打开文件 (⌘O)")
                }.keyboardShortcut("o", modifiers: .command)

                Button(action: { viewModel.openFolderPanel() }) {
                    Image(systemName: "folder.badge.plus").help("导入文件夹")
                }.keyboardShortcut("O", modifiers: [.command, .shift])

                Menu {
                    ForEach(PlayerViewModel.FolderSortOrder.allCases) { order in
                        Button(action: {
                            viewModel.folderSortOrder = order
                            viewModel.openFolderPanel()
                        }) {
                            HStack {
                                Text(order.rawValue)
                                if viewModel.folderSortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }.help("排序导入")

                Button(action: { viewModel.showPlaylist.toggle() }) {
                    Image(systemName: "list.bullet").help("播放列表 (⌘L)")
                }.keyboardShortcut("l", modifiers: .command)
            }

            ToolbarItemGroup(placement: .automatic) {
                Menu {
                    ForEach(ThemeManager.ThemeMode.allCases) { mode in
                        Button {
                            themeManager.themeMode = mode
                        } label: {
                            Label(mode.rawValue, systemImage: themeManager.themeMode == mode ? "checkmark.circle.fill" : mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: themeManager.themeMode.icon)
                }.help("外观：\(themeManager.themeMode.rawValue)")
                Menu {
                    ForEach(PlaybackSpeed.allCases) { speed in
                        Button(action: { viewModel.playbackSpeed = speed }) {
                            HStack {
                                Text("\(speed.rawValue)x")
                                if viewModel.playbackSpeed == speed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("\(viewModel.playbackSpeed.rawValue)x")
                        .frame(width: 40)
                }.help("播放速度")
            }
        }
        .overlay {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text(viewModel.loadingMessage).font(.callout)
                    Button("取消") { viewModel.returnToHome() }
                }
                .padding(24).modifier(PlayerSurface())
            }
        }
        .alert("字幕提示", isPresented: Binding(get: { viewModel.subtitleError != nil }, set: { if !$0 { viewModel.subtitleError = nil } })) {
            Button("好", role: .cancel) { viewModel.subtitleError = nil }
        } message: { Text(viewModel.subtitleError ?? "") }
        .alert("无法播放视频", isPresented: Binding(
            get: { viewModel.playbackError != nil },
            set: { if !$0 { viewModel.playbackError = nil } }
        )) {
            Button("好", role: .cancel) { viewModel.playbackError = nil }
            Button("打开其他文件") { viewModel.openFilePanel() }
        } message: {
            Text(viewModel.playbackError ?? "")
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        var urls = [Int: URL]()
        for (index, provider) in providers.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else { url = item as? URL }
                DispatchQueue.main.async {
                    urls[index] = url
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            viewModel.handleDroppedFiles(urls.sorted { $0.key < $1.key }.map(\.value))
        }
        return true
    }

}

/// A shared chrome keeps playback controls consistent in every projection mode.
struct PlaybackChrome<Surface: View>: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var controlsVisible = true
    @State private var showQuickSettings = false
    @State private var hideTask: Task<Void, Never>?
    let surface: Surface

    init(@ViewBuilder surface: () -> Surface) { self.surface = surface() }

    var body: some View {
        ZStack(alignment: .trailing) {
            surface.scaleEffect(viewModel.videoZoom).clipped()
            GeometryReader { geometry in
            VStack {
                Spacer()
                if !viewModel.activeSubtitleText.isEmpty {
                    Text(viewModel.activeSubtitleText)
                        .font(.system(size: viewModel.subtitleFontSize, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(viewModel.subtitleColor)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(viewModel.showSubtitleBackground ? viewModel.subtitleBackgroundColor.opacity(0.8) : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                        .opacity(viewModel.subtitleOpacity)
                        .padding(.horizontal, 32)
                        .padding(.bottom, max(geometry.size.height * viewModel.subtitlePosition,
                            controlsVisible || !viewModel.isPlaying || viewModel.seekKeepsControlsVisible || showQuickSettings ? 132 : 12))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.allowsHitTesting(false)
            VStack {
                if !viewModel.isFullscreen {
                    TopBar()
                }
                Spacer()
                BottomControls(showQuickSettings: $showQuickSettings)
            }
            .opacity(controlsVisible || !viewModel.isPlaying || viewModel.seekKeepsControlsVisible || showQuickSettings ? 1 : 0)
            .allowsHitTesting(controlsVisible || !viewModel.isPlaying || viewModel.seekKeepsControlsVisible || showQuickSettings)
            .animation(.easeInOut(duration: 0.2), value: controlsVisible)
            if showQuickSettings {
                QuickSettingsPanel(showPanel: $showQuickSettings)
                    .padding(12)
            }
        }
        .overlay(alignment: .top) {
            if let feedback = viewModel.subtitleFeedback {
                Text(feedback).font(.callout.monospacedDigit()).foregroundColor(.white)
                    .padding(10).background(.black.opacity(0.65), in: Capsule())
                    .padding(.top, 48).allowsHitTesting(false)
            }
        }
        .onContinuousHover { phase in
            if case .active = phase { revealControls() }
        }
        .onAppear { revealControls() }
        .onChange(of: viewModel.isPlaying) { _ in revealControls() }
        .onChange(of: viewModel.seekKeepsControlsVisible) { _ in revealControls() }
        .onChange(of: showQuickSettings) { _ in revealControls() }
        .onDisappear { hideTask?.cancel() }
        .ignoresSafeArea(.all, edges: viewModel.isFullscreen ? .all : [])
    }

    private func revealControls() {
        controlsVisible = true
        hideTask?.cancel()
        guard viewModel.isPlaying, !viewModel.seekKeepsControlsVisible, !showQuickSettings else { return }
        hideTask = Task { @MainActor in
            // Keep the video unobstructed during playback. Controls reappear as soon
            // as the pointer moves, but fade out quickly when it leaves the player.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }
}

struct StandardPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    var body: some View {
        PlaybackChrome {
            ZStack {
                Color.black
                if let player = viewModel.player {
                    SimpleVideoPlayer(player: player, layout: viewModel.videoLayout)
                        .onAppear { viewModel.setupPiP() }
                        .onChange(of: viewModel.currentVideoURL) { _ in viewModel.setupPiP() }
                }
            }
            .onTapGesture(count: 2) { viewModel.performClickAction(doubleClick: true) }
            .onTapGesture { viewModel.performClickAction() }
        }
    }
}

struct TopBar: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        HStack {
            Button(action: { viewModel.returnToHome() }) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("返回主页")
            Text(viewModel.videoTitle)
                .font(.callout.weight(.medium)).foregroundColor(.white).lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.42), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18)))
                .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
            Spacer()

            HStack(spacing: 12) {
                if viewModel.isABLooping {
                    Text("A-B 循环")
                        .font(.caption).foregroundColor(.green)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.green.opacity(0.3)).cornerRadius(4)
                }
                if viewModel.isLooping {
                    Image(systemName: "repeat").foregroundColor(.accentColor)
                }
                if viewModel.windowFloat {
                    Image(systemName: "pin.fill").foregroundColor(.accentColor)
                }
            }.padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(LinearGradient(gradient: Gradient(colors: [.black.opacity(0.8), .clear]),
                                   startPoint: .top, endPoint: .bottom))
    }
}

struct BottomControls: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Binding var showQuickSettings: Bool

    var body: some View {
        VStack(spacing: 10) {
            PlaybackTimeline()
            HStack(spacing: 16) {
                CtrlBtn(icon: "backward.end.fill") { viewModel.previousTrack() }.help("上一个视频")
                CtrlBtn(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", size: .title2) {
                    viewModel.togglePlayPause()
                }.help("播放 / 暂停（空格）")
                CtrlBtn(icon: "forward.end.fill") { viewModel.nextTrack() }.help("下一个视频")
                CtrlBtn(icon: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                    viewModel.toggleMute()
                }.help("静音（M）")
                Slider(value: $viewModel.volume, in: 0...1)
                    .frame(width: 72).accessibilityLabel("音量")
                Spacer(minLength: 4)
                Menu {
                    Section("全景视频") {
                        ForEach(VRMode.allCases) { mode in
                            Button { viewModel.threeDMode = .none; viewModel.vrMode = mode } label: {
                                Label(mode.rawValue, systemImage: viewModel.vrMode == mode ? "checkmark" : "circle")
                            }
                        }
                    }
                    Section("3D 视频") {
                        ForEach(ThreeDMode.allCases) { mode in
                            Button { viewModel.vrMode = .none; viewModel.threeDMode = mode } label: {
                                Label(mode.rawValue, systemImage: viewModel.threeDMode == mode ? "checkmark" : "circle")
                            }
                        }
                    }
                } label: {
                    Text(viewModel.vrMode != .none ? viewModel.vrMode.rawValue :
                         viewModel.threeDMode != .none ? viewModel.threeDMode.rawValue : "播放模式")
                        .font(.callout)
                }.menuStyle(.borderlessButton).fixedSize().help("普通 / 360° 全景 / 3D")
                Menu {
                    Toggle("单曲循环", isOn: $viewModel.isLooping)
                    Toggle("随机播放", isOn: $viewModel.shufflePlayback)
                    Divider()
                    Button("设置 A 点（A）") { viewModel.setLoopPointA() }
                    Button("设置 B 点（B）") { viewModel.setLoopPointB() }
                    Button("清除 A-B 循环") { viewModel.clearABLoop() }
                    Divider()
                    Menu("画面布局") {
                        ForEach(VideoLayout.allCases) { layout in
                            Button(layout.rawValue) { viewModel.videoLayout = layout }
                        }
                    }
                    Button("截图（⌘S）") { viewModel.takeScreenshot() }
                    Button("画中画（P）") { viewModel.togglePiP() }
                        .disabled(viewModel.directPlayback != nil)
                        .help("系统画中画目前仅支持系统播放器播放的视频")
                    Button("停止播放") { viewModel.stopPlayback() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }.menuStyle(.borderlessButton).fixedSize().help("更多播放选项")
                CtrlBtn(icon: "list.bullet") { viewModel.showPlaylist.toggle() }
                    .foregroundColor(viewModel.showPlaylist ? .accentColor : .primary)
                    .help(viewModel.showPlaylist ? "隐藏播放列表" : "显示播放列表")
                    .accessibilityLabel("播放列表")
                    .accessibilityValue(viewModel.showPlaylist ? "已展开" : "已收起")
                CtrlBtn(icon: "slider.horizontal.3") { showQuickSettings.toggle() }.help("快速设置")
                CtrlBtn(icon: viewModel.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    viewModel.toggleFullscreen()
                }.help(viewModel.isFullscreen ? "退出全屏（F）" : "全屏（F）")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .modifier(PlayerSurface())
        .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
        .padding(16)
    }
}

struct PlaybackTimeline: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    var body: some View {
        HStack(spacing: 12) {
            Text(viewModel.formatTime(viewModel.isScrubbing ? viewModel.scrubTarget : viewModel.currentTime))
            Slider(value: Binding(
                get: {
                    guard viewModel.duration > 0 else { return 0 }
                    let time = viewModel.isScrubbing ? viewModel.scrubTarget : viewModel.currentTime
                    return max(0, min(1, time / viewModel.duration))
                },
                set: { viewModel.scrubTarget = $0 * viewModel.duration }
            ), in: 0...1, onEditingChanged: { editing in
                if editing { viewModel.beginScrubbing() }
                else { viewModel.seek(to: viewModel.scrubTarget) }
            })
            .disabled(viewModel.duration <= 0)
            .accessibilityLabel("播放进度")
            Text(viewModel.formatTime(viewModel.duration))
                .foregroundColor(.secondary)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
    }
}

struct CtrlBtn: View {
    let icon: String
    var size: Font = .body
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(size)
                .frame(width: 28, height: 28).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct QuickSettingsPanel: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Binding var showPanel: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack {
                Text("快速设置")
                    .font(.headline)
                Spacer()
                Button(action: { showPanel = false }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("画面").font(.subheadline).fontWeight(.semibold).foregroundColor(.accentColor)
                        QSSlider(label: "亮度", value: $viewModel.brightness, range: -1...1)
                        QSSlider(label: "对比度", value: $viewModel.contrast, range: -1...1)
                        QSSlider(label: "饱和度", value: $viewModel.saturation, range: -1...1)
                        QSSlider(label: "色相", value: $viewModel.hue, range: -180...180)
                        Button("重置画面") {
                            viewModel.brightness = 0; viewModel.contrast = 0
                            viewModel.saturation = 0; viewModel.hue = 0
                        }.font(.caption)
                    }

                    Divider()

                    Group {
                        Text("音频").font(.subheadline).fontWeight(.semibold).foregroundColor(.accentColor)
                        QSSlider(label: "音频延迟", value: $viewModel.audioDelay, range: -5...5)
                    }

                    Divider()

                    Group {
                        Text("字幕").font(.subheadline).fontWeight(.semibold).foregroundColor(.accentColor)
                        QSSlider(label: "字幕延迟（秒）", value: $viewModel.subtitleDelay, range: -60...60)
                        SubtitleAppearanceControls()
                        Text("Z 提前 · X 延后 · ⇧Z 复位").font(.caption).foregroundColor(.secondary)
                        if let status = viewModel.subtitleStatus { Text(status).font(.caption).foregroundColor(.secondary) }
                        Toggle("字幕背景", isOn: $viewModel.showSubtitleBackground)
                        Picker("字幕", selection: $viewModel.selectedSubtitleTrack) {
                            Text("关闭").tag(-1)
                            ForEach(viewModel.subtitleTracks) { Text($0.name).tag($0.id) }
                        }
                        Button("加载字幕…") { viewModel.openSubtitlePanel() }
                        if let error = viewModel.subtitleError { Text(error).font(.caption).foregroundColor(.red) }
                    }

                    Divider()

                    Group {
                        Text("播放").font(.subheadline).fontWeight(.semibold).foregroundColor(.accentColor)
                        if let note = viewModel.compatibilityNote { Text(note).font(.caption).foregroundColor(.secondary) }
                        Toggle("循环播放", isOn: $viewModel.isLooping)
                        Toggle("随机播放", isOn: $viewModel.shufflePlayback)
                        Toggle("记住位置", isOn: $viewModel.rememberLastPosition)
                    }
                }.padding(16)
            }
        }
        .frame(width: 260)
        .modifier(PlayerSurface())
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
    }
}

struct QSSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.1f", value)).font(.caption).foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = PlayerPalette(scheme: scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    Image("MocpotLogo")
                        .resizable().scaledToFit()
                        .frame(width: 80, height: 80)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mocpot").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("每一种视角，都值得沉浸").font(.callout).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("你的私人放映室").font(.caption).foregroundColor(.secondary)
                }

                VStack(spacing: 18) {
                Image("MocpotLogo").resizable().scaledToFit().frame(width: 48, height: 48)
                    VStack(spacing: 6) {
                        Text("开始一场放映").font(.title2.weight(.semibold))
                        Text("拖入视频，或选择本地文件").foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button { viewModel.openFilePanel() } label: {
                            Label("打开视频", systemImage: "play.fill").padding(.horizontal, 8)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                        .tint(Color(red: 0.12, green: 0.34, blue: 0.72))
                        Button { viewModel.openFolderPanel() } label: {
                            Label("导入文件夹", systemImage: "folder").padding(.horizontal, 8)
                        }.buttonStyle(.bordered).controlSize(.large)
                    }
                    Text("⌘ O  打开文件").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                }
                .padding(28).frame(maxWidth: .infinity)
                .modifier(PlayerSurface(radius: 20))

                HStack(spacing: 12) {
                    FeatureBadge(icon: "play.tv", title: "日常观影", subtitle: "专注每一帧")
                    FeatureBadge(icon: "cube", title: "3D 视频", subtitle: "切换播放视角")
                    FeatureBadge(icon: "globe", title: "360° 全景", subtitle: "拖拽探索画面")
                }

                if !viewModel.visibleRecentFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近播放").font(.headline)
                            Spacer()
                            Text("继续上次的精彩").font(.caption).foregroundColor(.secondary)
                        }
                        VStack(spacing: 0) {
                            ForEach(viewModel.visibleRecentFiles.prefix(5), id: \.self) { url in
                                Button { viewModel.openFile(url: url) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "film").foregroundColor(palette.accent)
                                            .frame(width: 32, height: 32)
                                            .background(palette.inset, in: RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(url.deletingPathExtension().lastPathComponent).font(.callout).lineLimit(1)
                                            Text(url.pathExtension.uppercased()).font(.caption2).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "play.circle").foregroundColor(.secondary)
                                    }.padding(12).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if url != viewModel.visibleRecentFiles.prefix(5).last { Divider().padding(.leading, 56) }
                            }
                        }.modifier(PlayerSurface(radius: 12))
                    }
                }
            }
            .padding(36).frame(maxWidth: 820).frame(maxWidth: .infinity)
        }
        .foregroundColor(.primary)
        .background(palette.canvas)
    }
}

struct FeatureBadge: View {
    let icon: String, title: String, subtitle: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundColor(PlayerPalette(scheme: scheme).accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16).frame(maxWidth: .infinity)
        .modifier(PlayerSurface(radius: 12))
    }
}
