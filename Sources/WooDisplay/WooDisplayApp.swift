import AppKit
import SwiftUI

@MainActor
final class WooDisplayAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: CatalogueStore?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        return store.confirmClosingWorkspace() ? .terminateNow : .terminateCancel
    }
}

@main
struct WooDisplayApp: App {
    @NSApplicationDelegateAdaptor(WooDisplayAppDelegate.self) private var appDelegate
    @StateObject private var store = CatalogueStore()
    @StateObject private var updater = WooDisplayUpdater.shared

    var body: some Scene {
        WindowGroup("WooDisplay") {
            CatalogueView()
                .environmentObject(store)
                .environmentObject(updater)
                .frame(minWidth: 1_050, minHeight: 700)
                .task {
                    appDelegate.store = store
                    updater.checkAutomatically()
                }
                .alert("WooDisplay update available", isPresented: Binding(
                    get: { updater.availableCommit != nil },
                    set: { if !$0 { updater.availableCommit = nil } }
                )) {
                    Button("Download and Install") { updater.downloadAndInstall() }
                    Button("Later", role: .cancel) { updater.availableCommit = nil }
                } message: {
                    Text("A newer build (\(updater.shortAvailableCommit)) is available from GitHub. WooDisplay will relaunch after installing it.")
                }
                .alert("Software Update", isPresented: Binding(
                    get: { updater.message != nil },
                    set: { if !$0 { updater.message = nil } }
                )) {
                    Button("OK", role: .cancel) { updater.message = nil }
                } message: {
                    Text(updater.message ?? "")
                }
        }
        .defaultSize(width: 1_400, height: 880)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Workspace…") { store.openWorkspace() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Save Workspace As…") { store.saveWorkspace() }
                    .keyboardShortcut("s")
                    .disabled(store.products.isEmpty)
                Divider()
                Button("Import CSV…") { store.importCSV() }
                    .keyboardShortcut("o")
                Button("Export PDF…") { store.exportPDF() }
                    .keyboardShortcut("e")
                Divider()
                Button("Import Theme…") { store.importThemeSettings() }
                Button("Export Theme…") { store.exportThemeSettings() }
            }

            CommandMenu("Catalogue") {
                Button("Previous Page") { store.previousPage() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Next Page") { store.nextPage() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button(updater.isChecking ? "Checking for Updates…" : "Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(updater.isChecking)
            }
        }
    }
}
