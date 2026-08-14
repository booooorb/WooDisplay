import AppKit
import SwiftUI

enum AppPalette {
    static let window = Color(nsColor: .windowBackgroundColor)
    static let canvas = Color(
        nsColor: NSColor(name: NSColor.Name("WooDisplayCanvas")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0.135, green: 0.14, blue: 0.15, alpha: 1)
                : NSColor(srgbRed: 0.92, green: 0.93, blue: 0.95, alpha: 1)
        }
    )
    static let inspector = Color(nsColor: .controlBackgroundColor)
    static let controlSurface = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
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
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
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
    private var colors: CatalogueColorTheme { settings.colors(for: page.category) }

    var body: some View {
        VStack(spacing: 0) {
            if settings.showPageHeader {
                PreviewPageHeader(
                    settings: settings,
                    colors: colors,
                    category: page.category,
                    pageInCategory: page.pageInCategory,
                    categoryPageCount: page.categoryPageCount
                )
                    .frame(height: 58)
                    .padding(.horizontal, 30)
            } else {
                Color.clear.frame(height: 25)
            }

            productRows
                .padding(.horizontal, 30)
                .padding(.bottom, 11)

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                if settings.hasSellerInformation {
                    if !settings.sellerPrimaryLine.isEmpty {
                        Text(settings.sellerPrimaryLine)
                            .font(settings.font.swiftUIFont(size: 7.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                    }
                    if !settings.sellerContactLine.isEmpty {
                        Text(settings.sellerContactLine)
                            .font(settings.font.swiftUIFont(size: 7, weight: .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                    }
                }

                HStack {
                    Text("\(page.firstProductNumber)-\(page.lastProductNumber)")
                    Spacer()
                    Text("\(pageNumber) / \(pageCount)")
                }
                .font(settings.font.swiftUIFont(size: 8.5, weight: .medium))
            }
            .foregroundStyle(colors.text.swiftUIColor.opacity(0.55))
            .padding(.horizontal, 30)
            .frame(height: settings.hasSellerInformation ? 40 : 24)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .background(colors.page.swiftUIColor)
        .environment(\.colorScheme, colors.text == .white ? .dark : .light)
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
                                        colors: colors,
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
        let colors = settings.colors(for: product.catalogueCategory)
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProductImage(
                    url: product.primaryImageURL,
                    background: colors.imageBackground.swiftUIColor
                )
                .frame(width: 82, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(3)
                    Text(product.priceLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(colors.price.swiftUIColor)
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
    let colors: CatalogueColorTheme
    let category: String?
    let pageInCategory: Int
    let categoryPageCount: Int

    private var title: String {
        category.map { "Category: \($0)" } ?? settings.catalogueTitle
    }

    private var eyebrow: String {
        category == nil ? "ALL PRODUCTS" : settings.catalogueTitle.uppercased()
    }

    private var pageLabel: String {
        category == nil ? "CATALOGUE" : "CATEGORY PAGE \(pageInCategory) OF \(categoryPageCount)"
    }

    var body: some View {
        switch settings.layoutStyle {
        case .studio:
            HStack(spacing: 9) {
                companyLogo
                titleStack(titleSize: 16.5)
                Spacer()
                pageBadge
            }
            .foregroundStyle(colors.text.swiftUIColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(colors.text.swiftUIColor.opacity(0.14)).frame(height: 1)
            }
        case .editorial:
            ZStack {
                HStack {
                    companyLogo
                    Spacer()
                    pageBadge
                }
                titleStack(titleSize: 17, alignment: .center)
                    .frame(maxWidth: 280)
            }
            .foregroundStyle(colors.text.swiftUIColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(colors.accent.swiftUIColor).frame(width: 48, height: 2)
            }
        case .poster:
            HStack(spacing: 9) {
                companyLogo
                titleStack(titleSize: 17.5)
                Spacer()
                pageBadge
            }
            .foregroundStyle(colors.text.swiftUIColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(colors.accent.swiftUIColor).frame(height: 2)
            }
        case .gallery:
            HStack(spacing: 10) {
                companyLogo
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.accent.swiftUIColor)
                    .frame(width: 10, height: 28)
                titleStack(titleSize: 16)
                Spacer()
                pageBadge
            }
            .foregroundStyle(colors.text.swiftUIColor)
        }
    }

    @ViewBuilder
    private var companyLogo: some View {
        if let data = settings.companyLogoData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: CGFloat(settings.companyLogoSize),
                    height: CGFloat(settings.companyLogoSize)
                )
                .accessibilityLabel("Company logo")
        }
    }

    private func titleStack(
        titleSize: CGFloat,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 6.5, weight: .bold))
                .tracking(0.7)
                .opacity(0.62)
            Text(title)
                .font(settings.font.swiftUIFont(size: titleSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
    }

    private var pageBadge: some View {
        Text(pageLabel)
            .font(.system(size: 6.5, weight: .bold))
            .tracking(0.25)
            .foregroundStyle(colors.accent.contrastingText.swiftUIColor)
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(colors.accent.swiftUIColor)
            .clipShape(Capsule())
    }
}

private struct PreviewProductCell: View {
    let product: Product
    let settings: CatalogueSettingsSnapshot
    let colors: CatalogueColorTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            if settings.showImage {
                ProductImage(
                    url: product.primaryImageURL,
                    contentMode: settings.imageFit == .fill ? .fill : .fit,
                    background: colors.imageBackground.swiftUIColor
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
        .background(colors.card.swiftUIColor)
        .clipShape(cellShape)
        .overlay { cellBorder }
    }

    private var productText: some View {
        VStack(alignment: stackAlignment, spacing: 3) {
            if settings.showName {
                Text(product.name)
                    .font(settings.font.swiftUIFont(size: nameSize, weight: .semibold))
                    .foregroundStyle(colors.text.swiftUIColor)
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }

            if settings.showPrice {
                Text(product.priceLabel)
                    .font(settings.font.swiftUIFont(size: priceSize, weight: .bold))
                    .foregroundStyle(colors.price.swiftUIColor)
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
                .foregroundStyle(colors.text.swiftUIColor.opacity(0.65))
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)
        }
    }

    private func metadata(_ value: String) -> some View {
        Text(value)
            .font(settings.font.swiftUIFont(size: 7.5))
            .foregroundStyle(colors.text.swiftUIColor.opacity(0.62))
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
                    ? colors.accent.swiftUIColor
                    : colors.text.swiftUIColor.opacity(settings.borderStyle.opacity),
                lineWidth: isSelected ? max(2, settings.borderStyle.width) : settings.borderStyle.width
            )
        } else if isSelected {
            cellShape.stroke(colors.accent.swiftUIColor, lineWidth: 2)
        }
    }
}
