import Foundation
import Photos

enum SaveOutcome {
    case asset(String)
    case files([URL], folderBookmark: Data)
}

enum SaveError: LocalizedError {
    case photosNotAllowed
    case folderUnavailable
    case nothingCreated

    var errorDescription: String? {
        switch self {
        case .photosNotAllowed: return "沒有取用「照片」的權限"
        case .folderUnavailable: return "找不到儲存資料夾"
        case .nothingCreated: return "沒有建立任何檔案"
        }
    }
}

/// 右滑後不會立刻寫入，而是等幾秒再存。
/// 這段時間內按「復原」只要取消就好，不必刪除已存的照片（刪照片時 iOS 會跳出確認視窗）。
@MainActor
final class SaveQueue {
    private enum State { case pending, committing, done, failed }

    private final class Job {
        let item: PhotoItem
        let destination: Destination
        var state: State = .pending
        var outcome: SaveOutcome?
        var work: DispatchWorkItem?
        var revertRequested = false

        init(item: PhotoItem, destination: Destination) {
            self.item = item
            self.destination = destination
        }
    }

    var delay: TimeInterval = 3
    var onMessage: ((String) -> Void)?

    private var jobs: [UUID: Job] = [:]

    func enqueue(_ item: PhotoItem, to destination: Destination) -> UUID {
        let id = UUID()
        let job = Job(item: item, destination: destination)
        jobs[id] = job
        let work = DispatchWorkItem { [weak self] in self?.commit(id) }
        job.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return id
    }

    /// 立刻寫入所有還在等待的相片。
    func flush() {
        for (id, job) in jobs where job.state == .pending {
            job.work?.cancel()
            commit(id)
        }
    }

    func revert(_ id: UUID) {
        guard let job = jobs[id] else { return }
        switch job.state {
        case .pending:
            job.work?.cancel()
            jobs[id] = nil
        case .committing:
            job.revertRequested = true
        case .done:
            jobs[id] = nil
            if let outcome = job.outcome { remove(outcome) }
        case .failed:
            jobs[id] = nil
        }
    }

    private func commit(_ id: UUID) {
        guard let job = jobs[id], job.state == .pending else { return }
        job.state = .committing
        Task {
            do {
                let outcome = try await Saver.save(job.item, to: job.destination)
                job.outcome = outcome
                job.state = .done
                if job.revertRequested {
                    jobs[id] = nil
                    remove(outcome)
                }
            } catch {
                job.state = .failed
                onMessage?("「\(job.item.displayName)」沒有存成功：\(error.localizedDescription)")
            }
        }
    }

    private func remove(_ outcome: SaveOutcome) {
        Task {
            do {
                try await Saver.remove(outcome)
            } catch {
                if case .asset = outcome {
                    onMessage?("相片仍留在「照片」裡")
                } else {
                    onMessage?("無法刪除已存的檔案：\(error.localizedDescription)")
                }
            }
        }
    }
}

enum Saver {
    static func save(_ item: PhotoItem, to destination: Destination) async throws -> SaveOutcome {
        switch destination {
        case .library:
            return try await saveToPhotos(item, albumID: nil)
        case .album(let id, _):
            return try await saveToPhotos(item, albumID: id)
        case .folder(let bookmark, _):
            return try saveToFolder(item, bookmark: bookmark)
        }
    }

    static func remove(_ outcome: SaveOutcome) async throws {
        switch outcome {
        case .asset(let id):
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard assets.count > 0 else { throw SaveError.photosNotAllowed }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
        case .files(let urls, let bookmark):
            var stale = false
            let folder = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
            let ok = folder.startAccessingSecurityScopedResource()
            defer { if ok { folder.stopAccessingSecurityScopedResource() } }
            for url in urls { try FileManager.default.removeItem(at: url) }
        }
    }

    private final class IDBox: @unchecked Sendable { var id: String? }

    private static func saveToPhotos(_ item: PhotoItem, albumID: String?) async throws -> SaveOutcome {
        // 需要完整的讀寫權限：復原時才能把已存的照片刪掉，也才能放進相簿。
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        guard status == .authorized || status == .limited else { throw SaveError.photosNotAllowed }

        // 先複製到暫存區，再交給「照片」搬進圖庫（記憶卡上的原檔不動）。
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("save-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        let primarySource = item.standardURL ?? item.previewURL
        let alternateSource = item.standardURL != nil ? item.rawURL : nil
        let primary = temp.appendingPathComponent(primarySource.lastPathComponent)
        try fm.copyItem(at: primarySource, to: primary)
        var alternate: URL?
        if let alternateSource {
            let url = temp.appendingPathComponent(alternateSource.lastPathComponent)
            try fm.copyItem(at: alternateSource, to: url)
            alternate = url
        }

        let box = IDBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            options.originalFilename = primarySource.lastPathComponent
            request.addResource(with: .photo, fileURL: primary, options: options)
            if let alternate {
                let rawOptions = PHAssetResourceCreationOptions()
                rawOptions.shouldMoveFile = true
                rawOptions.originalFilename = alternate.lastPathComponent
                request.addResource(with: .alternatePhoto, fileURL: alternate, options: rawOptions)
            }
            guard let placeholder = request.placeholderForCreatedAsset else { return }
            box.id = placeholder.localIdentifier
            if let albumID,
               let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
            }
        }
        guard let id = box.id else { throw SaveError.nothingCreated }
        return .asset(id)
    }

    private static func saveToFolder(_ item: PhotoItem, bookmark: Data) throws -> SaveOutcome {
        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else {
            throw SaveError.folderUnavailable
        }
        let ok = folder.startAccessingSecurityScopedResource()
        defer { if ok { folder.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        func target(_ name: String, _ n: Int) -> URL {
            guard n > 1 else { return folder.appendingPathComponent(name) }
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            return folder.appendingPathComponent("\(base) \(n).\(ext)")
        }
        // 同名檔案已存在時，RAW 與 JPG 一起加上相同的編號，維持成對。
        let names = item.files.map(\.lastPathComponent)
        var n = 1
        while names.contains(where: { fm.fileExists(atPath: target($0, n).path) }) { n += 1 }

        var created: [URL] = []
        do {
            for file in item.files {
                let destination = target(file.lastPathComponent, n)
                try fm.copyItem(at: file, to: destination)
                created.append(destination)
            }
        } catch {
            for url in created { try? fm.removeItem(at: url) }
            throw error
        }
        guard !created.isEmpty else { throw SaveError.nothingCreated }
        return .files(created, folderBookmark: bookmark)
    }
}
