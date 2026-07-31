import Foundation

@main
struct ModelSmokeTest {
    @MainActor
    static func main() throws {
        let store = CatalogueStore()
        precondition(store.products.count == 253)
        precondition(CatalogueThemePreset.allCases.filter { $0 != .custom }.count == 8)
        precondition(store.inspectorMode == .layout)
        store.inspectorMode = .theme
        precondition(store.inspectorMode == .theme)
        store.inspectorMode = .layout
        precondition(store.categoryPageRanges.count == 10)
        precondition(store.pageCount == 28)

        let originalFirstCategory = store.categoryOrder[0]
        let originalSecondCategory = store.categoryOrder[1]
        store.moveCategory(originalSecondCategory, direction: -1)
        precondition(store.categoryOrder[0] == originalSecondCategory)
        precondition(store.currentCataloguePage.category == originalSecondCategory)
        store.moveCategory(originalSecondCategory, direction: 1)
        precondition(store.categoryOrder[0] == originalFirstCategory)
        precondition(store.currentCataloguePage.pageInCategory == 1)
        precondition(store.currentCataloguePage.categoryPageCount > 1)

        let categoryAccent = RGBAColor(red: 0.82, green: 0.20, blue: 0.28)
        store.enableCustomColors(for: originalFirstCategory)
        store.customizeCategoryAccent(categoryAccent, category: originalFirstCategory)
        precondition(store.settings.colors(for: originalFirstCategory).accent == categoryAccent)
        precondition(store.settings.colors(for: originalSecondCategory).accent != categoryAccent)

        let encodedTheme = try JSONEncoder().encode(store.makeThemeDocument())
        let decodedTheme = try JSONDecoder().decode(CatalogueThemeDocument.self, from: encodedTheme)
        store.resetAllCategoryColors()
        try store.applyThemeDocument(decodedTheme)
        precondition(store.settings.colors(for: originalFirstCategory).accent == categoryAccent)

        let themeURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("tmp/qa/WooDisplay-Theme.json")
        try store.saveThemeSettings(to: themeURL)
        store.resetAllCategoryColors()
        try store.loadThemeSettings(from: themeURL)
        precondition(store.settings.colors(for: originalFirstCategory).accent == categoryAccent)

        let product = store.currentCataloguePage.products[0]
        store.previewSelection = product
        store.omit(product)
        precondition(store.includedProducts.count == 252)
        precondition(store.omittedProductIDs.contains(product.id))
        precondition(store.previewSelection == nil)
        store.restore(product)
        precondition(store.includedProducts.count == 253)

        store.setGroupByCategory(false)
        store.setSortOrder(.priceLow)
        precondition(store.currentCataloguePage.category == nil)
        precondition(store.pageCount == 22)

        print("Model checks passed: two-mode settings, eight presets, category colors, theme round-trip, omission, sorting, and pagination.")
    }
}
