import AVFoundation
import AVKit
import SwiftUI

struct SimpleVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let pv = AVPlayerView()
        pv.player = player
        pv.controlsStyle = .none
        pv.videoGravity = .resizeAspect
        pv.layer?.backgroundColor = NSColor.black.cgColor
        return pv
    }

    func updateNSView(_ pv: AVPlayerView, context: Context) {
        pv.player = player
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var isDragOver = false
    @State private var showPlaylist = false
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if viewModel.currentVideoURL == nil {
                    WelcomeView()
                } else {
                    if viewModel.vrMode != .none {
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

            if showPlaylist {
                PlaylistView()
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color.black)
        .frame(minWidth: 800, minHeight: 500)
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

                Button(action: { showPlaylist.toggle() }) {
                    Image(systemName: "list.bullet").help("播放列表 (⌘L)")
                }.keyboardShortcut("l", modifiers: .command)
            }

            ToolbarItemGroup(placement: .principal) {
                Text(viewModel.videoTitle)
                    .font(.headline).foregroundColor(.white).lineLimit(1)
            }

            ToolbarItemGroup(placement: .automatic) {
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
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleGlobalKeyDown(event)
                return event
            }
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                viewModel.openFile(url: url)
            }
        }
        return true
    }

    func handleGlobalKeyDown(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommand = flags.contains(.command)

        switch event.keyCode {
        case 0:
            if !isCommand { viewModel.setLoopPointA() }
        case 11:
            if !isCommand { viewModel.setLoopPointB() }
        case 51:
            if !isCommand { viewModel.clearABLoop() }
        default:
            break
        }
    }
}

struct StandardPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var isHovering = false
    @State private var osdText = ""
    @State private var showOSD = false
    @State private var showQuickSettings = false
    @State private var hideUITimer: Timer?

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black

                if let player = viewModel.player {
                    SimpleVideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            viewModel.setupPiP()
                        }
                }

                if showOSD {
                    Text(osdText)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.black.opacity(0.7)).cornerRadius(8)
                        .transition(.opacity)
                }

                VStack {
                    if isHovering || !viewModel.isPlaying {
                        TopBar()
                    }
                    Spacer()
                    if isHovering || !viewModel.isPlaying {
                        BottomControls(showQuickSettings: $showQuickSettings)
                    }
                }
                .opacity(isHovering ? 1 : 0)

                if showQuickSettings {
                    QuickSettingsPanel(showPanel: $showQuickSettings)
                        .transition(.move(edge: .trailing))
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isHovering = hovering
                }
                if hovering {
                    resetHideUITimer()
                } else {
                    hideUITimer?.invalidate()
                }
            }
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    viewModel.toggleFullscreen()
                }
            )
            .onTapGesture(count: 1) {
                viewModel.togglePlayPause()
                osdText = viewModel.isPlaying ? "▶ 播放" : "⏸ 暂停"
                showOSD = true
                withAnimation { isHovering = true }
                resetHideUITimer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showOSD = false }
                }
            }
        }
    }

    private func resetHideUITimer() {
        hideUITimer?.invalidate()
        hideUITimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isHovering = false
                }
            }
        }
    }
}

struct TopBar: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        HStack {
            Text(viewModel.videoTitle)
                .font(.headline).foregroundColor(.white).lineLimit(1)
                .padding(.horizontal, 16)
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
        VStack(spacing: 0) {
            // Timeline
            HStack(spacing: 12) {
                Text(viewModel.formatTime(viewModel.isScrubbing ? viewModel.scrubTarget : viewModel.currentTime))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.white)

                Slider(
                    value: Binding(
                        get: { viewModel.isScrubbing ? viewModel.scrubTarget / max(viewModel.duration, 1) : (viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0) },
                        set: { newValue in
                            viewModel.isScrubbing = true
                            viewModel.scrubTarget = newValue * viewModel.duration
                            viewModel.currentTime = newValue * viewModel.duration
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if editing {
                            viewModel.isScrubbing = true
                        } else {
                            viewModel.seek(to: viewModel.scrubTarget)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.isScrubbing = false
                            }
                        }
                    }
                ).accentColor(.accentColor)

                Text(viewModel.formatTime(viewModel.duration))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
            }.padding(.horizontal, 16).padding(.bottom, 8)

            // Controls
            HStack {
                HStack(spacing: 16) {
                    CtrlBtn(icon: "backward.fill") { viewModel.previousTrack() }
                    CtrlBtn(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", size: .title) {
                        viewModel.togglePlayPause()
                    }
                    CtrlBtn(icon: "forward.fill") { viewModel.nextTrack() }
                    CtrlBtn(icon: "stop.fill") { viewModel.stopPlayback() }
                    CtrlBtn(icon: viewModel.isLooping ? "repeat.1" : "repeat") { viewModel.toggleLooping() }
                    CtrlBtn(icon: viewModel.shufflePlayback ? "shuffle" : "arrow.triangle.2.circlepath") {
                        viewModel.shufflePlayback.toggle()
                    }
                    .foregroundColor(viewModel.shufflePlayback ? .accentColor : .white)
                    CtrlBtn(icon: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right") {
                        viewModel.setLoopPointA()
                    }.help("设置 A 点 (A)")
                    CtrlBtn(icon: "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left") {
                        viewModel.setLoopPointB()
                    }.help("设置 B 点 (B)")
                }

                Spacer()

                HStack(spacing: 16) {
                    CtrlBtn(icon: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill") {
                        viewModel.toggleMute()
                    }
                    Slider(value: $viewModel.volume, in: 0...1).frame(width: 80).accentColor(.white)

                    Divider().frame(height: 20)

                    Menu {
                        ForEach(ThreeDMode.allCases) { mode in
                            Button(action: { viewModel.threeDMode = mode }) {
                                HStack { Text(mode.rawValue); if viewModel.threeDMode == mode { Image(systemName: "checkmark") } }
                            }
                        }
                    } label: {
                        Image(systemName: "3d").font(.title3)
                            .foregroundColor(viewModel.threeDMode != .none ? .cyan : .white)
                    }.menuStyle(.borderlessButton).help("3D 模式")

                    Menu {
                        ForEach(VRMode.allCases) { mode in
                            Button(action: { viewModel.vrMode = mode }) {
                                HStack { Text(mode.rawValue); if viewModel.vrMode == mode { Image(systemName: "checkmark") } }
                            }
                        }
                    } label: {
                        Image(systemName: "visionpro").font(.title3)
                            .foregroundColor(viewModel.vrMode != .none ? .purple : .white)
                    }.menuStyle(.borderlessButton).help("VR 模式")

                    Divider().frame(height: 20)

                    CtrlBtn(icon: "camera.fill") { viewModel.takeScreenshot() }.help("截图 (⌘S)")
                    CtrlBtn(icon: "sidebar.right") { showQuickSettings.toggle() }.help("快速设置")

                    Menu {
                        ForEach(VideoLayout.allCases) { layout in
                            Button(action: { viewModel.videoLayout = layout }) {
                                HStack { Text(layout.rawValue); if viewModel.videoLayout == layout { Image(systemName: "checkmark") } }
                            }
                        }
                    } label: {
                        Image(systemName: "rectangle.expand.vertical").font(.title3)
                    }.menuStyle(.borderlessButton).help("画面布局")

                    CtrlBtn(icon: "arrow.up.left.and.arrow.down.right") { viewModel.toggleFullscreen() }.help("全屏 (F)")

                    CtrlBtn(icon: "rectangle.inset.bottomright.filled") { viewModel.togglePiP() }.help("画中画")
                }
            }.padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.85)]),
                                   startPoint: .top, endPoint: .bottom))
    }
}

struct CtrlBtn: View {
    let icon: String
    var size: Font = .title3
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(size).foregroundColor(.white)
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
                        QSSlider(label: "字幕延迟", value: $viewModel.subtitleDelay, range: -5...5)
                        Toggle("字幕背景", isOn: $viewModel.showSubtitleBackground)
                    }

                    Divider()

                    Group {
                        Text("播放").font(.subheadline).fontWeight(.semibold).foregroundColor(.accentColor)
                        Toggle("循环播放", isOn: $viewModel.isLooping)
                        Toggle("随机播放", isOn: $viewModel.shufflePlayback)
                        Toggle("记住位置", isOn: $viewModel.rememberLastPosition)
                    }
                }.padding(16)
            }
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
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

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 80)).foregroundColor(.accentColor)
                .shadow(color: .accentColor.opacity(0.3), radius: 20)

            VStack(spacing: 8) {
                Text("Mocpot").font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("全功能视频播放器").font(.title3).foregroundColor(.gray)
            }

            VStack(spacing: 12) {
                Text("将视频文件拖放至此").foregroundColor(.gray)
                Text("或").foregroundColor(.gray)
                HStack(spacing: 16) {
                    Button("打开文件") { viewModel.openFilePanel() }
                        .buttonStyle(.bordered).controlSize(.large)
                    Button("导入文件夹") { viewModel.openFolderPanel() }
                        .buttonStyle(.bordered).controlSize(.large)
                }
            }.padding(.top, 10)

            HStack(spacing: 40) {
                FeatureBadge(icon: "play.tv", title: "标准播放", subtitle: "支持所有格式")
                FeatureBadge(icon: "3d", title: "3D 视频", subtitle: "左右/上下/红蓝")
                FeatureBadge(icon: "visionpro", title: "VR 全景", subtitle: "360° 沉浸体验")
            }.padding(.top, 20)

            if !viewModel.recentFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近播放").font(.caption).foregroundColor(.gray)
                    ForEach(viewModel.recentFiles.prefix(5), id: \.self) { url in
                        Button(action: { viewModel.openFile(url: url) }) {
                            HStack {
                                Image(systemName: "clock")
                                Text(url.lastPathComponent).lineLimit(1)
                                Spacer()
                            }
                            .font(.caption).foregroundColor(.accentColor)
                        }.buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 400)
                .padding(.top, 20)
            }
        }
    }
}

struct FeatureBadge: View {
    let icon: String, title: String, subtitle: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title)
            Text(title).font(.caption).fontWeight(.semibold)
            Text(subtitle).font(.caption2).foregroundColor(.gray)
        }.foregroundColor(.accentColor).frame(width: 100)
    }
}
