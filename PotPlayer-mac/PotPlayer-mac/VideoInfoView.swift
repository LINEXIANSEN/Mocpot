import SwiftUI

struct VideoInfoView: View {
    let url: URL
    let metadata: VideoMetadata
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("视频信息")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "文件")
                    InfoRow(label: "名称", value: url.lastPathComponent)
                    InfoRow(label: "路径", value: url.path)
                    InfoRow(label: "格式", value: url.pathExtension.uppercased())
                    InfoRow(label: "大小", value: viewModel.formatFileSize(metadata.fileSize))

                    if let date = metadata.creationDate {
                        InfoRow(label: "创建日期", value: formatDate(date))
                    }

                    Divider()

                    SectionHeader(title: "视频")
                    InfoRow(label: "分辨率", value: "\(metadata.width) × \(metadata.height)")
                    InfoRow(label: "编码", value: metadata.codec.isEmpty ? "未知" : metadata.codec)
                    InfoRow(label: "帧率", value: "\(Int(metadata.fps)) fps")
                    InfoRow(label: "码率", value: formatBitrate(metadata.bitrate))

                    Divider()

                    SectionHeader(title: "播放")
                    InfoRow(label: "时长", value: viewModel.formatTime(viewModel.duration))
                    InfoRow(label: "当前时间", value: viewModel.formatTime(viewModel.currentTime))
                    InfoRow(label: "速度", value: "\(viewModel.playbackSpeed.rawValue)×")
                    InfoRow(label: "音量", value: "\(Int(viewModel.volume * 100))%")

                    if viewModel.vrMode != .none {
                        Divider()
                        SectionHeader(title: "VR/3D")
                        InfoRow(label: "模式", value: viewModel.vrMode.rawValue)
                    }

                    if viewModel.threeDMode != .none {
                        InfoRow(label: "3D 模式", value: viewModel.threeDMode.rawValue)
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()

                Button("复制信息") {
                    copyToClipboard()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    func copyToClipboard() {
        let info = """
        文件：\(url.lastPathComponent)
        格式：\(url.pathExtension.uppercased())
        分辨率：\(metadata.width) × \(metadata.height)
        时长：\(viewModel.formatTime(viewModel.duration))
        大小：\(viewModel.formatFileSize(metadata.fileSize))
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    func formatBitrate(_ bitrate: Int) -> String {
        if bitrate >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(bitrate) / 1_000_000)
        } else if bitrate >= 1_000 {
            return String(format: "%.0f kbps", Double(bitrate) / 1_000)
        }
        return "\(bitrate) bps"
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.accentColor)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)

            Spacer()
        }
    }
}
