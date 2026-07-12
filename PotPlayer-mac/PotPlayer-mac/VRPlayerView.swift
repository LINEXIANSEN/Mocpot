import AVFoundation
import SwiftUI

struct VRPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var yaw: Double = 0
    @State private var pitch: Double = 0
    @State private var lastDragLocation: CGPoint = .zero
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Color.black

            if let player = viewModel.player {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let videoW = h * 2.5
                    let panRange = videoW - w
                    let normalizedYaw = yaw.truncatingRemainder(dividingBy: 360)
                    let xOffset = -normalizedYaw / 360.0 * videoW

                    SimpleVideoPlayer(player: player)
                        .frame(width: videoW, height: h)
                        .clipped()
                        .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                        .offset(x: xOffset > 0 ? xOffset - panRange : (xOffset < -panRange ? xOffset + panRange : xOffset))
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if !isDragging { lastDragLocation = value.location; isDragging = true }
                            yaw += (value.location.x - lastDragLocation.x) * 0.5
                            pitch = max(-70, min(70, pitch + (value.location.y - lastDragLocation.y) * 0.5))
                            lastDragLocation = value.location
                        }
                        .onEnded { _ in isDragging = false }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) { yaw = 0; pitch = 0 }
                }
            }

            VStack {
                HStack {
                    VRInfoBadge(text: viewModel.vrMode.rawValue)
                    Spacer()
                    VRInfoBadge(text: "拖拽旋转 · 双击回正")
                }.padding(16)
                Spacer()
                VRControlBar()
            }
        }
        .background(Color.black)
        .onAppear { if viewModel.vrMode == .none { viewModel.vrMode = .mono } }
    }
}

struct VRInfoBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.caption).foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.black.opacity(0.7)).cornerRadius(6)
    }
}

struct VRControlBar: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.formatTime(viewModel.currentTime))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                Slider(value: $viewModel.currentTime, in: 0...max(viewModel.duration, 1)) { e in
                    if !e { viewModel.seek(to: viewModel.currentTime) }
                }.accentColor(.purple)
                Text(viewModel.formatTime(viewModel.duration))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
            }.padding(.horizontal, 16).padding(.bottom, 8)

            HStack(spacing: 20) {
                VRBtn(icon: "backward.fill") { viewModel.previousTrack() }
                VRBtn(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", large: true) { viewModel.togglePlayPause() }
                VRBtn(icon: "stop.fill") { viewModel.stopPlayback() }
                VRBtn(icon: "forward.fill") { viewModel.nextTrack() }
                Spacer()
                VRBtn(icon: viewModel.isLooping ? "repeat.1" : "repeat") { viewModel.toggleLooping() }
                Menu {
                    ForEach(VRMode.allCases) { mode in
                        Button(action: { viewModel.vrMode = mode }) {
                            HStack { Text(mode.rawValue); if viewModel.vrMode == mode { Image(systemName: "checkmark") } }
                        }
                    }
                } label: {
                    Text(viewModel.vrMode.rawValue).font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.purple.opacity(0.5)).cornerRadius(4)
                }.menuStyle(.borderlessButton)
                VRBtn(icon: "arrow.up.left.and.arrow.down.right") { viewModel.toggleFullscreen() }
            }.padding(.horizontal, 16).padding(.bottom, 16)
        }
        .background(LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom))
    }
}

struct VRBtn: View {
    let icon: String
    var large: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: icon).font(large ? .title : .title3).foregroundColor(.white) }.buttonStyle(.plain)
    }
}
