import SwiftUI
import AppKit

/// Context menus for the rack canvas, shown from the right-click event monitor.
@MainActor
enum RackContextMenus {
    static func showCableContextMenu(patchVM: PatchViewModel, at event: NSEvent, in view: NSView, isDarkMode: Bool, worldPoint: CGPoint) {
        let handler = CableMenuHandler(patchVM: patchVM, worldPoint: worldPoint)
        let menu = NSMenu()
        objc_setAssociatedObject(menu, &CableMenuHandler.associatedKey, handler, .OBJC_ASSOCIATION_RETAIN)

        let colorItem = NSMenuItem(title: "Change Color", action: nil, keyEquivalent: "")
        let colorSub = NSMenu()
        let palette = isDarkMode ? CableRenderer.darkModePalette : CableRenderer.lightModePalette
        let grid = CableColorGrid(palette: palette) { index in
            patchVM.setSelectedCableColor(paletteIndex: index)
            menu.cancelTracking()
        }
        let hostingView = NSHostingView(rootView: grid)
        hostingView.frame.size = hostingView.fittingSize
        let gridItem = NSMenuItem()
        gridItem.view = hostingView
        colorSub.addItem(gridItem)
        colorItem.submenu = colorSub
        menu.addItem(colorItem)

        // Add Cable Pin (only when exactly one cable is selected)
        if patchVM.selectedCableIDs.count == 1 {
            let pinItem = NSMenuItem(title: "Add Cable Pin", action: #selector(CableMenuHandler.addCablePin), keyEquivalent: "")
            pinItem.target = handler
            menu.addItem(pinItem)
        }

        let count = patchVM.selectedCableIDs.count
        let copyItem = NSMenuItem(title: "Copy Selected Cables (\(count))", action: #selector(CableMenuHandler.copySelectedCables), keyEquivalent: "")
        copyItem.target = handler
        menu.addItem(copyItem)

        if patchVM.canPasteCables {
            let pasteItem = NSMenuItem(title: "Paste Cables", action: #selector(CableMenuHandler.pasteCables), keyEquivalent: "")
            pasteItem.target = handler
            menu.addItem(pasteItem)
        }

        let deleteItem = NSMenuItem(title: "Delete Selected Cables (\(count))", action: #selector(CableMenuHandler.deleteSelectedCables), keyEquivalent: "")
        deleteItem.target = handler
        menu.addItem(deleteItem)

        let location = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: location, in: view)
    }

    static func showPinContextMenu(patchVM: PatchViewModel, cableID: UUID, pinID: UUID, at event: NSEvent, in view: NSView) {
        let handler = PinMenuHandler(patchVM: patchVM, cableID: cableID, pinID: pinID)
        let menu = NSMenu()
        objc_setAssociatedObject(menu, &PinMenuHandler.associatedKey, handler, .OBJC_ASSOCIATION_RETAIN)

        let deleteItem = NSMenuItem(title: "Delete Cable Pin", action: #selector(PinMenuHandler.deletePin), keyEquivalent: "")
        deleteItem.target = handler
        menu.addItem(deleteItem)

        let location = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: location, in: view)
    }

    static func showModuleContextMenu(rackVM: RackViewModel, at event: NSEvent, in view: NSView) {
        let handler = ModuleMenuHandler(rackVM: rackVM)
        let menu = NSMenu()
        objc_setAssociatedObject(menu, &ModuleMenuHandler.associatedKey, handler, .OBJC_ASSOCIATION_RETAIN)

        let count = rackVM.selectedPlacedModuleIDs.count
        let title = count == 1 ? "Delete Module" : "Delete \(count) Modules"
        let deleteItem = NSMenuItem(title: title, action: #selector(ModuleMenuHandler.deleteSelectedModules), keyEquivalent: "")
        deleteItem.target = handler
        menu.addItem(deleteItem)

        let location = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: location, in: view)
    }
}

@MainActor
class CableMenuHandler: NSObject {
    /// Its address keys the associated object; the value is never read or written
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    let patchVM: PatchViewModel
    let worldPoint: CGPoint

    init(patchVM: PatchViewModel, worldPoint: CGPoint) {
        self.patchVM = patchVM
        self.worldPoint = worldPoint
    }

    @objc func deleteSelectedCables() {
        patchVM.deleteSelectedCables()
    }

    @objc func copySelectedCables() {
        patchVM.copySelectedCables()
    }

    @objc func pasteCables() {
        patchVM.pasteCables()
    }

    @objc func addCablePin() {
        guard let cableID = patchVM.selectedCableIDs.first,
              let cable = patchVM.activePatch?.cables.first(where: { $0.id == cableID })
        else { return }

        // Determine which segment the click is closest to, so the pin is inserted at the correct position
        let simulator = patchVM.cableSimulator
        let orderedPins = cable.orderedPins
        var bestSeg = orderedPins.count // default: append at end
        var bestDist = CGFloat.greatestFiniteMagnitude

        for seg in 0..<cable.segmentCount {
            let ropeID = cable.segmentRopeID(seg)
            guard let points = simulator.pointsForRope(id: ropeID) else { continue }
            let dist = GeometryHelpers.distanceToPolyline(point: worldPoint, polyline: points)
            if dist < bestDist {
                bestDist = dist
                bestSeg = seg
            }
        }

        let pin = CablePin(x: worldPoint.x, y: worldPoint.y, caseID: nil, sortIndex: bestSeg)
        patchVM.addCablePin(cableID: cableID, pin: pin)
    }
}

@MainActor
class PinMenuHandler: NSObject {
    /// Its address keys the associated object; the value is never read or written
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    let patchVM: PatchViewModel
    let cableID: UUID
    let pinID: UUID

    init(patchVM: PatchViewModel, cableID: UUID, pinID: UUID) {
        self.patchVM = patchVM
        self.cableID = cableID
        self.pinID = pinID
    }

    @objc func deletePin() {
        patchVM.deleteCablePin(cableID: cableID, pinID: pinID)
    }
}

@MainActor
class ModuleMenuHandler: NSObject {
    /// Its address keys the associated object; the value is never read or written
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    let rackVM: RackViewModel

    init(rackVM: RackViewModel) {
        self.rackVM = rackVM
    }

    @objc func deleteSelectedModules() {
        rackVM.deleteSelection()
    }
}
