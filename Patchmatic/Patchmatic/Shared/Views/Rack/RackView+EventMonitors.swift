import SwiftUI

#if os(macOS)
// AppKit event monitors for scroll-wheel zoom and right-click menus
extension RackView {
    /// Installs the scroll-wheel zoom and right-click menu monitors once
    func installEventMonitors() {
        guard eventMonitors.scrollMonitor == nil else { return }
        updateEventMonitorState()
        eventMonitors.scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [eventMonitors] event in
            guard let contentView = event.window?.contentView else { return event }
            let mouse = event.locationInWindow
            let flipped = CGPoint(x: mouse.x, y: contentView.bounds.height - mouse.y)
            guard eventMonitors.viewportFrame.contains(flipped) else { return event }
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
            guard abs(delta) > 0.001 else { return event }
            let factor = 1.0 + delta * 0.015
            let newZoom = RackViewModel.clampedZoom(currentZoom * factor)
            adjustPanForZoom(newZoom: newZoom)
            currentZoom = newZoom
            lastZoom = newZoom
            return event
        }
        eventMonitors.rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [self, eventMonitors] event in
            guard !eventMonitors.readOnly else { return event }
            guard let contentView = event.window?.contentView else { return event }
            let mouse = event.locationInWindow
            let flipped = CGPoint(x: mouse.x, y: contentView.bounds.height - mouse.y)
            guard eventMonitors.viewportFrame.contains(flipped) else { return event }

            let shiftHeld = event.modifierFlags.contains(.shift)

            let viewportPoint = CGPoint(
                x: flipped.x - eventMonitors.viewportFrame.minX,
                y: flipped.y - eventMonitors.viewportFrame.minY
            )
            let worldPoint = CGPoint(
                x: (viewportPoint.x - panOffset.width) / currentZoom,
                y: (viewportPoint.y - panOffset.height) / currentZoom
            )

            let isPatchMode = eventMonitors.showCables
            // Group mode: update module selection before context menu appears
            if isPatchMode, patchVM.showGroups {
                if let placed = rackVM.placedModule(at: worldPoint),
                   rackVM.controlAtPoint(worldPoint, in: placed) == nil {
                    if shiftHeld {
                        rackVM.selectedPlacedModuleIDs.insert(placed.id)
                    } else if !rackVM.selectedPlacedModuleIDs.contains(placed.id) {
                        rackVM.selectedPlacedModuleIDs = [placed.id]
                    }
                    return event
                }
            }

            // Pin hit test (patches mode only) — check before cables
            if isPatchMode {
                if let pinHit = cableGeometry?.pin(at: worldPoint) {
                    patchVM.selectedPinID = pinHit
                    patchVM.selectedCableIDs = [pinHit.cableID]
                    RackContextMenus.showPinContextMenu(patchVM: patchVM, cableID: pinHit.cableID, pinID: pinHit.pinID, at: event, in: contentView)
                    return nil
                }
            }

            // Cable body hit test (patches mode only)
            if isPatchMode, let cableID = cableGeometry?.cable(at: worldPoint) {
                if shiftHeld {
                    patchVM.selectedCableIDs.insert(cableID)
                } else if !patchVM.selectedCableIDs.contains(cableID) {
                    patchVM.selectedCableIDs = [cableID]
                }
                RackContextMenus.showCableContextMenu(patchVM: patchVM, at: event, in: contentView, isDarkMode: eventMonitors.isDarkMode, worldPoint: worldPoint)
                return nil
            }

            // Patch point hit test (patches mode only)
            if isPatchMode,
               let placed = rackVM.placedModule(at: worldPoint),
               let control = rackVM.controlAtPoint(worldPoint, in: placed),
               control.kind == .patchPoint {
                let cableIDs = patchVM.cablesForPatchPoint(moduleID: placed.id, controlID: control.id)
                if !cableIDs.isEmpty {
                    if shiftHeld {
                        for id in cableIDs { patchVM.selectedCableIDs.insert(id) }
                    } else {
                        let alreadySelected = cableIDs.allSatisfy { patchVM.selectedCableIDs.contains($0) }
                        if !alreadySelected {
                            patchVM.selectedCableIDs = Set(cableIDs)
                        }
                    }
                    RackContextMenus.showCableContextMenu(patchVM: patchVM, at: event, in: contentView, isDarkMode: eventMonitors.isDarkMode, worldPoint: worldPoint)
                    return nil
                }
            }

            // Module hit test (racks mode only)
            if !isPatchMode, let placed = rackVM.placedModule(at: worldPoint) {
                if shiftHeld {
                    rackVM.selectedCaseIDs.removeAll()
                    rackVM.selectedPlacedModuleIDs.insert(placed.id)
                } else if !rackVM.selectedPlacedModuleIDs.contains(placed.id) {
                    rackVM.clearSelection()
                    rackVM.selectedPlacedModuleIDs = [placed.id]
                }
                RackContextMenus.showModuleContextMenu(rackVM: rackVM, at: event, in: contentView)
                return nil
            }

            return event
        }
    }
}
#endif
