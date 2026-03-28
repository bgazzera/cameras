import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            playerSection

            if !viewModel.lastError.isEmpty {
                Text(viewModel.lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
    }

    private var playerSection: some View {
        ZStack {
            PlayerContainerView(videoView: viewModel.videoView)
                .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.playbackState.statusText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())

                        Text(viewModel.doorbellCallState.statusText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    Spacer()

                    Button {
                        openWindow(id: "settings")
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(14)

                Spacer()

                controlStrips
                    .padding(14)
            }
        }
    }

    private var controlStrips: some View {
        VStack(alignment: .trailing, spacing: 10) {
            secondaryControlStrip
                .frame(maxWidth: .infinity, alignment: .trailing)

            primaryControlStrip
        }
    }

    private var primaryControlStrip: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.visibleChannels) { channel in
                        Button(channelShortcutTitle(for: channel)) {
                            viewModel.connect(to: channel.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.configuration.selectedChannelID == channel.id ? .accentColor : .gray.opacity(0.85))
                    }
                }
            }

            Button("Portero") {
                viewModel.connectToDoorbell()
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isShowingDoorbellStream ? .green : .green.opacity(0.8))
            .frame(minHeight: 34)

            HStack(spacing: 10) {
                Button(viewModel.doorbellControlTitle) {
                    viewModel.handleDoorbellControl()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.doorbellCallState.isActive ? .red : .orange)
                .disabled(!viewModel.canAttemptDoorbellControl)
                .frame(minHeight: 34)

                Button(viewModel.talkbackButtonTitle) {
                    viewModel.toggleTalkback()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isTalkbackActive ? .red : .mint)
                .disabled(!viewModel.canToggleTalkback)
                .frame(minHeight: 34)
            }

            Divider()
                .frame(height: 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var secondaryControlStrip: some View {
        HStack(spacing: 10) {
            Button(viewModel.streamModeTitle) {
                viewModel.toggleDoorbellStreamMode()
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.streamModeTitle == "HD" ? .blue : .teal)
            .frame(minHeight: 34)

            Button(viewModel.isMuted ? "Unmute" : "Mute") {
                viewModel.toggleMute()
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 34)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func channelShortcutTitle(for channel: Channel) -> String {
        let trimmedName = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == channel.id {
            if channel.id == "0" {
                return "Channel 0"
            }

            return "Channel \(channel.id)"
        }

        return trimmedName
    }
}
