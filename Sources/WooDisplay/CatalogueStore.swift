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
    private var savedWorkspaceSnapshot: Data?
    private var workspaceURL: URL?
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
    @Published var showSellerInformation = true
    @Published var sellerCompany = "VeryShop Arts Inc"
    @Published var sellerContactName = "Laura"
    @Published var sellerWebsite = "veryshop.ca"
    @Published var sellerEmail = "veryshop.ca@gmail.com"
    @Published var sellerPhone = "604-601-1238"

    @Published var groupByCategory = true
    @Published var sortOrder: CatalogueSortOrder = .categoryThenName
    @Published var categoryOrder: [String] = []
    @Published var productOrder: [String] = []
    @Published var omittedProductIDs: Set<String> = []
    @Published var previewSelection: Product?
    @Published var swapSelection: Product?
    @Published var excludedBrands: Set<String> = []
    @Published var excludedCategories: Set<String> = []
    @Published var priceFilterEnabled = false
    @Published var filterMinimumPrice = 0.0
    @Published var filterMaximumPrice = 0.0
    @Published var stockFilterEnabled = false
    @Published var filterMinimumStock = 0.0
    @Published var filterMaximumStock = 0.0
    @Published var excludeOutOfStock = false

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
    @Published var workspaceStatusMessage: String?
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
            showSellerInformation: showSellerInformation,
            sellerCompany: sellerCompany,
            sellerContactName: sellerContactName,
            sellerWebsite: sellerWebsite,
            sellerEmail: sellerEmail,
            sellerPhone: sellerPhone,
            groupByCategory: groupByCategory,
            sortOrder: sortOrder,
            categoryOrder: categoryOrder,
            productOrder: productOrder,
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

    var filteredProducts: [Product] {
        products.filter { product in
            guard !excludedBrands.contains(product.brand),
                  !excludedCategories.contains(product.catalogueCategory) else {
                return false
            }
            guard priceFilterEnabled else { return true }
            guard let price = product.currentPrice else { return false }
            return price >= filterMinimumPrice && price <= filterMaximumPrice
        }.filter { product in
            guard !excludeOutOfStock || product.isInStock else { return false }
            guard stockFilterEnabled else { return true }
            guard let quantity = product.stockQuantity else { return false }
            return Double(quantity) >= filterMinimumStock && Double(quantity) <= filterMaximumStock
        }
    }

    var includedProducts: [Product] {
        filteredProducts.filter { !omittedProductIDs.contains($0.id) }
    }

    var omittedProducts: [Product] {
        products.filter { omittedProductIDs.contains($0.id) }
    }

    var availableBrands: [(name: String, count: Int)] {
        Dictionary(grouping: products, by: \.brand)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.name.isEmpty { return false }
                if rhs.name.isEmpty { return true }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var availableCategories: [(name: String, count: Int)] {
        Dictionary(grouping: products, by: \.catalogueCategory)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var cataloguePriceRange: ClosedRange<Double> {
        let prices = products.compactMap(\.currentPrice)
        return (prices.min() ?? 0)...(prices.max() ?? 0)
    }

    var catalogueStockRange: ClosedRange<Double> {
        let quantities = products.compactMap(\.stockQuantity).map(Double.init)
        return (quantities.min() ?? 0)...(quantities.max() ?? 0)
    }

    var hasNumericStockQuantities: Bool {
        products.contains { $0.stockQuantity != nil }
    }

    var activeFilterCount: Int {
        excludedBrands.count
            + excludedCategories.count
            + (priceFilterEnabled ? 1 : 0)
            + (stockFilterEnabled ? 1 : 0)
            + (excludeOutOfStock ? 1 : 0)
    }

    var filteredOutCount: Int { products.count - filteredProducts.count }

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

    func selectForSwap(_ product: Product) {
        previewSelection = nil
        guard let first = swapSelection else {
            if sortOrder != .custom {
                productOrder = cataloguePages.flatMap(\.products).map(\.id)
                let missing = products.map(\.id).filter { !productOrder.contains($0) }
                productOrder.append(contentsOf: missing)
                sortOrder = .custom
            }
            swapSelection = product
            return
        }

        guard first.id != product.id else {
            swapSelection = nil
            return
        }
        guard let firstIndex = productOrder.firstIndex(of: first.id),
              let secondIndex = productOrder.firstIndex(of: product.id) else {
            swapSelection = nil
            return
        }
        productOrder.swapAt(firstIndex, secondIndex)
        swapSelection = nil
    }

    func restore(_ product: Product) {
        omittedProductIDs.remove(product.id)
        clampCurrentPage()
    }

    func restoreAllProducts() {
        omittedProductIDs.removeAll()
        clampCurrentPage()
    }

    func setBrand(_ brand: String, included: Bool) {
        if included { excludedBrands.remove(brand) } else { excludedBrands.insert(brand) }
        currentPage = 0
    }

    func setCategoryFilter(_ category: String, included: Bool) {
        if included { excludedCategories.remove(category) } else { excludedCategories.insert(category) }
        currentPage = 0
    }

    func setPriceFilterEnabled(_ enabled: Bool) {
        priceFilterEnabled = enabled
        currentPage = 0
    }

    func setMinimumPrice(_ value: Double) {
        filterMinimumPrice = max(
            cataloguePriceRange.lowerBound,
            min(value, filterMaximumPrice)
        )
        currentPage = 0
    }

    func setMaximumPrice(_ value: Double) {
        filterMaximumPrice = min(
            cataloguePriceRange.upperBound,
            max(value, filterMinimumPrice)
        )
        currentPage = 0
    }

    func setStockFilterEnabled(_ enabled: Bool) {
        stockFilterEnabled = enabled && hasNumericStockQuantities
        currentPage = 0
    }

    func setMinimumStock(_ value: Double) {
        filterMinimumStock = max(
            catalogueStockRange.lowerBound,
            min(value.rounded(), filterMaximumStock)
        )
        currentPage = 0
    }

    func setMaximumStock(_ value: Double) {
        filterMaximumStock = min(
            catalogueStockRange.upperBound,
            max(value.rounded(), filterMinimumStock)
        )
        currentPage = 0
    }

    func setExcludeOutOfStock(_ excluded: Bool) {
        excludeOutOfStock = excluded
        currentPage = 0
    }

    func resetFilters() {
        excludedBrands.removeAll()
        excludedCategories.removeAll()
        priceFilterEnabled = false
        stockFilterEnabled = false
        excludeOutOfStock = false
        let range = cataloguePriceRange
        filterMinimumPrice = range.lowerBound
        filterMaximumPrice = range.upperBound
        let stockRange = catalogueStockRange
        filterMinimumStock = stockRange.lowerBound
        filterMaximumStock = stockRange.upperBound
        currentPage = 0
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

    func openWorkspace() {
        let panel = NSOpenPanel()
        panel.title = "Open WooDisplay workspace"
        panel.message = "Open a workspace containing the catalogue, logo, filters, omissions, layout, and theme."
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Open Workspace"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try loadWorkspace(from: url)
            workspaceStatusMessage = "Opened \(url.lastPathComponent)."
        } catch {
            workspaceStatusMessage = "The workspace could not be opened: \(error.localizedDescription)"
        }
    }

    func saveWorkspace() {
        let panel = NSSavePanel()
        panel.title = "Save WooDisplay workspace"
        panel.message = "Save a self-contained copy with the catalogue, logo, filters, omissions, layout, and theme."
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "WooDisplay-Workspace.json"
        panel.prompt = "Save Workspace"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try saveWorkspace(to: url)
            workspaceStatusMessage = "Saved a complete workspace copy to \(url.lastPathComponent)."
        } catch {
            workspaceStatusMessage = "The workspace could not be saved: \(error.localizedDescription)"
        }
    }

    func saveWorkspace(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let document = makeWorkspaceDocument()
        try encoder.encode(document).write(to: url, options: .atomic)
        savedWorkspaceSnapshot = try workspaceSnapshot(for: document)
        workspaceURL = url
    }

    func loadWorkspace(from url: URL) throws {
        let document = try JSONDecoder().decode(
            WooDisplayWorkspaceDocument.self,
            from: Data(contentsOf: url)
        )
        guard document.version <= WooDisplayWorkspaceDocument.currentVersion else {
            throw ThemeSettingsError.unsupportedVersion(document.version)
        }
        applyWorkspaceDocument(document)
        savedWorkspaceSnapshot = try workspaceSnapshot(for: document)
        workspaceURL = url
    }

    var hasUnsavedWorkspace: Bool {
        guard !products.isEmpty,
              let current = try? workspaceSnapshot(for: makeWorkspaceDocument()) else {
            return false
        }
        return current != savedWorkspaceSnapshot
    }

    func saveWorkspaceBeforeClosing() -> Bool {
        if let workspaceURL {
            do {
                try saveWorkspace(to: workspaceURL)
                return true
            } catch {
                workspaceStatusMessage = "The workspace could not be saved: \(error.localizedDescription)"
                return false
            }
        }

        let panel = NSSavePanel()
        panel.title = "Save WooDisplay workspace before closing"
        panel.message = "Choose where to save this complete workspace."
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "WooDisplay-Workspace.json"
        panel.prompt = "Save"
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try saveWorkspace(to: url)
            return true
        } catch {
            workspaceStatusMessage = "The workspace could not be saved: \(error.localizedDescription)"
            return false
        }
    }

    func confirmClosingWorkspace() -> Bool {
        guard hasUnsavedWorkspace else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes to this WooDisplay workspace?"
        alert.informativeText = "Your catalogue, layout, filters, omissions, logo, and theme have unsaved changes."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don’t Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveWorkspaceBeforeClosing()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func workspaceSnapshot(for document: WooDisplayWorkspaceDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    func makeWorkspaceDocument() -> WooDisplayWorkspaceDocument {
        WooDisplayWorkspaceDocument(
            sourceName: sourceName,
            products: products,
            currentPage: currentPage,
            inspectorMode: inspectorMode,
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
            catalogueTitle: catalogueTitle,
            companyLogoData: companyLogoData,
            companyLogoName: companyLogoName,
            companyLogoSize: companyLogoSize,
            showSellerInformation: showSellerInformation,
            sellerCompany: sellerCompany,
            sellerContactName: sellerContactName,
            sellerWebsite: sellerWebsite,
            sellerEmail: sellerEmail,
            sellerPhone: sellerPhone,
            groupByCategory: groupByCategory,
            sortOrder: sortOrder,
            productOrder: productOrder,
            categoryOrder: categoryOrder,
            omittedProductIDs: omittedProductIDs,
            excludedBrands: excludedBrands,
            excludedCategories: excludedCategories,
            priceFilterEnabled: priceFilterEnabled,
            filterMinimumPrice: filterMinimumPrice,
            filterMaximumPrice: filterMaximumPrice,
            stockFilterEnabled: stockFilterEnabled,
            filterMinimumStock: filterMinimumStock,
            filterMaximumStock: filterMaximumStock,
            excludeOutOfStock: excludeOutOfStock,
            selectedTheme: selectedTheme,
            customAccent: customAccent,
            customPageColor: customPageColor,
            customTextColor: customTextColor,
            customPriceColor: customPriceColor,
            customCardColor: customCardColor,
            customImageBackgroundColor: customImageBackgroundColor,
            customFont: customFont,
            customLayoutStyle: customLayoutStyle,
            customTextAlignment: customTextAlignment,
            customImageFit: customImageFit,
            customCornerStyle: customCornerStyle,
            customBorderStyle: customBorderStyle,
            customSpacing: customSpacing,
            categoryColorThemes: categoryColorThemes
        )
    }

    func applyWorkspaceDocument(_ document: WooDisplayWorkspaceDocument) {
        sourceName = document.sourceName
        products = document.products
        inspectorMode = document.inspectorMode
        showImage = document.showImage
        showName = document.showName
        showPrice = document.showPrice
        showSKU = document.showSKU
        showCategory = document.showCategory
        showStock = document.showStock
        showBrand = document.showBrand
        showDescription = document.showDescription
        productsPerPage = document.productsPerPage
        showPageHeader = document.showPageHeader
        catalogueTitle = document.catalogueTitle
        companyLogoData = document.companyLogoData
        companyLogoName = document.companyLogoName
        companyLogoSize = document.companyLogoSize
        showSellerInformation = document.showSellerInformation
        sellerCompany = document.sellerCompany
        sellerContactName = document.sellerContactName
        sellerWebsite = document.sellerWebsite
        sellerEmail = document.sellerEmail
        sellerPhone = document.sellerPhone
        groupByCategory = document.groupByCategory
        sortOrder = document.sortOrder
        productOrder = document.productOrder ?? document.products.map(\.id)
        categoryOrder = document.categoryOrder
        omittedProductIDs = document.omittedProductIDs
        excludedBrands = document.excludedBrands
        excludedCategories = document.excludedCategories
        priceFilterEnabled = document.priceFilterEnabled
        filterMinimumPrice = document.filterMinimumPrice
        filterMaximumPrice = document.filterMaximumPrice
        stockFilterEnabled = document.stockFilterEnabled
        filterMinimumStock = document.filterMinimumStock
        filterMaximumStock = document.filterMaximumStock
        excludeOutOfStock = document.excludeOutOfStock
        selectedTheme = document.selectedTheme
        customAccent = document.customAccent
        customPageColor = document.customPageColor
        customTextColor = document.customTextColor
        customPriceColor = document.customPriceColor
        customCardColor = document.customCardColor
        customImageBackgroundColor = document.customImageBackgroundColor
        customFont = document.customFont
        customLayoutStyle = document.customLayoutStyle
        customTextAlignment = document.customTextAlignment
        customImageFit = document.customImageFit
        customCornerStyle = document.customCornerStyle
        customBorderStyle = document.customBorderStyle
        customSpacing = document.customSpacing
        categoryColorThemes = document.categoryColorThemes
        previewSelection = nil
        swapSelection = nil
        errorMessage = nil
        currentPage = max(0, min(document.currentPage, pageCount - 1))
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
            productOrder = products.map(\.id)
            omittedProductIDs.removeAll()
            excludedBrands.removeAll()
            excludedCategories.removeAll()
            priceFilterEnabled = false
            stockFilterEnabled = false
            excludeOutOfStock = false
            let range = cataloguePriceRange
            filterMinimumPrice = range.lowerBound
            filterMaximumPrice = range.upperBound
            let stockRange = catalogueStockRange
            filterMinimumStock = stockRange.lowerBound
            filterMaximumStock = stockRange.upperBound
            previewSelection = nil
            swapSelection = nil
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
