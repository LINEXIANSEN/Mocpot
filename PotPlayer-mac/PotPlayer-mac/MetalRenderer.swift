import AVFoundation
import QuartzCore

class MetalRenderer: NSObject {
    let viewModel: PlayerViewModel
    var videoOutput: AVPlayerItemVideoOutput?
    var pixelBuffer: CVPixelBuffer?

    init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
        super.init()
        setupVideoOutput()
    }

    func setupVideoOutput() {
        guard let playerItem = viewModel.player?.currentItem else { return }

        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        playerItem.add(videoOutput!)
    }

    func updateRotation(pitch: Float, yaw: Float, fov: Float) {
    }

    func draw() {
        guard let output = videoOutput,
              let playerItem = viewModel.player?.currentItem else { return }

        let currentTime = playerItem.currentTime()
        guard output.hasNewPixelBuffer(forItemTime: currentTime) else { return }

        pixelBuffer = output.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil)
    }

    deinit {
    }
}
