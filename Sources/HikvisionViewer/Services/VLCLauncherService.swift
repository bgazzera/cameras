import AppKit
import Foundation
@preconcurrency import VLCKit

@MainActor
final class VLCLauncherService: NSObject, VLCMediaPlayerDelegate {
    let videoView: VLCVideoView

    var onStateChange: ((PlaybackState) -> Void)?
    var shouldReconnect = true

    private let mediaPlayer: VLCMediaPlayer
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectAttempt = 0
    private var currentStreamURL: URL?
    private var userInitiatedStop = false
    private var desiredMuted = false

    override init() {
        let videoView = VLCVideoView(frame: .zero)
        videoView.backColor = .black
        videoView.fillScreen = false
        self.videoView = videoView
        self.mediaPlayer = VLCMediaPlayer(videoView: videoView)

        super.init()

        mediaPlayer.delegate = self
        mediaPlayer.drawable = videoView
    }

    func connect(streamURL: URL) throws {
        currentStreamURL = streamURL
        userInitiatedStop = false
        reconnectAttempt = 0
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        playCurrentStream(reportAsReconnect: false)
    }

    func play() throws {
        userInitiatedStop = false
        mediaPlayer.play()
    }

    func pause() throws {
        mediaPlayer.pause()
    }

    func stop() throws {
        userInitiatedStop = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        currentStreamURL = nil
        mediaPlayer.stop()
        emit(.stopped)
    }

    func setMuted(_ muted: Bool) {
        desiredMuted = muted
        applyMuteState()
    }

    func toggleMute() throws -> Bool {
        desiredMuted.toggle()
        applyMuteState()
        return desiredMuted
    }

    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            self.handleMediaPlayerStateChanged()
        }
    }

    private func handleMediaPlayerStateChanged() {
        switch mediaPlayer.state {
        case .opening, .buffering:
            if reconnectAttempt > 0 {
                emit(.reconnecting(reconnectAttempt))
            } else {
                emit(.launching)
            }
        case .playing:
            reconnectAttempt = 0
            applyMuteState()
            emit(.playing)
        case .paused:
            emit(.paused)
        case .stopped:
            if userInitiatedStop {
                userInitiatedStop = false
                emit(.stopped)
            }
        case .ended:
            scheduleReconnect(message: "The stream ended.")
        case .error:
            scheduleReconnect(message: "The stream failed to play.")
        case .esAdded:
            break
        @unknown default:
            emit(.error("The player entered an unknown state."))
        }
    }

    private func playCurrentStream(reportAsReconnect: Bool) {
        guard let currentStreamURL else {
            emit(.error("No stream URL is available for playback."))
            return
        }

        let media = VLCMedia(url: currentStreamURL)
        media.addOption(":rtsp-tcp")
        media.addOption(":network-caching=150")
        media.addOption(":live-caching=150")
        media.addOption(":clock-jitter=0")

        mediaPlayer.media = media
        applyMuteState()
        emit(reportAsReconnect ? .reconnecting(reconnectAttempt) : .launching)
        mediaPlayer.play()
    }

    private func applyMuteState() {
        mediaPlayer.audio?.isMuted = desiredMuted
    }

    private func scheduleReconnect(message: String) {
        guard shouldReconnect, currentStreamURL != nil, !userInitiatedStop else {
            emit(.error(message))
            return
        }

        reconnectWorkItem?.cancel()
        reconnectAttempt += 1
        emit(.reconnecting(reconnectAttempt))

        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.playCurrentStream(reportAsReconnect: true)
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func emit(_ state: PlaybackState) {
        onStateChange?(state)
    }
}
