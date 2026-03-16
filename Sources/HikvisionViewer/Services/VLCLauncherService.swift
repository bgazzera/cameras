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
    private var currentPresentation = VideoPresentation.default
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

    func connect(streamURL: URL, presentation: VideoPresentation = .default) throws {
        currentStreamURL = streamURL
        currentPresentation = presentation
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
        currentPresentation = .default
        mediaPlayer.stop()
        applyPresentation(.default)
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
            applyPresentation(currentPresentation)
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
        applyPresentation(currentPresentation)
        applyMuteState()
        emit(reportAsReconnect ? .reconnecting(reconnectAttempt) : .launching)
        mediaPlayer.play()
    }

    private func applyMuteState() {
        mediaPlayer.audio?.isMuted = desiredMuted
    }

    private func applyPresentation(_ presentation: VideoPresentation) {
        mediaPlayer.scaleFactor = 0
        videoView.fillScreen = false

        switch presentation {
        case .default:
            mediaPlayer.videoCropGeometry = nil
            mediaPlayer.videoAspectRatio = nil
        case .forced16x9:
            mediaPlayer.videoCropGeometry = nil
            mediaPlayer.videoAspectRatio = strdup("16:9")
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
}
