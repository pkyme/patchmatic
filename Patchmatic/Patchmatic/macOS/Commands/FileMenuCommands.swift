import SwiftUI

struct PrintCommands: View {
    @FocusedValue(\.printPatch) private var printPatch

    var body: some View {
        Button("Print Patch\u{2026}") { printPatch?() }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printPatch == nil)
    }
}

struct SyncFolderCommands: View {
    let documentManager: DocumentManager
    @FocusedValue(\.editorVM) private var editorVM
    @FocusedValue(\.rackVM) private var rackVM
    @FocusedValue(\.patchVM) private var patchVM

    private var committedState: DocumentManager.SaveAdjustment? {
        EditSession.committedState(of: [editorVM, rackVM, patchVM])
    }

    var body: some View {
        Button("Sync Folder\u{2026}") { chooseFolder() }
        Button("Stop Using Sync Folder") { stopSyncing() }
            .disabled(documentManager.syncFolderURL == nil)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Choose a folder in iCloud Drive to share your library with Patchmatic on iPad."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        if folder != documentManager.syncFolderURL,
           SyncFolder.fileExists(at: SyncFolder.documentURL(in: folder)) {
            let alert = NSAlert()
            alert.messageText = "Replace Library in Folder?"
            alert.informativeText = "This folder already contains a Patchmatic library. It will be replaced with the library on this Mac."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            try documentManager.moveLibrary(to: folder, adjusting: committedState)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func stopSyncing() {
        do {
            try documentManager.moveLibraryToLocalStorage(adjusting: committedState)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
