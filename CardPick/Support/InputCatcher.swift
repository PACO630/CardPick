import SwiftUI
import UIKit

struct KeyCommandItem {
    let title: String
    let input: String
    var modifiers: UIKeyModifierFlags = []
    let action: () -> Void
}

/// 實體鍵盤與觸控板：
/// - 鍵盤快捷鍵用 UIKeyCommand（按住 ⌘ 會出現在系統的快捷鍵列表）。
/// - 觸控板雙指左右滑，就像用手指把卡片滑走。
struct InputCatcher: UIViewRepresentable {
    var commands: [KeyCommandItem]
    var scrollEnabled: Bool
    var onScroll: (CGFloat) -> Void
    var onScrollEnd: (_ x: CGFloat, _ velocityX: CGFloat) -> Void

    func makeUIView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: CatcherView, context: Context) {
        apply(to: uiView)
        uiView.reclaimSoon()
    }

    private func apply(to view: CatcherView) {
        view.items = commands
        view.scrollEnabled = scrollEnabled
        view.onScroll = onScroll
        view.onScrollEnd = onScrollEnd
    }

    final class CatcherView: UIView, UIGestureRecognizerDelegate {
        var items: [KeyCommandItem] = []
        var scrollEnabled = false
        var onScroll: ((CGFloat) -> Void)?
        var onScrollEnd: ((CGFloat, CGFloat) -> Void)?

        private var pan: UIPanGestureRecognizer?
        private var timer: Timer?

        override var canBecomeFirstResponder: Bool { true }

        override var keyCommands: [UIKeyCommand]? {
            items.enumerated().map { index, item in
                let command = UIKeyCommand(title: item.title, action: #selector(run(_:)),
                                           input: item.input, modifierFlags: item.modifiers,
                                           propertyList: index)
                command.wantsPriorityOverSystemBehavior = true
                return command
            }
        }

        @objc private func run(_ command: UIKeyCommand) {
            guard let index = command.propertyList as? Int, index < items.count else { return }
            items[index].action()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window else {
                timer?.invalidate()
                timer = nil
                return
            }
            if pan == nil {
                let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                recognizer.allowedScrollTypesMask = .continuous
                recognizer.allowedTouchTypes = []   // 只接收觸控板捲動，不影響手指觸控
                recognizer.cancelsTouchesInView = false
                recognizer.delegate = self
                window.addGestureRecognizer(recognizer)
                pan = recognizer
            }
            if timer == nil {
                // 檔案選擇器、提示框關閉後，重新取得鍵盤焦點。
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.reclaim() }
                // 系統彈窗（照片權限、刪除確認）關閉後，雖然仍是第一回應者卻收不到按鍵，要重新取得一次。
                let center = NotificationCenter.default
                for name in [UIApplication.didBecomeActiveNotification, UIWindow.didBecomeKeyNotification] {
                    center.addObserver(self, selector: #selector(refocus), name: name, object: nil)
                }
            }
            reclaimSoon()
        }

        @objc private func refocus() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self, self.window?.rootViewController?.presentedViewController == nil else { return }
                if self.isFirstResponder { self.resignFirstResponder() }
                self.becomeFirstResponder()
            }
        }

        func reclaimSoon() {
            DispatchQueue.main.async { [weak self] in self?.reclaim() }
        }

        private func reclaim() {
            guard let window, !isFirstResponder,
                  window.rootViewController?.presentedViewController == nil else { return }
            becomeFirstResponder()
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let x = recognizer.translation(in: window).x
            switch recognizer.state {
            case .changed:
                if scrollEnabled { onScroll?(x) }
            case .ended:
                if scrollEnabled { onScrollEnd?(x, recognizer.velocity(in: window).x * 0.25) }
            case .cancelled, .failed:
                if scrollEnabled { onScrollEnd?(0, 0) }
            default:
                break
            }
        }

        override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard recognizer === pan, scrollEnabled, let pan else { return false }
            let v = pan.velocity(in: window)
            return abs(v.x) > abs(v.y)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
