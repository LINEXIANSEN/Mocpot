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
                        SimpleVideoPlayer(viewModel: viewModel, player: player).equatable().clipped()
                        Color.white.frame(width: 2)
                        SimpleVideoPlayer(viewModel: viewModel, player: player).equatable().clipped()
                    }
                case .overUnder:
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            SimpleVideoPlayer(viewModel: viewModel, player: player).equatable().frame(height: geo.size.height / 2).clipped()
                            Color.white.frame(height: 2)
                            SimpleVideoPlayer(viewModel: viewModel, player: player).equatable().frame(height: geo.size.height / 2).clipped()
                        }
                    }
                case .anaglyphRedCyan, .anaglyphYellowBlue:
                    ZStack {
                        SimpleVideoPlayer(viewModel: viewModel, player: player).equatable().allowsHitTesting(false)
                        SimpleVideoPlayer(viewModel: viewModel, player: player).equatable().blendMode(.multiply).opacity(0.7)
                    }
                default:
                    SimpleVideoPlayer(viewModel: viewModel, player: player).equatable()
                }
            }
        }
        .onTapGesture(count: 2) { viewModel.performClickAction(doubleClick: true) }
        .onTapGesture { viewModel.performClickAction() }
        }
    }
}
