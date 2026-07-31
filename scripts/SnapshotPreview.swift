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
        if let requestedTheme {
            store.selectTheme(requestedTheme)
        }
        let rootView = CatalogueView()
            .environmentObject(store)
            .frame(width: 1400, height: 880)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 1400, height: 880)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            hostingView.layoutSubtreeIfNeeded()
            guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                app.terminate(nil)
                return
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("tmp/app-render-\(requestedTheme?.rawValue ?? "studio").png")
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
