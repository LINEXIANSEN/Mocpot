import AVFoundation
import SceneKit
import SwiftUI

struct VRPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        PlaybackChrome {
            ZStack(alignment: .topLeading) {
                Color.black
                if let player = viewModel.player {
                    VRSceneContainer(player: player, isPlaying: viewModel.isPlaying,
                                     togglePlayback: viewModel.togglePlayPause)
                }
                Text("拖拽环顾 · 滚轮缩放 · 双击回正")
                    .font(.caption).foregroundColor(.white.opacity(0.65))
                    .padding(10).background(.black.opacity(0.4), in: Capsule())
                    .padding(.top, 56).padding(.leading, 16)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct VRSceneContainer: NSViewRepresentable {
    let player: AVPlayer
    let isPlaying: Bool
    let togglePlayback: () -> Void

    func makeNSView(context: Context) -> PanoramaSceneView {
        let view = PanoramaSceneView()
        view.backgroundColor = .black
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .none
        let scene = SCNScene()
        let material = SCNMaterial()
        material.diffuse.contents = player
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        let sphere = SCNSphere(radius: 50)
        sphere.segmentCount = 64
        sphere.firstMaterial = material
        scene.rootNode.addChildNode(SCNNode(geometry: sphere))
        let camera = SCNCamera()
        camera.fieldOfView = 80
        camera.zNear = 0.1
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        view.scene = scene
        view.pointOfView = cameraNode
        view.material = material
        view.boundPlayer = player
        view.togglePlayback = togglePlayback
        view.isPlaying = isPlaying
        view.rendersContinuously = isPlaying
        return view
    }

    func updateNSView(_ view: PanoramaSceneView, context: Context) {
        // Updating the playback clock must never recreate the video texture.
        if view.boundPlayer !== player {
            view.material?.diffuse.contents = player
            view.boundPlayer = player
            view.resetCamera()
        }
        if view.isPlaying != isPlaying {
            view.isPlaying = isPlaying
            view.rendersContinuously = isPlaying
        }
        view.togglePlayback = togglePlayback
    }

    static func dismantleNSView(_ view: PanoramaSceneView, coordinator: ()) {
        view.isPlaying = false
        view.rendersContinuously = false
        view.material?.diffuse.contents = nil
        view.boundPlayer = nil
        view.togglePlayback = nil
        view.pendingClick?.cancel()
        view.scene = nil
    }
}

/// Camera movement stays in SceneKit; it does not invalidate the SwiftUI player tree.
final class PanoramaSceneView: SCNView {
    weak var boundPlayer: AVPlayer?
    var material: SCNMaterial?
    var togglePlayback: (() -> Void)?
    private var yaw: CGFloat = 0
    private var pitch: CGFloat = 0
    private var dragDistance: CGFloat = 0
    var pendingClick: DispatchWorkItem?

    override func mouseDown(with event: NSEvent) {
        pendingClick?.cancel()
        dragDistance = 0
    }

    override func mouseDragged(with event: NSEvent) {
        dragDistance += abs(event.deltaX) + abs(event.deltaY)
        yaw -= event.deltaX * 0.006
        pitch = max(-1.45, min(1.45, pitch + event.deltaY * 0.006))
        updateCamera()
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 { resetCamera() }
        else if dragDistance < 3 {
            let click = DispatchWorkItem { [weak self] in self?.togglePlayback?() }
            pendingClick = click
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: click)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let camera = pointOfView?.camera else { return }
        camera.fieldOfView = max(35, min(110, camera.fieldOfView + event.scrollingDeltaY * 0.15))
        needsDisplay = true
    }

    func resetCamera() {
        yaw = 0
        pitch = 0
        pointOfView?.camera?.fieldOfView = 80
        updateCamera()
    }

    private func updateCamera() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        pointOfView?.eulerAngles = SCNVector3(pitch, yaw, 0)
        SCNTransaction.commit()
        needsDisplay = true
    }
}
