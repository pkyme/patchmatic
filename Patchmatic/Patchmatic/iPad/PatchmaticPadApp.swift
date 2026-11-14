import SwiftUI

@main
struct PatchmaticPadApp: App {
    @State private var documentManager = DocumentManager()

    var body: some Scene {
        WindowGroup {
            PadRootView(documentManager: documentManager)
        }
    }
}
