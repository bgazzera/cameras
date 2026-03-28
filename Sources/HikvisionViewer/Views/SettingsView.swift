import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Form {
            connectionSection
            doorbellSection
            channelSection
            playbackSection
        }
        .formStyle(.grouped)
        .padding(20)
        .onDisappear {
            viewModel.saveSettings()
        }
    }

    private var connectionSection: some View {
        Section("NVR Connection") {
            TextField("Host or IP", text: $viewModel.configuration.host)
                .textFieldStyle(.roundedBorder)

            TextField("Username", text: $viewModel.configuration.username)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            HStack {
                VStack(alignment: .leading) {
                    Text("RTSP Port")
                    TextField("554", value: $viewModel.configuration.rtspPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("HTTP Port")
                    TextField("80", value: $viewModel.configuration.httpPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var channelSection: some View {
        Section("Channels") {
            TextField("Manual Channel ID", text: $viewModel.configuration.selectedChannelID)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var doorbellSection: some View {
        Section("Doorbell") {
            TextField("Portero Host or IP", text: $viewModel.configuration.doorbellHost)
                .textFieldStyle(.roundedBorder)

            HStack {
                VStack(alignment: .leading) {
                    Text("Doorbell RTSP Port")
                    TextField("554", value: $viewModel.configuration.doorbellRTSPPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Doorbell HTTP Port")
                    TextField("80", value: $viewModel.configuration.doorbellHTTPPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Doorbell HD Channel")
                    TextField("101", text: $viewModel.configuration.doorbellHDChannelID)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Doorbell SD Channel")
                    TextField("102", text: $viewModel.configuration.doorbellSDChannelID)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Toggle("Prefer HD by default for all streams", isOn: $viewModel.configuration.preferHD)

            Toggle("Show notifications when the doorbell rings", isOn: $viewModel.configuration.doorbellNotificationsEnabled)
            Toggle("Switch to the Portero stream when the doorbell rings", isOn: $viewModel.configuration.autoSwitchToDoorbellOnRing)

            Button("Connect Portero") {
                viewModel.connectToDoorbell()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Reconnect automatically if VLC exits unexpectedly", isOn: $viewModel.configuration.autoReconnect)

            Text("Answer and hang-up use the Hikvision call-signal endpoint. The Mic button now opens Hikvision's native TwoWayAudio backchannel and streams microphone audio directly to the device. If the doorbell is actively ringing, the app clears the intercom call first before opening the talkback channel.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button("Save") {
                    viewModel.saveSettings()
                }

                Button("Connect Selected Channel") {
                    viewModel.connect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}