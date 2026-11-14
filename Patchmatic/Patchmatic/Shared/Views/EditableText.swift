import SwiftUI
#if os(macOS)
import AppKit
#endif

struct EditableText: View {
    let text: String
    let onCommit: (String) -> Void
    var isSelected: Bool = false
    @Binding private var beginEditing: Bool

    init(text: String, onCommit: @escaping (String) -> Void, isSelected: Bool = false, beginEditing: Binding<Bool> = .constant(false)) {
        self.text = text
        self.onCommit = onCommit
        self.isSelected = isSelected
        self._beginEditing = beginEditing
    }

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    onCommit(editText)
                    isEditing = false
                }
                #if os(macOS)
                .onExitCommand {
                    isEditing = false
                }
                #endif
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        onCommit(editText)
                        isEditing = false
                    }
                }
                .onAppear {
                    editText = text
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
        } else {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                #if os(macOS)
                .overlay(
                    SelectionClickMonitor(isSelected: isSelected) {
                        editText = text
                        isEditing = true
                    }
                )
                #endif
                .onChange(of: beginEditing) { _, trigger in
                    if trigger {
                        editText = text
                        isEditing = true
                        beginEditing = false
                    }
                }
        }
    }
}

#if os(macOS)
private struct SelectionClickMonitor: NSViewRepresentable {
    let isSelected: Bool
    let action: () -> Void

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.isSelected = isSelected
        nsView.action = action
        if !isSelected {
            nsView.cancelRename()
        }
    }

    class MonitorView: NSView {
        var isSelected: Bool = false
        var action: (() -> Void)?
        private var renameTimer: Timer?

        required init?(coder: NSCoder) { fatalError() }
        override init(frame: NSRect) { super.init(frame: frame) }

        override func mouseDown(with event: NSEvent) {
            let alreadySelected = isSelected
            let tableHasFocus = enclosingTableView.map { $0 === window?.firstResponder } ?? false
            super.mouseDown(with: event)
            if event.clickCount == 1 && alreadySelected && tableHasFocus {
                cancelRename()
                renameTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.action?() }
                }
            } else {
                cancelRename()
            }
        }

        private var enclosingTableView: NSTableView? {
            var v: NSView? = self
            while let current = v {
                if let table = current as? NSTableView { return table }
                v = current.superview
            }
            return nil
        }

        func cancelRename() {
            renameTimer?.invalidate()
            renameTimer = nil
        }

        isolated deinit { cancelRename() }
    }
}
#endif
