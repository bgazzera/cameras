import Foundation

struct HikvisionNVRService {
    func discoverChannels(configuration: NVRConfiguration, password: String) async throws -> [Channel] {
        let host = configuration.trimmedHost
        let username = configuration.trimmedUsername
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else {
            throw HikvisionNVRServiceError.missingHost
        }

        guard !username.isEmpty else {
            throw HikvisionNVRServiceError.missingUsername
        }

        guard !trimmedPassword.isEmpty else {
            throw HikvisionNVRServiceError.missingPassword
        }

        let candidates = [
            "/ISAPI/ContentMgmt/InputProxy/channels",
            "/ISAPI/Streaming/channels",
        ]

        var lastError: Error?
        for path in candidates {
            do {
                let url = try makeURL(host: host, port: configuration.httpPort, path: path)
                let channels = try await fetchChannels(url: url, username: username, password: trimmedPassword)
                if !channels.isEmpty {
                    return normalizedChannels(channels, forPath: path)
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? HikvisionNVRServiceError.noChannelsFound
    }

    func fallbackChannels(selectedChannelID: String) -> [Channel] {
        let trimmedChannelID = selectedChannelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChannelID.isEmpty, trimmedChannelID != "0" else {
            return []
        }

        return [Channel(id: trimmedChannelID, name: trimmedChannelID)]
    }

    private func sortChannels(_ channels: [Channel]) -> [Channel] {
        channels.sorted { lhs, rhs in
            let lhsValue = Int(lhs.id) ?? .max
            let rhsValue = Int(rhs.id) ?? .max

            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }

            return lhs.id < rhs.id
        }
    }

    private func normalizedChannels(_ channels: [Channel], forPath path: String) -> [Channel] {
        if path == "/ISAPI/ContentMgmt/InputProxy/channels" {
            return sortChannels(channels)
        }

        let mainStreams = channels.filter { channel in
            guard let numericID = Int(channel.id) else {
                return true
            }

            return numericID < 100 || numericID % 100 == 1
        }

        return sortChannels(mainStreams.isEmpty ? channels : mainStreams)
    }

    private func makeURL(host: String, port: Int, path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path

        guard let url = components.url else {
            throw HikvisionNVRServiceError.invalidEndpoint
        }

        return url
    }

    private func fetchChannels(url: URL, username: String, password: String) async throws -> [Channel] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/xml", forHTTPHeaderField: "Accept")

        let authDelegate = HTTPAuthenticationDelegate(username: username, password: password)
        let session = URLSession(configuration: .ephemeral, delegate: authDelegate, delegateQueue: nil)
        let (data, response) = try await session.data(for: request, delegate: authDelegate)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HikvisionNVRServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw HikvisionNVRServiceError.authenticationFailed
        default:
            throw HikvisionNVRServiceError.httpStatus(httpResponse.statusCode)
        }

        let parser = ChannelXMLParser()
        return try parser.parse(data: data)
    }
}

private final class HTTPAuthenticationDelegate: NSObject, URLSessionTaskDelegate {
    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let method = challenge.protectionSpace.authenticationMethod
        guard method == NSURLAuthenticationMethodHTTPBasic || method == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        completionHandler(.useCredential, credential)
    }
}

enum HikvisionNVRServiceError: LocalizedError {
    case missingHost
    case missingUsername
    case missingPassword
    case invalidEndpoint
    case invalidResponse
    case authenticationFailed
    case httpStatus(Int)
    case noChannelsFound

    var errorDescription: String? {
        switch self {
        case .missingHost:
            return "Enter the NVR host or IP before discovering channels."
        case .missingUsername:
            return "Enter the NVR username before discovering channels."
        case .missingPassword:
            return "Enter the NVR password before discovering channels."
        case .invalidEndpoint:
            return "The NVR discovery endpoint could not be created."
        case .invalidResponse:
            return "The NVR returned an invalid response."
        case .authenticationFailed:
            return "The NVR rejected the supplied username or password."
        case .httpStatus(let code):
            return "The NVR discovery endpoint returned HTTP \(code)."
        case .noChannelsFound:
            return "No channels were returned by the NVR."
        }
    }
}

private final class ChannelXMLParser: NSObject, XMLParserDelegate {
    private var channels: [Channel] = []
    private var currentID = ""
    private var currentName = ""
    private var currentElement = ""
    private var insideChannel = false

    func parse(data: Data) throws -> [Channel] {
        channels.removeAll(keepingCapacity: true)
        currentID = ""
        currentName = ""
        currentElement = ""
        insideChannel = false

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw parser.parserError ?? HikvisionNVRServiceError.invalidResponse
        }

        return channels
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        currentElement = name

        if name == "streamingchannel" || name == "inputproxychannel" {
            insideChannel = true
            currentID = ""
            currentName = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideChannel else {
            return
        }

        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return
        }

        switch currentElement {
        case "id":
            currentID += value
        case "channelname", "name":
            currentName += value
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()

        if name == "streamingchannel" || name == "inputproxychannel" {
            insideChannel = false
            let id = currentID.trimmingCharacters(in: .whitespacesAndNewlines)
            let channelName = currentName.trimmingCharacters(in: .whitespacesAndNewlines)

            if !id.isEmpty {
                channels.append(Channel(id: id, name: channelName.isEmpty ? id : channelName))
            }
        }

        currentElement = ""
    }
}
