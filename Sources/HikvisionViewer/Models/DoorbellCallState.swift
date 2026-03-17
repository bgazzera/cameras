import Foundation

enum DoorbellCallState: Equatable {
    case unavailable
    case idle
    case ringing(String)
    case active(String)
    case unknown(String)
    case error(String)

    init(status: String) {
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmedStatus.lowercased()

        if trimmedStatus.isEmpty {
            self = .unknown("Unknown")
            return
        }

        if normalized == "idle" {
            self = .idle
            return
        }

        if normalized.contains("ring") || normalized.contains("incoming") || normalized.contains("call") {
            self = .ringing(trimmedStatus)
            return
        }

        if normalized.contains("talk") || normalized.contains("answer") || normalized.contains("connect") || normalized.contains("busy") {
            self = .active(trimmedStatus)
            return
        }

        self = .unknown(trimmedStatus)
    }

    var isRinging: Bool {
        if case .ringing = self {
            return true
        }

        return false
    }

    var isActive: Bool {
        if case .active = self {
            return true
        }

        return false
    }

    var isEngaged: Bool {
        isRinging || isActive
    }

    var statusText: String {
        switch self {
        case .unavailable:
            return "Doorbell offline"
        case .idle:
            return "Doorbell idle"
        case .ringing(let status):
            return "Doorbell ringing (\(status))"
        case .active(let status):
            return "Doorbell active (\(status))"
        case .unknown(let status):
            return "Doorbell \(status)"
        case .error(let message):
            return message
        }
    }

    var controlTitle: String {
        isActive ? "Hang" : "Answer"
    }
}