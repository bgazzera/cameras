import AVFoundation
import Foundation

struct MicrophonePermissionService {
    func requestAccessIfNeeded() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted {
                return
            }

            throw MicrophonePermissionError.accessDenied
        case .denied, .restricted:
            throw MicrophonePermissionError.accessDenied
        @unknown default:
            throw MicrophonePermissionError.unknown
        }
    }
}

enum MicrophonePermissionError: LocalizedError {
    case accessDenied
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Microphone access is required for doorbell talk. Allow microphone access for HikvisionViewer in System Settings > Privacy & Security > Microphone."
        case .unknown:
            return "Microphone permission could not be determined."
        }
    }
}