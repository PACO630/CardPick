import Foundation
import CryptoKit

/// 記住每張記憶卡已經挑到哪裡，下次打開同一張卡會從沒看過的相片繼續。
enum ProgressStore {
    private static let queue = DispatchQueue(label: "cardpick.progress")

    static func key(for url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Progress", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func file(_ key: String) -> URL { folder.appendingPathComponent("\(key).json") }

    static func load(_ key: String) -> [String: Decision] {
        queue.sync {
            guard let data = try? Data(contentsOf: file(key)),
                  let decoded = try? JSONDecoder().decode([String: Decision].self, from: data) else { return [:] }
            return decoded
        }
    }

    static func save(_ key: String, _ decisions: [String: Decision]) {
        queue.async {
            guard let data = try? JSONEncoder().encode(decisions) else { return }
            try? data.write(to: file(key), options: .atomic)
        }
    }

    static func clear(_ key: String) {
        queue.sync { try? FileManager.default.removeItem(at: file(key)) }
    }
}
