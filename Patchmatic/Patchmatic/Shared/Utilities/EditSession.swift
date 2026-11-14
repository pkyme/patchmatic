import SwiftUI

@MainActor
@Observable
final class EditSession {
    private(set) var snapshot: Data?
    var isEditing: Bool { snapshot != nil }

    var pendingSelectionID: UUID?
    var pendingSaveConfirmation: Bool = false

    weak var undoManager: UndoManager?

    func beginEditing(snapshot: Data) {
        guard !isEditing else { return }
        self.snapshot = snapshot
    }

    /// Ends the session, removing its undo steps. Undo steps registered against other
    /// targets, such as patch and set deletions, are kept.
    func commitEditing() {
        undoManager?.removeAllActions(withTarget: self)
        snapshot = nil
    }

    /// Ends the session, removing its undo steps, and returns the stored snapshot for the
    /// caller to restore.
    @discardableResult
    func discardEditing() -> Data? {
        undoManager?.removeAllActions(withTarget: self)
        let data = snapshot
        snapshot = nil
        return data
    }

    func cancelSelectionChange() {
        pendingSelectionID = nil
    }

    /// Registers an undo action in its own group, or in the open group if there is one
    /// (e.g. during a drag), since the undo manager does not group by event.
    func registerGroupedUndo<Target: AnyObject>(
        target: Target,
        actionName: String? = nil,
        handler: @escaping (Target) -> Void
    ) {
        undoManager?.registerGroupedUndo(target: target, actionName: actionName, handler: handler)
    }

    /// Records an undo step for an item kept as a snapshot during editing.
    /// `capture` snapshots the item's current state and `apply` restores a snapshot.
    /// Undoing registers the state it replaces, so redo works. Steps are registered
    /// against this session so ending it removes exactly these steps.
    func recordSnapshotUndo<Target: AnyObject>(
        target: Target,
        capture: @escaping (Target) -> Data?,
        apply: @escaping (Target, Data) -> Void
    ) {
        guard isEditing, let snapshot = capture(target) else { return }
        registerGroupedUndo(target: self) { [weak target] session in
            guard let target else { return }
            session.restore(snapshot, on: target, capture: capture, apply: apply)
        }
    }

    private func restore<Target: AnyObject>(
        _ snapshot: Data,
        on target: Target,
        capture: @escaping (Target) -> Data?,
        apply: @escaping (Target, Data) -> Void
    ) {
        if let inverse = capture(target) {
            undoManager?.registerUndo(withTarget: self) { [weak target] session in
                guard let target else { return }
                session.restore(inverse, on: target, capture: capture, apply: apply)
            }
        }
        apply(target, snapshot)
    }
}

/// A view model that edits through an `EditSession`.
@MainActor
protocol EditSessionOwner: AnyObject {
    var editSession: EditSession { get }
}

extension EditSessionOwner {
    var undoManager: UndoManager? {
        get { editSession.undoManager }
        set { editSession.undoManager = newValue }
    }

    var isEditing: Bool { editSession.isEditing }
}

/// A view model whose edit session can restore the last committed state of the item
/// being edited into a document, so saves never persist uncommitted edits.
/// A view model with an edit session that can be saved or discarded.
@MainActor
protocol EditCommitting: AnyObject {
    func commitEditing()
    func discardEditing()
}

@MainActor
protocol CommittedStateRestoring: AnyObject {
    var isEditing: Bool { get }
    func restoreCommittedState(in document: PatchmaticDocument)
}

extension EditSession {
    /// A save adjustment that replaces every item with uncommitted edits by its last
    /// committed state, or nil when nothing is being edited.
    static func committedState(of editors: [CommittedStateRestoring?]) -> DocumentManager.SaveAdjustment? {
        let active = editors.compactMap { $0 }.filter(\.isEditing)
        guard !active.isEmpty else { return nil }
        return { document in active.forEach { $0.restoreCommittedState(in: document) } }
    }
}

@MainActor
extension UndoManager {
    /// Registers an undo action in its own group, or in the open group if there is one
    /// (e.g. during a drag). Patchmatic turns off grouping by event, so each action
    /// needs an explicit group to be undoable on its own.
    func registerGroupedUndo<Target: AnyObject>(
        target: Target,
        actionName: String? = nil,
        handler: @escaping (Target) -> Void
    ) {
        let needsGroup = groupingLevel == 0
        if needsGroup { beginUndoGrouping() }
        registerUndo(withTarget: target, handler: handler)
        if let actionName { setActionName(actionName) }
        if needsGroup { endUndoGrouping() }
    }
}
