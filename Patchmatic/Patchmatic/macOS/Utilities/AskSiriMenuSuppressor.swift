import AppKit

/// Prevents macOS 27+ from inserting the "Ask Siri" field into menus.
/// Uses private AppKit API (no public opt-out exists); skipped when the selector is unavailable.
@MainActor
enum AskSiriMenuSuppressor {
    private static var observer: NSObjectProtocol?
    nonisolated private static let setBehavior = NSSelectorFromString("_setPreferredIntelligentAssistantInteractionBehavior:")
    nonisolated private static let getBehavior = NSSelectorFromString("_preferredIntelligentAssistantInteractionBehavior")
    /// Behavior value that disables the assistant field.
    nonisolated private static let disabledBehavior = 2

    private typealias Setter = @convention(c) (AnyObject, Selector, Int) -> Void
    private typealias Getter = @convention(c) (AnyObject, Selector) -> Int

    static func install() {
        guard observer == nil,
              NSMenu.instancesRespond(to: setBehavior),
              NSMenu.instancesRespond(to: getBehavior),
              let setIMP = class_getMethodImplementation(NSMenu.self, setBehavior),
              let getIMP = class_getMethodImplementation(NSMenu.self, getBehavior)
        else { return }
        let set = unsafeBitCast(setIMP, to: Setter.self)
        let get = unsafeBitCast(getIMP, to: Getter.self)

        observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification, object: nil, queue: nil
        ) { note in
            guard let menu = note.object as? NSMenu,
                  get(menu, getBehavior) != disabledBehavior else { return }
            set(menu, setBehavior, disabledBehavior)
        }
    }
}
