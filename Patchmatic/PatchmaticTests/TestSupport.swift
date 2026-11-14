import Foundation
@testable import Patchmatic

/// The bundled sample library: one rack with a VCO, VCF and VCA in one case,
/// and one patch with two cables.
@MainActor
struct SampleFixture {
    let document = SampleData.makeDocument()

    var rack: Rack { document.racks[0] }
    var rackCase: Case { rack.cases[0] }
    var patch: Patch { document.patches[0] }
    func definition(named name: String) -> ModuleDefinition {
        document.moduleLibrary.first { $0.name == name }!
    }
    func placed(named name: String) -> PlacedModule {
        let id = definition(named: name).id
        return rackCase.placedModules.first { $0.moduleDefinitionID == id }!
    }
}

func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

/// An undo manager configured like the app's: no automatic grouping by event.
func makeUndoManager() -> UndoManager {
    let manager = UndoManager()
    manager.groupsByEvent = false
    return manager
}
