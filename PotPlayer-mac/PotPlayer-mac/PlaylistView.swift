import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
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

    var filteredPlaylist: [URL] {
        var items = viewModel.playlist
        if !searchText.isEmpty {
            items = items.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
        }
        switch sortOrder {
        case .orderAdded:
            return items
        case .nameAsc:
            return items.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        case .nameDesc:
            return items.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedDescending }
        case .dateAsc:
            return items.sorted { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 < d2
            }
        case .dateDesc:
            return items.sorted { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 > d2
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("播放列表")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.playlist.count)")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2)).cornerRadius(8)
            }.padding(.horizontal, 12).padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索...", text: $searchText).textFieldStyle(.plain)
            }.padding(8).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(6)
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
                ForEach(filteredPlaylist, id: \.self) { url in
                    PlaylistItemView(url: url, isSelected: viewModel.currentVideoURL == url)
                        .tag(url)
                        .onTapGesture(count: 2) { viewModel.playURL(url) }
                        .contextMenu {
                            Button("播放") { viewModel.playURL(url) }
                            Button("3D 播放") { viewModel.threeDMode = .sideBySide; viewModel.playURL(url) }
                            Button("VR 播放") { viewModel.vrMode = .mono; viewModel.playURL(url) }
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
        }.background(Color(nsColor: .windowBackgroundColor))
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
