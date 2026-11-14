import SwiftUI

extension RackViewModel {
    // MARK: - Case drag (free positioning)

    func beginCaseDrag(caseIDs: Set<UUID>, anchor: CGPoint) {
        prepareEdit(grouped: true)
        caseDragAnchor = anchor
        caseDragStartPositions = [:]
        guard let rack else { return }
        for rackCase in rack.cases where caseIDs.contains(rackCase.id) {
            caseDragStartPositions[rackCase.id] = CGPoint(x: rackCase.positionX, y: rackCase.positionY)
        }
    }

    func updateCaseDrag(point: CGPoint, zoom: CGFloat) {
        guard let rack else { return }
        let dx = point.x - caseDragAnchor.x
        let dy = point.y - caseDragAnchor.y
        let thresholdWorld = caseSnapThresholdPx / zoom
        for rackCase in rack.cases {
            guard let start = caseDragStartPositions[rackCase.id] else { continue }
            let rawX = start.x + dx
            let rawY = start.y + dy
            rackCase.positionX = guidSnap(rawX, threshold: thresholdWorld)
            rackCase.positionY = guidSnap(rawY, threshold: thresholdWorld)
        }
    }

    func endCaseDrag() {
        undoManager?.endUndoGrouping()
        caseDragStartPositions = [:]
    }

    func guidSnap(_ value: CGFloat, threshold: CGFloat) -> CGFloat {
        let nearest = (value / caseSnapGrid).rounded() * caseSnapGrid
        return abs(value - nearest) < threshold ? nearest : value
    }
    // MARK: - Module drag state

    struct DropIndicator {
        var caseID: UUID
        var rowIndex: Int
        var positionHP: Int
        var widthHP: Int
        /// New row positions for modules pushed aside to make room at the drop location
        var displacedPositions: [UUID: Int] = [:]
    }
    // MARK: - Module drag

    func beginModuleDrag(moduleID: UUID, startPoint: CGPoint) {
        guard let rack else { return }
        guard let rackCase = rack.caseForModule(moduleID),
              let placed = rackCase.placedModules.first(where: { $0.id == moduleID })
        else { return }
        let origin = moduleOrigin(for: placed, in: rackCase)
        moduleDragID = moduleID
        moduleDragPoint = startPoint
        moduleDragGrabOffset = CGSize(
            width: startPoint.x - origin.x,
            height: startPoint.y - origin.y
        )
        buildModuleWidthCache()

        // Multi-module drag: if the dragged module is part of a selection,
        // include other selected modules in the same case
        multiDragIDs.removeAll()
        multiDragOriginalPositions.removeAll()
        if selectedPlacedModuleIDs.contains(moduleID) && selectedPlacedModuleIDs.count > 1 {
            for id in selectedPlacedModuleIDs where id != moduleID {
                if let companion = rackCase.placedModules.first(where: { $0.id == id }) {
                    multiDragIDs.insert(id)
                    multiDragOriginalPositions[id] = (row: companion.rowIndex, hp: companion.positionInRow)
                }
            }
        }
        multiDragOriginalPositions[moduleID] = (row: placed.rowIndex, hp: placed.positionInRow)

        prepareEdit(grouped: true)
    }

    func updateModuleDrag(point: CGPoint) {
        moduleDragPoint = point

        guard let dragID = moduleDragID,
              let rack,
              let sourceCase = rack.caseForModule(dragID),
              let placed = sourceCase.placedModules.first(where: { $0.id == dragID }),
              let definition = document.moduleDefinition(for: placed.moduleDefinitionID)
        else {
            dropIndicator = nil
            return
        }

        guard let (targetCase, localPoint) = caseAtPoint(point) else {
            dropIndicator = nil
            return
        }
        guard let targetRow = targetCase.rowAt(y: localPoint.y),
              targetCase.rows[targetRow].size == definition.format else {
            dropIndicator = nil
            return
        }

        let topLeftX = localPoint.x - moduleDragGrabOffset.width
        let snappedHP = max(0, min(Int(round(topLeftX / EurorackConstants.pointsPerHP)), targetCase.rowWidthHP - definition.widthHP))

        // For multi-module drag, only allow within same case
        if !multiDragIDs.isEmpty && targetCase.id != sourceCase.id {
            dropIndicator = nil
            return
        }

        let allDragIDs = multiDragIDs.union([dragID])

        if canPlaceModule(id: dragID, width: definition.widthHP, inCase: targetCase, row: targetRow, atPosition: snappedHP, excluding: multiDragIDs) {
            // Validate companion modules can also be placed at their offset positions
            if !multiDragIDs.isEmpty {
                guard let primaryOrig = multiDragOriginalPositions[dragID] else {
                    dropIndicator = nil
                    return
                }
                let hpDelta = snappedHP - primaryOrig.hp
                let rowDelta = targetRow - primaryOrig.row

                var allValid = true
                for companionID in multiDragIDs {
                    guard let origPos = multiDragOriginalPositions[companionID],
                          let companion = sourceCase.placedModules.first(where: { $0.id == companionID }),
                          let compDef = document.moduleDefinition(for: companion.moduleDefinitionID)
                    else { allValid = false; break }

                    let newRow = origPos.row + rowDelta
                    let newHP = origPos.hp + hpDelta
                    guard newRow >= 0, newRow < targetCase.rows.count,
                          targetCase.rows[newRow].size == compDef.format,
                          canPlaceModule(id: companionID, width: compDef.widthHP, inCase: targetCase, row: newRow, atPosition: newHP, excluding: allDragIDs)
                    else { allValid = false; break }
                }
                guard allValid else {
                    dropIndicator = nil
                    return
                }
            }

            dropIndicator = DropIndicator(caseID: targetCase.id, rowIndex: targetRow, positionHP: snappedHP, widthHP: definition.widthHP)
        } else if multiDragIDs.isEmpty,
                  let layout = insertionLayout(width: definition.widthHP, inCase: targetCase, row: targetRow, atPosition: snappedHP, excluding: [dragID]) {
            dropIndicator = DropIndicator(caseID: targetCase.id, rowIndex: targetRow, positionHP: layout.position, widthHP: definition.widthHP, displacedPositions: layout.displaced)
        } else {
            dropIndicator = nil
        }
    }

    func endModuleDrag() {
        defer {
            moduleDragID = nil
            moduleDragPoint = nil
            moduleDragGrabOffset = .zero
            dropIndicator = nil
            moduleWidthCache.removeAll()
            multiDragIDs.removeAll()
            multiDragOriginalPositions.removeAll()
        }

        guard let rack,
              let dragID = moduleDragID,
              let indicator = dropIndicator,
              let sourceCase = rack.caseForModule(dragID),
              let placed = sourceCase.placedModules.first(where: { $0.id == dragID }),
              let targetCase = rack.cases.first(where: { $0.id == indicator.caseID })
        else {
            undoManager?.endUndoGrouping()
            return
        }

        for (id, position) in indicator.displacedPositions {
            if let index = targetCase.placedModules.firstIndex(where: { $0.id == id }) {
                targetCase.placedModules[index].positionInRow = position
            }
        }

        if !multiDragIDs.isEmpty, let primaryOrig = multiDragOriginalPositions[dragID] {
            // Multi-module drag: apply same delta to all modules
            let hpDelta = indicator.positionHP - primaryOrig.hp
            let rowDelta = indicator.rowIndex - primaryOrig.row

            moveModule(dragID, inCase: targetCase, toRow: indicator.rowIndex, position: indicator.positionHP)
            for companionID in multiDragIDs {
                guard let origPos = multiDragOriginalPositions[companionID] else { continue }
                moveModule(companionID, inCase: sourceCase, toRow: origPos.row + rowDelta, position: origPos.hp + hpDelta)
            }
        } else if sourceCase.id != targetCase.id {
            sourceCase.placedModules.removeAll { $0.id == dragID }
            var moved = placed
            moved.rowIndex = indicator.rowIndex
            moved.positionInRow = indicator.positionHP
            targetCase.placedModules.append(moved)
        } else {
            moveModule(dragID, inCase: targetCase, toRow: indicator.rowIndex, position: indicator.positionHP)
        }
        undoManager?.endUndoGrouping()
    }
    // MARK: - New module drag (from library strip)

    func beginNewModuleDrag(definitionID: UUID) {
        newModuleDragDefinitionID = definitionID
        buildModuleWidthCache()
    }

    func updateNewModuleDrag(point: CGPoint) {
        newModuleDragPoint = point

        guard let defID = newModuleDragDefinitionID,
              let definition = document.moduleDefinition(for: defID)
        else {
            dropIndicator = nil
            return
        }

        guard let (targetCase, localPoint) = caseAtPoint(point) else {
            dropIndicator = nil
            return
        }
        guard let targetRow = targetCase.rowAt(y: localPoint.y),
              targetCase.rows[targetRow].size == definition.format else {
            dropIndicator = nil
            return
        }

        let topLeftX = localPoint.x - EurorackConstants.width(forHP: definition.widthHP) / 2
        let snappedHP = max(0, min(Int(round(topLeftX / EurorackConstants.pointsPerHP)), targetCase.rowWidthHP - definition.widthHP))

        if canPlaceModule(id: UUID(), width: definition.widthHP, inCase: targetCase, row: targetRow, atPosition: snappedHP) {
            dropIndicator = DropIndicator(caseID: targetCase.id, rowIndex: targetRow, positionHP: snappedHP, widthHP: definition.widthHP)
        } else {
            dropIndicator = nil
        }
    }

    func endNewModuleDrag() {
        defer {
            newModuleDragDefinitionID = nil
            newModuleDragPoint = nil
            newModuleDragScreenPoint = nil
            dropIndicator = nil
            moduleWidthCache.removeAll()
        }

        guard let defID = newModuleDragDefinitionID,
              let indicator = dropIndicator,
              let rack,
              let targetCase = rack.cases.first(where: { $0.id == indicator.caseID })
        else { return }

        prepareEdit(grouped: true)
        let placed = PlacedModule(
            moduleDefinitionID: defID,
            rowIndex: indicator.rowIndex,
            positionInRow: indicator.positionHP
        )
        targetCase.placedModules.append(placed)
        undoManager?.endUndoGrouping()
    }

    var newModuleDragDefinition: ModuleDefinition? {
        guard let defID = newModuleDragDefinitionID else { return nil }
        return document.moduleDefinition(for: defID)
    }

    var moduleDragOrigin: CGPoint? {
        guard let point = moduleDragPoint else { return nil }
        return CGPoint(
            x: point.x - moduleDragGrabOffset.width,
            y: point.y - moduleDragGrabOffset.height
        )
    }

    /// Origin for a companion module during multi-drag, offset relative to the primary drag module
    func moduleOriginForCompanionDrag(_ companionID: UUID) -> CGPoint? {
        guard let dragID = moduleDragID,
              let dragOrigin = moduleDragOrigin,
              let rack,
              let rackCase = rack.caseForModule(dragID),
              let primaryOrig = multiDragOriginalPositions[dragID],
              let companionOrig = multiDragOriginalPositions[companionID]
        else { return nil }

        let primaryOrigOrigin = CGPoint(
            x: CGFloat(primaryOrig.hp) * EurorackConstants.pointsPerHP + rackCase.positionX,
            y: rackCase.positionY + rackCase.rowYOffset(primaryOrig.row)
        )
        let companionOrigOrigin = CGPoint(
            x: CGFloat(companionOrig.hp) * EurorackConstants.pointsPerHP + rackCase.positionX,
            y: rackCase.positionY + rackCase.rowYOffset(companionOrig.row)
        )
        return CGPoint(
            x: dragOrigin.x + (companionOrigOrigin.x - primaryOrigOrigin.x),
            y: dragOrigin.y + (companionOrigOrigin.y - primaryOrigOrigin.y)
        )
    }

    func buildModuleWidthCache() {
        moduleWidthCache.removeAll()
        for def in document.moduleLibrary {
            moduleWidthCache[def.id] = def.widthHP
        }
    }

    func canPlaceModule(id: UUID, width: Int, inCase rackCase: Case, row: Int, atPosition position: Int, excluding: Set<UUID> = []) -> Bool {
        guard position >= 0, position + width <= rackCase.rowWidthHP else { return false }
        let allExcluded = excluding.union([id])
        let others = rackCase.modules(inRow: row).filter { !allExcluded.contains($0.id) }
        let newStart = position
        let newEnd = position + width
        for other in others {
            let otherWidth = moduleWidthCache[other.moduleDefinitionID]
                ?? document.moduleDefinition(for: other.moduleDefinitionID)?.widthHP
            guard let otherWidth else { continue }
            let otherStart = other.positionInRow
            let otherEnd = otherStart + otherWidth
            if newStart < otherEnd && newEnd > otherStart {
                return false
            }
        }
        return true
    }

    /// Finds a placement for a module of `width` HP near `position` by pushing overlapping
    /// modules in the row aside. Modules whose centre lies left of the inserted module's centre
    /// are pushed left, the rest right. The position is clamped so pushed modules stay in the row.
    /// Returns nil if the row does not have enough free HP.
    func insertionLayout(width: Int, inCase rackCase: Case, row: Int, atPosition position: Int, excluding: Set<UUID>) -> (position: Int, displaced: [UUID: Int])? {
        let rowWidth = rackCase.rowWidthHP
        let others: [(id: UUID, start: Int, width: Int)] = rackCase.modules(inRow: row).compactMap { other in
            guard !excluding.contains(other.id),
                  let w = moduleWidthCache[other.moduleDefinitionID]
                    ?? document.moduleDefinition(for: other.moduleDefinitionID)?.widthHP
            else { return nil }
            return (other.id, other.positionInRow, w)
        }

        let centre2 = 2 * position + width
        let left = others.filter { 2 * $0.start + $0.width < centre2 }.sorted { $0.start > $1.start }
        let right = others.filter { 2 * $0.start + $0.width >= centre2 }.sorted { $0.start < $1.start }
        let leftTotal = left.reduce(0) { $0 + $1.width }
        let rightTotal = right.reduce(0) { $0 + $1.width }

        let maxPosition = rowWidth - rightTotal - width
        guard leftTotal <= maxPosition else { return nil }
        let clamped = min(max(position, leftTotal), maxPosition)

        var displaced: [UUID: Int] = [:]
        var boundary = clamped
        for module in left {
            if module.start + module.width > boundary {
                displaced[module.id] = boundary - module.width
                boundary -= module.width
            } else {
                boundary = module.start
            }
        }
        boundary = clamped + width
        for module in right {
            if module.start < boundary {
                displaced[module.id] = boundary
                boundary += module.width
            } else {
                boundary = module.start + module.width
            }
        }
        return (clamped, displaced)
    }
}
