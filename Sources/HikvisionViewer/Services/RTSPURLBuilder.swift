import Foundation

enum RTSPURLBuilder {
    static func buildURL(configuration: NVRConfiguration, password: String, channelID: String) throws -> URL {
        try buildURL(
            host: configuration.trimmedHost,
            username: configuration.trimmedUsername,
            password: password,
            rtspPort: configuration.rtspPort,
            channelID: channelID
        )
    }

    static func buildURL(host: String, username: String, password: String, rtspPort: Int, channelID: String) throws -> URL {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else {
            throw RTSPURLBuilderError.missingHost
        }

        guard !username.isEmpty else {
            throw RTSPURLBuilderError.missingUsername
        }

        guard !trimmedPassword.isEmpty else {
            throw RTSPURLBuilderError.missingPassword
        }

        guard !trimmedChannelID.isEmpty else {
            throw RTSPURLBuilderError.missingChannel
        }

        let encodedUser = encodeUserInfo(username)
        let encodedPassword = encodeUserInfo(trimmedPassword)
        let normalizedChannelID = normalizeChannelID(trimmedChannelID)
        let encodedChannel = normalizedChannelID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalizedChannelID
        let urlString = "rtsp://\(encodedUser):\(encodedPassword)@\(host):\(rtspPort)/Streaming/Channels/\(encodedChannel)?transportmode=unicast"

        guard let url = URL(string: urlString) else {
            throw RTSPURLBuilderError.invalidURL
        }

        return url
    }

    private static func encodeUserInfo(_ value: String) -> String {
        var allowed = CharacterSet.urlUserAllowed
        allowed.remove(charactersIn: ":@/?#[]")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func normalizeChannelID(_ value: String) -> String {
        guard let numericValue = Int(value) else {
            return value
        }

        if numericValue == 0 {
            return "001"
        }

        if numericValue < 100 {
            return "\(numericValue)01"
        }

        return value
    }
}

enum RTSPURLBuilderError: LocalizedError {
    case missingHost
    case missingUsername
    case missingPassword
    case missingChannel
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingHost:
            return "Enter the NVR host or IP address."
        case .missingUsername:
            return "Enter the NVR username."
        case .missingPassword:
            return "Enter the NVR password."
        case .missingChannel:
            return "Choose or enter a channel ID."
        case .invalidURL:
            return "The RTSP URL could not be built from the current settings."
        }
    }
}
