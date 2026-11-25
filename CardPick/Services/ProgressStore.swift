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
        queue.sync {
            try? FileManager.default.removeItem(at: file(key))
            try? FileManager.default.removeItem(at: savedFile(key))
        }
    }

    // MARK: - 已經真正寫入的相片（用來補存 App 被關掉前還沒存的）

    private static func savedFile(_ key: String) -> URL { folder.appendingPathComponent("\(key)-saved.json") }

    private static func readSaved(_ key: String) -> Set<String> {
        guard let data = try? Data(contentsOf: savedFile(key)),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    private static func writeSaved(_ key: String, _ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids.sorted()) else { return }
        try? data.write(to: savedFile(key), options: .atomic)
    }

    static func loadSaved(_ key: String) -> Set<String> {
        queue.sync { readSaved(key) }
    }

    /// 舊版沒有「已存入」紀錄。第一次用新版開啟時，把當時決定要存的都當作已經存好，避免重複存。
    static func migrateSavedRecord(_ key: String) {
        queue.sync {
            guard !FileManager.default.fileExists(atPath: savedFile(key).path) else { return }
            var legacy: Set<String> = []
            if let data = try? Data(contentsOf: file(key)),
               let decisions = try? JSONDecoder().decode([String: Decision].self, from: data) {
                legacy = Set(decisions.filter { $0.value == .save }.map(\.key))
            }
            writeSaved(key, legacy)
        }
    }

    static func markSaved(_ key: String, _ id: String) {
        queue.async { var ids = readSaved(key); ids.insert(id); writeSaved(key, ids) }
    }

    static func unmarkSaved(_ key: String, _ id: String) {
        queue.async { var ids = readSaved(key); ids.remove(id); writeSaved(key, ids) }
    }
}
