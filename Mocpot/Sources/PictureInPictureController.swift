import AVKit
import Combine

class PictureInPictureController: NSObject, ObservableObject {
    @Published var isPiPActive = false
    
    private var pipController: AVPictureInPictureController?
    
    func setup(with player: AVPlayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported on this device")
            return
        }
        
        // Create a dedicated player layer for PiP
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        playerLayer.opacity = 0
        playerLayer.isHidden = true
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        
        print("PiP controller initialized")
    }
    
    func togglePiP() {
        guard let pipController = pipController else {
            print("PiP not initialized")
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
    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        print("PiP will start")
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        print("PiP did start")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("PiP will stop")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("PiP did stop")
    }
    
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed: \(error.localizedDescription)")
    }
    
    func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    func pictureInPictureController(_ controller: AVPictureInPictureController, willStopPictureInPictureWithAnimationControlledByUser userStoppedIt: Bool) {
        print("PiP will stop, user stopped: \(userStoppedIt)")
    }
}
