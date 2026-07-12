import SwiftUI

struct MenuBarCommands: Commands {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("打开文件...") {
                viewModel.openFilePanel()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("关闭") {
                viewModel.stopPlayback()
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandGroup(after: .toolbar) {
            Menu("播放速度") {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Button("\(speed.rawValue)x") {
                        viewModel.playbackSpeed = speed
                    }
                }
            }

            Menu("画面布局") {
                ForEach(VideoLayout.allCases) { layout in
                    Button(layout.rawValue) {
                        viewModel.videoLayout = layout
                    }
                }
            }

            Menu("3D 模式") {
                ForEach(ThreeDMode.allCases) { mode in
                    Button(mode.rawValue) {
                        viewModel.threeDMode = mode
                    }
                }
            }

            Menu("VR 模式") {
                ForEach(VRMode.allCases) { mode in
                    Button(mode.rawValue) {
                        viewModel.vrMode = mode
                    }
                }
            }

            Divider()

            Button("循环播放") {
                viewModel.toggleLooping()
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("全屏") {
                viewModel.toggleFullscreen()
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Mocpot 帮助") {
                // Help
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
