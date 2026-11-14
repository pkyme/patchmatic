import SwiftUI
import UniformTypeIdentifiers

// Screen image magnifier and image picking
extension RackView {
    func showMagnifier(for moduleID: UUID, controlID: UUID) {
        guard showCables else { return }
        guard let rack = rackVM.rack else { return }

        // Find the placed module and control
        var placedModule: (placed: PlacedModule, definition: ModuleDefinition, case: Case)?
        for rackCase in rack.cases {
            if let placed = rackCase.placedModules.first(where: { $0.id == moduleID }),
               let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID),
               definition.controls.contains(where: { $0.id == controlID && $0.kind == .screen }) {
                placedModule = (placed, definition, rackCase)
                break
            }
        }

        guard let (placed, definition, _) = placedModule,
              let control = definition.controls.first(where: { $0.id == controlID }),
              let screenImage = patchVM.activePatch?.screenImage(forModule: moduleID, control: controlID),
              let activeFile = screenImage.activeFilename,
              let image = ImageStore.load(activeFile) else {
            magnifiedScreen = nil
            magnifierInfo = nil
            return
        }

        let origin = rackVM.moduleOrigin(for: placed)
        let size = rackVM.moduleSize(for: placed) ?? .zero
        let worldRect = control.screenRect(in: size).offsetBy(dx: origin.x, dy: origin.y)
        let vpRect = CGRect(
            x: worldRect.minX * currentZoom + panOffset.width,
            y: worldRect.minY * currentZoom + panOffset.height,
            width: worldRect.width * currentZoom,
            height: worldRect.height * currentZoom
        )

        magnifiedScreen = (moduleID, controlID)
        let hasImages = !screenImage.imageFilenames.isEmpty
        let canCycle = screenImage.imageFilenames.count > 1
        withAnimation(.spring(duration: 0.18)) {
            magnifierInfo = ScreenMagnifierInfo(
                image: image,
                controlViewportRect: vpRect,
                moduleID: moduleID,
                controlID: controlID,
                hasImages: hasImages,
                canCycle: canCycle
            )
        }
    }

    func screenControlForModule(_ moduleID: UUID, controlID: UUID) -> Control? {
        guard let rack = rackVM.rack else { return nil }
        for rackCase in rack.cases {
            if let placed = rackCase.placedModules.first(where: { $0.id == moduleID }),
               let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID) {
                return definition.controls.first { $0.id == controlID && $0.kind == .screen }
            }
        }
        return nil
    }

    func openScreenImagePicker(moduleID: UUID, controlID: UUID) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK,
                  let url = panel.url,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let image = PlatformImage.fromURL(url) else { return }
            let control = screenControlForModule(moduleID, controlID: controlID)
            let aspectRatio = control.map { $0.screenWidth / $0.screenHeight } ?? 1.5
            DispatchQueue.main.async {
                screenCropRequest = ScreenCropRequest(
                    moduleID: moduleID,
                    controlID: controlID,
                    sourceImage: image,
                    aspectRatio: aspectRatio
                )
            }
        }
        #endif
    }
}
