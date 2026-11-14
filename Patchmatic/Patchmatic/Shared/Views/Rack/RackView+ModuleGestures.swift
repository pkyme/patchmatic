import SwiftUI
import UniformTypeIdentifiers

// Canvas drag handling in Racks mode and read-only Sets mode
extension RackView {
    func handleModuleDragChanged(_ value: DragGesture.Value) {
        let point = scaledPoint(value.location)

        if gesture.rackDrag == .idle {
            let dx = value.location.x - value.startLocation.x
            let dy = value.location.y - value.startLocation.y
            guard dx * dx + dy * dy >= 16 else { return } // 4pt threshold

            let startPoint = scaledPoint(value.startLocation)

            // Check modifier keys
            let isShiftDrag: Bool
            let isOptionDrag: Bool
            #if canImport(AppKit)
            let flags = NSEvent.modifierFlags
            isShiftDrag = flags.contains(.shift)
            isOptionDrag = flags.contains(.option)
            #else
            isShiftDrag = false
            isOptionDrag = false
            #endif

            // Option+drag always pans
            if isOptionDrag {
                gesture.rackDrag = .pan
                lastPanOffset = panOffset
                return
            }

            // Shift+drag on empty space starts marquee selection
            if isShiftDrag {
                gesture.rackDrag = .marquee(start: startPoint)
                return
            }

            // If starting on a module, select it if needed and begin drag
            if let placed = rackVM.placedModule(at: startPoint) {
                if !rackVM.selectedPlacedModuleIDs.contains(placed.id) {
                    rackVM.clearSelection()
                    rackVM.selectedPlacedModuleIDs = [placed.id]
                }
                rackVM.beginModuleDrag(moduleID: placed.id, startPoint: startPoint)
                gesture.rackDrag = .module
            } else if let headerCase = rackVM.caseHeaderAtPoint(startPoint, zoom: currentZoom) {
                // Dragging from title bar — select and move like a window
                if !rackVM.selectedCaseIDs.contains(headerCase.id) {
                    rackVM.clearSelection()
                    rackVM.selectedCaseIDs = [headerCase.id]
                }
                rackVM.beginCaseDrag(caseIDs: rackVM.selectedCaseIDs, anchor: startPoint)
                gesture.rackDrag = .caseDrag
            } else if let hitCase = rackVM.caseAtPointForSelection(startPoint, zoom: currentZoom),
                      rackVM.selectedCaseIDs.contains(hitCase.id) {
                // Dragging from content area of an already-selected case
                rackVM.beginCaseDrag(caseIDs: rackVM.selectedCaseIDs, anchor: startPoint)
                gesture.rackDrag = .caseDrag
            } else {
                // Empty space — pan the canvas
                gesture.rackDrag = .pan
                lastPanOffset = panOffset
            }
        }

        switch gesture.rackDrag {
        case .module:
            rackVM.updateModuleDrag(point: point)
        case .marquee(let start):
            let rect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
            rackVM.marqueeRect = rect
            rackVM.selectItemsInRect(rect)
        case .caseDrag:
            rackVM.updateCaseDrag(point: point, zoom: currentZoom)
        case .pan:
            let translation = value.translation
            panOffset = CGSize(
                width: lastPanOffset.width + translation.width,
                height: lastPanOffset.height + translation.height
            )
        case .idle:
            break
        }
    }

    func handleModuleDragEnded(_ value: DragGesture.Value) {
        let mode = gesture.rackDrag
        gesture.rackDrag = .idle

        switch mode {
        case .module:
            rackVM.endModuleDrag()
        case .marquee:
            // Marquee selection already applied during drag
            rackVM.marqueeRect = nil
        case .caseDrag:
            rackVM.endCaseDrag()
        case .pan:
            lastPanOffset = panOffset
        case .idle:
            // No drag started — treat as a click for selection
            let point = scaledPoint(value.startLocation)
            let extending: Bool
            #if canImport(AppKit)
            extending = NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)
            #else
            extending = false
            #endif

            if let placed = rackVM.placedModule(at: point) {
                if extending {
                    rackVM.selectedCaseIDs.removeAll()
                    if rackVM.selectedPlacedModuleIDs.contains(placed.id) {
                        rackVM.selectedPlacedModuleIDs.remove(placed.id)
                    } else {
                        rackVM.selectedPlacedModuleIDs.insert(placed.id)
                    }
                } else {
                    rackVM.clearSelection()
                    rackVM.selectedPlacedModuleIDs = [placed.id]
                }
            } else if let rackCase = rackVM.caseAtPointForSelection(point, zoom: currentZoom) {
                if extending {
                    rackVM.selectedPlacedModuleIDs.removeAll()
                    if rackVM.selectedCaseIDs.contains(rackCase.id) {
                        rackVM.selectedCaseIDs.remove(rackCase.id)
                    } else {
                        rackVM.selectedCaseIDs.insert(rackCase.id)
                    }
                } else {
                    rackVM.clearSelection()
                    rackVM.selectedCaseIDs = [rackCase.id]
                }
            } else {
                rackVM.clearSelection()
            }
        }
    }

    func handleReadOnlyDragChanged(_ value: DragGesture.Value) {
        // Handle ongoing pan
        if gesture.isPanningInReadOnlyMode {
            let translation = value.translation
            panOffset = CGSize(
                width: lastPanOffset.width + translation.width,
                height: lastPanOffset.height + translation.height
            )
            return
        }

        // Only start panning after sufficient movement (distinguishes clicks from drags)
        let dist = hypot(value.translation.width, value.translation.height)
        guard dist > 4 else { return }
        gesture.isPanningInReadOnlyMode = true
        lastPanOffset = panOffset
    }

    func handleReadOnlyDragEnded(_ value: DragGesture.Value) {
        if gesture.isPanningInReadOnlyMode {
            gesture.isPanningInReadOnlyMode = false
            lastPanOffset = panOffset
            return
        }

        // Click: toggle magnifier for screen controls, dismiss otherwise
        let startPoint = scaledPoint(value.startLocation)
        if let placed = rackVM.placedModule(at: startPoint),
           let control = rackVM.controlAtPoint(startPoint, in: placed),
           control.kind == .screen {
            if magnifiedScreen?.moduleID == placed.id && magnifiedScreen?.controlID == control.id {
                magnifiedScreen = nil
                magnifierInfo = nil
            } else {
                showMagnifier(for: placed.id, controlID: control.id)
            }
        } else if magnifierInfo != nil {
            magnifiedScreen = nil
            magnifierInfo = nil
        }
    }
}
