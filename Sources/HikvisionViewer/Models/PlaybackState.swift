import Foundation

enum PlaybackState: Equatable {
    case idle
    case launching
    case playing
    case paused
    case stopped
    case reconnecting(Int)
    case error(String)

    var statusText: String {
        switch self {
        case .idle:
            return "Idle"
        case .launching:
            return "Launching VLC"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
        case .reconnecting(let attempt):
            return "Reconnecting (attempt \(attempt))"
        case .error(let message):
            return message
        }
    }
}
