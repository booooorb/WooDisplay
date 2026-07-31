import AppKit
import Combine
import Foundation

@MainActor
final class CatalogueStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var sourceName = ""
    @Published var currentPage = 0

    @Published var showImage = true
    @Published var showName = true
    @Published var showPrice = true
    @Published var showSKU = false
    @Published var showCategory = false
    @Published var showStock = false
    @Published var showBrand = false
    @Published var showDescription = false
    @Published var productsPerPage = 12
    @Published var showPageHeader = true
    @Published var catalogueTitle = "Product Catalogue"

    @Published var selectedTheme: CatalogueThemePreset = .studio
    @Published var customAccent = CatalogueThemePreset.studio.accent
    @Published var customPageColor = CatalogueThemePreset.studio.pageColor
    @Published var customFont = CatalogueThemePreset.studio.font

    @Published var errorMessage: String?
    @Published var isExporting = false
    @Published var exportProgress = 0.0
    @Published var completedExportURL: URL?

    init() {
        loadDefaultCatalogue()
    }

    var settings: CatalogueSettingsSnapshot {
        CatalogueSettingsSnapshot(
            showImage: showImage,
            showName: showName,
            showPrice: showPrice,
            showSKU: showSKU,
            showCategory: showCategory,
            showStock: showStock,
            showBrand: showBrand,
            showDescription: showDescription,
            productsPerPage: productsPerPage,
            showPageHeader: showPageHeader,
            catalogueTitle: catalogueTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Product Catalogue"
                : catalogueTitle,
            theme: selectedTheme,
            accent: selectedTheme == .custom ? customAccent : selectedTheme.accent,
            pageColor: selectedTheme == .custom ? customPageColor : selectedTheme.pageColor,
            font: selectedTheme == .custom ? customFont : selectedTheme.font,
            layoutStyle: selectedTheme == .custom ? .studio : selectedTheme.layoutStyle
        )
    }

    var pageCount: Int {
        max(1, Int(ceil(Double(products.count) / Double(max(1, productsPerPage)))))
    }

    var pageProducts: [Product] {
        guard !products.isEmpty else { return [] }
        let safePage = min(currentPage, pageCount - 1)
        let start = safePage * productsPerPage
        return Array(products[start..<min(start + productsPerPage, products.count)])
    }

    func selectTheme(_ theme: CatalogueThemePreset) {
        selectedTheme = theme
    }

    func customizeAccent(_ color: RGBAColor) {
        copySelectedPresetToCustom()
        customAccent = color
        selectedTheme = .custom
    }

    func customizePageColor(_ color: RGBAColor) {
        copySelectedPresetToCustom()
        customPageColor = color
        selectedTheme = .custom
    }

    func customizeFont(_ font: CatalogueFontFamily) {
        copySelectedPresetToCustom()
        customFont = font
        selectedTheme = .custom
    }

    func setProductsPerPage(_ value: Int) {
        productsPerPage = value
        currentPage = min(currentPage, pageCount - 1)
    }

    func previousPage() {
        currentPage = max(0, currentPage - 1)
    }

    func nextPage() {
        currentPage = min(pageCount - 1, currentPage + 1)
    }

    func importCSV() {
        let panel = NSOpenPanel()
        panel.title = "Import WooCommerce catalogue"
        panel.message = "Choose a WooCommerce product export in CSV format."
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url: url)
    }

    func exportPDF() {
        guard !products.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export printable catalogue"
        panel.message = "Save the previewed catalogue layout as a print-ready PDF."
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedPDFName()
        panel.prompt = "Export PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let exportProducts = products
        let source = sourceName
        let exportSettings = settings
        isExporting = true
        exportProgress = 0
        completedExportURL = nil

        Task {
            do {
                try await PDFCatalogueExporter.export(
                    products: exportProducts,
                    sourceName: source,
                    settings: exportSettings,
                    to: url
                ) { [weak self] progress in
                    self?.exportProgress = progress
                }
                isExporting = false
                completedExportURL = url
            } catch {
                isExporting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func revealCompletedExport() {
        guard let completedExportURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([completedExportURL])
        self.completedExportURL = nil
    }

    func load(url: URL) {
        do {
            let table = try CSVParser.parse(url: url)
            products = try CatalogueBuilder.products(from: table)
            sourceName = url.lastPathComponent
            currentPage = 0
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDefaultCatalogue() {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "catalogue", withExtension: "csv"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("wc-product-export-30-7-2026-1785460675095.csv"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("catalogue.csv")
        ]

        if let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) {
            load(url: url)
        } else {
            errorMessage = "The bundled catalogue could not be found. Use Import CSV to choose a WooCommerce export."
        }
    }

    private func suggestedPDFName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "WooDisplay-Catalogue-\(formatter.string(from: Date())).pdf"
    }

    private func copySelectedPresetToCustom() {
        guard selectedTheme != .custom else { return }
        customAccent = selectedTheme.accent
        customPageColor = selectedTheme.pageColor
        customFont = selectedTheme.font
    }
}
