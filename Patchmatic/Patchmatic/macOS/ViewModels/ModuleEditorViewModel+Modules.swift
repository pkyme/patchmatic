import SwiftUI

extension ModuleEditorViewModel {
    // MARK: - Module CRUD

    func setModuleFormat(_ module: ModuleDefinition, to newFormat: RowSize) {
        guard newFormat != module.format else { return }
        prepareEdit()
        let scale = newFormat.heightMM / module.format.heightMM
        let newHP = Int((CGFloat(module.widthHP) * scale).rounded())
        module.format = newFormat
        module.widthHP = max(EurorackConstants.minModuleHP, min(EurorackConstants.maxModuleHP, newHP))
    }

    func setModuleWidthHP(_ module: ModuleDefinition, to widthHP: Int) {
        prepareEdit()
        module.widthHP = widthHP
    }

    func addModule() {
        let name = GeometryHelpers.uniqueName("New Module", among: document.moduleLibrary.map(\.name))
        let module = ModuleDefinition(name: name)
        document.moduleLibrary.append(module)
        selectedModuleIDs = [module.id]
    }

    func renameModule(_ module: ModuleDefinition, to newName: String) {
        let others = document.moduleLibrary.filter { $0.id != module.id }.map(\.name)
        module.name = GeometryHelpers.uniqueName(newName, among: others)
    }

    func requestDeleteModule(_ module: ModuleDefinition) {
        requestDeleteModules([module.id])
    }

    func requestDeleteSelectedModules() {
        requestDeleteModules(selectedModuleIDs)
    }

    func requestDeleteModules(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        if ids.contains(where: document.isModuleInUse) {
            pendingDeleteModuleIDs = ids
        } else {
            deleteModules(ids)
        }
    }

    func confirmDeleteModules() {
        guard let ids = pendingDeleteModuleIDs else { return }
        pendingDeleteModuleIDs = nil
        deleteModules(ids)
    }

    func deleteModules(_ ids: Set<UUID>) {
        // Uncommitted edits to a deleted module have nothing left to apply to
        if let data = editSession.snapshot,
           let edited = restoreFromSnapshot(data, as: ModuleDefinition.self),
           ids.contains(edited.id) {
            editSession.discardEditing()
        }
        for id in ids {
            if let module = document.moduleLibrary.first(where: { $0.id == id }) {
                if let filename = module.imageFileName {
                    deleteImageIfUnused(filename, excludingModuleID: module.id)
                }
                document.moduleLibrary.removeAll { $0.id == module.id }
                for rack in document.racks {
                    for rackCase in rack.cases {
                        rackCase.placedModules.removeAll { $0.moduleDefinitionID == module.id }
                    }
                }
                selectedModuleIDs.remove(module.id)
            }
        }
        if selectedModuleIDs.isEmpty {
            backgroundImage = nil
        }
    }

    func duplicateModule(_ module: ModuleDefinition) {
        let copyName = GeometryHelpers.uniqueName("\(module.name) Copy", among: document.moduleLibrary.map(\.name))
        let copy = ModuleDefinition(
            name: copyName,
            format: module.format,
            widthHP: module.widthHP,
            controls: module.controls.map { var c = $0; c.id = UUID(); return c },
            imageFileName: module.imageFileName
        )
        document.moduleLibrary.append(copy)
        selectedModuleIDs = [copy.id]
    }
    // MARK: - Image Import

    func importImage(_ image: PlatformImage) {
        let geometry = ImageAnalyzer.analyzeGeometry(image)
        let importName = GeometryHelpers.uniqueName("Imported Module", among: document.moduleLibrary.map(\.name))
        let module = ModuleDefinition(
            name: importName,
            format: geometry.suggestedFormat,
            widthHP: geometry.suggestedWidthHP,
            controls: []
        )
        let filename = ImageStore.makeFilename(for: module.id)
        if ImageStore.save(image, filename: filename) {
            module.imageFileName = filename
        }
        document.moduleLibrary.append(module)
        selectedModuleIDs = [module.id]
        backgroundImage = image
    }

    func setBackgroundImage(_ image: PlatformImage) {
        guard let module = selectedModule else { return }
        if let oldFilename = module.imageFileName {
            deleteImageIfUnused(oldFilename, excludingModuleID: module.id)
        }
        let filename = ImageStore.makeFilename(for: module.id)
        module.imageFileName = ImageStore.save(image, filename: filename) ? filename : nil
        backgroundImage = image
    }

    func deleteImageIfUnused(_ filename: String, excludingModuleID: UUID) {
        let stillUsed = document.moduleLibrary.contains { $0.id != excludingModuleID && $0.imageFileName == filename }
        if !stillUsed { ImageStore.delete(filename) }
    }
}
