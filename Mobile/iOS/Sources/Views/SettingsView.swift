import SwiftUI

struct MobileSettingsView: View {
    @ObservedObject var viewModel: MobileAppViewModel

    var body: some View {
        Form {
            connectionSection
            doorbellSection
            playbackSection
        }
        .navigationTitle("Settings")
        .onDisappear {
            viewModel.saveSettings()
        }
    }

    private var connectionSection: some View {
        Section("NVR Connection") {
            TextField("Host or IP", text: $viewModel.configuration.host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Username", text: $viewModel.configuration.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $viewModel.password)

            TextField("RTSP Port", value: $viewModel.configuration.rtspPort, format: .number)
                .keyboardType(.numberPad)

            TextField("HTTP Port", value: $viewModel.configuration.httpPort, format: .number)
                .keyboardType(.numberPad)

            TextField("Manual Channel ID", text: $viewModel.configuration.selectedChannelID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var doorbellSection: some View {
        Section("Doorbell") {
            TextField("Portero Host or IP", text: $viewModel.configuration.doorbellHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Doorbell RTSP Port", value: $viewModel.configuration.doorbellRTSPPort, format: .number)
                .keyboardType(.numberPad)

            TextField("Doorbell HTTP Port", value: $viewModel.configuration.doorbellHTTPPort, format: .number)
                .keyboardType(.numberPad)

            TextField("Doorbell HD Channel", text: $viewModel.configuration.doorbellHDChannelID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Doorbell SD Channel", text: $viewModel.configuration.doorbellSDChannelID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Toggle("Prefer HD by default", isOn: $viewModel.configuration.preferHD)
            Toggle("Doorbell notifications", isOn: $viewModel.configuration.doorbellNotificationsEnabled)
            Toggle("Auto switch to Portero on ring", isOn: $viewModel.configuration.autoSwitchToDoorbellOnRing)
        }
    }

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Reconnect automatically", isOn: $viewModel.configuration.autoReconnect)

            Button("Connect Selected Channel") {
                viewModel.connect()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
