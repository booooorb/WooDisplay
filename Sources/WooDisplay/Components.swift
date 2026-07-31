import SwiftUI

enum AppPalette {
    static let canvas = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let inspector = Color(red: 0.975, green: 0.978, blue: 0.984)
    static let border = Color.black.opacity(0.12)
    static let secondaryText = Color(red: 0.38, green: 0.41, blue: 0.46)
    static let imageBackground = Color.black.opacity(0.035)
}

struct ProductImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit

    var body: some View {
        ZStack {
            AppPalette.imageBackground

            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.18))) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.small).tint(.secondary)
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: contentMode).transition(.opacity)
                    case .failure:
                        ImageFallback()
                    @unknown default:
                        ImageFallback()
                    }
                }
            } else {
                ImageFallback()
            }
        }
    }
}

struct ImageFallback: View {
    var body: some View {
        Image(systemName: "photo")
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(.tertiary)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    let accent: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(accent.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct PDFPagePreview: View {
    let products: [Product]
    let pageNumber: Int
    let pageCount: Int
    let settings: CatalogueSettingsSnapshot

    private let pageSize = CGSize(width: 612, height: 792)

    var body: some View {
        VStack(spacing: 0) {
            if settings.showPageHeader {
                PreviewPageHeader(settings: settings)
                    .frame(height: 58)
                    .padding(.horizontal, 30)
            } else {
                Color.clear.frame(height: 25)
            }

            productRows
                .padding(.horizontal, 30)
                .padding(.bottom, 11)

            Spacer(minLength: 0)

            HStack {
                Text("\(products.isEmpty ? 0 : ((pageNumber - 1) * settings.productsPerPage) + 1)–\(min(pageNumber * settings.productsPerPage, ((pageCount - 1) * settings.productsPerPage) + products.count))")
                Spacer()
                Text("\(pageNumber) / \(pageCount)")
            }
            .font(settings.font.swiftUIFont(size: 8.5, weight: .medium))
            .foregroundStyle(settings.textColor.swiftUIColor.opacity(0.55))
            .padding(.horizontal, 30)
            .frame(height: 24)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .background(settings.pageColor.swiftUIColor)
        .environment(\.colorScheme, settings.textColor == .white ? .dark : .light)
    }

    private var productRows: some View {
        GeometryReader { geometry in
            let gap = settings.layoutStyle == .poster ? 8.0 : 10.0
            let rowGap = settings.layoutStyle == .editorial ? 14.0 : gap
            let cellWidth = (geometry.size.width - (CGFloat(settings.columns - 1) * gap)) / CGFloat(settings.columns)
            let cellHeight = (geometry.size.height - (CGFloat(settings.rows - 1) * rowGap)) / CGFloat(settings.rows)

            VStack(spacing: rowGap) {
                ForEach(0..<settings.rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<settings.columns, id: \.self) { column in
                            let index = row * settings.columns + column
                            if index < products.count {
                                PreviewProductCell(product: products[index], settings: settings)
                                    .frame(width: cellWidth, height: cellHeight)
                            } else {
                                Color.clear.frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PreviewPageHeader: View {
    let settings: CatalogueSettingsSnapshot

    var body: some View {
        switch settings.layoutStyle {
        case .studio:
            HStack(alignment: .center) {
                Text(settings.catalogueTitle)
                    .font(settings.font.swiftUIFont(size: 17, weight: .bold))
                Spacer()
                Capsule()
                    .fill(settings.accent.swiftUIColor)
                    .frame(width: 35, height: 5)
            }
            .foregroundStyle(settings.textColor.swiftUIColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(settings.textColor.swiftUIColor.opacity(0.14)).frame(height: 1)
            }
        case .editorial:
            Text(settings.catalogueTitle)
                .font(settings.font.swiftUIFont(size: 18, weight: .semibold))
                .foregroundStyle(settings.textColor.swiftUIColor)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(settings.accent.swiftUIColor).frame(width: 48, height: 2)
                }
        case .poster:
            HStack {
                Text(settings.catalogueTitle.uppercased())
                    .font(settings.font.swiftUIFont(size: 21, weight: .bold))
                    .tracking(0.4)
                Spacer()
                Text("CATALOGUE")
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(settings.accent.swiftUIColor)
                    .foregroundStyle(settings.accent.contrastingText.swiftUIColor)
            }
            .foregroundStyle(settings.textColor.swiftUIColor)
        case .gallery:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(settings.accent.swiftUIColor)
                    .frame(width: 10, height: 28)
                Text(settings.catalogueTitle)
                    .font(settings.font.swiftUIFont(size: 16, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(settings.textColor.swiftUIColor)
        }
    }
}

private struct PreviewProductCell: View {
    let product: Product
    let settings: CatalogueSettingsSnapshot

    var body: some View {
        VStack(alignment: settings.layoutStyle == .editorial ? .center : .leading, spacing: 0) {
            if settings.showImage {
                ProductImage(url: product.primaryImageURL)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .padding(imageInset)
            }

            productText
                .padding(.horizontal, textInset)
                .padding(.top, settings.showImage ? 6 : 10)
                .padding(.bottom, 9)
        }
        .background(cellBackground)
        .clipShape(cellShape)
        .overlay { cellBorder }
    }

    private var productText: some View {
        VStack(alignment: settings.layoutStyle == .editorial ? .center : .leading, spacing: 3) {
            if settings.showName {
                Text(product.name)
                    .font(settings.font.swiftUIFont(size: nameSize, weight: .semibold))
                    .foregroundStyle(settings.textColor.swiftUIColor)
                    .lineLimit(2)
                    .multilineTextAlignment(settings.layoutStyle == .editorial ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: settings.layoutStyle == .editorial ? .center : .leading)
            }

            if settings.showPrice {
                Text(product.priceLabel)
                    .font(settings.font.swiftUIFont(size: priceSize, weight: .bold))
                    .foregroundStyle(priceColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            optionalMetadata
        }
    }

    @ViewBuilder
    private var optionalMetadata: some View {
        if settings.showSKU && !product.sku.isEmpty {
            metadata("SKU \(product.sku)")
        }
        if settings.showCategory {
            metadata(product.primaryCategory)
        }
        if settings.showStock {
            metadata(product.stockLabel)
        }
        if settings.showBrand && !product.brand.isEmpty {
            metadata(product.brand)
        }
        if settings.showDescription {
            Text(product.cleanDescription)
                .font(settings.font.swiftUIFont(size: 7.5))
                .foregroundStyle(settings.textColor.swiftUIColor.opacity(0.65))
                .lineLimit(2)
                .multilineTextAlignment(settings.layoutStyle == .editorial ? .center : .leading)
        }
    }

    private func metadata(_ value: String) -> some View {
        Text(value)
            .font(settings.font.swiftUIFont(size: 7.5))
            .foregroundStyle(settings.textColor.swiftUIColor.opacity(0.62))
            .lineLimit(1)
    }

    private var nameSize: CGFloat { settings.productsPerPage == 16 ? 8.5 : 10 }
    private var priceSize: CGFloat { settings.productsPerPage == 16 ? 8.5 : 10.5 }
    private var textInset: CGFloat { settings.layoutStyle == .poster ? 8 : 6 }
    private var imageInset: CGFloat { settings.layoutStyle == .gallery ? 8 : 0 }

    private var priceColor: Color {
        settings.layoutStyle == .poster ? settings.textColor.swiftUIColor : settings.accent.swiftUIColor
    }

    @ViewBuilder
    private var cellBackground: some View {
        switch settings.layoutStyle {
        case .studio, .editorial:
            Color.clear
        case .poster:
            settings.accent.swiftUIColor.opacity(0.12)
        case .gallery:
            Color.white.opacity(0.88)
        }
    }

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: settings.layoutStyle == .gallery ? 8 : 0, style: .continuous)
    }

    @ViewBuilder
    private var cellBorder: some View {
        switch settings.layoutStyle {
        case .studio:
            cellShape.stroke(settings.textColor.swiftUIColor.opacity(0.15), lineWidth: 0.75)
        case .editorial:
            cellShape.stroke(settings.accent.swiftUIColor.opacity(0.28), lineWidth: 0.7)
        case .poster:
            cellShape.stroke(settings.textColor.swiftUIColor, lineWidth: 2)
        case .gallery:
            cellShape.stroke(settings.accent.swiftUIColor.opacity(0.18), lineWidth: 0.75)
        }
    }
}
