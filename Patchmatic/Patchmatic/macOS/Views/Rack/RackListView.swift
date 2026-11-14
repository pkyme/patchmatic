import SwiftUI

struct RackListView: View {
    @Bindable var rackVM: RackViewModel
    @State private var listSelection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Racks")
                    .font(.headline)
                Spacer()
                Button(action: rackVM.addRack) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(rackVM.document.racks, selection: $listSelection) { rack in
                EditableText(text: rack.name, onCommit: { newName in
                    rackVM.renameRack(rack, to: newName)
                }, isSelected: rackVM.document.activeRackID == rack.id, beginEditing: Binding(
                    get: { rackVM.renamingRackID == rack.id },
                    set: { if !$0 { rackVM.renamingRackID = nil } }
                ))
                .tag(rack.id)
                .contextMenu {
                    Button("Rename") {
                        rackVM.renamingRackID = rack.id
                    }
                    Button("Duplicate") {
                        rackVM.duplicateRack(rack)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        rackVM.deleteRack(rack)
                    }
                }
            }
            .listStyle(.sidebar)
            .onAppear { listSelection = rackVM.document.activeRackID }
            .onChange(of: listSelection) { _, id in
                if let id, id != rackVM.document.activeRackID,
                   let rack = rackVM.document.racks.first(where: { $0.id == id }) {
                    rackVM.selectRack(rack)
                }
            }
            .onChange(of: rackVM.document.activeRackID) { _, id in
                listSelection = id
            }
            .onChange(of: rackVM.pendingRackSelectionID) { old, new in
                if old != nil && new == nil {
                    listSelection = rackVM.document.activeRackID
                }
            }
        }
    }
}
