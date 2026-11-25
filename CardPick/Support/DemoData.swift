import UIKit
import ImageIO
import UniformTypeIdentifiers

/// 測試用：以 `-demo` 啟動時，產生一個假的記憶卡資料夾並直接開啟。
/// `-demoPhase start` 停在開始畫面。
enum DemoData {
    @MainActor
    static func startIfRequested(_ session: SessionModel) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-demo") else { return }
        let root = makeCard()
        ProgressStore.clear(ProgressStore.key(for: root))
        let phase = UserDefaults.standard.string(forKey: "demoPhase")
        if phase == "start" { return }
        session.open(root)
        // `-demoDrag 200`：卡片停在拖曳中的位置，方便檢查滑動時的圖示。
        // `-demoDragLeft 200`：往左拖曳中（命令列參數不能用負號開頭）。
        let right = UserDefaults.standard.double(forKey: "demoDrag")
        let drag = right != 0 ? right : -UserDefaults.standard.double(forKey: "demoDragLeft")
        if drag != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { session.dragX = drag }
        }
    }

    private struct Scene {
        let sky: [UInt32]
        let sun: UInt32
        let sunAt: CGPoint
        let far: UInt32
        let near: UInt32
        let ground: UInt32
        let portrait: Bool
    }

    private static let scenes: [Scene] = [
        Scene(sky: [0xCFE3EF, 0xEEF2EA], sun: 0xFFFFFF, sunAt: CGPoint(x: 0.72, y: 0.31), far: 0xA9C1BD, near: 0x6B8F84, ground: 0x3F6156, portrait: false),
        Scene(sky: [0xF6B26B, 0xF2845C, 0x7A5BA6], sun: 0xFFF0C2, sunAt: CGPoint(x: 0.35, y: 0.46), far: 0x6D4F8B, near: 0x40305F, ground: 0x271F44, portrait: false),
        Scene(sky: [0x2F6FD0, 0x9CCAF5], sun: 0xFFFFFF, sunAt: CGPoint(x: 0.6, y: 0.18), far: 0xEEF4FB, near: 0x7F97B6, ground: 0x2E4A6B, portrait: true),
        Scene(sky: [0xFFD99C, 0xF7A46C], sun: 0xFFF6DC, sunAt: CGPoint(x: 0.53, y: 0.35), far: 0xC45A3B, near: 0x7B2F20, ground: 0x3E1B13, portrait: false),
        Scene(sky: [0x14223F, 0x3E4F8B, 0xE07B5F], sun: 0xFFD3A8, sunAt: CGPoint(x: 0.65, y: 0.55), far: 0x27345F, near: 0x151D39, ground: 0x0D1327, portrait: false),
        Scene(sky: [0x8EC5FC, 0xE2F2FF], sun: 0xFFFBE6, sunAt: CGPoint(x: 0.2, y: 0.24), far: 0x93C27E, near: 0x51893E, ground: 0x2F5D28, portrait: false),
        Scene(sky: [0x0F2027, 0x2C5364], sun: 0xF8F4E3, sunAt: CGPoint(x: 0.8, y: 0.2), far: 0x35596B, near: 0x1C3440, ground: 0x0B1A20, portrait: false),
        Scene(sky: [0xFBD3E9, 0xBB377D], sun: 0xFFF5F9, sunAt: CGPoint(x: 0.45, y: 0.3), far: 0x9B3B6E, near: 0x5E1F43, ground: 0x34102A, portrait: true)
    ]

    private static func makeCard() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Demo/EOS_DIGITAL", isDirectory: true)
        let folder = root.appendingPathComponent("DCIM/100CANON", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var date = DateComponents(calendar: .current, year: 2026, month: 11, day: 2, hour: 6, minute: 12).date ?? Date()
        for (index, scene) in scenes.enumerated() {
            let url = folder.appendingPathComponent(String(format: "IMG_%04d.JPG", 418 + index * 3))
            write(render(scene), to: url, date: date)
            date.addTimeInterval(3600 * 5 + 1234)
        }
        return root
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func render(_ scene: Scene) -> UIImage {
        let size = scene.portrait ? CGSize(width: 1200, height: 1800) : CGSize(width: 1800, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = scene.sky.map { color($0).cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let w = size.width, h = size.height
            color(scene.sun).withAlphaComponent(0.92).setFill()
            let r = min(w, h) * 0.08
            cg.fillEllipse(in: CGRect(x: scene.sunAt.x * w - r, y: scene.sunAt.y * h - r, width: r * 2, height: r * 2))

            func ridge(_ points: [CGFloat], base: CGFloat, fill: UInt32) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: h))
                for (i, p) in points.enumerated() {
                    path.addLine(to: CGPoint(x: w * CGFloat(i) / CGFloat(points.count - 1), y: h * (base - p)))
                }
                path.addLine(to: CGPoint(x: w, y: h))
                path.close()
                color(fill).setFill()
                path.fill()
            }
            ridge([0.0, 0.14, 0.06, 0.22, 0.08, 0.17, 0.03], base: 0.62, fill: scene.far)
            ridge([0.0, 0.12, 0.03, 0.16, 0.02, 0.09, 0.04], base: 0.76, fill: scene.near)
            ridge([0.0, 0.03, 0.05, 0.03, 0.0], base: 0.88, fill: scene.ground)
        }
    }

    private static let exifFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    private static func write(_ image: UIImage, to url: URL, date: Date) {
        guard let cg = image.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85,
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: exifFormatter.string(from: date)]
        ]
        CGImageDestinationAddImage(destination, cg, props as CFDictionary)
        CGImageDestinationFinalize(destination)
    }
}
