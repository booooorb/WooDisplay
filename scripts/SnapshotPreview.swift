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
        let showCategoryColors = CommandLine.arguments.contains("categorycolors")
        let showThemeMode = CommandLine.arguments.contains("thememode")
        let useDarkAppearance = CommandLine.arguments.contains("dark")
        let logoPath = CommandLine.arguments
            .first { $0.hasPrefix("logo=") }
            .map { String($0.dropFirst("logo=".count)) }
        let logoSize = CommandLine.arguments
            .first { $0.hasPrefix("logosize=") }
            .flatMap { Double($0.dropFirst("logosize=".count)) }
        let renderHeight: CGFloat = tallLayout ? 1_240 : 880
        app.appearance = NSAppearance(named: useDarkAppearance ? .darkAqua : .aqua)
        if let requestedTheme {
            store.selectTheme(requestedTheme)
        }
        if let logoPath, let data = try? Data(contentsOf: URL(fileURLWithPath: logoPath)) {
            store.companyLogoData = data
            store.companyLogoName = URL(fileURLWithPath: logoPath).lastPathComponent
        }
        if let logoSize {
            store.companyLogoSize = min(40, max(18, logoSize))
        }
        if showPopover {
            store.omittedProductIDs = Set(store.products.prefix(2).map(\.id))
        }
        if showCategoryColors, let category = store.categoryOrder.first {
            store.colorEditorCategory = category
            store.enableCustomColors(for: category)
            store.customizeCategoryAccent(
                RGBAColor(red: 0.78, green: 0.18, blue: 0.25),
                category: category
            )
            store.customizeCategoryPageColor(
                RGBAColor(red: 1.0, green: 0.95, blue: 0.94),
                category: category
            )
            store.customizeCategoryImageBackgroundColor(
                RGBAColor(red: 0.98, green: 0.90, blue: 0.90),
                category: category
            )
        }
        if showThemeMode || showCategoryColors {
            store.inspectorMode = .theme
        }
        let rootView = CatalogueView()
            .environmentObject(store)
            .environment(\.colorScheme, useDarkAppearance ? .dark : .light)
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
                        "tmp/app-render-\(requestedTheme?.rawValue ?? "studio")\(logoPath == nil ? "" : "-company-logo")\(showPopover ? "-popover" : "")\(showThemeMode ? "-theme-mode" : "")\(showCategoryColors ? "-category-colors" : "")\(useDarkAppearance ? "-dark" : "-light")\(tallLayout ? "-tall" : "").png"
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
