import Foundation

// Detects changes made by other processes (e.g. iCloud sync) to a file, or to files inside a folder.
final class DocumentFilePresenter: NSObject, NSFilePresenter {
    var presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()

    var onDidChange: (() -> Void)?
    var onDidMove: ((URL) -> Void)?
    var onSubitemDidChange: ((URL) -> Void)?

    init(url: URL) {
        self.presentedItemURL = url
        super.init()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        NSFileCoordinator.addFilePresenter(self)
    }

    /// Unregisters the presenter. NSFileCoordinator retains registered presenters,
    /// so this must be called explicitly; releasing the presenter is not enough.
    func invalidate() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    func presentedItemDidChange() {
        onDidChange?()
    }

    func presentedSubitemDidChange(at url: URL) {
        onSubitemDidChange?(url)
    }

    func presentedItemDidMove(to newURL: URL) {
        presentedItemURL = newURL
        onDidMove?(newURL)
    }
}
