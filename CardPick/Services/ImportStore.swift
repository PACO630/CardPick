import Foundation

/// 從記憶卡複製進來的相片，存在 App 自己的 Application Support/Imports/<時間> 資料夾。
/// 每次只保留最近一次匯入，供「繼續挑選」使用；換一張卡時刪掉舊的，不佔空間。
enum ImportStore {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Imports", isDirectory: true)
    }

    /// 把選擇器複製好的檔案搬進新的匯入資料夾；失敗時回傳 nil。
    static func store(_ files: [URL]) -> URL? {
        let fm = FileManager.default
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let folder = root.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files {
                var target = folder.appendingPathComponent(file.lastPathComponent)
                var n = 2
                while fm.fileExists(atPath: target.path) {
                    let base = (file.lastPathComponent as NSString).deletingPathExtension
                    target = folder.appendingPathComponent("\(base) \(n).\(file.pathExtension)")
                    n += 1
                }
                do {
                    try fm.moveItem(at: file, to: target)
                } catch {
                    try fm.copyItem(at: file, to: target)
                }
            }
            return folder
        } catch {
            try? fm.removeItem(at: folder)
            return nil
        }
    }

    /// 除了 keep 以外的所有匯入資料夾。
    static func folders(except keep: URL?) -> [URL] {
        let keepPath = keep?.resolvingSymlinksInPath().standardizedFileURL.path
        let all = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.resolvingSymlinksInPath().standardizedFileURL.path != keepPath }
    }

    static func remove(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }
}
