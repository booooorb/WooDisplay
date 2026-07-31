import Foundation

@main
struct ModelSmokeTest {
    @MainActor
    static func main() {
        let store = CatalogueStore()
        precondition(store.products.count == 253)
        precondition(store.categoryPageRanges.count == 10)
        precondition(store.pageCount == 28)

        let originalFirstCategory = store.categoryOrder[0]
        let originalSecondCategory = store.categoryOrder[1]
        store.moveCategory(originalSecondCategory, direction: -1)
        precondition(store.categoryOrder[0] == originalSecondCategory)
        precondition(store.currentCataloguePage.category == originalSecondCategory)
        store.moveCategory(originalSecondCategory, direction: 1)
        precondition(store.categoryOrder[0] == originalFirstCategory)

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

        print("Model checks passed: categories, reordering, omission, restore, sorting, and pagination.")
    }
}
