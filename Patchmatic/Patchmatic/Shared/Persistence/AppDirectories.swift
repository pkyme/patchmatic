import Foundation

/// Local storage locations in Application Support, used when no sync folder is set.
enum AppDirectories {
    /// ~/Library/Application Support/Patchmatic
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Patchmatic", isDirectory: true)
    }

    static var images: URL { root.appendingPathComponent("images", isDirectory: true) }
    static var audio: URL { root.appendingPathComponent("audio", isDirectory: true) }
    static var autosave: URL { root.appendingPathComponent("autosave.patchmatic") }

    /// `url`, after creating it as a directory if needed.
    static func created(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
