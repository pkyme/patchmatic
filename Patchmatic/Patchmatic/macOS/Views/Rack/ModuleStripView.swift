import SwiftUI

struct ModuleStripView: View {
    @Bindable var rackVM: RackViewModel

    @State private var selection: Set<UUID> = []

    var body: some View {
        Divider()
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    rackVM.moduleStripHeight = max(80, min(300, rackVM.moduleStripDragStartHeight - value.translation.height))
                }
                .onEnded { _ in
                    rackVM.moduleStripDragStartHeight = rackVM.moduleStripHeight
                })
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
        GeometryReader { geo in
            ModuleGridView(
                modules: rackVM.document.moduleLibrary,
                selectedModuleIDs: $selection,
                axis: .horizontal,
                thumbnailHeight: max(40, geo.size.height - 44),
                draggable: true,
                onDragStart: { module in
                    rackVM.beginNewModuleDrag(definitionID: module.id)
                }
            )
        }
        .frame(height: rackVM.moduleStripHeight)
        .onDrop(of: [.text], isTargeted: nil) { _ in false }
    }
}
