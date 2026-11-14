import SwiftUI
import UniformTypeIdentifiers

/// iPad entry view: connects to the sync folder, loads the library and keeps it current.
struct PadRootView: View {
    let documentManager: DocumentManager

    private enum LoadState {
        case needsFolder
        case loading
        case loaded
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @State private var showingFolderPicker = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.appearanceMode) private var appearanceMode: String = "system"

    var body: some View {
        Group {
            switch state {
            case .needsFolder:
                ContentUnavailableView {
                    Label("Choose Your Library", systemImage: "folder")
                } description: {
                    Text("Select the iCloud Drive folder chosen in Patchmatic on your Mac (File > Sync Folder).")
                } actions: {
                    Button("Choose Folder") { showingFolderPicker = true }
                        .buttonStyle(.borderedProminent)
                }
            case .loading:
                ProgressView("Loading library\u{2026}")
            case .loaded:
                PadPatchSetsView(documentManager: documentManager) {
                    showingFolderPicker = true
                }
                .id(documentManager.documentGeneration)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                    Button("Choose Another Folder") { showingFolderPicker = true }
                }
            }
        }
        .preferredColorScheme(appearanceMode == "light" ? .light : appearanceMode == "dark" ? .dark : nil)
        .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder]) { result in
            guard case .success(let folder) = result else { return }
            Task { await connect(to: folder) }
        }
        .task {
            if documentManager.restoreSyncFolder() {
                await load()
            } else {
                state = .needsFolder
            }
        }
        // File presenters are removed while in the background, as iOS requires; changes
        // made meanwhile are picked up by the reload on returning to the foreground.
        .onChange(of: scenePhase) { _, phase in
            guard case .loaded = state else { return }
            switch phase {
            case .active:
                documentManager.startMonitoringSyncFolder()
                documentManager.scheduleSyncReload()
            case .background:
                documentManager.stopMonitoring()
            default:
                break
            }
        }
    }

    private func connect(to folder: URL) async {
        guard folder.startAccessingSecurityScopedResource() else {
            state = .failed("Patchmatic couldn't access that folder.")
            return
        }
        do {
            try SyncFolder.store(folder)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        documentManager.useSyncFolder(folder)
        await load()
    }

    private func load() async {
        state = .loading
        do {
            try await documentManager.loadFromSyncFolder()
            documentManager.startMonitoringSyncFolder()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
