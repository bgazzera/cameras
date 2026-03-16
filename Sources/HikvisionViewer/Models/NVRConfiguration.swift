import Foundation

struct NVRConfiguration: Codable {
    var host: String = ""
    var username: String = ""
    var rtspPort: Int = 554
    var httpPort: Int = 80
    var selectedChannelID: String = "101"
    var doorbellHost: String = "192.168.86.54"
    var doorbellRTSPPort: Int = 554
    var doorbellHTTPPort: Int = 80
    var doorbellHDChannelID: String = "101"
    var doorbellSDChannelID: String = "102"
    var preferHD: Bool = true
    var doorbellNotificationsEnabled: Bool = true
    var autoSwitchToDoorbellOnRing: Bool = true
    var autoReconnect: Bool = true

    var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDoorbellHost: String {
        doorbellHost.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDoorbellHDChannelID: String {
        doorbellHDChannelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDoorbellSDChannelID: String {
        doorbellSDChannelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var activeDoorbellChannelID: String {
        let preferred = preferHD ? trimmedDoorbellHDChannelID : trimmedDoorbellSDChannelID
        if !preferred.isEmpty {
            return preferred
        }

        return preferHD ? "101" : "102"
    }
}
