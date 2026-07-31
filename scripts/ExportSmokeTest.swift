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

        for theme in CatalogueThemePreset.allCases where theme != .custom {
            let settings = makeSettings(theme: theme)
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
            theme: .custom,
            accent: RGBAColor(red: 0.72, green: 0.18, blue: 0.36),
            pageColor: RGBAColor(red: 0.98, green: 0.95, blue: 0.88),
            font: .menlo,
            layoutStyle: .studio
        )
        try PDFCatalogueExporter.render(
            products: Array(products.prefix(16)),
            sourceName: csvURL.lastPathComponent,
            settings: customSettings,
            imageData: images,
            to: output.appendingPathComponent("custom-options.pdf")
        )

        try PDFCatalogueExporter.render(
            products: products,
            sourceName: csvURL.lastPathComponent,
            settings: makeSettings(theme: .studio),
            imageData: images,
            to: output.appendingPathComponent("complete-studio.pdf")
        )
        print("Rendered \(products.count) products and all four theme presets.")
    }

    private static func makeSettings(theme: CatalogueThemePreset) -> CatalogueSettingsSnapshot {
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
            theme: theme,
            accent: theme.accent,
            pageColor: theme.pageColor,
            font: theme.font,
            layoutStyle: theme.layoutStyle
        )
    }
}
