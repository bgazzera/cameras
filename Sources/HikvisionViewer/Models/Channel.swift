import Foundation

struct Channel: Identifiable, Hashable, Codable {
    let id: String
    let name: String

    var displayName: String {
        if name.isEmpty || name == id {
            return "Channel \(id)"
        }

        return "\(name) (\(id))"
    }
}
