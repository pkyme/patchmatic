import Foundation
import ImageIO
import os

enum ImageStore {
    private static let defaultImagesDir = AppDirectories.created(AppDirectories.images)

    /// Read from background thumbnail warmup as well as the main thread
    private static let _imagesDir = OSAllocatedUnfairLock<URL?>(initialState: nil)

    /// When true, generated thumbnails are kept in memory only and never written to disk.
    static var isReadOnly: Bool {
        get { _isReadOnly.withLock { $0 } }
        set { _isReadOnly.withLock { $0 = newValue } }
    }
    private static let _isReadOnly = OSAllocatedUnfairLock(initialState: false)

    static var imagesDir: URL {
        _imagesDir.withLock { $0 } ?? defaultImagesDir
    }

    static func setImagesDirectory(_ url: URL) {
        _imagesDir.withLock { $0 = url }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        cache.removeAllObjects()
        masterCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        thumbnailKeysByFile.withLock { $0.removeAll() }
        ImageStoreChanges.shared.recordChange()
    }

    static func invalidateCache(for filename: String) {
        cache.removeObject(forKey: filename as NSString)
        masterCache.removeObject(forKey: filename as NSString)
        if let keys = thumbnailKeysByFile.withLock({ $0.removeValue(forKey: filename) }) {
            for key in keys { thumbnailCache.removeObject(forKey: key as NSString) }
        }
        ImageStoreChanges.shared.recordChange()
    }

    // NSCache is thread-safe
    nonisolated(unsafe) private static let cache = NSCache<NSString, PlatformImage>()

    /// Saves `image` as JPEG, returning false if it couldn't be encoded or written.
    @discardableResult
    static func save(_ image: PlatformImage, filename: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return false }
        let url = imagesDir.appendingPathComponent(filename)
        // A filename can be reused for a new image, e.g. a module's replaced background
        invalidateCache(for: filename)
        guard CoordinatedFiles.write(data, to: url) else { return false }
        cache.setObject(image, forKey: filename as NSString)
        generateMasterThumbnail(from: url, filename: filename)
        return true
    }

    /// Copies an image file, downloading it from iCloud first if needed.
    @discardableResult
    static func copy(_ filename: String, to newFilename: String) -> Bool {
        CoordinatedFiles.copy(from: imagesDir.appendingPathComponent(filename),
                              to: imagesDir.appendingPathComponent(newFilename))
    }

    static func load(_ filename: String) -> PlatformImage? {
        if let cached = cache.object(forKey: filename as NSString) {
            return cached
        }
        let url = imagesDir.appendingPathComponent(filename)
        guard SyncFolder.isDownloaded(url) else {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return nil
        }
        guard let image = PlatformImage.fromURL(url) else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }

    static func delete(_ filename: String) {
        invalidateCache(for: filename)
        let url = imagesDir.appendingPathComponent(filename)
        CoordinatedFiles.delete(at: url)
        CoordinatedFiles.delete(at: thumbURL(for: filename))
    }

    static func exists(_ filename: String) -> Bool {
        SyncFolder.fileExists(at: imagesDir.appendingPathComponent(filename))
    }

    static func makeFilename(for moduleID: UUID) -> String {
        "\(moduleID.uuidString).jpg"
    }

    static func makeScreenFilename(patchID: UUID, placedModuleID: UUID, controlID: UUID) -> String {
        "screen-\(patchID.uuidString)-\(placedModuleID.uuidString)-\(controlID.uuidString)-\(UUID().uuidString).jpg"
    }

    // MARK: - Thumbnails

    /// Fixed master size: covers 300pt at 3× (ProMotion XDR). Single file per module, generated once.
    private static let masterMaxPx: CGFloat = 900

    private final class CGImageBox { let image: CGImage; init(_ image: CGImage) { self.image = image } }

    /// In-memory cache of master CGImages keyed by filename.
    // NSCache is thread-safe
    nonisolated(unsafe) private static let masterCache = NSCache<NSString, CGImageBox>()

    /// Per display-size cache keyed by "\(filename)-\(Int(maxHeight))".
    // NSCache is thread-safe
    nonisolated(unsafe) private static let thumbnailCache = NSCache<NSString, PlatformImage>()
    /// Tracks thumbnail cache keys per filename for targeted invalidation.
    /// Accessed from background thumbnail loading as well as the main thread
    private static let thumbnailKeysByFile = OSAllocatedUnfairLock<[String: Set<String>]>(initialState: [:])

    private static func thumbURL(for filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        return imagesDir.appendingPathComponent("\(base)_thumb.jpg")
    }

    /// Generates and persists the master thumbnail from a full-size image URL.
    private static func generateMasterThumbnail(from url: URL, filename: String) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: masterMaxPx,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
        masterCache.setObject(CGImageBox(cgImage), forKey: filename as NSString)
        guard !isReadOnly else { return }
        let dest = thumbURL(for: filename)
        guard let imgDest = CGImageDestinationCreateWithURL(dest as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(imgDest, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(imgDest)
    }

    /// Returns (or lazily generates) the master CGImage for a filename.
    private static func masterCGImage(for filename: String) -> CGImage? {
        if let cached = masterCache.object(forKey: filename as NSString) {
            return cached.image
        }
        let dest = thumbURL(for: filename)
        if SyncFolder.isDownloaded(dest),
           let source = CGImageSourceCreateWithURL(dest as CFURL, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            masterCache.setObject(CGImageBox(cgImage), forKey: filename as NSString)
            return cgImage
        }
        // Thumb file doesn't exist yet — generate it from the original.
        let url = imagesDir.appendingPathComponent(filename)
        if !SyncFolder.isDownloaded(url) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return nil
        }
        generateMasterThumbnail(from: url, filename: filename)
        return masterCache.object(forKey: filename as NSString)?.image
    }

    /// Downsamples a CGImage to fit within maxHeight, using high-quality Core Graphics interpolation.
    private static func downsample(_ source: CGImage, maxHeight: CGFloat) -> CGImage? {
        let srcW = CGFloat(source.width)
        let srcH = CGFloat(source.height)
        let scale = min(1.0, maxHeight / srcH)
        let dstW = max(1, Int((srcW * scale).rounded()))
        let dstH = max(1, Int((srcH * scale).rounded()))
        guard let ctx = CGContext(
            data: nil, width: dstW, height: dstH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))
        return ctx.makeImage()
    }

    /// The thumbnail if it is already in memory, without touching the disk.
    static func cachedThumbnail(_ filename: String, maxHeight: CGFloat) -> PlatformImage? {
        thumbnailCache.object(forKey: "\(filename)-\(Int(maxHeight))" as NSString)
    }

    /// Loads or generates a thumbnail. Safe to call off the main thread.
    static func loadThumbnail(_ filename: String, maxHeight: CGFloat) -> PlatformImage? {
        let cacheKey = "\(filename)-\(Int(maxHeight))" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }
        guard let master = masterCGImage(for: filename),
              let cgImage = downsample(master, maxHeight: maxHeight) else { return nil }
        #if canImport(AppKit)
        let image = PlatformImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        let image = PlatformImage(cgImage: cgImage)
        #endif
        thumbnailCache.setObject(image, forKey: cacheKey)
        let key = cacheKey as String
        thumbnailKeysByFile.withLock { _ = $0[filename, default: []].insert(key) }
        return image
    }

    /// Preloads master thumbnails for all given filenames on a background thread.
    static func warmupThumbnails(filenames: [String]) {
        DispatchQueue.global(qos: .utility).async {
            for filename in filenames {
                _ = masterCGImage(for: filename)
            }
        }
    }
}

/// Lets views reload images when cached image files change. `version` increases whenever
/// a file's cache entries are invalidated or the images directory changes.
@Observable
final class ImageStoreChanges: @unchecked Sendable {
    static let shared = ImageStoreChanges()
    /// Only changed on the main thread
    private(set) var version = 0

    func recordChange() {
        if Thread.isMainThread {
            version += 1
        } else {
            DispatchQueue.main.async { self.version += 1 }
        }
    }
}
