import AVFoundation
import SwiftUI

struct ThreeDPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        PlaybackChrome {
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
        }
        .onTapGesture(count: 2) { viewModel.performClickAction(doubleClick: true) }
        .onTapGesture { viewModel.performClickAction() }
        }
    }
}
