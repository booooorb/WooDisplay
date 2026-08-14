import Foundation

struct Product: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let type: String
    let sku: String
    let name: String
    let shortDescription: String
    let description: String
    let regularPrice: Double?
    let salePrice: Double?
    let variationPrices: [Double]
    let categories: [String]
    let tags: [String]
    let imageURLs: [URL]
    let isInStock: Bool
    let stockQuantity: Int?
    let brand: String
    let attributeName: String
    let attributeValues: [String]
    let isFeatured: Bool

    var primaryImageURL: URL? { imageURLs.first }

    var currentPrice: Double? {
        salePrice ?? regularPrice ?? variationPrices.min()
    }

    var highestPrice: Double? {
        variationPrices.max() ?? currentPrice
    }

    var priceLabel: String {
        guard let low = currentPrice else { return "Price on request" }
        if let high = highestPrice, abs(high - low) > 0.005 {
            return "\(money(low)) – \(money(high))"
        }
        return money(low)
    }

    var originalPriceLabel: String? {
        guard let salePrice, let regularPrice, salePrice < regularPrice else { return nil }
        return money(regularPrice)
    }

    var stockLabel: String {
        if isInStock {
            if let stockQuantity, stockQuantity > 0 {
                return "In stock (\(stockQuantity))"
            }
            return "In stock"
        }
        return "Out of stock"
    }

    var primaryCategory: String {
        categories.first ?? "Uncategorised"
    }

    var catalogueCategory: String {
        primaryCategory.components(separatedBy: ">").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? primaryCategory
    }

    var cleanDescription: String {
        let source = shortDescription.isEmpty ? description : shortDescription
        let stripped = source
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped.isEmpty ? "No product description is available." : stripped
    }

    var searchText: String {
        ([name, sku, brand, description, shortDescription] + categories + tags)
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func money(_ value: Double) -> String {
        "CA$" + value.formatted(.number.precision(.fractionLength(2)))
    }
}

enum CatalogueBuilder {
    static func products(from table: CSVTable) throws -> [Product] {
        let variationRows = table.rows.filter { $0["Type"] == "variation" }
        let variationsByParent = Dictionary(grouping: variationRows) { row in
            (row["Parent"] ?? "").replacingOccurrences(of: "id:", with: "")
        }

        let products = table.rows.compactMap { row -> Product? in
            let type = row["Type"] ?? ""
            guard type != "variation", row["Published"] == "1" else { return nil }

            let id = row["ID"] ?? UUID().uuidString
            let variations = variationsByParent[id] ?? []
            let variationPrices = variations.compactMap { price(from: $0) }
            let variationStock = variations.contains { $0["In stock?"] == "1" }
            let parentInStock = row["In stock?"] == "1"

            let parentAttributes = splitList(row["Attribute 1 value(s)"] ?? "")
            let variationAttributes = variations.compactMap { $0["Attribute 1 value(s)"] }
            let attributes = orderedUnique(parentAttributes + variationAttributes)

            return Product(
                id: id,
                type: type,
                sku: row["SKU"]?.trimmed ?? "",
                name: row["Name"]?.trimmed ?? "Untitled product",
                shortDescription: row["Short description"] ?? "",
                description: row["Description"] ?? "",
                regularPrice: double(row["Regular price"]),
                salePrice: double(row["Sale price"]),
                variationPrices: variationPrices,
                categories: splitList(row["Categories"] ?? ""),
                tags: splitList(row["Tags"] ?? ""),
                imageURLs: imageURLs(row["Images"] ?? ""),
                isInStock: parentInStock || variationStock,
                stockQuantity: int(row["Stock"]),
                brand: row["Brands"]?.trimmed ?? "",
                attributeName: row["Attribute 1 name"]?.trimmed ?? "",
                attributeValues: attributes,
                isFeatured: row["Is featured?"] == "1"
            )
        }

        guard !products.isEmpty else {
            throw CSVParserError.emptyCatalogue
        }

        return products.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func price(from row: [String: String]) -> Double? {
        double(row["Sale price"]) ?? double(row["Regular price"])
    }

    private static func double(_ value: String?) -> Double? {
        guard let value = value?.trimmed, !value.isEmpty else { return nil }
        return Double(value.replacingOccurrences(of: ",", with: ""))
    }

    private static func int(_ value: String?) -> Int? {
        guard let value = value?.trimmed, !value.isEmpty else { return nil }
        return Int(Double(value) ?? 0)
    }

    private static func splitList(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    private static func imageURLs(_ value: String) -> [URL] {
        splitList(value).compactMap { URL(string: $0) }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
