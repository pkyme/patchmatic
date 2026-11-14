import Foundation

@MainActor
@Observable
final class DocumentManager {
    var document: PatchmaticDocument
    var fileURL: URL?

    private var filePresenter: DocumentFilePresenter?
    private var reloadWorkItem: DispatchWorkItem?

    // MARK: - Sync folder state

    /// User-chosen folder (typically in iCloud Drive) holding the shared library, if any.
    private(set) var syncFolderURL: URL?
    /// Incremented after each reload of the document from the sync folder.
    private(set) var documentGeneration = 0
    /// Incremented when files in the sync folder's images directory change or finish downloading.
    private(set) var imagesGeneration = 0
    private var imagesPresenter: DocumentFilePresenter?
    private var imagesWorkItem: DispatchWorkItem?
    /// Contents of the last coordinated save or sync folder load, used to skip writes and reloads when nothing has changed.
    private var lastSavedData: Data?
    /// Storage problem to show the user; cleared once the alert is dismissed.
    var storageAlert: StorageAlert?
    private var isSaveFailing = false
    /// Set when an unreadable library couldn't be moved aside, so it is never overwritten.
    private var isAutosaveDisabled = false

    struct StorageAlert: Equatable {
        var title: String
        var message: String

        static func syncFolder(_ message: String) -> StorageAlert {
            StorageAlert(title: "Sync Folder Unavailable", message: message)
        }
    }

    /// Outcome of reading the autosaved or synced library.
    enum LoadResult {
        case loaded
        case missing
        case failed(Error)
    }

    /// Adjusts a copy of the document before it is written, e.g. to replace items
    /// with uncommitted edits by their last committed state.
    typealias SaveAdjustment = (PatchmaticDocument) -> Void

    #if os(iOS)
    /// The iPad only reads the shared library; it never writes the document or images.
    static let isReadOnly = true
    #else
    static let isReadOnly = false
    #endif

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    init(document: PatchmaticDocument = PatchmaticDocument()) {
        self.document = document
        ImageStore.isReadOnly = Self.isReadOnly
    }

    // MARK: - File presenters

    func stopMonitoring() {
        filePresenter?.invalidate()
        filePresenter = nil
        imagesPresenter?.invalidate()
        imagesPresenter = nil
    }

    // MARK: - Auto-persistence

    static var localAutosaveURL: URL {
        _ = AppDirectories.created(AppDirectories.root)
        return AppDirectories.autosave
    }

    static var localImagesDir: URL { AppDirectories.images }
    static var localAudioDir: URL { AppDirectories.audio }

    /// Saves the document to the sync folder or Application Support.
    /// `adjusting` is applied to a copy of the document, never to the live one.
    func autosave(adjusting: SaveAdjustment? = nil) {
        guard !Self.isReadOnly, !isAutosaveDisabled else { return }
        storeSelection()
        do {
            let data = try encodedDocument(adjusting: adjusting)
            if let url = syncDocumentURL {
                try coordinatedWrite(data, to: url)
            } else {
                try writeLocal(data, to: fileURL ?? Self.localAutosaveURL)
            }
            isSaveFailing = false
        } catch {
            // Warn once per failure streak rather than on every timed save
            if !isSaveFailing {
                storageAlert = syncDocumentURL != nil
                    ? .syncFolder("Patchmatic couldn't save to your sync folder: \(error.localizedDescription) Your changes will be saved there once the folder is available again.")
                    : StorageAlert(title: "Couldn't Save Library", message: "Patchmatic couldn't save your library: \(error.localizedDescription)")
            }
            isSaveFailing = true
        }
    }

    func loadAutosaved() -> LoadResult {
        do {
            if let url = syncDocumentURL {
                guard SyncFolder.fileExists(at: url) else { return .missing }
                try coordinatedLoad(from: url)
            } else {
                let url = Self.localAutosaveURL
                guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
                try load(from: url)
            }
            return .loaded
        } catch {
            return .failed(error)
        }
    }

    /// Moves an unreadable local library aside so autosave can't overwrite it,
    /// and returns the backup location.
    @discardableResult
    func quarantineLocalAutosave(error: Error) -> URL? {
        let source = Self.localAutosaveURL
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let backup = source.deletingLastPathComponent()
            .appendingPathComponent("autosave.corrupt-\(formatter.string(from: Date())).patchmatic")
        let detail = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        do {
            try FileManager.default.moveItem(at: source, to: backup)
            storageAlert = StorageAlert(
                title: "Couldn't Open Library",
                message: "Patchmatic couldn't read your library and has started with an empty one. The unreadable file was kept at \(backup.path).\n\n\(detail)"
            )
            return backup
        } catch {
            storageAlert = StorageAlert(
                title: "Couldn't Open Library",
                message: "Patchmatic couldn't read your library at \(source.path) or move it aside, so saving is disabled for this session.\n\n\(detail)"
            )
            isAutosaveDisabled = true
            return nil
        }
    }

    // MARK: - Encoding

    private func encodedDocument(adjusting: SaveAdjustment?) throws -> Data {
        guard !isAutosaveDisabled else { throw DocumentError.autosaveDisabled }
        guard let adjusting else { return try encoder.encode(document) }
        let copy = try decoder.decode(PatchmaticDocument.self, from: encoder.encode(document))
        adjusting(copy)
        return try encoder.encode(copy)
    }

    // MARK: - Coordinated I/O

    /// Writes `data` under file coordination and records it as the current file contents.
    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        guard data != lastSavedData || url != fileURL else { return }
        try Self.coordinatedWriteData(data, to: url, presenter: filePresenter)
        preserveConflicts(at: url)
        lastSavedData = data
        fileURL = url
    }

    private static func coordinatedWriteData(_ data: Data, to url: URL, presenter: NSFilePresenter?) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: presenter).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writingURL in
            do { try data.write(to: writingURL, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    private func writeLocal(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        fileURL = url
    }

    /// Reads a file under file coordination, which downloads it from iCloud first if needed.
    nonisolated private static func coordinatedRead(at url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(DocumentError.noFileURL)
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readingURL in
            result = Result { try Data(contentsOf: readingURL) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    private func coordinatedLoad(from url: URL) throws {
        let data = try Self.coordinatedRead(at: url)
        let loaded = try decoder.decode(PatchmaticDocument.self, from: data)
        loaded.removeMissingPatchesFromSets()
        Self.restoreSelection(in: loaded)
        document = loaded
        fileURL = url
        preserveConflicts(at: url)
        warmupThumbnails()
    }

    /// Copies any iCloud conflict versions of the library beside it, then resolves them,
    /// so edits made on another Mac are never silently discarded.
    private func preserveConflicts(at url: URL) {
        guard let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !versions.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let base = url.deletingPathExtension().lastPathComponent
        var saved: [String] = []
        for (index, version) in versions.enumerated() {
            let stamp = formatter.string(from: version.modificationDate ?? Date())
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("\(base).conflict-\(stamp)-\(index + 1).\(url.pathExtension)")
            do {
                try FileManager.default.copyItem(at: version.url, to: backup)
                saved.append(backup.lastPathComponent)
                version.isResolved = true
            } catch {
                // Left unresolved so it can be preserved on the next save
            }
        }
        if saved.count == versions.count {
            try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        }
        if !saved.isEmpty {
            storageAlert = .syncFolder("Another device saved a different version of your library at the same time. Patchmatic kept this Mac's version and saved the other as \(saved.joined(separator: ", ")) in your sync folder.")
        }
    }

    // MARK: - Sync folder

    var syncDocumentURL: URL? {
        syncFolderURL.map(SyncFolder.documentURL(in:))
    }

    /// Points document, image and audio storage at the sync folder.
    func useSyncFolder(_ folder: URL) {
        syncFolderURL = folder
        ImageStore.setImagesDirectory(SyncFolder.imagesDir(in: folder))
        AudioStore.setAudioDirectory(SyncFolder.audioDir(in: folder))
    }

    /// Restores the previously chosen sync folder, if one is stored and still reachable.
    @discardableResult
    func restoreSyncFolder() -> Bool {
        guard let folder = SyncFolder.storedFolder() else { return false }
        useSyncFolder(folder)
        return true
    }

    /// Switches storage back to Application Support without clearing the stored folder.
    func useLocalStorage() {
        syncFolderURL = nil
        fileURL = nil
        ImageStore.setImagesDirectory(Self.localImagesDir)
        AudioStore.setAudioDirectory(Self.localAudioDir)
    }

    #if os(iOS)
    /// Reads the library from the sync folder off the main thread.
    @MainActor
    func loadFromSyncFolder() async throws {
        guard let url = syncDocumentURL else { throw DocumentError.noFileURL }
        guard SyncFolder.fileExists(at: url) else { throw DocumentError.noLibraryInFolder }
        let data = try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedRead(at: url)
        }.value
        guard data != lastSavedData || url != fileURL else { return }
        let loaded = try decoder.decode(PatchmaticDocument.self, from: data)
        loaded.removeMissingPatchesFromSets()
        document = loaded
        lastSavedData = data
        fileURL = url
        documentGeneration += 1
        warmupThumbnails()
        downloadReferencedFiles()
    }

    /// Watches the sync folder's document and images for changes made on other devices.
    func startMonitoringSyncFolder() {
        guard let folder = syncFolderURL, let docURL = syncDocumentURL else { return }
        stopMonitoring()

        let presenter = DocumentFilePresenter(url: docURL)
        presenter.onDidChange = { [weak self] in
            DispatchQueue.main.async { self?.scheduleSyncReload() }
        }
        filePresenter = presenter

        let images = DocumentFilePresenter(url: SyncFolder.imagesDir(in: folder))
        images.onSubitemDidChange = { [weak self] url in
            DispatchQueue.main.async { self?.handleSyncImageChange(url) }
        }
        imagesPresenter = images
    }

    /// Reloads the document after a short delay, coalescing bursts of change notifications.
    func scheduleSyncReload() {
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in try? await self?.loadFromSyncFolder() }
        }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func handleSyncImageChange(_ url: URL) {
        ImageStore.invalidateCache(for: url.lastPathComponent)
        imagesWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.imagesGeneration += 1 }
        imagesWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Requests download of every image and audio file the document references,
    /// so the library remains usable offline.
    private func downloadReferencedFiles() {
        var images = document.moduleLibrary.compactMap(\.imageFileName)
        var audio: [String] = []
        for patch in document.patches {
            images += patch.screenImages.flatMap(\.imageFilenames)
            if let filename = patch.audioPreviewFilename { audio.append(filename) }
        }
        let imageFiles = images, audioFiles = audio
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            for filename in imageFiles {
                try? fm.startDownloadingUbiquitousItem(at: ImageStore.imagesDir.appendingPathComponent(filename))
            }
            for filename in audioFiles {
                try? fm.startDownloadingUbiquitousItem(at: AudioStore.url(for: filename))
            }
        }
    }
    #endif

    #if os(macOS)
    /// Copies the library, images and audio into `folder` and switches storage to it.
    /// An existing library in the folder is replaced. Storage is only switched once
    /// every write has succeeded, so a failure leaves the current location in use.
    func moveLibrary(to folder: URL, adjusting: SaveAdjustment? = nil) throws {
        try Self.copyMissingFiles(from: ImageStore.imagesDir, to: SyncFolder.imagesDir(in: folder))
        try Self.copyMissingFiles(from: AudioStore.audioDir, to: SyncFolder.audioDir(in: folder))
        let data = try encodedDocument(adjusting: adjusting)
        let docURL = SyncFolder.documentURL(in: folder)
        try Self.coordinatedWriteData(data, to: docURL, presenter: nil)
        try SyncFolder.store(folder)
        useSyncFolder(folder)
        lastSavedData = data
        fileURL = docURL
    }

    /// Copies the library, images and audio back to Application Support and stops using the sync folder.
    func moveLibraryToLocalStorage(adjusting: SaveAdjustment? = nil) throws {
        try Self.copyMissingFiles(from: ImageStore.imagesDir, to: Self.localImagesDir)
        try Self.copyMissingFiles(from: AudioStore.audioDir, to: Self.localAudioDir)
        let data = try encodedDocument(adjusting: adjusting)
        try data.write(to: Self.localAutosaveURL, options: .atomic)
        SyncFolder.clear()
        useLocalStorage()
        fileURL = Self.localAutosaveURL
    }

    private static func copyMissingFiles(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        guard source.standardizedFileURL != destination.standardizedFileURL else { return }
        let names = (try? fm.contentsOfDirectory(atPath: source.path)) ?? []
        for name in names where !name.hasPrefix(".") {
            let target = destination.appendingPathComponent(name)
            guard !fm.fileExists(atPath: target.path) else { continue }
            try fm.copyItem(at: source.appendingPathComponent(name), to: target)
        }
    }
    #endif

    // MARK: - Load

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let loaded = try decoder.decode(PatchmaticDocument.self, from: data)
        loaded.removeMissingPatchesFromSets()
        Self.restoreSelection(in: loaded)
        document = loaded
        fileURL = url
        warmupThumbnails()
    }

    // MARK: - Launch

    /// True when the app is hosting unit tests
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// An empty library that is never saved, so test runs don't touch the user's data.
    static func forTesting() -> DocumentManager {
        let manager = DocumentManager()
        manager.isAutosaveDisabled = true
        return manager
    }

    #if os(macOS)
    /// Loads the library at launch: from the sync folder if one is set and readable,
    /// otherwise from Application Support. A first launch gets sample data; an
    /// unreadable local library is moved aside and replaced with an empty one.
    static func loadAtLaunch() -> DocumentManager {
        let manager = DocumentManager()
        // An unreadable sync folder falls back to local storage so autosave can't overwrite it
        let localFallbackWarning = "Patchmatic couldn't read the library in your sync folder, so it's using the copy stored on this Mac. Changes made now won't reach your iPad. Check that iCloud Drive is available and relaunch, or choose File > Sync Folder."
        if manager.restoreSyncFolder() {
            if case .loaded = manager.loadAutosaved() {} else {
                manager.useLocalStorage()
                manager.storageAlert = .syncFolder(localFallbackWarning)
            }
        } else if SyncFolder.hasStoredFolder {
            manager.storageAlert = .syncFolder(localFallbackWarning)
        }
        if manager.syncFolderURL == nil {
            switch manager.loadAutosaved() {
            case .loaded:
                break
            case .missing:
                manager.document = SampleData.makeDocument()
            case .failed(let error):
                manager.quarantineLocalAutosave(error: error)
            }
        }
        manager.warmupThumbnails()
        return manager
    }
    #endif

    // MARK: - Selection

    /// Applies this Mac's stored selection. Libraries saved by older builds carry their
    /// own selection, which is kept when nothing is stored yet.
    private static func restoreSelection(in document: PatchmaticDocument) {
        let defaults = UserDefaults.standard
        document.applySelection(
            rackID: defaults.string(forKey: AppSettings.activeRackID).flatMap(UUID.init),
            patchID: defaults.string(forKey: AppSettings.activePatchID).flatMap(UUID.init),
            setID: defaults.string(forKey: AppSettings.activeSetID).flatMap(UUID.init)
        )
    }

    private func storeSelection() {
        let defaults = UserDefaults.standard
        defaults.set(document.activeRackID?.uuidString, forKey: AppSettings.activeRackID)
        defaults.set(document.activePatchID?.uuidString, forKey: AppSettings.activePatchID)
        defaults.set(document.activeSetID?.uuidString, forKey: AppSettings.activeSetID)
    }

    func warmupThumbnails() {
        let filenames = document.moduleLibrary.compactMap { $0.imageFileName }
        ImageStore.warmupThumbnails(filenames: filenames)
    }

    enum DocumentError: LocalizedError {
        case noFileURL
        case noLibraryInFolder
        case autosaveDisabled

        var errorDescription: String? {
            switch self {
            case .noFileURL:
                return "No file URL specified."
            case .noLibraryInFolder:
                return "This folder doesn't contain a Patchmatic library. On your Mac, choose File > Sync Folder and select the same folder."
            case .autosaveDisabled:
                return "Saving is disabled because the library on disk couldn't be read."
            }
        }
    }
}
