import SwiftUI

@main
struct WooDisplayApp: App {
    @StateObject private var store = CatalogueStore()

    var body: some Scene {
        WindowGroup("WooDisplay") {
            CatalogueView()
                .environmentObject(store)
                .frame(minWidth: 1_050, minHeight: 700)
        }
        .defaultSize(width: 1_400, height: 880)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import CSV…") { store.importCSV() }
                    .keyboardShortcut("o")
                Button("Export PDF…") { store.exportPDF() }
                    .keyboardShortcut("e")
            }

            CommandMenu("Catalogue") {
                Button("Previous Page") { store.previousPage() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Next Page") { store.nextPage() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
        }
    }
}
