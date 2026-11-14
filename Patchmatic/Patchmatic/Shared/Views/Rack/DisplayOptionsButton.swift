import SwiftUI

#if os(iOS)
/// Toolbar button presenting image opacity and appearance settings in a popover.
struct DisplayOptionsButton: View {
    @Bindable var rackVM: RackViewModel
    @AppStorage(AppSettings.appearanceMode) private var appearanceMode: String = "system"
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Display", systemImage: "circle.lefthalf.filled")
        }
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Opacity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Slider(value: $rackVM.backgroundImageOpacity, in: 0...1)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding()
            .frame(width: 280)
            .presentationCompactAdaptation(.popover)
        }
    }
}
#endif
