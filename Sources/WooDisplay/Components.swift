import SwiftUI

enum AppPalette {
    static let canvas = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let inspector = Color(red: 0.975, green: 0.978, blue: 0.984)
    static let border = Color.black.opacity(0.12)
    static let secondaryText = Color(red: 0.38, green: 0.41, blue: 0.46)
}

struct ProductImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit
    var background = Color.black.opacity(0.035)

    var body: some View {
        ZStack {
            background
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
    let page: CataloguePage
    let pageNumber: Int
    let pageCount: Int
    let settings: CatalogueSettingsSnapshot
    var selectedProductID: String?
    var onSelectProduct: ((Product) -> Void)?

    private let pageSize = CGSize(width: 612, height: 792)

    var body: some View {
        VStack(spacing: 0) {
            if settings.showPageHeader {
                PreviewPageHeader(settings: settings, category: page.category)
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
                Text("\(page.firstProductNumber)-\(page.lastProductNumber)")
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
            let gap = settings.spacing.gap
            let cellWidth = (geometry.size.width - (CGFloat(settings.columns - 1) * gap)) / CGFloat(settings.columns)
            let cellHeight = (geometry.size.height - (CGFloat(settings.rows - 1) * gap)) / CGFloat(settings.rows)

            VStack(spacing: gap) {
                ForEach(0..<settings.rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<settings.columns, id: \.self) { column in
                            let index = row * settings.columns + column
                            if index < page.products.count {
                                let product = page.products[index]
                                Button {
                                    onSelectProduct?(product)
                                } label: {
                                    PreviewProductCell(
                                        product: product,
                                        settings: settings,
                                        isSelected: selectedProductID == product.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .help("Product options")
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

struct ProductOmitPopover: View {
    let product: Product
    let settings: CatalogueSettingsSnapshot
    let omit: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProductImage(
                    url: product.primaryImageURL,
                    background: settings.imageBackgroundColor.swiftUIColor
                )
                .frame(width: 82, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(3)
                    Text(product.priceLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(settings.priceColor.swiftUIColor)
                    Text(product.catalogueCategory)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: omit) {
                Label("Omit from catalogue", systemImage: "eye.slash")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 27)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.red.opacity(0.72))
                    }
            }
            .buttonStyle(.plain)

            Button("Cancel", action: cancel)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 270)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}

private struct PreviewPageHeader: View {
    let settings: CatalogueSettingsSnapshot
    let category: String?

    private var title: String {
        guard let category else { return settings.catalogueTitle }
        return "\(settings.catalogueTitle) / \(category)"
    }

    var body: some View {
        switch settings.layoutStyle {
        case .studio:
            HStack {
                Text(title)
                    .font(settings.font.swiftUIFont(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Capsule().fill(settings.accent.swiftUIColor).frame(width: 35, height: 5)
            }
            .foregroundStyle(settings.textColor.swiftUIColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(settings.textColor.swiftUIColor.opacity(0.14)).frame(height: 1)
            }
        case .editorial:
            Text(title)
                .font(settings.font.swiftUIFont(size: 18, weight: .semibold))
                .foregroundStyle(settings.textColor.swiftUIColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(settings.accent.swiftUIColor).frame(width: 48, height: 2)
                }
        case .poster:
            HStack {
                Text(title.uppercased())
                    .font(settings.font.swiftUIFont(size: 21, weight: .bold))
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
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
                Text(title)
                    .font(settings.font.swiftUIFont(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
            }
            .foregroundStyle(settings.textColor.swiftUIColor)
        }
    }
}

private struct PreviewProductCell: View {
    let product: Product
    let settings: CatalogueSettingsSnapshot
    let isSelected: Bool

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            if settings.showImage {
                ProductImage(
                    url: product.primaryImageURL,
                    contentMode: settings.imageFit == .fill ? .fill : .fit,
                    background: settings.imageBackgroundColor.swiftUIColor
                )
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
        .background(settings.cardColor.swiftUIColor)
        .clipShape(cellShape)
        .overlay { cellBorder }
    }

    private var productText: some View {
        VStack(alignment: stackAlignment, spacing: 3) {
            if settings.showName {
                Text(product.name)
                    .font(settings.font.swiftUIFont(size: nameSize, weight: .semibold))
                    .foregroundStyle(settings.textColor.swiftUIColor)
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }

            if settings.showPrice {
                Text(product.priceLabel)
                    .font(settings.font.swiftUIFont(size: priceSize, weight: .bold))
                    .foregroundStyle(settings.priceColor.swiftUIColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            optionalMetadata
        }
    }

    @ViewBuilder
    private var optionalMetadata: some View {
        if settings.showSKU && !product.sku.isEmpty { metadata("SKU \(product.sku)") }
        if settings.showCategory { metadata(product.catalogueCategory) }
        if settings.showStock { metadata(product.stockLabel) }
        if settings.showBrand && !product.brand.isEmpty { metadata(product.brand) }
        if settings.showDescription {
            Text(product.cleanDescription)
                .font(settings.font.swiftUIFont(size: 7.5))
                .foregroundStyle(settings.textColor.swiftUIColor.opacity(0.65))
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)
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

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: settings.cornerStyle.radius, style: .continuous)
    }

    private var stackAlignment: HorizontalAlignment {
        switch settings.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var textAlignment: TextAlignment {
        switch settings.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch settings.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    @ViewBuilder
    private var cellBorder: some View {
        if settings.borderStyle.width > 0 {
            cellShape.stroke(
                isSelected
                    ? settings.accent.swiftUIColor
                    : settings.textColor.swiftUIColor.opacity(settings.borderStyle.opacity),
                lineWidth: isSelected ? max(2, settings.borderStyle.width) : settings.borderStyle.width
            )
        } else if isSelected {
            cellShape.stroke(settings.accent.swiftUIColor, lineWidth: 2)
        }
    }
}
