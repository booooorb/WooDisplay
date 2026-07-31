import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum ThemeSettingsError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This theme file uses unsupported version \(version)."
        }
    }
}

@MainActor
final class CatalogueStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var sourceName = ""
    @Published var currentPage = 0
    @Published var inspectorMode: SettingsInspectorMode = .layout

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
    @Published var companyLogoData: Data?
    @Published var companyLogoName: String?
    @Published var companyLogoSize = 30.0

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
    @Published var customLayoutStyle = CatalogueThemePreset.studio.layoutStyle
    @Published var customTextAlignment = CatalogueThemePreset.studio.textAlignment
    @Published var customImageFit: CatalogueImageFit = .contain
    @Published var customCornerStyle = CatalogueThemePreset.studio.cornerStyle
    @Published var customBorderStyle = CatalogueThemePreset.studio.borderStyle
    @Published var customSpacing = CatalogueThemePreset.studio.spacing
    @Published var categoryColorThemes: [String: CatalogueColorTheme] = [:]
    @Published var colorEditorCategory: String?

    @Published var errorMessage: String?
    @Published var themeStatusMessage: String?
    @Published var brandStatusMessage: String?
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
            companyLogoData: companyLogoData,
            companyLogoSize: companyLogoSize,
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
            layoutStyle: isCustom ? customLayoutStyle : selectedTheme.layoutStyle,
            textAlignment: isCustom ? customTextAlignment : selectedTheme.textAlignment,
            imageFit: isCustom ? customImageFit : .contain,
            cornerStyle: isCustom ? customCornerStyle : selectedTheme.cornerStyle,
            borderStyle: isCustom ? customBorderStyle : selectedTheme.borderStyle,
            spacing: isCustom ? customSpacing : selectedTheme.spacing,
            categoryColors: categoryColorThemes
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

    func colors(for category: String?) -> CatalogueColorTheme {
        settings.colors(for: category)
    }

    func hasCustomColors(for category: String) -> Bool {
        categoryColorThemes[category] != nil
    }

    func enableCustomColors(for category: String) {
        guard categoryColorThemes[category] == nil else { return }
        categoryColorThemes[category] = settings.globalColors
    }

    func resetCustomColors(for category: String) {
        categoryColorThemes.removeValue(forKey: category)
    }

    func resetAllCategoryColors() {
        categoryColorThemes.removeAll()
    }

    func customizeCategoryAccent(_ color: RGBAColor, category: String) {
        updateCategoryColors(category) {
            $0.accent = color
            $0.price = color
        }
    }

    func customizeCategoryPageColor(_ color: RGBAColor, category: String) {
        updateCategoryColors(category) { $0.page = color }
    }

    func customizeCategoryTextColor(_ color: RGBAColor, category: String) {
        updateCategoryColors(category) { $0.text = color }
    }

    func customizeCategoryPriceColor(_ color: RGBAColor, category: String) {
        updateCategoryColors(category) { $0.price = color }
    }

    func customizeCategoryCardColor(_ color: RGBAColor, category: String) {
        updateCategoryColors(category) { $0.card = color }
    }

    func customizeCategoryImageBackgroundColor(_ color: RGBAColor, category: String) {
        updateCategoryColors(category) { $0.imageBackground = color }
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

    func importCompanyLogo() {
        let panel = NSOpenPanel()
        panel.title = "Choose company logo"
        panel.message = "Choose a PNG, JPEG, GIF, TIFF, HEIC, or PDF logo."
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Use Logo"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 20_000_000, NSImage(data: data) != nil else {
                brandStatusMessage = "That file could not be used as a logo. Choose a valid image under 20 MB."
                return
            }
            companyLogoData = data
            companyLogoName = url.lastPathComponent
        } catch {
            brandStatusMessage = "The logo could not be loaded: \(error.localizedDescription)"
        }
    }

    func removeCompanyLogo() {
        companyLogoData = nil
        companyLogoName = nil
    }

    func importThemeSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import WooDisplay theme"
        panel.message = "Choose a WooDisplay JSON theme file."
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Import Theme"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try loadThemeSettings(from: url)
            themeStatusMessage = "Imported \(url.lastPathComponent). Global styling and category colors are now active."
        } catch {
            themeStatusMessage = "The theme could not be imported: \(error.localizedDescription)"
        }
    }

    func exportThemeSettings() {
        let panel = NSSavePanel()
        panel.title = "Export WooDisplay theme"
        panel.message = "Save global styling and custom category colors as a reusable JSON theme."
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "WooDisplay-Theme.json"
        panel.prompt = "Export Theme"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try saveThemeSettings(to: url)
            themeStatusMessage = "Exported theme settings to \(url.lastPathComponent)."
        } catch {
            themeStatusMessage = "The theme could not be exported: \(error.localizedDescription)"
        }
    }

    func saveThemeSettings(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(makeThemeDocument()).write(to: url, options: .atomic)
    }

    func loadThemeSettings(from url: URL) throws {
        let document = try JSONDecoder().decode(
            CatalogueThemeDocument.self,
            from: Data(contentsOf: url)
        )
        try applyThemeDocument(document)
    }

    func makeThemeDocument() -> CatalogueThemeDocument {
        CatalogueThemeDocument(
            selectedTheme: selectedTheme,
            customColors: CatalogueColorTheme(
                accent: customAccent,
                page: customPageColor,
                text: customTextColor,
                price: customPriceColor,
                card: customCardColor,
                imageBackground: customImageBackgroundColor
            ),
            font: customFont,
            layoutStyle: customLayoutStyle,
            textAlignment: customTextAlignment,
            imageFit: customImageFit,
            cornerStyle: customCornerStyle,
            borderStyle: customBorderStyle,
            spacing: customSpacing,
            categoryColors: categoryColorThemes
        )
    }

    func applyThemeDocument(_ document: CatalogueThemeDocument) throws {
        guard document.version <= CatalogueThemeDocument.currentVersion else {
            throw ThemeSettingsError.unsupportedVersion(document.version)
        }

        selectedTheme = document.selectedTheme
        customAccent = document.customColors.accent
        customPageColor = document.customColors.page
        customTextColor = document.customColors.text
        customPriceColor = document.customColors.price
        customCardColor = document.customColors.card
        customImageBackgroundColor = document.customColors.imageBackground
        customFont = document.font
        customLayoutStyle = document.layoutStyle
        customTextAlignment = document.textAlignment
        customImageFit = document.imageFit
        customCornerStyle = document.cornerStyle
        customBorderStyle = document.borderStyle
        customSpacing = document.spacing
        categoryColorThemes = document.categoryColors
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
        customLayoutStyle = selectedTheme.layoutStyle
        customTextAlignment = selectedTheme.textAlignment
        customImageFit = .contain
        customCornerStyle = selectedTheme.cornerStyle
        customBorderStyle = selectedTheme.borderStyle
        customSpacing = selectedTheme.spacing
    }

    private func updateCategoryColors(
        _ category: String,
        update: (inout CatalogueColorTheme) -> Void
    ) {
        var colors = categoryColorThemes[category] ?? settings.globalColors
        update(&colors)
        categoryColorThemes[category] = colors
    }

    private func clampCurrentPage() {
        currentPage = min(safeCurrentPage, max(0, pageCount - 1))
    }
}
