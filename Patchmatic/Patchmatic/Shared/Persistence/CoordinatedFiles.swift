import Foundation
import os

private let log = Logger(subsystem: "com.patchmatic.app", category: "Files")

/// File operations under NSFileCoordinator, so they cooperate with iCloud Drive and
/// other processes using the sync folder. Failures are logged and reported to the caller.
enum CoordinatedFiles {
    @discardableResult
    static func write(_ data: Data, to url: URL) -> Bool {
        perform("write", url) { error, failure in
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: error) { target in
                do { try data.write(to: target, options: .atomic) } catch { failure = error }
            }
        }
    }

    /// Deletes the file if it exists. A missing file is not an error.
    @discardableResult
    static func delete(at url: URL) -> Bool {
        perform("delete", url) { error, failure in
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: error) { target in
                guard FileManager.default.fileExists(atPath: target.path) else { return }
                do { try FileManager.default.removeItem(at: target) } catch { failure = error }
            }
        }
    }

    /// Copies a file, replacing any existing destination. Reading under coordination
    /// downloads an iCloud source first.
    @discardableResult
    static func copy(from source: URL, to destination: URL) -> Bool {
        perform("copy", destination) { error, failure in
            NSFileCoordinator().coordinate(readingItemAt: source, options: [], writingItemAt: destination,
                                           options: .forReplacing, error: error) { readURL, writeURL in
                do {
                    if FileManager.default.fileExists(atPath: writeURL.path) {
                        try FileManager.default.removeItem(at: writeURL)
                    }
                    try FileManager.default.copyItem(at: readURL, to: writeURL)
                } catch { failure = error }
            }
        }
    }

    private static func perform(_ operation: String, _ url: URL,
                                _ body: (NSErrorPointer, inout Error?) -> Void) -> Bool {
        var coordinationError: NSError?
        var failure: Error?
        body(&coordinationError, &failure)
        if let error = coordinationError ?? failure {
            log.error("Couldn't \(operation, privacy: .public) \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        return true
    }
}
