import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct DocumentCodingTests {
    @Test func sampleLibraryRoundTripsStably() throws {
        let data = try encode(SampleFixture().document)
        let decoded = try JSONDecoder().decode(PatchmaticDocument.self, from: data)
        #expect(try encode(decoded) == data)
    }

    @Test func savedLibraryCarriesTheSchemaVersionButNotTheSelection() throws {
        let json = try JSONSerialization.jsonObject(with: encode(SampleFixture().document)) as! [String: Any]
        #expect(json["schemaVersion"] as? Int == PatchmaticDocument.currentSchemaVersion)
        #expect(json["activeRackID"] == nil)
        #expect(json["activePatchID"] == nil)
        #expect(json["activeSetID"] == nil)
    }

    @Test func libraryFromANewerVersionIsRejected() {
        let json = #"{"schemaVersion": 999, "moduleLibrary": [], "racks": [], "patches": []}"#
        #expect(throws: PatchmaticDocument.SchemaError.self) {
            try decode(PatchmaticDocument.self, json)
        }
    }

    @Test func libraryWithoutVersionOrOptionalFieldsLoads() throws {
        let rackID = UUID(), patchID = UUID(), selection = UUID()
        let json = """
        {"moduleLibrary": [], "racks": [{"id": "\(rackID)", "name": "R", "cases": []}],
         "patches": [{"id": "\(patchID)", "name": "P", "rackID": "\(rackID)", "cables": [], "knobValues": []}],
         "activePatchID": "\(selection)"}
        """
        let document = try decode(PatchmaticDocument.self, json)
        #expect(document.sets.isEmpty)
        #expect(document.patches[0].moduleNotes.isEmpty)
        #expect(document.patches[0].patchNotes == "")
        // Selection saved by older builds is still read as the initial selection
        #expect(document.activePatchID == selection)
    }

    @Test func missingDefaultedFieldsTakeTheirDefaults() throws {
        let group = try decode(ModuleGroup.self, #"{"id": "\#(UUID())", "name": "G"}"#)
        #expect(group.notes == "")
        #expect(group.colorIndex == 0)
        #expect(group.placedModuleIDs.isEmpty)

        let color = try decode(CableColor.self, #"{"red": 1, "green": 0.5, "blue": 0}"#)
        #expect(color.opacity == 1)

        let pin = try decode(CablePin.self, #"{"id": "\#(UUID())", "x": 1, "y": 2}"#)
        #expect(pin.sortIndex == 0)
        #expect(pin.caseID == nil)

        let label = try decode(Control.LabelConfig.self, #"{"position": "Below"}"#)
        #expect(label.fontSize == 5)
        #expect(label.offset == 0)
    }

    @Test func moduleNotesAreStoredUnderTheNotesKey() throws {
        let patch = SampleFixture().patch
        patch.moduleNotes = [ModuleNote(placedModuleID: UUID(), position: NormalizedPoint(x: 0.5, y: 0.5), text: "hi")]
        let json = try JSONSerialization.jsonObject(with: encode(patch)) as! [String: Any]
        #expect((json["notes"] as? [Any])?.count == 1)
        #expect(json["moduleNotes"] == nil)
        let decoded = try JSONDecoder().decode(Patch.self, from: encode(patch))
        #expect(decoded.moduleNotes.map(\.text) == ["hi"])
    }

    @Test func legacyCasesStackedAtTheOriginAreSpreadOut() throws {
        let json = """
        {"id": "\(UUID())", "name": "R", "cases": [
          {"id": "\(UUID())", "name": "A", "rows": [{"id": "\(UUID())", "size": "3U"}], "rowWidthHP": 84, "placedModules": []},
          {"id": "\(UUID())", "name": "B", "rows": [{"id": "\(UUID())", "size": "3U"}], "rowWidthHP": 84, "placedModules": []}
        ]}
        """
        let rack = try decode(Rack.self, json)
        #expect(rack.cases[0].positionY == 0)
        #expect(rack.cases[1].positionY > rack.cases[0].totalHeight())
    }
}
