import Foundation

@main
struct ExportSmokeTest {
    @MainActor
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let csvURL = root.appendingPathComponent("wc-product-export-30-7-2026-1785460675095.csv")
        let table = try CSVParser.parse(url: csvURL)
        let products = try CatalogueBuilder.products(from: table)
        let cache = root.appendingPathComponent("tmp/pdfs/images")
        var images: [String: Data] = [:]
        for product in products {
            let path = cache.appendingPathComponent("\(product.id).jpg")
            if let data = try? Data(contentsOf: path) {
                images[product.id] = data
            }
        }

        let output = root.appendingPathComponent("tmp/native-pdf")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let categoryOrder = Array(Set(products.map(\.catalogueCategory))).sorted()

        for theme in CatalogueThemePreset.allCases where theme != .custom {
            let settings = makeSettings(theme: theme, categoryOrder: categoryOrder)
            try PDFCatalogueExporter.render(
                products: Array(products.prefix(12)),
                sourceName: csvURL.lastPathComponent,
                settings: settings,
                imageData: images,
                to: output.appendingPathComponent("\(theme.rawValue).pdf")
            )
        }

        let customSettings = CatalogueSettingsSnapshot(
            showImage: true,
            showName: true,
            showPrice: true,
            showSKU: true,
            showCategory: true,
            showStock: true,
            showBrand: true,
            showDescription: true,
            productsPerPage: 16,
            showPageHeader: false,
            catalogueTitle: "Custom Catalogue",
            groupByCategory: false,
            sortOrder: .categoryThenName,
            categoryOrder: categoryOrder,
            theme: .custom,
            accent: RGBAColor(red: 0.72, green: 0.18, blue: 0.36),
            pageColor: RGBAColor(red: 0.98, green: 0.95, blue: 0.88),
            textColor: .ink,
            priceColor: RGBAColor(red: 0.72, green: 0.18, blue: 0.36),
            cardColor: RGBAColor(red: 1, green: 0.98, blue: 0.92),
            imageBackgroundColor: RGBAColor(red: 0.95, green: 0.92, blue: 0.84),
            font: .baskerville,
            layoutStyle: .studio,
            textAlignment: .center,
            imageFit: .fill,
            cornerStyle: .rounded,
            borderStyle: .strong,
            spacing: .compact
        )
        try PDFCatalogueExporter.render(
            products: Array(products.prefix(16)),
            sourceName: csvURL.lastPathComponent,
            settings: customSettings,
            imageData: images,
            to: output.appendingPathComponent("custom-options.pdf")
        )

        let groupedSettings = makeSettings(
            theme: .studio,
            groupByCategory: true,
            categoryOrder: categoryOrder
        )
        let completeURL = output.appendingPathComponent("complete-studio.pdf")
        try PDFCatalogueExporter.render(
            products: products,
            sourceName: csvURL.lastPathComponent,
            settings: groupedSettings,
            imageData: images,
            to: completeURL
        )

        let finalOutput = root.appendingPathComponent("output/pdf/WooDisplay-Catalogue.pdf")
        try FileManager.default.createDirectory(
            at: finalOutput.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: finalOutput)
        try FileManager.default.copyItem(at: completeURL, to: finalOutput)

        try PDFCatalogueExporter.render(
            products: Array(products.dropFirst(2)),
            sourceName: csvURL.lastPathComponent,
            settings: groupedSettings,
            imageData: images,
            to: output.appendingPathComponent("grouped-omitted.pdf")
        )
        print("Rendered \(products.count) products, category grouping, omission, and all four themes.")
    }

    private static func makeSettings(
        theme: CatalogueThemePreset,
        groupByCategory: Bool = false,
        categoryOrder: [String]
    ) -> CatalogueSettingsSnapshot {
        CatalogueSettingsSnapshot(
            showImage: true,
            showName: true,
            showPrice: true,
            showSKU: false,
            showCategory: false,
            showStock: false,
            showBrand: false,
            showDescription: false,
            productsPerPage: 12,
            showPageHeader: true,
            catalogueTitle: "Product Catalogue",
            groupByCategory: groupByCategory,
            sortOrder: .categoryThenName,
            categoryOrder: categoryOrder,
            theme: theme,
            accent: theme.accent,
            pageColor: theme.pageColor,
            textColor: theme.textColor,
            priceColor: theme.priceColor,
            cardColor: theme.cardColor,
            imageBackgroundColor: theme.imageBackgroundColor,
            font: theme.font,
            layoutStyle: theme.layoutStyle,
            textAlignment: theme.textAlignment,
            imageFit: .contain,
            cornerStyle: theme.cornerStyle,
            borderStyle: theme.borderStyle,
            spacing: theme.spacing
        )
    }
}
