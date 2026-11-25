import Foundation

/// 記憶卡上的一張相片。相機同時拍 RAW + JPG 時，兩個同名檔案算同一張。
struct PhotoItem: Identifiable, Hashable {
    /// 相對於來源資料夾的路徑（不含副檔名、小寫），用來記錄進度。
    let id: String
    /// 這張相片的所有檔案（例如 IMG_0421.JPG 與 IMG_0421.CR3）。
    let files: [URL]
    /// 用來顯示預覽的檔案（有 JPG／HEIC 就用它，否則用 RAW）。
    let previewURL: URL
    let displayName: String
    /// 「RAW+JPG」或「RAW」，一般相片為 nil。
    let kindLabel: String?

    var rawURL: URL? { files.first(where: FileTypes.isRaw) }
    var standardURL: URL? { files.first(where: FileTypes.isStandard) }
    var isRawOnly: Bool { standardURL == nil }
}

enum FileTypes {
    static let standard: Set<String> = ["jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "webp"]
    static let raw: Set<String> = ["dng", "cr2", "cr3", "crw", "nef", "nrw", "arw", "srf", "sr2", "raf",
                                   "orf", "rw2", "pef", "srw", "x3f", "3fr", "erf", "kdc", "mrw", "iiq", "rwl"]

    static func isStandard(_ url: URL) -> Bool { standard.contains(url.pathExtension.lowercased()) }
    static func isRaw(_ url: URL) -> Bool { raw.contains(url.pathExtension.lowercased()) }
    static func isPhoto(_ url: URL) -> Bool { isStandard(url) || isRaw(url) }
}

enum Decision: String, Codable {
    case save
    case skip
}

/// 右滑的相片要存到哪裡。
enum Destination: Codable, Equatable {
    /// 「照片」App 的圖庫（不放進特定相簿）。
    case library
    /// 「照片」App 裡的某個相簿。
    case album(id: String, name: String)
    /// 「檔案」App 裡的某個資料夾（以 security-scoped bookmark 記住）。
    case folder(bookmark: Data, name: String)

    var title: String {
        switch self {
        case .library: return "照片圖庫"
        case .album(_, let name): return name
        case .folder(_, let name): return name
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

struct FolderRef: Codable, Equatable, Identifiable {
    var id: Data { bookmark }
    let name: String
    let bookmark: Data
}

struct LastSource: Codable, Equatable {
    let name: String
    let bookmark: Data
}

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
