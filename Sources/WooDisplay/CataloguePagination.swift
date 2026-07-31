import Foundation

struct CataloguePage: Identifiable, Sendable {
    let id: String
    let products: [Product]
    let category: String?
    let pageInCategory: Int
    let categoryPageCount: Int
    let firstProductNumber: Int
    let lastProductNumber: Int
}

struct CategoryPageRange: Identifiable, Sendable {
    let name: String
    let startPage: Int
    let endPage: Int
    let productCount: Int

    var id: String { name }
    var pageLabel: String {
        startPage == endPage ? "\(startPage)" : "\(startPage)-\(endPage)"
    }
}

enum CataloguePaginator {
    static func pages(
        products: [Product],
        settings: CatalogueSettingsSnapshot
    ) -> [CataloguePage] {
        guard !products.isEmpty else {
            return [
                CataloguePage(
                    id: "empty",
                    products: [],
                    category: nil,
                    pageInCategory: 1,
                    categoryPageCount: 1,
                    firstProductNumber: 0,
                    lastProductNumber: 0
                )
            ]
        }

        if settings.groupByCategory {
            return groupedPages(products: products, settings: settings)
        }

        let ordered = sort(products, by: settings.sortOrder, categoryOrder: settings.categoryOrder)
        return chunk(
            ordered,
            category: nil,
            productsPerPage: settings.productsPerPage,
            startingAt: 1
        )
    }

    static func ranges(for pages: [CataloguePage]) -> [CategoryPageRange] {
        var ranges: [CategoryPageRange] = []
        for (index, page) in pages.enumerated() {
            guard let category = page.category else { continue }
            if let last = ranges.last, last.name == category {
                ranges[ranges.count - 1] = CategoryPageRange(
                    name: last.name,
                    startPage: last.startPage,
                    endPage: index + 1,
                    productCount: last.productCount + page.products.count
                )
            } else {
                ranges.append(
                    CategoryPageRange(
                        name: category,
                        startPage: index + 1,
                        endPage: index + 1,
                        productCount: page.products.count
                    )
                )
            }
        }
        return ranges
    }

    private static func groupedPages(
        products: [Product],
        settings: CatalogueSettingsSnapshot
    ) -> [CataloguePage] {
        let grouped = Dictionary(grouping: products, by: \.catalogueCategory)
        let known = Set(grouped.keys)
        let requestedOrder = settings.categoryOrder.filter { known.contains($0) }
        let missing = known.subtracting(requestedOrder).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        let categoryOrder = requestedOrder + missing

        var pages: [CataloguePage] = []
        var productNumber = 1
        for category in categoryOrder {
            let categoryProducts = sort(
                grouped[category] ?? [],
                by: settings.sortOrder == .categoryThenName ? .name : settings.sortOrder,
                categoryOrder: categoryOrder
            )
            let categoryPages = chunk(
                categoryProducts,
                category: category,
                productsPerPage: settings.productsPerPage,
                startingAt: productNumber
            )
            pages.append(contentsOf: categoryPages)
            productNumber += categoryProducts.count
        }
        return pages
    }

    private static func sort(
        _ products: [Product],
        by order: CatalogueSortOrder,
        categoryOrder: [String]
    ) -> [Product] {
        let categoryRanks = Dictionary(uniqueKeysWithValues: categoryOrder.enumerated().map {
            ($0.element, $0.offset)
        })

        switch order {
        case .categoryThenName:
            return products.sorted {
                let lhsRank = categoryRanks[$0.catalogueCategory] ?? Int.max
                let rhsRank = categoryRanks[$1.catalogueCategory] ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .name:
            return products.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .priceLow:
            return products.sorted {
                ($0.currentPrice ?? .greatestFiniteMagnitude) < ($1.currentPrice ?? .greatestFiniteMagnitude)
            }
        case .priceHigh:
            return products.sorted {
                ($0.currentPrice ?? -.greatestFiniteMagnitude) > ($1.currentPrice ?? -.greatestFiniteMagnitude)
            }
        }
    }

    private static func chunk(
        _ products: [Product],
        category: String?,
        productsPerPage: Int,
        startingAt firstProductNumber: Int
    ) -> [CataloguePage] {
        var result: [CataloguePage] = []
        for start in stride(from: 0, to: products.count, by: productsPerPage) {
            let end = min(start + productsPerPage, products.count)
            let pageProducts = Array(products[start..<end])
            let pageCount = max(1, Int(ceil(Double(products.count) / Double(productsPerPage))))
            result.append(
                CataloguePage(
                    id: "\(category ?? "all")-\(start)",
                    products: pageProducts,
                    category: category,
                    pageInCategory: (start / productsPerPage) + 1,
                    categoryPageCount: pageCount,
                    firstProductNumber: firstProductNumber + start,
                    lastProductNumber: firstProductNumber + end - 1
                )
            )
        }
        return result
    }
}
