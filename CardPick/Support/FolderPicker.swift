import UIKit
import UniformTypeIdentifiers

/// 用「檔案」的選擇器挑一個資料夾（記憶卡或儲存位置）。
@MainActor
final class FolderPicker: NSObject, UIDocumentPickerDelegate {
    static let shared = FolderPicker()

    private var completion: ((URL) -> Void)?

    func present(completion: @escaping (URL) -> Void) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        guard var top = window?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = self
        self.completion = completion
        top.present(picker, animated: true)
    }

    nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor in
            if let url = urls.first { self.completion?(url) }
            self.completion = nil
        }
    }

    nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Task { @MainActor in self.completion = nil }
    }
}
