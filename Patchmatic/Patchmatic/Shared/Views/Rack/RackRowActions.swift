import Foundation

/// Actions that module panels in a rack row can trigger. A nil action is unavailable,
/// e.g. editing actions in read-only Sets mode.
struct RackRowActions {
    var addScreenImage: ((_ moduleID: UUID, _ controlID: UUID) -> Void)?
    var removeScreenImage: ((_ moduleID: UUID, _ controlID: UUID) -> Void)?
    var zoomScreenImage: ((_ moduleID: UUID, _ controlID: UUID) -> Void)?
    var addNote: ((_ moduleID: UUID, _ position: NormalizedPoint) -> Void)?
    var editNote: ((_ moduleID: UUID, _ note: ModuleNote) -> Void)?
    var addPatchPointNote: ((_ moduleID: UUID, _ controlID: UUID) -> Void)?
    /// Called with the module and control under the pointer, or nils when it leaves
    var hoverControl: ((_ moduleID: UUID?, _ controlID: UUID?) -> Void)?
    var createGroup: ((_ moduleIDs: Set<UUID>) -> Void)?
}
