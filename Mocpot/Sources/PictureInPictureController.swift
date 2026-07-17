import AVKit
import Combine

class PictureInPictureController: NSObject, ObservableObject {
    @Published var isPiPActive = false
    
    private var pipController: AVPictureInPictureController?
    
    func setup(with playerView: AVPlayerView) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported on this device")
            return
        }
        
        guard let playerLayer = playerView.layer else {
            print("No player layer found")
            return
        }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer as! AVPlayerLayer)
        pipController?.delegate = self
        pipController?.setValue(1, forKey: "controlsStyle")
        
        print("PiP controller initialized successfully")
    }
    
    func togglePiP() {
        guard let pipController = pipController else {
            print("PiP controller not initialized")
            return
        }
        
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else {
            pipController.startPictureInPicture()
        }
    }
    
    func startPiP() {
        pipController?.startPictureInPicture()
    }
    
    func stopPiP() {
        pipController?.stopPictureInPicture()
    }
}

extension PictureInPictureController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = true
        }
        print("PiP will start")
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP did start")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
        print("PiP will stop")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP did stop")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
        print("PiP failed to start: \(error.localizedDescription)")
    }
}
