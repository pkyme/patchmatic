import Foundation
import os

enum AudioStore {
    private static let defaultAudioDir = AppDirectories.created(AppDirectories.audio)

    private static let _audioDir = OSAllocatedUnfairLock<URL?>(initialState: nil)

    static var audioDir: URL {
        _audioDir.withLock { $0 } ?? defaultAudioDir
    }

    static func setAudioDirectory(_ url: URL) {
        _audioDir.withLock { $0 = url }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Copies an audio file into the store, returning false if it couldn't be copied.
    @discardableResult
    static func save(from sourceURL: URL, as filename: String) -> Bool {
        CoordinatedFiles.copy(from: sourceURL, to: audioDir.appendingPathComponent(filename))
    }

    static func url(for filename: String) -> URL {
        audioDir.appendingPathComponent(filename)
    }

    /// The file's URL if it can be read now; otherwise starts an iCloud download and returns nil.
    static func playableURL(for filename: String) -> URL? {
        let url = url(for: filename)
        guard SyncFolder.isDownloaded(url) else {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return nil
        }
        return url
    }

    static func delete(_ filename: String) {
        CoordinatedFiles.delete(at: audioDir.appendingPathComponent(filename))
    }

    /// True if the file is present locally or as an iCloud placeholder awaiting download.
    static func exists(_ filename: String) -> Bool {
        SyncFolder.fileExists(at: audioDir.appendingPathComponent(filename))
    }

    /// A new unique filename, so replacing a patch's audio never overwrites the file
    /// that discard or undo would restore.
    static func makeFilename(patchID: UUID, ext: String) -> String {
        let safeExt = ext.isEmpty ? "m4a" : ext
        return "audio-\(patchID.uuidString)-\(UUID().uuidString).\(safeExt)"
    }
}
