import SwiftUI
import AppKit

// MARK: - Window title hider + logo injector

/// Zero-size NSViewRepresentable that hides the window title text and injects the
/// app logo into the title bar via NSTitlebarAccessoryViewController.
struct WindowTitleHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowObserverView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - NSView subclass for zero-delay window detection

private class WindowObserverView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        configure(window)
    }

    private func configure(_ window: NSWindow) {
        window.titleVisibility = .hidden
        guard !window.titlebarAccessoryViewControllers.contains(where: { $0 is LogoTitlebarAccessory }) else { return }

        // Template image in Media.xcassets: the logo cropped to its ink, as an alpha mask
        if let logo = NSImage(named: "TitlebarLogo")?.copy() as? NSImage {
            let height: CGFloat = 18
            logo.size = NSSize(width: height * logo.size.width / logo.size.height, height: height)
            attach(logo, to: window)
        }
    }

    private func attach(_ logo: NSImage, to window: NSWindow) {
        guard !window.titlebarAccessoryViewControllers.contains(where: { $0 is LogoTitlebarAccessory }) else { return }
        let accessory = LogoTitlebarAccessory(logo: logo)
        accessory.layoutAttribute = .left
        window.addTitlebarAccessoryViewController(accessory)
    }
}

// MARK: - Titlebar accessory

private final class LogoTitlebarAccessory: NSTitlebarAccessoryViewController {
    private let logo: NSImage

    init(logo: NSImage) {
        self.logo = logo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let h: CGFloat = 18
        let aspect = logo.size.width / logo.size.height
        let w = ceil(h * aspect)
        let leadingPad: CGFloat = 20

        let imageView = NSImageView()
        imageView.image = logo
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignRight
        imageView.contentTintColor = .labelColor
        imageView.frame = NSRect(x: 0, y: 0, width: leadingPad + w, height: h)

        let click = NSClickGestureRecognizer(target: self, action: #selector(openAboutPanel))
        imageView.addGestureRecognizer(click)

        view = imageView
    }

    @objc private func openAboutPanel() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let icon = NSApp.applicationIconImage {
            options[.applicationIcon] = icon
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
