import SwiftUI

// MARK: - Keyboard shortcuts

struct RackKeyboardShortcuts: ViewModifier {
    let rackVM: RackViewModel
    let patchVM: PatchViewModel
    let showCables: Bool
    let readOnly: Bool

    func body(content: Content) -> some View {
        content
            .onKeyPress(.leftArrow) {
                guard !readOnly, !showCables, !rackVM.selectedPlacedModuleIDs.isEmpty else { return .ignored }
                rackVM.nudgeSelectedModules(by: -1)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard !readOnly, !showCables, !rackVM.selectedPlacedModuleIDs.isEmpty else { return .ignored }
                rackVM.nudgeSelectedModules(by: 1)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "ad")) { keyPress in
                guard !readOnly, !showCables, keyPress.modifiers == .command else { return .ignored }
                switch keyPress.characters {
                case "a":
                    rackVM.selectAllModules()
                    return .handled
                case "d":
                    guard !rackVM.selectedPlacedModuleIDs.isEmpty else { return .ignored }
                    rackVM.duplicateSelectedModules()
                    return .handled
                default:
                    return .ignored
                }
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "cv")) { keyPress in
                guard !readOnly, showCables, keyPress.modifiers == .command else { return .ignored }
                switch keyPress.characters {
                case "c":
                    guard !patchVM.selectedCableIDs.isEmpty else { return .ignored }
                    patchVM.copySelectedCables()
                    return .handled
                case "v":
                    guard patchVM.canPasteCables else { return .ignored }
                    patchVM.pasteCables()
                    return .handled
                default:
                    return .ignored
                }
            }
    }
}
