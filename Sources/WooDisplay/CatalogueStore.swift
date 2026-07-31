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

    @Published var groupByCategory = true
    @Published var sortOrder: CatalogueSortOrder = .categoryThenName
    @Published var categoryOrder: [String] = []
    @Published var omittedProductIDs: Set<String> = []
    @Published var previewSelection: Product?

    @Published var selectedTheme: CatalogueThemePreset = .studio
    @Published var customAccent = CatalogueThemePreset.studio.accent
    @Published var customPageColor = CatalogueThemePreset.studio.pageColor
    @Published var customTextColor = CatalogueThemePreset.studio.textColor
    @Published var customPriceColor = CatalogueThemePreset.studio.priceColor
    @Published var customCardColor = CatalogueThemePreset.studio.cardColor
    @Published var customImageBackgroundColor = CatalogueThemePreset.studio.imageBackgroundColor
    @Published var customFont = CatalogueThemePreset.studio.font
    @Published var customTextAlignment = CatalogueThemePreset.studio.textAlignment
    @Published var customImageFit: CatalogueImageFit = .contain
    @Published var customCornerStyle = CatalogueThemePreset.studio.cornerStyle
    @Published var customBorderStyle = CatalogueThemePreset.studio.borderStyle
    @Published var customSpacing = CatalogueThemePreset.studio.spacing

    @Published var errorMessage: String?
    @Published var isExporting = false
    @Published var exportProgress = 0.0
    @Published var completedExportURL: URL?

    init() {
        loadDefaultCatalogue()
    }

    var settings: CatalogueSettingsSnapshot {
        let isCustom = selectedTheme == .custom
        return CatalogueSettingsSnapshot(
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
            groupByCategory: groupByCategory,
            sortOrder: sortOrder,
            categoryOrder: categoryOrder,
            theme: selectedTheme,
            accent: isCustom ? customAccent : selectedTheme.accent,
            pageColor: isCustom ? customPageColor : selectedTheme.pageColor,
            textColor: isCustom ? customTextColor : selectedTheme.textColor,
            priceColor: isCustom ? customPriceColor : selectedTheme.priceColor,
            cardColor: isCustom ? customCardColor : selectedTheme.cardColor,
            imageBackgroundColor: isCustom ? customImageBackgroundColor : selectedTheme.imageBackgroundColor,
            font: isCustom ? customFont : selectedTheme.font,
            layoutStyle: isCustom ? .studio : selectedTheme.layoutStyle,
            textAlignment: isCustom ? customTextAlignment : selectedTheme.textAlignment,
            imageFit: isCustom ? customImageFit : .contain,
            cornerStyle: isCustom ? customCornerStyle : selectedTheme.cornerStyle,
            borderStyle: isCustom ? customBorderStyle : selectedTheme.borderStyle,
            spacing: isCustom ? customSpacing : selectedTheme.spacing
        )
    }

    var includedProducts: [Product] {
        products.filter { !omittedProductIDs.contains($0.id) }
    }

    var omittedProducts: [Product] {
        products.filter { omittedProductIDs.contains($0.id) }
    }

    var cataloguePages: [CataloguePage] {
        CataloguePaginator.pages(products: includedProducts, settings: settings)
    }

    var pageCount: Int { cataloguePages.count }

    var safeCurrentPage: Int {
        min(max(0, currentPage), max(0, pageCount - 1))
    }

    var currentCataloguePage: CataloguePage {
        cataloguePages[safeCurrentPage]
    }

    var categoryPageRanges: [CategoryPageRange] {
        CataloguePaginator.ranges(for: cataloguePages)
    }

    func selectTheme(_ theme: CatalogueThemePreset) {
        selectedTheme = theme
    }

    func customizeAccent(_ color: RGBAColor) {
        prepareCustom()
        customAccent = color
        customPriceColor = color
        selectedTheme = .custom
    }

    func customizePageColor(_ color: RGBAColor) {
        prepareCustom()
        customPageColor = color
        selectedTheme = .custom
    }

    func customizeTextColor(_ color: RGBAColor) {
        prepareCustom()
        customTextColor = color
        selectedTheme = .custom
    }

    func customizePriceColor(_ color: RGBAColor) {
        prepareCustom()
        customPriceColor = color
        selectedTheme = .custom
    }

    func customizeCardColor(_ color: RGBAColor) {
        prepareCustom()
        customCardColor = color
        selectedTheme = .custom
    }

    func customizeImageBackgroundColor(_ color: RGBAColor) {
        prepareCustom()
        customImageBackgroundColor = color
        selectedTheme = .custom
    }

    func customizeFont(_ font: CatalogueFontFamily) {
        prepareCustom()
        customFont = font
        selectedTheme = .custom
    }

    func customizeTextAlignment(_ alignment: CatalogueTextAlignment) {
        prepareCustom()
        customTextAlignment = alignment
        selectedTheme = .custom
    }

    func customizeImageFit(_ fit: CatalogueImageFit) {
        prepareCustom()
        customImageFit = fit
        selectedTheme = .custom
    }

    func customizeCornerStyle(_ style: CatalogueCornerStyle) {
        prepareCustom()
        customCornerStyle = style
        selectedTheme = .custom
    }

    func customizeBorderStyle(_ style: CatalogueBorderStyle) {
        prepareCustom()
        customBorderStyle = style
        selectedTheme = .custom
    }

    func customizeSpacing(_ spacing: CatalogueSpacing) {
        prepareCustom()
        customSpacing = spacing
        selectedTheme = .custom
    }

    func setProductsPerPage(_ value: Int) {
        productsPerPage = value
        clampCurrentPage()
    }

    func setGroupByCategory(_ enabled: Bool) {
        groupByCategory = enabled
        currentPage = 0
    }

    func setSortOrder(_ order: CatalogueSortOrder) {
        sortOrder = order
        currentPage = 0
    }

    func moveCategory(_ category: String, direction: Int) {
        guard let index = categoryOrder.firstIndex(of: category) else { return }
        let destination = index + direction
        guard categoryOrder.indices.contains(destination) else { return }
        categoryOrder.swapAt(index, destination)
        currentPage = 0
    }

    func omit(_ product: Product) {
        omittedProductIDs.insert(product.id)
        previewSelection = nil
        clampCurrentPage()
    }

    func restore(_ product: Product) {
        omittedProductIDs.remove(product.id)
        clampCurrentPage()
    }

    func restoreAllProducts() {
        omittedProductIDs.removeAll()
        clampCurrentPage()
    }

    func previousPage() {
        currentPage = max(0, safeCurrentPage - 1)
    }

    func nextPage() {
        currentPage = min(pageCount - 1, safeCurrentPage + 1)
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
        guard !includedProducts.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export printable catalogue"
        panel.message = "Save the previewed catalogue layout as a print-ready PDF."
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedPDFName()
        panel.prompt = "Export PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let exportProducts = includedProducts
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
            categoryOrder = Array(Set(products.map(\.catalogueCategory))).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
            omittedProductIDs.removeAll()
            previewSelection = nil
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

    private func prepareCustom() {
        guard selectedTheme != .custom else { return }
        customAccent = selectedTheme.accent
        customPageColor = selectedTheme.pageColor
        customTextColor = selectedTheme.textColor
        customPriceColor = selectedTheme.priceColor
        customCardColor = selectedTheme.cardColor
        customImageBackgroundColor = selectedTheme.imageBackgroundColor
        customFont = selectedTheme.font
        customTextAlignment = selectedTheme.textAlignment
        customImageFit = .contain
        customCornerStyle = selectedTheme.cornerStyle
        customBorderStyle = selectedTheme.borderStyle
        customSpacing = selectedTheme.spacing
    }

    private func clampCurrentPage() {
        currentPage = min(safeCurrentPage, max(0, pageCount - 1))
    }
}
