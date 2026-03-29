import Foundation
import UIKit
@preconcurrency import VLCKit

@MainActor
final class IOSPlaybackService: NSObject, @preconcurrency VLCMediaPlayerDelegate {
    let videoView: UIView

    var onStateChange: ((PlaybackState) -> Void)?
    var shouldReconnect = true

    private let mediaPlayer: VLCMediaPlayer
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectAttempt = 0
    private var currentStreamURL: URL?
    private var currentPresentation = VideoPresentation.default
    private var userInitiatedStop = false
    private var desiredMuted = false

    override init() {
        let videoView = UIView(frame: .zero)
        videoView.backgroundColor = .black
        self.videoView = videoView
        self.mediaPlayer = VLCMediaPlayer()

        super.init()

        mediaPlayer.delegate = self
        mediaPlayer.drawable = videoView
    }

    func connect(streamURL: URL, presentation: VideoPresentation = .default) {
        currentStreamURL = streamURL
        currentPresentation = presentation
        userInitiatedStop = false
        reconnectAttempt = 0
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        playCurrentStream(reportAsReconnect: false)
    }

    func stop() {
        userInitiatedStop = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        currentStreamURL = nil
        currentPresentation = .default
        mediaPlayer.stop()
        applyPresentation(.default)
        emit(.stopped)
    }

    func setMuted(_ muted: Bool) {
        desiredMuted = muted
        applyMuteState()
    }

    func toggleMute() -> Bool {
        desiredMuted.toggle()
        applyMuteState()
        return desiredMuted
    }

    nonisolated func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        Task { @MainActor [weak self] in
            self?.handleMediaPlayerStateChanged(newState)
        }
    }

    private func handleMediaPlayerStateChanged(_ state: VLCMediaPlayerState) {
        switch state {
        case .opening, .buffering:
            if reconnectAttempt > 0 {
                emit(.reconnecting(reconnectAttempt))
            } else {
                emit(.launching)
            }
        case .playing:
            reconnectAttempt = 0
            applyPresentation(currentPresentation)
            applyMuteState()
            emit(.playing)
        case .paused:
            emit(.paused)
        case .stopping:
            if userInitiatedStop {
                emit(.stopped)
            }
        case .stopped:
            if userInitiatedStop {
                userInitiatedStop = false
                emit(.stopped)
            } else {
                scheduleReconnect(message: "The stream ended.")
            }
        case .error:
            scheduleReconnect(message: "The stream failed to play.")
        @unknown default:
            emit(.error("The player entered an unknown state."))
        }
    }

    private func playCurrentStream(reportAsReconnect: Bool) {
        guard let currentStreamURL else {
            emit(.error("No stream URL is available for playback."))
            return
        }

        guard let media = VLCMedia(url: currentStreamURL) else {
            emit(.error("The stream URL could not be prepared for playback."))
            return
        }
        media.addOption(":rtsp-tcp")
        media.addOption(":network-caching=150")
        media.addOption(":live-caching=150")
        media.addOption(":clock-jitter=0")
        mediaPlayer.media = media
        applyPresentation(currentPresentation)
        applyMuteState()
        emit(reportAsReconnect ? .reconnecting(reconnectAttempt) : .launching)
        mediaPlayer.play()
    }

    private func applyMuteState() {
        mediaPlayer.audio?.isMuted = desiredMuted
    }

    private func applyPresentation(_ presentation: VideoPresentation) {
        switch presentation {
        case .default:
            mediaPlayer.videoAspectRatio = nil
        case .forced16x9, .fillWidth16x9:
            mediaPlayer.videoAspectRatio = "16:9"
        }
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

enum VideoPresentation {
    case `default`
    case forced16x9
    case fillWidth16x9
}
