import SwiftUI

struct PlayerControlsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var showAdvancedControls = false

    var body: some View {
        VStack(spacing: 0) {
            if showAdvancedControls {
                AdvancedControlsPanel()
                    .transition(.move(edge: .top))
            }

            Divider()

            HStack(spacing: 20) {
                Button(action: { viewModel.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Previous Track (⌘[)")

                Button(action: { viewModel.seekBackward(seconds: 10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Backward 10s (←)")

                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)
                .help("Play/Pause (Space)")

                Button(action: { viewModel.seekForward(seconds: 10) }) {
                    Image(systemName: "goforward.10")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Forward 10s (→)")

                Button(action: { viewModel.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Next Track (⌘])")

                Divider()
                    .frame(height: 20)

                Button(action: { viewModel.stopPlayback() }) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Stop (Esc)")

                Button(action: { viewModel.toggleLooping() }) {
                    Image(systemName: viewModel.isLooping ? "repeat.1" : "repeat")
                        .font(.title3)
                        .foregroundColor(viewModel.isLooping ? .accentColor : .white)
                }
                .buttonStyle(.plain)
                .help("Loop")

                Spacer()

                Button(action: {
                    withAnimation { showAdvancedControls.toggle() }
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Advanced Controls")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct AdvancedControlsPanel: View {
    @EnvironmentObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Video Adjustments")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            AdjustSlider(label: "Brightness", value: $viewModel.brightness, range: -1...1, icon: "sun.max.fill")
            AdjustSlider(label: "Contrast", value: $viewModel.contrast, range: -1...1, icon: "circle.lefthalf.filled")
            AdjustSlider(label: "Saturation", value: $viewModel.saturation, range: -1...1, icon: "paintpalette.fill")
            AdjustSlider(label: "Hue", value: $viewModel.hue, range: -180...180, icon: "drop.fill")

            Divider()

            HStack {
                Text("Audio")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            AdjustSlider(label: "Audio Delay", value: $viewModel.audioDelay, range: -5...5, icon: "waveform", unit: "s")
            AdjustSlider(label: "Subtitle Delay", value: $viewModel.subtitleDelay, range: -5...5, icon: "text.quote", unit: "s")

            Divider()

            HStack {
                Toggle("Deinterlace", isOn: $viewModel.deinterlace)
                    .font(.caption)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Reset") {
                    viewModel.brightness = 0
                    viewModel.contrast = 0
                    viewModel.saturation = 0
                    viewModel.hue = 0
                    viewModel.audioDelay = 0
                    viewModel.subtitleDelay = 0
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct AdjustSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String
    var unit: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            Slider(value: $value, in: range)
                .frame(maxWidth: 200)

            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
        }
    }
}
