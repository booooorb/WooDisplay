import AppKit
import SwiftUI

@MainActor
enum WooDisplayBrand {
    static let name = "WooDisplay"

    static var logoImage: NSImage {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
            currentDirectory.appendingPathComponent("Assets/AppIcon.png")
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) {
                return image
            }
        }

        return NSApplication.shared.applicationIconImage
    }
}

struct WooDisplayLogo: View {
    var size: CGFloat

    var body: some View {
        Image(nsImage: WooDisplayBrand.logoImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel(WooDisplayBrand.name)
    }
}
