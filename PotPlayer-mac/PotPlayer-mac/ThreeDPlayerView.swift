import AVFoundation
import SwiftUI

struct ThreeDPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        ZStack {
            Color.black
            if let player = viewModel.player {
                switch viewModel.threeDMode {
                case .sideBySide:
                    HStack(spacing: 0) {
                        SimpleVideoPlayer(player: player).clipped()
                        Color.white.frame(width: 2)
                        SimpleVideoPlayer(player: player).clipped()
                    }
                case .overUnder:
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            SimpleVideoPlayer(player: player).frame(height: geo.size.height / 2).clipped()
                            Color.white.frame(height: 2)
                            SimpleVideoPlayer(player: player).frame(height: geo.size.height / 2).clipped()
                        }
                    }
                case .anaglyphRedCyan, .anaglyphYellowBlue:
                    ZStack {
                        SimpleVideoPlayer(player: player).allowsHitTesting(false)
                        SimpleVideoPlayer(player: player).blendMode(.multiply).opacity(0.7)
                    }
                default:
                    SimpleVideoPlayer(player: player)
                }
            }
            VStack {
                HStack {
                    Text(viewModel.threeDMode.rawValue).font(.caption).fontWeight(.bold)
                        .foregroundColor(.cyan).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.3)).cornerRadius(4)
                    Spacer()
                    Text("3D 模式").font(.caption).foregroundColor(.cyan)
                }.padding(16)
                Spacer()
                ThreeDCtrlBar()
            }
        }
    }
}

struct ThreeDCtrlBar: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.formatTime(viewModel.currentTime))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                Slider(value: $viewModel.currentTime, in: 0...max(viewModel.duration, 1)) { e in
                    if !e { viewModel.seek(to: viewModel.currentTime) }
                }.frame(maxWidth: 400).accentColor(.cyan)
                Text("\(viewModel.formatTime(viewModel.currentTime)) / \(viewModel.formatTime(viewModel.duration))")
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                Spacer()
            }.padding(.horizontal, 16).padding(.bottom, 8)

            HStack(spacing: 20) {
                ThreeDBtn(icon: "backward.fill") { viewModel.previousTrack() }
                ThreeDBtn(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", large: true) {
                    viewModel.togglePlayPause()
                }
                ThreeDBtn(icon: "stop.fill") { viewModel.stopPlayback() }
                ThreeDBtn(icon: "forward.fill") { viewModel.nextTrack() }
                Spacer()
                ThreeDBtn(icon: viewModel.isLooping ? "repeat.1" : "repeat") { viewModel.toggleLooping() }
                Menu {
                    ForEach(ThreeDMode.allCases) { mode in
                        Button(action: { viewModel.threeDMode = mode }) {
                            HStack { Text(mode.rawValue); if viewModel.threeDMode == mode { Image(systemName: "checkmark") } }
                        }
                    }
                } label: {
                    Text(viewModel.threeDMode.rawValue).font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.5)).cornerRadius(4)
                }.menuStyle(.borderlessButton)
                ThreeDBtn(icon: "arrow.up.left.and.arrow.down.right") { viewModel.toggleFullscreen() }
            }.padding(.horizontal, 16).padding(.bottom, 16)
        }
        .background(LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom))
    }
}

struct ThreeDBtn: View {
    let icon: String
    var large: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: icon).font(large ? .title : .title3).foregroundColor(.white) }.buttonStyle(.plain)
    }
}
