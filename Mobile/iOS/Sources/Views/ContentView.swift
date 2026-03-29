import SwiftUI

struct MobileContentView: View {
    @ObservedObject var viewModel: MobileAppViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                playerSection

                if !viewModel.lastError.isEmpty {
                    Text(viewModel.lastError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .navigationTitle("Hikvision")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    MobileSettingsView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingSettings = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var playerSection: some View {
        VStack(spacing: 12) {
            MobilePlayerContainerView(videoView: viewModel.videoView)
                .frame(maxWidth: .infinity, minHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Text(viewModel.playbackState.statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())

                Text(viewModel.doorbellCallState.statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.visibleChannels) { channel in
                        Button(channelShortcutTitle(for: channel)) {
                            viewModel.connect(to: channel.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.configuration.selectedChannelID == channel.id ? .accentColor : .gray)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Portero") {
                    viewModel.connectToDoorbell()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isShowingDoorbellStream ? .green : .green.opacity(0.8))

                Button(viewModel.streamModeTitle) {
                    viewModel.toggleDoorbellStreamMode()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.streamModeTitle == "HD" ? .blue : .teal)

                Button(viewModel.isMuted ? "Unmute" : "Mute") {
                    viewModel.toggleMute()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 10) {
                Button(viewModel.doorbellControlTitle) {
                    viewModel.handleDoorbellControl()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.doorbellCallState.isActive ? .red : .orange)
                .disabled(!viewModel.canAttemptDoorbellControl)

                Button(viewModel.talkbackButtonTitle) {
                    viewModel.toggleTalkback()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isTalkbackActive ? .red : .mint)
                .disabled(!viewModel.canToggleTalkback)

                Button("Discover") {
                    Task {
                        await viewModel.discoverChannels()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDiscovering)
            }
        }
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
