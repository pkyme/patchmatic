import Foundation

/// A user-chosen folder (typically in iCloud Drive) that holds the shared library.
/// The Mac writes to it; the iPad reads from it.
enum SyncFolder {
    static let documentName = "library.patchmatic"

    static func documentURL(in folder: URL) -> URL {
        folder.appendingPathComponent(documentName)
    }

    static func imagesDir(in folder: URL) -> URL {
        folder.appendingPathComponent("images", isDirectory: true)
    }

    static func audioDir(in folder: URL) -> URL {
        folder.appendingPathComponent("audio", isDirectory: true)
    }

    /// Resolves the stored folder bookmark. On iOS this also starts security-scoped
    /// access, which is held for the lifetime of the app.
    static func storedFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: AppSettings.syncFolderBookmark) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else { return nil }
        #if os(iOS)
        // Returns false for URLs that need no security scope; a denied read surfaces later as a load error
        _ = url.startAccessingSecurityScopedResource()
        #endif
        if isStale { try? store(url) }
        return url
    }

    static func store(_ folder: URL) throws {
        let data = try folder.bookmarkData()
        UserDefaults.standard.set(data, forKey: AppSettings.syncFolderBookmark)
    }

    static var hasStoredFolder: Bool {
        UserDefaults.standard.data(forKey: AppSettings.syncFolderBookmark) != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: AppSettings.syncFolderBookmark)
    }

    /// True if the file is present locally or as an iCloud placeholder awaiting download.
    static func fileExists(at url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) || fm.fileExists(atPath: placeholderURL(for: url).path)
    }

    /// True if the file's contents can be read without waiting for an iCloud download.
    static func isDownloaded(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true else { return true }
        return values.ubiquitousItemDownloadingStatus != .notDownloaded
    }

    private static func placeholderURL(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
    }
}
