import SwiftUI

#if canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

extension PlatformImage {
    var platformCGImage: CGImage? {
        #if canImport(AppKit)
        cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        cgImage
        #endif
    }

    #if canImport(AppKit)
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = platformCGImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    #endif

    static func fromURL(_ url: URL) -> PlatformImage? {
        #if canImport(AppKit)
        NSImage(contentsOf: url)
        #else
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
        #endif
    }

    static func fromData(_ data: Data) -> PlatformImage? {
        #if canImport(AppKit)
        NSImage(data: data)
        #else
        UIImage(data: data)
        #endif
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
