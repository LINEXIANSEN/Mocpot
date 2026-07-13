import AVFoundation
import SceneKit
import SwiftUI

struct VRPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var yaw: Double = 0
    @State private var pitch: Double = 0
    @State private var lastDragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var showHint = true

    var body: some View {
        ZStack {
            Color.black

            if let player = viewModel.player {
                VRSceneContainer(player: player, yaw: $yaw, pitch: $pitch)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !isDragging { lastDragLocation = value.location; isDragging = true }
                                yaw -= (value.location.x - lastDragLocation.x) * 0.008
                                pitch = max(-1.2, min(1.2, pitch + (value.location.y - lastDragLocation.y) * 0.008))
                                lastDragLocation = value.location
                            }
                            .onEnded { _ in isDragging = false }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.4)) { yaw = 0; pitch = 0 }
                    }
            }

            VStack {
                HStack {
                    VRInfoBadge(text: viewModel.vrMode.rawValue)
                    Spacer()
                    if showHint {
                        VRInfoBadge(text: "拖拽旋转 · 双击回正")
                            .transition(.opacity)
                    }
                }.padding(16)
                Spacer()
                VRControlBar()
            }
        }
        .background(Color.black)
        .onAppear {
            if viewModel.vrMode == .none { viewModel.vrMode = .mono }
            showHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showHint = false }
            }
        }
    }
}

struct VRSceneContainer: NSViewRepresentable {
    let player: AVPlayer
    @Binding var yaw: Double
    @Binding var pitch: Double

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let sceneView = SCNView()
        sceneView.backgroundColor = .black
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.isPlaying = true
        sceneView.rendersContinuously = true
        sceneView.frame = container.bounds
        sceneView.autoresizingMask = [.width, .height]

        let scene = SCNScene()

        let sphere = SCNSphere(radius: 50)
        sphere.segmentCount = 64

        let material = SCNMaterial()
        material.isDoubleSided = true
        material.diffuse.contents = player
        material.lightingModel = .constant
        material.cullMode = .front
        sphere.firstMaterial = material

        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.name = "vrSphere"
        scene.rootNode.addChildNode(sphereNode)

        let camera = SCNCamera()
        camera.fieldOfView = 80
        camera.zNear = 0.1
        camera.zFar = 200

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        sceneView.scene = scene
        sceneView.pointOfView = cameraNode

        container.addSubview(sceneView)

        context.coordinator.cameraNode = cameraNode
        context.coordinator.sceneView = sceneView

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let cameraNode = context.coordinator.cameraNode,
              let sceneView = context.coordinator.sceneView else { return }

        cameraNode.eulerAngles = SCNVector3(pitch, yaw, 0)

        if let sphereNode = sceneView.scene?.rootNode.childNode(withName: "vrSphere", recursively: false) {
            sphereNode.geometry?.firstMaterial?.diffuse.contents = player
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var cameraNode: SCNNode?
        var sceneView: SCNView?
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
                ).accentColor(.purple)
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
