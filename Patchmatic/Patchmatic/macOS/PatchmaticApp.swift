import SwiftUI

@main
struct PatchmaticApp: App {
    @State private var documentManager: DocumentManager
    @AppStorage(AppSettings.selectedMode) private var storedMode: String = AppMode.racks.rawValue
    private var currentMode: AppMode { AppMode(rawValue: storedMode) ?? .racks }

    init() {
        RackViewModel.sanitizeStoredCanvasState()

        NSWindow.allowsAutomaticWindowTabbing = false
        AskSiriMenuSuppressor.install()
        let manager = DocumentManager.isRunningTests ? .forTesting() : DocumentManager.loadAtLaunch()
        self._documentManager = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(documentManager: documentManager)
        }
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                SyncFolderCommands(documentManager: documentManager)
            }
            CommandGroup(replacing: .printItem) {
                PrintCommands()
            }

            // MARK: - View Menu
            CommandGroup(after: .toolbar) {
                ModeCommands(currentMode: currentMode)
                Divider()
                ZoomCommands(currentMode: currentMode)
                Divider()
                ViewToggleCommands(currentMode: currentMode)
                Divider()
                AppearanceCommands()
            }

            // MARK: - Help Menu
            CommandGroup(replacing: .help) {
                Button("Patchmatic Help") {
                    NSWorkspace.shared.open(URL(string: "https://pkyme.github.io/patchmatic/")!)
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            // MARK: - Mode Menus
            if currentMode == .modules {
                CommandMenu("Modules") { ModulesMenuCommands() }
            } else if currentMode == .racks {
                CommandMenu("Racks") { RacksMenuCommands() }
            } else if currentMode == .patches {
                CommandMenu("Patches") { PatchesMenuCommands() }
            } else {
                CommandMenu("Sets") { SetsMenuCommands() }
            }
        }
    }
}
