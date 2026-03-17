@preconcurrency import AVFoundation
import CryptoKit
import Foundation
import Network

actor DoorbellTalkbackService {
    private var activeSession: TalkbackSession?

    func start(configuration: NVRConfiguration, password: String) async throws {
        guard activeSession == nil else {
            return
        }

        let credentials = try DoorbellCredentials(configuration: configuration, password: password)
        let client = DigestDoorbellHTTPClient(credentials: credentials)
        let channel = try await client.fetchTalkbackChannel()
        let session = TalkbackSession(credentials: credentials, client: client, channel: channel)

        do {
            try await session.start()
            activeSession = session
        } catch {
            await session.stop()
            throw error
        }
    }

    func stop() async {
        guard let activeSession else {
            return
        }

        self.activeSession = nil
        await activeSession.stop()
    }
}

enum DoorbellTalkbackServiceError: LocalizedError {
    case missingHost
    case missingUsername
    case missingPassword
    case unsupportedCodec(String)
    case missingChannel
    case missingChallenge
    case invalidChallenge
    case invalidResponse
    case httpStatus(Int)
    case microphoneUnavailable
    case microphoneStartFailed(String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .missingHost:
            return "Enter the Portero host or IP address."
        case .missingUsername:
            return "Enter the Hikvision username."
        case .missingPassword:
            return "Enter the Hikvision password."
        case .unsupportedCodec(let codec):
            return "The Portero reported an unsupported talkback codec: \(codec)."
        case .missingChannel:
            return "The Portero did not expose a usable talkback channel."
        case .missingChallenge:
            return "The Portero did not provide a digest-auth challenge."
        case .invalidChallenge:
            return "The Portero returned an invalid digest-auth challenge."
        case .invalidResponse:
            return "The Portero returned an invalid response."
        case .httpStatus(let code):
            return "The Portero endpoint returned HTTP \(code)."
        case .microphoneUnavailable:
            return "No microphone input is available on this Mac."
        case .microphoneStartFailed(let reason):
            return "The microphone stream could not start: \(reason)."
        case .networkUnavailable:
            return "The talkback connection to the Portero could not be opened."
        }
    }
}

private struct DoorbellCredentials {
    let host: String
    let port: Int
    let username: String
    let password: String

    init(configuration: NVRConfiguration, password: String) throws {
        let host = configuration.trimmedDoorbellHost
        let username = configuration.trimmedUsername
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else {
            throw DoorbellTalkbackServiceError.missingHost
        }

        guard !username.isEmpty else {
            throw DoorbellTalkbackServiceError.missingUsername
        }

        guard !trimmedPassword.isEmpty else {
            throw DoorbellTalkbackServiceError.missingPassword
        }

        self.host = host
        port = configuration.doorbellHTTPPort
        self.username = username
        self.password = trimmedPassword
    }

    var baseURL: URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        return components.url ?? URL(string: "http://\(host):\(port)")!
    }

    var hostHeader: String {
        if port == 80 {
            return host
        }

        return "\(host):\(port)"
    }
}

private struct TalkbackChannel {
    let id: String
    let codec: TalkbackCodec
}

private enum TalkbackCodec {
    case pcmu
    case pcma

    init(rawValue: String) throws {
        switch rawValue {
        case "G.711ulaw":
            self = .pcmu
        case "G.711alaw":
            self = .pcma
        default:
            throw DoorbellTalkbackServiceError.unsupportedCodec(rawValue)
        }
    }

    func encode(_ samples: UnsafeBufferPointer<Int16>) -> Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(samples.count)

        for sample in samples {
            switch self {
            case .pcmu:
                bytes.append(Self.encodeMuLaw(sample))
            case .pcma:
                bytes.append(Self.encodeALaw(sample))
            }
        }

        return Data(bytes)
    }

    private static func encodeMuLaw(_ sample: Int16) -> UInt8 {
        let bias = 0x84
        let clip = 32635

        var pcm = Int(sample)
        var sign = 0
        if pcm < 0 {
            pcm = -pcm
            sign = 0x80
        }

        if pcm > clip {
            pcm = clip
        }

        pcm += bias

        var exponent = 7
        var mask = 0x4000
        while exponent > 0 && (pcm & mask) == 0 {
            exponent -= 1
            mask >>= 1
        }

        let mantissa = (pcm >> ((exponent == 0) ? 4 : (exponent + 3))) & 0x0F
        let encoded = ~(sign | (exponent << 4) | mantissa)
        return UInt8(encoded & 0xFF)
    }

    private static func encodeALaw(_ sample: Int16) -> UInt8 {
        let clip = 32635

        var pcm = Int(sample)
        let signBit: Int
        if pcm >= 0 {
            signBit = 0x80
        } else {
            signBit = 0x00
            pcm = -pcm - 1
        }

        if pcm > clip {
            pcm = clip
        }

        let encoded: Int
        if pcm < 256 {
            encoded = signBit | (pcm >> 4)
        } else {
            var exponent = 1
            var value = pcm >> 8
            while value > 1 {
                value >>= 1
                exponent += 1
            }

            let mantissa = (pcm >> (exponent + 3)) & 0x0F
            encoded = signBit | (exponent << 4) | mantissa
        }

        return UInt8((encoded ^ 0x55) & 0xFF)
    }
}

private actor TalkbackSession {
    private let credentials: DoorbellCredentials
    private let client: DigestDoorbellHTTPClient
    private let channel: TalkbackChannel
    private let audioEngine: MicrophoneTalkbackEngine
    private let streamConnection: TalkbackHTTPAudioConnection

    init(credentials: DoorbellCredentials, client: DigestDoorbellHTTPClient, channel: TalkbackChannel) {
        self.credentials = credentials
        self.client = client
        self.channel = channel
        streamConnection = TalkbackHTTPAudioConnection(host: credentials.host, port: credentials.port)
        audioEngine = MicrophoneTalkbackEngine(codec: channel.codec) { [streamConnection] data in
            streamConnection.sendAudio(data)
        }
    }

    func start() async throws {
        try await client.closeAudioChannelIfNeeded(channelID: channel.id)
        try await client.openAudioChannel(channelID: channel.id)

        do {
            try await streamConnection.open(
                hostHeader: credentials.hostHeader,
                requestPath: client.audioDataPath(channelID: channel.id),
                authorizationHeader: try await client.authorizationHeader(method: "PUT", path: client.audioDataPath(channelID: channel.id))
            )
        } catch {
            try? await client.closeAudioChannel(channelID: channel.id)
            throw error
        }

        do {
            try audioEngine.start()
        } catch {
            await streamConnection.close()
            try? await client.closeAudioChannel(channelID: channel.id)
            throw error
        }
    }

    func stop() async {
        audioEngine.stop()
        await streamConnection.close()
        try? await client.closeAudioChannel(channelID: channel.id)
    }
}

private actor DigestDoorbellHTTPClient {
    private let credentials: DoorbellCredentials
    private var challenge: DigestChallenge?
    private var nonceCount = 0

    init(credentials: DoorbellCredentials) {
        self.credentials = credentials
    }

    func fetchTalkbackChannel() async throws -> TalkbackChannel {
        let path = "/ISAPI/System/TwoWayAudio/channels"
        let (data, _) = try await send(method: "GET", path: path, accept: "application/xml")
        let xml = String(decoding: data, as: UTF8.self)
        let channelID = xml.firstTagValue(named: "id") ?? ""
        let codecValue = xml.firstTagValue(named: "audioCompressionType") ?? ""

        guard !channelID.isEmpty else {
            throw DoorbellTalkbackServiceError.missingChannel
        }

        return TalkbackChannel(id: channelID, codec: try TalkbackCodec(rawValue: codecValue))
    }

    func openAudioChannel(channelID: String) async throws {
        _ = try await send(method: "PUT", path: "/ISAPI/System/TwoWayAudio/channels/\(channelID)/open")
    }

    func closeAudioChannel(channelID: String) async throws {
        _ = try await send(method: "PUT", path: "/ISAPI/System/TwoWayAudio/channels/\(channelID)/close")
    }

    func closeAudioChannelIfNeeded(channelID: String) async throws {
        do {
            try await closeAudioChannel(channelID: channelID)
        } catch DoorbellTalkbackServiceError.httpStatus {
        } catch {
        }
    }

    func audioDataPath(channelID: String) -> String {
        "/ISAPI/System/TwoWayAudio/channels/\(channelID)/audioData"
    }

    func authorizationHeader(method: String, path: String) async throws -> String {
        let challenge = try await currentChallenge(for: path, method: method)
        nonceCount += 1
        return challenge.authorizationHeader(
            username: credentials.username,
            password: credentials.password,
            method: method,
            uri: path,
            nonceCount: nonceCount
        )
    }

    private func send(method: String, path: String, accept: String? = nil) async throws -> (Data, HTTPURLResponse) {
        let url = try makeURL(path: path)
        let response = try await authenticatedResponse(method: method, path: path, url: url, accept: accept)
        return response
    }

    private func authenticatedResponse(method: String, path: String, url: URL, accept: String?) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        if let accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }

        request.setValue(try await authorizationHeader(method: method, path: path), forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoorbellTalkbackServiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            challenge = nil
            var retryRequest = request
            retryRequest.setValue(try await authorizationHeader(method: method, path: path), forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)

            guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
                throw DoorbellTalkbackServiceError.invalidResponse
            }

            guard (200...299).contains(retryHTTPResponse.statusCode) else {
                throw DoorbellTalkbackServiceError.httpStatus(retryHTTPResponse.statusCode)
            }

            return (retryData, retryHTTPResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DoorbellTalkbackServiceError.httpStatus(httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    private func currentChallenge(for path: String, method: String) async throws -> DigestChallenge {
        if let challenge {
            return challenge
        }

        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoorbellTalkbackServiceError.invalidResponse
        }

        let headerValue = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
        guard httpResponse.statusCode == 401 else {
            throw DoorbellTalkbackServiceError.missingChallenge
        }

        let parsedChallenge = try DigestChallenge(headerValue: headerValue)
        challenge = parsedChallenge
        nonceCount = 0
        return parsedChallenge
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: credentials.baseURL)?.absoluteURL else {
            throw DoorbellTalkbackServiceError.invalidResponse
        }

        return url
    }
}

private struct DigestChallenge {
    let realm: String
    let nonce: String
    let qop: String?
    let opaque: String?
    let algorithm: String?

    init(headerValue: String) throws {
        let trimmed = headerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("Digest ") else {
            throw DoorbellTalkbackServiceError.invalidChallenge
        }

        let parameters = String(trimmed.dropFirst("Digest ".count))
        let pairs = parameters.split(separator: ",")
        var values: [String: String] = [:]

        for pair in pairs {
            let fragments = pair.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard fragments.count == 2 else {
                continue
            }

            values[fragments[0]] = fragments[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        guard let realm = values["realm"], let nonce = values["nonce"] else {
            throw DoorbellTalkbackServiceError.invalidChallenge
        }

        self.realm = realm
        self.nonce = nonce
        qop = values["qop"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first
        opaque = values["opaque"]
        algorithm = values["algorithm"]
    }

    func authorizationHeader(username: String, password: String, method: String, uri: String, nonceCount: Int) -> String {
        let nc = String(format: "%08x", nonceCount)
        let cnonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let ha1 = Self.hexMD5("\(username):\(realm):\(password)")
        let ha2 = Self.hexMD5("\(method):\(uri)")

        let response: String
        if let qop {
            response = Self.hexMD5("\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)")
        } else {
            response = Self.hexMD5("\(ha1):\(nonce):\(ha2)")
        }

        var header = "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\""

        if let qop {
            header += ", qop=\(qop), nc=\(nc), cnonce=\"\(cnonce)\""
        }

        if let opaque {
            header += ", opaque=\"\(opaque)\""
        }

        if let algorithm {
            header += ", algorithm=\(algorithm)"
        } else {
            header += ", algorithm=MD5"
        }

        return header
    }

    private static func hexMD5(_ value: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private final class TalkbackHTTPAudioConnection: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "com.bgazzera.HikvisionViewer.talkback.connection")
    private var connection: NWConnection?
    private var isClosed = false

    init(host: String, port: Int) {
        self.host = host
        self.port = UInt16(port)
    }

    func open(hostHeader: String, requestPath: String, authorizationHeader: String) async throws {
        let connection = NWConnection(host: .init(host), port: .init(rawValue: port) ?? .http, using: .tcp)
        self.connection = connection
        isClosed = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let openState = ConnectionOpenState()
            connection.stateUpdateHandler = { connectionState in
                switch connectionState {
                case .ready:
                    if !openState.resumeIfNeeded() {
                        return
                    }

                    continuation.resume(returning: ())
                case .failed(let error):
                    if !openState.resumeIfNeeded() {
                        return
                    }

                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }

        let request = [
            "PUT \(requestPath) HTTP/1.1",
            "Host: \(hostHeader)",
            "Authorization: \(authorizationHeader)",
            "Content-Type: application/octet-stream",
            "Content-Length: 0",
            "",
            "",
        ].joined(separator: "\r\n")

        try await send(Data(request.utf8), isComplete: false)
    }

    func sendAudio(_ data: Data) {
        guard !data.isEmpty, let connection, !isClosed else {
            return
        }

        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func close() async {
        guard let connection, !isClosed else {
            return
        }

        isClosed = true
        await withCheckedContinuation { continuation in
            connection.send(content: nil, isComplete: true, completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
        connection.cancel()
        self.connection = nil
    }

    private func send(_ data: Data, isComplete: Bool) async throws {
        guard let connection else {
            throw DoorbellTalkbackServiceError.networkUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, isComplete: isComplete, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}

private final class MicrophoneTalkbackEngine {
    private let engine = AVAudioEngine()
    private let codec: TalkbackCodec
    private let sendHandler: (Data) -> Void
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 8_000, channels: 1, interleaved: true)!
    private var converter: AVAudioConverter?

    init(codec: TalkbackCodec, sendHandler: @escaping (Data) -> Void) {
        self.codec = codec
        self.sendHandler = sendHandler
    }

    func start() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        guard inputFormat.channelCount > 0 else {
            throw DoorbellTalkbackServiceError.microphoneUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw DoorbellTalkbackServiceError.microphoneStartFailed("Audio conversion is unsupported.")
        }

        self.converter = converter
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw DoorbellTalkbackServiceError.microphoneStartFailed(error.localizedDescription)
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        guard let converter else {
            return
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = max(AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1, 1)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }

        let conversionState = AudioConversionState(buffer: buffer)
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if conversionState.didConsumeInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            conversionState.didConsumeInput = true
            outStatus.pointee = .haveData
            return conversionState.buffer
        }

        guard conversionError == nil, status != .error, outputBuffer.frameLength > 0,
              let int16ChannelData = outputBuffer.int16ChannelData else {
            return
        }

        let samples = UnsafeBufferPointer(start: int16ChannelData[0], count: Int(outputBuffer.frameLength))
        sendHandler(codec.encode(samples))
    }
}

private final class ConnectionOpenState: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func resumeIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !resumed else {
            return false
        }

        resumed = true
        return true
    }
}

private final class AudioConversionState: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var didConsumeInput = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

private extension String {
    func firstTagValue(named tag: String) -> String? {
        guard let openRange = range(of: "<\(tag)>") else {
            return nil
        }

        let searchStart = openRange.upperBound
        guard let closeRange = self[searchStart...].range(of: "</\(tag)>") else {
            return nil
        }

        return String(self[searchStart..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}