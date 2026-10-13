import SwiftUI
import Combine

struct PlaylistView: View, Equatable {
    @Environment(\.colorScheme) private var scheme
    let viewModel: PlayerViewModel
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.viewModel === rhs.viewModel }
    @State private var playlist: [URL] = []
    @State private var currentURL: URL?
    @State private var importing = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var searchText = ""
    @State private var selectedItems: Set<URL> = []
    @State private var sortOrder: SortOrder = .orderAdded

    enum SortOrder: String, CaseIterable, Identifiable {
        case orderAdded = "添加顺序"
        case nameAsc = "名称 A→Z"
        case nameDesc = "名称 Z→A"
        case dateAsc = "时间 旧→新"
        case dateDesc = "时间 新→旧"

        var id: String { rawValue }
    }

    @State private var displayedItems: [URL] = []
    private func refreshItems() {
        refreshTask?.cancel()
        let files = playlist, query = searchText, order = sortOrder
        refreshTask = Task { @MainActor in
            let worker = Task.detached(priority: .utility) {
                var items = files.filter { query.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(query) }
                switch order {
                case .orderAdded: break
                case .nameAsc: items.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                case .nameDesc: items.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending }
                case .dateAsc, .dateDesc:
                    var dates: [URL: Date] = [:]
                    for url in items {
                        if Task.isCancelled { return [URL]() }
                        dates[url] = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    }
                    items.sort {
                        let a = dates[$0]!, b = dates[$1]!
                        if a == b { return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                        return order == .dateAsc ? a < b : a > b
                    }
                }
                return items
            }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            displayedItems = result
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("播放列表")
                    .font(.headline)
                Spacer()
                if importing { ProgressView().controlSize(.small).help("正在导入文件夹…") }
                Text("\(playlist.count)")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2)).cornerRadius(8)
                PlaylistCloseButton { viewModel.showPlaylist = false }
                    .frame(width: 28, height: 28)
            }.padding(.horizontal, 12).padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索...", text: $searchText).textFieldStyle(.plain)
            }.padding(8).background(PlayerPalette(scheme: scheme).inset).cornerRadius(6)
             .padding(.horizontal, 12).padding(.top, 8)

            HStack {
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button(action: { sortOrder = order }) {
                            HStack {
                                Text(order.rawValue)
                                if sortOrder == order { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down").font(.caption)
                        Text(sortOrder.rawValue).font(.caption)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15)).cornerRadius(4)
                }.menuStyle(.borderlessButton)

                Spacer()

                Button(action: { viewModel.shufflePlaylist() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle").font(.caption)
                        Text("随机").font(.caption)
                    }
                }.buttonStyle(.borderless)
            }.padding(.horizontal, 12).padding(.top, 4)

            Divider().padding(.top, 8)

            List(selection: $selectedItems) {
                ForEach(displayedItems, id: \.self) { url in
                    PlaylistItemView(url: url, isSelected: currentURL == url)
                        .tag(url)
                        .onTapGesture(count: 2) { viewModel.playURL(url) }
                        .contextMenu {
                            Button("播放") { viewModel.playURL(url) }
                            Button("3D 播放") { viewModel.playURL(url); viewModel.vrMode = .none; viewModel.threeDMode = .sideBySide }
                            Button("VR 播放") { viewModel.playURL(url); viewModel.threeDMode = .none; viewModel.vrMode = .mono }
                            Divider()
                            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            Button("复制路径") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.path, forType: .string)
                            }
                            Divider()
                            Button("从列表移除") { viewModel.removeFromPlaylist(url) }
                        }
                }
            }.listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .overlay {
                if displayedItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: searchText.isEmpty ? "music.note.list" : "magnifyingglass").font(.title)
                        Text(searchText.isEmpty ? "播放列表还是空的" : "没有匹配的视频").font(.callout)
                        Text(searchText.isEmpty ? "打开视频，开始添加" : "试试其他关键词").font(.caption)
                    }.foregroundColor(.secondary).allowsHitTesting(false)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: { viewModel.openFilePanel() }) {
                    Label("添加", systemImage: "plus").font(.caption)
                }.buttonStyle(.borderless)

                Button(action: { viewModel.shufflePlaylist() }) {
                    Label("随机", systemImage: "shuffle").font(.caption)
                }.buttonStyle(.borderless)

                Spacer()

                Button(action: { viewModel.clearPlaylist() }) {
                    Label("清空", systemImage: "trash").font(.caption)
                }.buttonStyle(.borderless).foregroundColor(.red)
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }
        .foregroundColor(.primary)
        .background(.regularMaterial)
        .background(PlayerPalette(scheme: scheme).surface.opacity(0.62))
        .overlay(alignment: .leading) { Rectangle().fill(PlayerPalette(scheme: scheme).border).frame(width: 1).allowsHitTesting(false) }
        .onReceive(viewModel.$playlist.removeDuplicates().receive(on: DispatchQueue.main)) { playlist = $0; refreshItems() }
        .onReceive(viewModel.$currentVideoURL.removeDuplicates().receive(on: DispatchQueue.main)) { currentURL = $0 }
        .onReceive(viewModel.$isImportingFolder.removeDuplicates().receive(on: DispatchQueue.main)) { importing = $0 }
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: searchText) { _ in refreshItems() }
        .onChange(of: sortOrder) { _ in refreshItems() }
    }
}

/// A native button keeps the entire close target clickable inside the sidebar.
struct PlaylistCloseButton: NSViewRepresentable {
    let close: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(close: close) }
    func makeNSView(context: Context) -> NSButton {
        let button = PlaylistDismissButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭播放列表")!,
                              target: context.coordinator, action: #selector(Coordinator.activate))
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.toolTip = "关闭播放列表"
        button.setAccessibilityLabel("关闭播放列表")
        button.identifier = NSUserInterfaceItemIdentifier("playlist.close")
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) { context.coordinator.close = close }
    final class Coordinator: NSObject {
        var close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        @objc func activate() { close() }
    }
}

final class PlaylistDismissButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) {
        // Close on press, before a playback/layout update can move the release
        // target or enter AppKit's synchronous button-tracking loop.
        guard isEnabled else { return }
        _ = sendAction(action, to: target)
    }
}

struct PlaylistItemView: View {
    let url: URL
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.caption).lineLimit(1)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                Text(url.deletingLastPathComponent().path)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            if isSelected {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2).foregroundColor(.accentColor)
            }
        }.padding(.vertical, 3)
    }

    var fileIcon: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "m4v", "mov": return "film"
        case "mkv", "webm": return "film.stack"
        case "avi", "wmv", "flv": return "video"
        default: return "doc"
        }
    }
}
