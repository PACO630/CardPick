import UIKit
import UniformTypeIdentifiers

/// 用「檔案」的選擇器挑記憶卡或儲存位置。
@MainActor
final class FolderPicker: NSObject, UIDocumentPickerDelegate {
    static let shared = FolderPicker()

    private var completion: (([URL]) -> Void)?

    /// 只挑一個資料夾（儲存位置）。
    func present(completion: @escaping (URL) -> Void) {
        present(types: [.folder], multiple: false) { urls in
            if let url = urls.first { completion(url) }
        }
    }

    /// 挑記憶卡：可以打開整個資料夾，也可以直接勾選相片。
    /// iPadOS 16 在外接記憶卡上有時無法用「打開」選資料夾，勾選相片是保底的方式。
    func presentSource(completion: @escaping ([URL]) -> Void) {
        var types: [UTType] = [.folder, .image]
        if let raw = UTType("public.camera-raw-image") { types.append(raw) }
        present(types: types, multiple: true, completion: completion)
    }

    private func present(types: [UTType], multiple: Bool, completion: @escaping ([URL]) -> Void) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        guard var top = window?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = multiple
        picker.shouldShowFileExtensions = true
        picker.delegate = self
        self.completion = completion
        top.present(picker, animated: true)
    }

    nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor in
            if !urls.isEmpty { self.completion?(urls) }
            self.completion = nil
        }
    }

    nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Task { @MainActor in self.completion = nil }
    }
}
