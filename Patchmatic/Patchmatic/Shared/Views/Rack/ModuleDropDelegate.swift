import SwiftUI
import UniformTypeIdentifiers

struct ModuleDropDelegate: DropDelegate {
    let rackVM: RackViewModel
    let zoom: CGFloat
    let panOffset: CGSize

    private func worldPoint(from location: CGPoint) -> CGPoint {
        CGPoint(
            x: (location.x - panOffset.width) / zoom,
            y: (location.y - panOffset.height) / zoom
        )
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard rackVM.newModuleDragDefinitionID != nil else {
            return DropProposal(operation: .move)
        }
        rackVM.newModuleDragScreenPoint = info.location
        rackVM.updateNewModuleDrag(point: worldPoint(from: info.location))
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        rackVM.updateNewModuleDrag(point: worldPoint(from: info.location))
        rackVM.endNewModuleDrag()
        return true
    }

    func dropEntered(info: DropInfo) {
        // Recover the definition ID from the payload. This handles two cases:
        // 1. Re-entering the canvas after dropExited cleared the screen point
        // 2. onDragStart not firing on subsequent drags (SwiftUI onDrag stuck-state bug)
        guard let provider = info.itemProviders(for: [.text]).first else { return }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let uuidStr = item as? String,
                  let uuid = UUID(uuidString: uuidStr) else { return }
            DispatchQueue.main.async {
                rackVM.beginNewModuleDrag(definitionID: uuid)
            }
        }
    }

    func dropExited(info: DropInfo) {
        // Hide the ghost and drop indicator without clearing the definition ID,
        // so re-entering the canvas during the same drag session still works.
        rackVM.newModuleDragScreenPoint = nil
        rackVM.dropIndicator = nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        true
    }
}
