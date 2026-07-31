import AppKit
import SwiftUI

@main
struct SnapshotPreview {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let store = CatalogueStore()
        let requestedTheme = CommandLine.arguments.dropFirst().first
            .flatMap(CatalogueThemePreset.init(rawValue:))
        let showPopover = CommandLine.arguments.contains("popover")
        let tallLayout = CommandLine.arguments.contains("tall")
        let renderHeight: CGFloat = tallLayout ? 1_240 : 880
        if let requestedTheme {
            store.selectTheme(requestedTheme)
        }
        if showPopover {
            store.omittedProductIDs = Set(store.products.prefix(2).map(\.id))
        }
        let rootView = CatalogueView()
            .environmentObject(store)
            .frame(width: 1400, height: renderHeight)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 1400, height: renderHeight)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)

        if showPopover {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                store.previewSelection = store.currentCataloguePage.products.first
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            hostingView.layoutSubtreeIfNeeded()
            guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                app.terminate(nil)
                return
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent(
                        "tmp/app-render-\(requestedTheme?.rawValue ?? "studio")\(showPopover ? "-popover" : "")\(tallLayout ? "-tall" : "").png"
                    )
                try? FileManager.default.createDirectory(
                    at: output.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? data.write(to: output)
            }
            app.terminate(nil)
        }

        app.run()
    }
}
