import UIKit
import ImageIO

struct PhotoMeta {
    let date: Date?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var dateText: String? { date.map { Self.formatter.string(from: $0) } }
}

/// 在背景把相片縮成螢幕需要的大小，並快取最近幾張。
final class ImageLoader {
    static let shared = ImageLoader()

    /// iPad Air 4 螢幕寬 2360 px，卡片最多約佔 75%，2400 px 已足夠清晰。
    var maxPixel: CGFloat = 2400

    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "cardpick.image", qos: .userInitiated, attributes: .concurrent)
    private let lock = NSLock()
    private var inflight: [String: [(UIImage?) -> Void]] = [:]
    private var metas: [String: PhotoMeta] = [:]

    private init() {
        cache.countLimit = 14
    }

    func cachedImage(for item: PhotoItem) -> UIImage? {
        cache.object(forKey: item.id as NSString)
    }

    func meta(for item: PhotoItem) -> PhotoMeta? {
        lock.lock(); defer { lock.unlock() }
        return metas[item.id]
    }

    func image(for item: PhotoItem) async -> UIImage? {
        if let cached = cachedImage(for: item) { return cached }
        return await withCheckedContinuation { continuation in
            request(item) { continuation.resume(returning: $0) }
        }
    }

    func prefetch(_ items: [PhotoItem]) {
        for item in items where cachedImage(for: item) == nil {
            request(item) { _ in }
        }
    }

    private func request(_ item: PhotoItem, completion: @escaping (UIImage?) -> Void) {
        lock.lock()
        if inflight[item.id] != nil {
            inflight[item.id]?.append(completion)
            lock.unlock()
            return
        }
        inflight[item.id] = [completion]
        lock.unlock()

        let maxPixel = self.maxPixel
        queue.async { [weak self] in
            guard let self else { return }
            let image = Self.decode(item, maxPixel: maxPixel)
            let meta = Self.readMeta(item.previewURL)
            if let image { self.cache.setObject(image, forKey: item.id as NSString) }
            self.lock.lock()
            self.metas[item.id] = meta
            let callbacks = self.inflight.removeValue(forKey: item.id) ?? []
            self.lock.unlock()
            DispatchQueue.main.async { callbacks.forEach { $0(image) } }
        }
    }

    private static func decode(_ item: PhotoItem, maxPixel: CGFloat) -> UIImage? {
        let url = item.previewURL
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        // RAW 檔先用相機內嵌的預覽圖，速度快很多；沒有內嵌預覽才完整解碼。
        let raw = FileTypes.isRaw(url)
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        if raw {
            options[kCGImageSourceCreateThumbnailFromImageIfAbsent] = true
        } else {
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
        }
        if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cg)
        }
        if raw {
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
            if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return UIImage(cgImage: cg)
            }
        }
        return nil
    }

    private static let exifFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    private static func readMeta(_ url: URL) -> PhotoMeta {
        var date: Date?
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
            let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            if let text = (exif?[kCGImagePropertyExifDateTimeOriginal] ?? tiff?[kCGImagePropertyTIFFDateTime]) as? String {
                date = exifFormatter.date(from: text)
            }
        }
        if date == nil {
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            date = values?.creationDate ?? values?.contentModificationDate
        }
        return PhotoMeta(date: date)
    }
}
