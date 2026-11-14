import Foundation

struct PlacedModule: Codable, Identifiable, Hashable {
    var id = UUID()
    /// References a ModuleDefinition by ID
    var moduleDefinitionID: UUID
    /// Which rack row this module is in (0-indexed)
    var rowIndex: Int
    /// Horizontal position in HP from left edge of the row
    var positionInRow: Int
}
