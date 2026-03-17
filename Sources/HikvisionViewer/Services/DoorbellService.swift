import Foundation

struct DoorbellService {
    func fetchCallState(configuration: NVRConfiguration, password: String) async throws -> DoorbellCallState {
        let status = try await fetchCallStatus(configuration: configuration, password: password)
        return DoorbellCallState(status: status)
    }

    func sendCallSignal(configuration: NVRConfiguration, password: String, command: DoorbellCallSignalCommand) async throws {
        let host = configuration.trimmedDoorbellHost
        let username = configuration.trimmedUsername
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else {
            throw DoorbellServiceError.missingHost
        }

        guard !username.isEmpty else {
            throw DoorbellServiceError.missingUsername
        }

        guard !trimmedPassword.isEmpty else {
            throw DoorbellServiceError.missingPassword
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = configuration.doorbellHTTPPort
        components.path = "/ISAPI/VideoIntercom/callSignal"
        components.queryItems = [URLQueryItem(name: "format", value: "json")]

        guard let url = components.url else {
            throw DoorbellServiceError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CallSignalRequest(command: command.apiValue))

        let delegate = DigestAuthenticationDelegate(username: username, password: trimmedPassword)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoorbellServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw DoorbellServiceError.authenticationFailed
        default:
            if let responseStatus = try? JSONDecoder().decode(HikvisionResponseStatus.self, from: data) {
                throw DoorbellServiceError.commandFailed(responseStatus.statusString, responseStatus.subStatusCode)
            }

            throw DoorbellServiceError.httpStatus(httpResponse.statusCode)
        }

        if !data.isEmpty,
           let responseStatus = try? JSONDecoder().decode(HikvisionResponseStatus.self, from: data),
           responseStatus.statusString.caseInsensitiveCompare("ok") != .orderedSame,
           responseStatus.statusCode != 1 {
            throw DoorbellServiceError.commandFailed(responseStatus.statusString, responseStatus.subStatusCode)
        }
    }

    private func fetchCallStatus(configuration: NVRConfiguration, password: String) async throws -> String {
        let host = configuration.trimmedDoorbellHost
        let username = configuration.trimmedUsername
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else {
            throw DoorbellServiceError.missingHost
        }

        guard !username.isEmpty else {
            throw DoorbellServiceError.missingUsername
        }

        guard !trimmedPassword.isEmpty else {
            throw DoorbellServiceError.missingPassword
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = configuration.doorbellHTTPPort
        components.path = "/ISAPI/VideoIntercom/callStatus"

        guard let url = components.url else {
            throw DoorbellServiceError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let delegate = DigestAuthenticationDelegate(username: username, password: trimmedPassword)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoorbellServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw DoorbellServiceError.authenticationFailed
        default:
            throw DoorbellServiceError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(DoorbellCallStatusResponse.self, from: data)
        return decoded.callStatus.status
    }
}

enum DoorbellCallSignalCommand {
    case answer
    case hangUp

    var apiValue: String {
        switch self {
        case .answer:
            return "answer"
        case .hangUp:
            return "hangUp"
        }
    }
}

enum DoorbellServiceError: LocalizedError {
    case missingHost
    case missingUsername
    case missingPassword
    case invalidEndpoint
    case invalidResponse
    case authenticationFailed
    case httpStatus(Int)
    case commandFailed(String, String?)

    var errorDescription: String? {
        switch self {
        case .missingHost:
            return "Enter the Portero host or IP address."
        case .missingUsername:
            return "Enter the Hikvision username."
        case .missingPassword:
            return "Enter the Hikvision password."
        case .invalidEndpoint:
            return "The Portero endpoint could not be created."
        case .invalidResponse:
            return "The Portero returned an invalid response."
        case .authenticationFailed:
            return "The Portero rejected the supplied credentials."
        case .httpStatus(let code):
            return "The Portero endpoint returned HTTP \(code)."
        case .commandFailed(let status, let subStatus):
            if let subStatus, !subStatus.isEmpty {
                return "The Portero rejected the call command: \(status) (\(subStatus))."
            }

            return "The Portero rejected the call command: \(status)."
        }
    }
}

private struct DoorbellCallStatusResponse: Decodable {
    let callStatus: DoorbellCallStatusPayload

    enum CodingKeys: String, CodingKey {
        case callStatus = "CallStatus"
    }
}

private struct DoorbellCallStatusPayload: Decodable {
    let status: String
}

private struct CallSignalRequest: Encodable {
    let callSignal: CallSignalPayload

    init(command: String) {
        callSignal = CallSignalPayload(cmdType: command)
    }

    enum CodingKeys: String, CodingKey {
        case callSignal = "CallSignal"
    }
}

private struct CallSignalPayload: Encodable {
    let cmdType: String
}

private struct HikvisionResponseStatus: Decodable {
    let statusCode: Int
    let statusString: String
    let subStatusCode: String?

    enum CodingKeys: String, CodingKey {
        case statusCode
        case statusString
        case subStatusCode
    }
}

private final class DigestAuthenticationDelegate: NSObject, URLSessionTaskDelegate {
    private let credential: URLCredential

    init(username: String, password: String) {
        credential = URLCredential(user: username, password: password, persistence: .forSession)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let method = challenge.protectionSpace.authenticationMethod

        if method == NSURLAuthenticationMethodHTTPDigest || method == NSURLAuthenticationMethodHTTPBasic {
            completionHandler(.useCredential, credential)
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }
}