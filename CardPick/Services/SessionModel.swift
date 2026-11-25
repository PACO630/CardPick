import SwiftUI
import UIKit
import Photos

@MainActor
final class SessionModel: ObservableObject {
    enum Phase: Equatable { case start, loading, deck, done }

    /// 剛被滑走、正在飛出畫面的卡片（獨立畫出，讓下一張可以同時往前補位）。
    struct Departing: Identifiable {
        let id = UUID()
        let item: PhotoItem
        let startX: CGFloat
        let direction: CGFloat
    }

    struct HistoryEntry {
        let position: Int
        let itemID: String
        let itemName: String
        let decision: Decision
        let jobID: UUID?
    }

    @Published private(set) var phase: Phase = .start
    @Published private(set) var items: [PhotoItem] = []
    @Published private(set) var queue: [Int] = []
    @Published private(set) var position = 0
    @Published var dragX: CGFloat = 0
    @Published private(set) var departing: [Departing] = []
    @Published private(set) var arrivalX: CGFloat = 0
    @Published private(set) var toast: String?
    @Published private(set) var loadingCount = 0
    @Published private(set) var sourceName = ""
    @Published private(set) var reviewingSkipped = false
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var destination: Destination
    @Published private(set) var recentFolders: [FolderRef]
    @Published private(set) var lastSource: LastSource?
    @Published private(set) var savedCount = 0
    @Published private(set) var skippedCount = 0
    @Published var showDestinations = false
    @Published var alert: AlertInfo?

    let saves = SaveQueue()
    /// 卡片飛出畫面的距離，由畫面寬度決定。
    var travel: CGFloat = 1400

    private var decisions: [String: Decision] = [:]
    private var sourceKey = ""
    private var accessed: [URL] = []
    private var toastWork: DispatchWorkItem?

    init() {
        destination = Self.loadJSON(Destination.self, "destination") ?? .library
        recentFolders = Self.loadJSON([FolderRef].self, "recentFolders") ?? []
        lastSource = Self.loadJSON(LastSource.self, "lastSource")
        saves.onMessage = { [weak self] message in self?.showToast(message) }
        // 只保留「繼續挑選」會用到的那一次匯入；其餘的先補存沒存到的相片，再刪掉。
        var keep: URL?
        if let last = lastSource {
            var stale = false
            keep = try? URL(resolvingBookmarkData: last.bookmark, bookmarkDataIsStale: &stale)
        }
        cleanupImports(keep: keep)
    }

    /// 清掉舊的匯入資料夾。裡面如果還有右滑了、卻還沒真正存進去的相片（例如 App 被關掉），先存完再刪。
    private func cleanupImports(keep: URL?) {
        Task {
            let leftovers = await Task.detached(priority: .utility) { () -> [(URL, String, [PhotoItem])] in
                ImportStore.folders(except: keep).map { folder in
                    let key = ProgressStore.key(for: folder)
                    let unsaved = Self.unsavedIDs(key)
                    let items = unsaved.isEmpty ? [] : FolderScanner.scan(root: folder) { _ in }.filter { unsaved.contains($0.id) }
                    return (folder, key, items)
                }
            }.value
            for (folder, key, items) in leftovers {
                guard !items.isEmpty else {
                    ImportStore.remove(folder)
                    ProgressStore.clear(key)
                    continue
                }
                for item in items { _ = saves.enqueue(item, to: destination, sourceKey: key) }
                saves.flush {
                    ImportStore.remove(folder)
                    ProgressStore.clear(key)
                }
            }
        }
    }

    /// 決定要存、但還沒真正寫入的相片。
    nonisolated private static func unsavedIDs(_ key: String) -> Set<String> {
        ProgressStore.migrateSavedRecord(key)
        let saved = ProgressStore.loadSaved(key)
        return Set(ProgressStore.load(key).filter { $0.value == .save && !saved.contains($0.key) }.map(\.key))
    }

    // MARK: - 目前狀態

    var current: PhotoItem? { position < queue.count ? items[queue[position]] : nil }

    var visible: [PhotoItem] {
        guard position < queue.count else { return [] }
        return queue[position..<min(position + 3, queue.count)].map { items[$0] }
    }

    var canUndo: Bool { !history.isEmpty && (phase == .deck || phase == .done) }

    // MARK: - 來源（記憶卡）

    func chooseSource() {
        FolderPicker.shared.presentSource { [weak self] urls in self?.importCopies(urls) }
    }

    /// 系統選擇器已經把勾選的相片複製進 App 的暫存區；搬到 App 自己的「匯入」資料夾再開始挑。
    /// iPadOS 16 直接讀取外接記憶卡上的檔案會卡住，先複製進來最可靠。
    private func importCopies(_ urls: [URL]) {
        let photos = urls.filter(FileTypes.isPhoto)
        guard !photos.isEmpty else { return }
        saves.flush()
        showDestinations = false
        sourceName = Self.importName
        loadingCount = photos.count
        withAnimation(.easeInOut(duration: 0.25)) { phase = .loading }

        Task.detached(priority: .userInitiated) { [weak self] in
            let folder = ImportStore.store(photos)
            await self?.finishImport(folder)
        }
    }

    private func finishImport(_ folder: URL?) {
        guard let folder else {
            withAnimation { phase = .start }
            alert = AlertInfo(title: "無法讀取相片", message: "請確認 iPad 還有足夠的儲存空間，再重新選擇一次。")
            return
        }
        open(folder, name: Self.importName)
        cleanupImports(keep: folder)
    }

    private static let importName = "記憶卡"

    /// 取得新來源的存取權；舊來源可能還有相片正在寫入，稍後再釋放。
    private func replaceAccess(with urls: [URL]) {
        let previous = accessed
        accessed = urls.filter { $0.startAccessingSecurityScopedResource() }
        let keep = Set(urls)
        let release = previous.filter { !keep.contains($0) }
        if !release.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                release.forEach { $0.stopAccessingSecurityScopedResource() }
            }
        }
    }

    /// 記憶卡名稱：資料夾在 DCIM 底下時，用 DCIM 上一層（卡的名稱）。
    private static func cardName(for folder: URL) -> String {
        var url = folder
        while url.pathComponents.count > 1 {
            if url.lastPathComponent.uppercased() == "DCIM" { return url.deletingLastPathComponent().lastPathComponent }
            url = url.deletingLastPathComponent()
        }
        return folder.lastPathComponent
    }

    func resumeLast() {
        guard let last = lastSource else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: last.bookmark, bookmarkDataIsStale: &stale) else {
            alert = AlertInfo(title: "找不到「\(last.name)」", message: "請確認記憶卡已經接上 iPad，或重新選擇記憶卡。")
            return
        }
        open(url, name: last.name)
    }

    func open(_ url: URL, name customName: String? = nil) {
        saves.flush()
        showDestinations = false

        replaceAccess(with: [url])

        guard (try? url.checkResourceIsReachable()) == true else {
            alert = AlertInfo(title: "找不到「\(url.lastPathComponent)」", message: "請確認記憶卡已經接上 iPad，或重新選擇記憶卡。")
            withAnimation { phase = .start }
            return
        }

        let name = customName ?? (url.lastPathComponent.uppercased() == "DCIM"
            ? url.deletingLastPathComponent().lastPathComponent : Self.cardName(for: url))
        sourceName = name
        if let bookmark = try? url.bookmarkData() {
            lastSource = LastSource(name: name, bookmark: bookmark)
            Self.saveJSON(lastSource, "lastSource")
        }
        sourceKey = ProgressStore.key(for: url)
        loadingCount = 0
        withAnimation(.easeInOut(duration: 0.25)) { phase = .loading }

        Task.detached(priority: .userInitiated) { [weak self] in
            let found = FolderScanner.scan(root: url) { count in
                Task { @MainActor in self?.loadingCount = count }
            }
            await self?.finishLoading(found)
        }
    }

    private func finishLoading(_ found: [PhotoItem]) {
        guard !found.isEmpty else {
            withAnimation { phase = .start }
            alert = AlertInfo(title: "找不到相片",
                              message: "選擇的項目裡沒有 JPG、HEIC 或 RAW 相片。")
            return
        }
        items = found
        decisions = ProgressStore.load(sourceKey)
        recount()
        // 上次右滑了、但 App 被關掉而沒存到的相片，排回去等下次寫入。
        let unsaved = Self.unsavedIDs(sourceKey)
        for item in found where unsaved.contains(item.id) {
            _ = saves.enqueue(item, to: destination, sourceKey: sourceKey)
        }
        history = []
        reviewingSkipped = false
        queue = found.indices.filter { decisions[found[$0].id] == nil }
        position = 0
        dragX = 0
        arrivalX = 0
        withAnimation(.easeInOut(duration: 0.3)) { phase = queue.isEmpty ? .done : .deck }
        if !queue.isEmpty && queue.count < found.count { showToast("從上次看到的地方繼續") }
        prefetch()
        // 要存進「照片」時，開始挑之前先問權限，免得滑到一半才跳出來。
        if !destination.isFolder, PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            Task { _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        }
    }

    func goStart() {
        saves.flush()
        showDestinations = false
        withAnimation(.easeInOut(duration: 0.25)) { phase = .start }
    }

    // MARK: - 左滑／右滑

    func decide(_ decision: Decision, fromX x: CGFloat? = nil) {
        guard phase == .deck, !showDestinations, let item = current else { return }
        let direction: CGFloat = decision == .save ? 1 : -1
        let flying = Departing(item: item, startX: x ?? dragX, direction: direction)
        departing.append(flying)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.departing.removeAll { $0.id == flying.id }
        }

        var jobID: UUID?
        if decision == .save {
            jobID = saves.enqueue(item, to: destination, sourceKey: sourceKey)
        }
        history.append(HistoryEntry(position: position, itemID: item.id, itemName: item.displayName,
                                    decision: decision, jobID: jobID))
        decisions[item.id] = decision
        persist()
        recount()

        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            dragX = 0
            arrivalX = 0
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { position += 1 }

        if position >= queue.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
                guard let self, self.position >= self.queue.count, self.phase == .deck else { return }
                withAnimation(.easeInOut(duration: 0.3)) { self.phase = .done }
            }
        }
        prefetch()
    }

    /// 手指、滑鼠拖曳或觸控板雙指滑動結束時呼叫。
    func endDrag(x: CGFloat, predictedX: CGFloat) {
        guard phase == .deck else { return }
        if x > 130 || (x > 40 && predictedX > 380) {
            decide(.save, fromX: x)
        } else if x < -130 || (x < -40 && predictedX < -380) {
            decide(.skip, fromX: x)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { dragX = 0 }
        }
    }

    func undo() {
        guard canUndo, !showDestinations, let last = history.popLast() else { return }
        if let id = last.jobID { saves.revert(id) }
        decisions[last.itemID] = nil
        persist()
        recount()

        let direction: CGFloat = last.decision == .save ? 1 : -1
        let message = last.decision == .save ? "已復原：「\(last.itemName)」不儲存" : "已復原：拿回「\(last.itemName)」"
        var instant = Transaction()
        instant.disablesAnimations = true

        let bringBack = { [weak self] in
            guard let self else { return }
            withTransaction(instant) {
                self.arrivalX = direction * self.travel
                self.dragX = 0
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { self.position = last.position }
            self.showToast(message)
            self.prefetch()
        }

        if phase == .done {
            // 先回到卡片畫面，下一個循環再讓卡片飛回來，才看得到動畫。
            withTransaction(instant) { phase = .deck }
            DispatchQueue.main.async { bringBack() }
        } else {
            bringBack()
        }
    }

    func reviewSkipped() {
        let skipped = items.indices.filter { decisions[items[$0].id] == .skip }
        guard !skipped.isEmpty else { return }
        for index in skipped { decisions[items[index].id] = nil }
        persist()
        recount()
        queue = skipped
        position = 0
        history = []
        arrivalX = 0
        reviewingSkipped = true
        withAnimation(.easeInOut(duration: 0.3)) { phase = .deck }
        prefetch()
    }

    // MARK: - 儲存位置

    func setDestination(_ newValue: Destination) {
        destination = newValue
        Self.saveJSON(newValue, "destination")
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { showDestinations = false }
    }

    func chooseFolderDestination() {
        FolderPicker.shared.present { [weak self] url in
            guard let self else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let bookmark = try? url.bookmarkData() else {
                self.alert = AlertInfo(title: "無法使用這個資料夾", message: "請選擇「我的 iPad」或 iCloud 雲碟裡的資料夾。")
                return
            }
            let ref = FolderRef(name: url.lastPathComponent, bookmark: bookmark)
            var list = self.recentFolders.filter { $0.name != ref.name }
            list.insert(ref, at: 0)
            self.recentFolders = Array(list.prefix(4))
            Self.saveJSON(self.recentFolders, "recentFolders")
            self.setDestination(.folder(bookmark: bookmark, name: ref.name))
        }
    }

    func flushSaves() { saves.flush() }

    // MARK: - 提示

    func showToast(_ text: String) {
        toastWork?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { toast = text }
        UIAccessibility.post(notification: .announcement, argument: text)
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    // MARK: - 內部

    private func prefetch() {
        guard position < queue.count else { return }
        let upcoming = queue[position..<min(position + 4, queue.count)].map { items[$0] }
        ImageLoader.shared.prefetch(upcoming)
    }

    private func persist() {
        ProgressStore.save(sourceKey, decisions)
    }

    private func recount() {
        savedCount = decisions.values.filter { $0 == .save }.count
        skippedCount = decisions.values.filter { $0 == .skip }.count
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func saveJSON<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
