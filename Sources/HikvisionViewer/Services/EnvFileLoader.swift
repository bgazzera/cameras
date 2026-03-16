import Foundation

struct EnvFileLoader {
    func loadDefaults() -> [String: String] {
        for url in candidateURLs() {
            guard let values = try? parseEnvFile(at: url), !values.isEmpty else {
                continue
            }

            return values
        }

        return [:]
    }

    private func candidateURLs() -> [URL] {
        var urls: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent("defaults.env"))
        }

        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        urls.append(currentDirectoryURL.appendingPathComponent(".env"))

        return urls
    }

    private func parseEnvFile(at url: URL) throws -> [String: String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var values: [String: String] = [:]

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty, !line.hasPrefix("#"), let separatorIndex = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                continue
            }

            var value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            } else if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }

            values[key] = value
        }

        return values
    }
}