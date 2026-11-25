import Foundation

/// 掃描記憶卡（或任何資料夾）裡的相片，把同名的 RAW + JPG 合併成一張。
enum FolderScanner {
    static func scan(root: URL, progress: @escaping (Int) -> Void) -> [PhotoItem] {
        let fm = FileManager.default
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        var groups: [String: [URL]] = [:]
        var found = 0
        for case let url as URL in enumerator {
            guard FileTypes.isPhoto(url) else { continue }
            let full = url.resolvingSymlinksInPath().standardizedFileURL.path
            let relative = full.hasPrefix(rootPath + "/") ? String(full.dropFirst(rootPath.count + 1)) : url.lastPathComponent
            let key = (relative as NSString).deletingPathExtension.lowercased()
            if groups[key] == nil {
                found += 1
                if found % 25 == 0 { progress(found) }
            }
            groups[key, default: []].append(url)
        }
        progress(found)

        let keys = groups.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return keys.compactMap { key in
            guard let files = groups[key]?.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else { return nil }
            let standard = files.first(where: FileTypes.isStandard)
            let raw = files.first(where: FileTypes.isRaw)
            guard let preview = standard ?? raw else { return nil }
            let label: String?
            if let standard, raw != nil {
                let ext = standard.pathExtension.uppercased()
                label = "RAW+" + (ext == "JPEG" ? "JPG" : ext)
            } else if raw != nil {
                label = "RAW"
            } else {
                label = nil
            }
            return PhotoItem(id: key, files: files, previewURL: preview,
                             displayName: preview.lastPathComponent, kindLabel: label)
        }
    }
}
