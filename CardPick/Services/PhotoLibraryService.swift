import Photos
import UIKit

/// 列出「照片」App 的相簿，並可新增相簿。
@MainActor
final class PhotoLibraryService: ObservableObject {
    struct Album: Identifiable, Equatable {
        let id: String
        let name: String
        let count: Int
        let keyAssetID: String?
    }

    @Published private(set) var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var albums: [Album] = []

    var canListAlbums: Bool { status == .authorized || status == .limited }

    func requestAccess() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        reload()
    }

    func reload() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard canListAlbums else {
            albums = []
            return
        }
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var list: [Album] = []
        collections.enumerateObjects { collection, _, _ in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            list.append(Album(id: collection.localIdentifier,
                              name: collection.localizedTitle ?? "未命名相簿",
                              count: assets.count,
                              keyAssetID: assets.firstObject?.localIdentifier))
        }
        albums = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func createAlbum(named name: String) async throws -> Album {
        final class Box: @unchecked Sendable { var id: String? }
        let box = Box()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            box.id = request.placeholderForCreatedAssetCollection.localIdentifier
        }
        reload()
        guard let id = box.id else { throw SaveError.nothingCreated }
        return albums.first(where: { $0.id == id }) ?? Album(id: id, name: name, count: 0, keyAssetID: nil)
    }
}
