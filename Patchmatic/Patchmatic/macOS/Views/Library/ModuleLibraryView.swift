import SwiftUI
import UniformTypeIdentifiers

struct ModuleLibraryView: View {
    @Bindable var editorVM: ModuleEditorViewModel
    @Bindable var rackVM: RackViewModel

    @State private var showingDetectControlsAlert = false

    var body: some View {
        ModuleGridView(
            modules: editorVM.document.moduleLibrary,
            selectedModuleIDs: Binding(
                get: { editorVM.selectedModuleIDs },
                set: { editorVM.requestSelectModules($0) }
            ),
            contextMenu: { module in
                AnyView(Group {
                    if let rack = rackVM.rack {
                        ForEach(rack.cases) { rackCase in
                            let matchingRows = rackCase.rows.enumerated().filter { $0.element.size == module.format }
                            if !matchingRows.isEmpty {
                                Menu("Add to \(rackCase.name)") {
                                    ForEach(matchingRows, id: \.offset) { rowIndex, row in
                                        Button("Row \(rowIndex + 1) (\(row.size.rawValue))") {
                                            rackVM.addModuleToRack(module, case: rackCase, row: rowIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Button("Rename") {
                        editorVM.requestSelectModule(module.id)
                        editorVM.renameModuleRequested = true
                    }
                    Button("Duplicate") {
                        editorVM.duplicateModule(module)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        editorVM.requestDeleteModule(module)
                    }
                })
            }
        )
        .focusable()
        .focusEffectDisabled()
        .onChange(of: editorVM.selectedModuleIDs) {
            editorVM.loadBackgroundImage()
        }
        .onDeleteCommand {
            editorVM.requestDeleteSelectedModules()
        }
        .alert("Module In Use", isPresented: Binding(
            get: { editorVM.pendingDeleteModuleIDs != nil },
            set: { if !$0 { editorVM.pendingDeleteModuleIDs = nil } }
        )) {
            Button("Delete Anyway", role: .destructive) { editorVM.confirmDeleteModules() }
            Button("Cancel", role: .cancel) { editorVM.pendingDeleteModuleIDs = nil }
        } message: {
            let count = editorVM.pendingDeleteModuleIDs?.count ?? 0
            Text(count == 1
                 ? "This module is placed in one or more racks. Deleting it will remove all placements."
                 : "Some of these modules are placed in racks. Deleting will remove all placements.")
        }
        .onDrop(of: [.image], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .fileImporter(
            isPresented: Binding(get: { editorVM.showingImageImporter }, set: { editorVM.showingImageImporter = $0 }),
            allowedContentTypes: [.png, .jpeg, .tiff, .heic],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let image = PlatformImage.fromURL(url) else { return }
            editorVM.importImage(image)
            showingDetectControlsAlert = true
        }
        .alert("Detect Controls", isPresented: $showingDetectControlsAlert) {
            Button("Detect") { editorVM.analyseImage() }
            Button("Skip", role: .cancel) { }
        } message: {
            Text("Would you like to automatically detect controls in this image?")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ControlGroup {
                    Button { editorVM.showingImageImporter = true } label: {
                        Image(systemName: "camera")
                    }
                    .help("New Module from Image")
                    Button(action: editorVM.addModule) {
                        Image(systemName: "plus")
                    }
                    .help("New Blank Module")
                }
            }
        }
    }

    // MARK: - Image Import

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data, let image = PlatformImage.fromData(data) else { return }
            DispatchQueue.main.async {
                editorVM.importImage(image)
                showingDetectControlsAlert = true
            }
        }
    }
}
