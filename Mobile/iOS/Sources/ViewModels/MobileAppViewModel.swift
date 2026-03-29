import Foundation
import UIKit

@MainActor
final class MobileAppViewModel: ObservableObject {
    @Published var configuration = NVRConfiguration()
    @Published var password = ""
    @Published var channels: [Channel] = []
    @Published var playbackState: PlaybackState = .idle
    @Published var doorbellCallState: DoorbellCallState = .unavailable
    @Published var isMuted = false
    @Published var isShowingDoorbellStream = false
    @Published var isDiscovering = false
    @Published var isTalkbackActive = false
    @Published var isTalkbackBusy = false
    @Published var lastError = ""

    private let appAttentionService = IOSAppAttentionService()
    private let credentialStore = CredentialStore()
    private let doorbellService = DoorbellService()
    private let envFileLoader = EnvFileLoader()
    private let microphonePermissionService = MicrophonePermissionService()
    private let notificationService = LocalNotificationService()
    private let nvrService = HikvisionNVRService()
    private let talkbackService = DoorbellTalkbackService()
    private let playbackService = IOSPlaybackService()
    private let zeroChannel = Channel(id: "0", name: "Channel 0")
    private let defaultsKey = "hikvisionViewerMobile.configuration"
    private let defaults = UserDefaults(suiteName: "com.bgazzera.HikvisionViewerMobile") ?? .standard
    private var doorbellMonitorTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?

    var videoView: UIView {
        playbackService.videoView
    }

    var visibleChannels: [Channel] {
        var visible = [zeroChannel]
        visible.append(contentsOf: channels.filter { $0.id != zeroChannel.id })

        let manualChannelID = configuration.selectedChannelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualChannelID.isEmpty,
           manualChannelID != zeroChannel.id,
           !visible.contains(where: { $0.id == manualChannelID }) {
            visible.append(Channel(id: manualChannelID, name: manualChannelID))
        }

        return visible
    }

    var canMonitorDoorbell: Bool {
        !configuration.trimmedDoorbellHost.isEmpty && !configuration.trimmedUsername.isEmpty && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isDoorbellPlaybackActive: Bool {
        isShowingDoorbellStream && playbackState.isActivePlayback
    }

    var canAttemptDoorbellControl: Bool {
        doorbellCallState.isEngaged && isDoorbellPlaybackActive && !isTalkbackBusy
    }

    var doorbellControlTitle: String {
        doorbellCallState.controlTitle
    }

    var streamModeTitle: String {
        configuration.preferHD ? "HD" : "SD"
    }

    var canToggleTalkback: Bool {
        canMonitorDoorbell && isDoorbellPlaybackActive && !isTalkbackBusy
    }

    var talkbackButtonTitle: String {
        if isTalkbackBusy {
            return isTalkbackActive ? "Stopping Mic..." : "Starting Mic..."
        }

        return isTalkbackActive ? "Mic Off" : "Mic On"
    }

    init() {
        applyEnvDefaults()
        restoreConfiguration()
        applyEnvDefaultsToMissingFields()
        applyEnvironmentOverrides()
        restorePasswordIfNeeded()
        isMuted = true
        playbackService.setMuted(true)
        channels = nvrService.fallbackChannels(selectedChannelID: configuration.selectedChannelID)
        playbackService.onStateChange = { [weak self] state in
            self?.playbackState = state
            if case .error(let message) = state {
                self?.lastError = message
            }
        }

        Task {
            await notificationService.requestAuthorizationIfNeeded()
        }

        restartDoorbellMonitoring()
        startupTask = Task { [weak self] in
            await self?.startupDiscoverAndConnectIfPossible()
        }
    }

    deinit {
        startupTask?.cancel()
        doorbellMonitorTask?.cancel()
        let talkbackService = talkbackService
        Task {
            await talkbackService.stop()
        }
    }

    func discoverChannels() async {
        _ = await performChannelDiscovery(selection: .preserveCurrentOrFirst)
    }

    func connect() {
        lastError = ""
        stopTalkbackIfNeeded()
        isShowingDoorbellStream = false

        do {
            try persistConfiguration()
            let effectiveChannelID = effectiveChannelID(for: configuration.selectedChannelID)
            let url = try RTSPURLBuilder.buildURL(
                configuration: configuration,
                password: password,
                channelID: effectiveChannelID
            )
            playbackService.shouldReconnect = configuration.autoReconnect
            playbackService.connect(streamURL: url, presentation: presentation(for: effectiveChannelID))
        } catch {
            lastError = error.localizedDescription
            playbackState = .error(error.localizedDescription)
        }
    }

    func connect(to channelID: String) {
        configuration.selectedChannelID = channelID
        connect()
    }

    func connectToDoorbell() {
        lastError = ""

        do {
            try persistConfiguration()
            let url = try RTSPURLBuilder.buildURL(
                host: configuration.trimmedDoorbellHost,
                username: configuration.trimmedUsername,
                password: password,
                rtspPort: configuration.doorbellRTSPPort,
                channelID: configuration.activeDoorbellChannelID
            )
            playbackService.shouldReconnect = configuration.autoReconnect
            isShowingDoorbellStream = true
            playbackService.connect(streamURL: url, presentation: .default)
        } catch {
            lastError = error.localizedDescription
            playbackState = .error(error.localizedDescription)
        }
    }

    func toggleMute() {
        isMuted = playbackService.toggleMute()
    }

    func handleDoorbellControl() {
        guard canAttemptDoorbellControl else {
            return
        }

        Task {
            do {
                let command: DoorbellCallSignalCommand = doorbellCallState.isActive ? .hangUp : .answer

                if command == .answer {
                    try await microphonePermissionService.requestAccessIfNeeded()
                    try await doorbellService.sendCallSignal(configuration: configuration, password: password, command: command)
                    try await Task.sleep(nanoseconds: 300_000_000)
                    try await startTalkback(clearIncomingCall: false)
                } else {
                    await stopTalkback()
                    try await doorbellService.sendCallSignal(configuration: configuration, password: password, command: command)
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func toggleTalkback() {
        guard canToggleTalkback || isTalkbackActive else {
            return
        }

        Task {
            do {
                if isTalkbackActive {
                    await stopTalkback()
                    return
                }

                try await startTalkback(clearIncomingCall: false)
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func toggleDoorbellStreamMode() {
        configuration.preferHD.toggle()
        try? persistConfiguration()

        if isShowingDoorbellStream {
            connectToDoorbell()
        } else {
            connect()
        }
    }

    func saveSettings() {
        do {
            try persistConfiguration()
            restartDoorbellMonitoring()
        } catch {
            lastError = error.localizedDescription
            playbackState = .error(error.localizedDescription)
        }
    }

    private func restoreConfiguration() {
        guard let data = defaults.data(forKey: defaultsKey) else {
            return
        }

        if let saved = try? JSONDecoder().decode(NVRConfiguration.self, from: data) {
            configuration = saved
        }
    }

    private func applyEnvironmentOverrides() {
        let environment = ProcessInfo.processInfo.environment

        if let host = environment["HIKVISION_NVR_HOST"], !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configuration.host = host
        }

        if let username = environment["HIKVISION_NVR_USERNAME"], !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configuration.username = username
        }

        if let channel = environment["HIKVISION_NVR_CHANNEL"], !channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configuration.selectedChannelID = channel
        }

        if let passwordOverride = environment["HIKVISION_NVR_PASSWORD"], !passwordOverride.isEmpty {
            password = passwordOverride
        }

        if let host = environment["HIKVISION_DOORBELL_HOST"], !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            configuration.doorbellHost = host
        }
    }

    private func applyEnvDefaults() {
        let defaults = envFileLoader.loadDefaults()
        guard !defaults.isEmpty else {
            return
        }

        applyDefaultValues(defaults)
    }

    private func applyEnvDefaultsToMissingFields() {
        let defaults = envFileLoader.loadDefaults()
        guard !defaults.isEmpty else {
            return
        }

        applyDefaultValues(defaults, fillMissingOnly: true)
    }

    private func applyDefaultValues(_ values: [String: String], fillMissingOnly: Bool = false) {
        if shouldApply(values["HIKVISION_NVR_HOST"], current: configuration.host, fillMissingOnly: fillMissingOnly) {
            configuration.host = values["HIKVISION_NVR_HOST"] ?? configuration.host
        }

        if shouldApply(values["HIKVISION_NVR_USERNAME"], current: configuration.username, fillMissingOnly: fillMissingOnly) {
            configuration.username = values["HIKVISION_NVR_USERNAME"] ?? configuration.username
        }

        if shouldApply(values["HIKVISION_NVR_CHANNEL"], current: configuration.selectedChannelID, fillMissingOnly: fillMissingOnly, treatDefaultStringAsMissing: true) {
            configuration.selectedChannelID = values["HIKVISION_NVR_CHANNEL"] ?? configuration.selectedChannelID
        }

        if shouldApply(values["HIKVISION_NVR_PASSWORD"], current: password, fillMissingOnly: fillMissingOnly) {
            password = values["HIKVISION_NVR_PASSWORD"] ?? password
        }

        if shouldApply(values["HIKVISION_DOORBELL_HOST"], current: configuration.doorbellHost, fillMissingOnly: fillMissingOnly, treatDefaultStringAsMissing: true, defaultValue: "192.168.86.54") {
            configuration.doorbellHost = values["HIKVISION_DOORBELL_HOST"] ?? configuration.doorbellHost
        }
    }

    private func effectiveChannelID(for channelID: String) -> String {
        let trimmedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let numericValue = Int(trimmedChannelID) else {
            return trimmedChannelID
        }

        if numericValue == 0 {
            return "001"
        }

        let streamSuffix = configuration.preferHD ? "01" : "02"
        let baseChannel = numericValue < 100 ? numericValue : numericValue / 100
        return "\(baseChannel)\(streamSuffix)"
    }

    private func presentation(for effectiveChannelID: String) -> VideoPresentation {
        effectiveChannelID == "001" ? .fillWidth16x9 : .default
    }

    private func shouldApply(_ candidate: String?, current: String, fillMissingOnly: Bool, treatDefaultStringAsMissing: Bool = false, defaultValue: String = "") -> Bool {
        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if !fillMissingOnly {
            return true
        }

        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCurrent.isEmpty {
            return true
        }

        if treatDefaultStringAsMissing && trimmedCurrent == defaultValue {
            return true
        }

        return false
    }

    private func restorePasswordIfNeeded() {
        guard password.isEmpty else {
            return
        }

        guard !configuration.trimmedUsername.isEmpty else {
            return
        }

        let candidateHosts = [configuration.trimmedHost, configuration.trimmedDoorbellHost].filter { !$0.isEmpty }

        for host in candidateHosts {
            if let restored = try? credentialStore.loadPassword(host: host, username: configuration.trimmedUsername), !restored.isEmpty {
                password = restored
                return
            }
        }
    }

    private func persistConfiguration() throws {
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: defaultsKey)

        if !configuration.trimmedHost.isEmpty && !configuration.trimmedUsername.isEmpty && !password.isEmpty {
            try credentialStore.savePassword(password, host: configuration.trimmedHost, username: configuration.trimmedUsername)
        }

        if !configuration.trimmedDoorbellHost.isEmpty && !configuration.trimmedUsername.isEmpty && !password.isEmpty {
            try credentialStore.savePassword(password, host: configuration.trimmedDoorbellHost, username: configuration.trimmedUsername)
        }
    }

    @discardableResult
    private func performChannelDiscovery(selection: ChannelDiscoverySelection) async -> Bool {
        isDiscovering = true
        lastError = ""
        defer { isDiscovering = false }

        do {
            try persistConfiguration()
            let discovered = try await nvrService.discoverChannels(configuration: configuration, password: password)
            channels = discovered

            switch selection {
            case .firstDiscovered:
                if let first = discovered.first {
                    configuration.selectedChannelID = first.id
                }
            case .preserveCurrentOrFirst:
                if !discovered.contains(where: { $0.id == configuration.selectedChannelID }), let first = discovered.first {
                    configuration.selectedChannelID = first.id
                }
            }

            try persistConfiguration()
            return true
        } catch {
            channels = nvrService.fallbackChannels(selectedChannelID: configuration.selectedChannelID)
            lastError = error.localizedDescription
            playbackState = .error(error.localizedDescription)
            return false
        }
    }

    private func startupDiscoverAndConnectIfPossible() async {
        guard !configuration.trimmedHost.isEmpty,
              !configuration.trimmedUsername.isEmpty,
              !password.isEmpty else {
            return
        }

        guard await performChannelDiscovery(selection: .firstDiscovered) else {
            return
        }

        connect()
    }

    private func restartDoorbellMonitoring() {
        doorbellMonitorTask?.cancel()

        guard canMonitorDoorbell else {
            doorbellCallState = .unavailable
            return
        }

        doorbellMonitorTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshDoorbellState()

                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func refreshDoorbellState() async {
        do {
            let newState = try await doorbellService.fetchCallState(configuration: configuration, password: password)
            handleDoorbellStateTransition(to: newState)
        } catch DoorbellServiceError.missingHost {
            doorbellCallState = .unavailable
        } catch {
            doorbellCallState = .error(error.localizedDescription)
        }
    }

    private func handleDoorbellStateTransition(to newState: DoorbellCallState) {
        let previousState = doorbellCallState
        doorbellCallState = newState

        guard !previousState.isRinging, newState.isRinging else {
            return
        }

        appAttentionService.playDoorbellSound()
        appAttentionService.bringApplicationToFront()

        if configuration.autoSwitchToDoorbellOnRing {
            connectToDoorbell()
        }

        if configuration.doorbellNotificationsEnabled {
            Task {
                await notificationService.notifyDoorbellRinging()
            }
        }
    }

    private func startTalkback(clearIncomingCall: Bool) async throws {
        guard isDoorbellPlaybackActive else {
            return
        }

        lastError = ""
        isTalkbackBusy = true
        defer { isTalkbackBusy = false }

        do {
            try await microphonePermissionService.requestAccessIfNeeded()

            if clearIncomingCall && doorbellCallState.isRinging {
                try await doorbellService.sendCallSignal(configuration: configuration, password: password, command: .answer)
                try await Task.sleep(nanoseconds: 300_000_000)
                try await doorbellService.sendCallSignal(configuration: configuration, password: password, command: .hangUp)
                try await Task.sleep(nanoseconds: 200_000_000)
            }

            try await talkbackService.start(configuration: configuration, password: password)
            isTalkbackActive = true
        } catch {
            await talkbackService.stop()
            isTalkbackActive = false
            throw error
        }
    }

    private func stopTalkback() async {
        await talkbackService.stop()
        isTalkbackActive = false
    }

    private func stopTalkbackIfNeeded() {
        guard isTalkbackActive else {
            return
        }

        Task {
            await stopTalkback()
        }
    }
}

private enum ChannelDiscoverySelection {
    case preserveCurrentOrFirst
    case firstDiscovered
}
