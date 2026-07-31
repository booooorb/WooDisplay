import AppKit
import CoreGraphics
import Foundation
import ImageIO

enum PDFExportError: LocalizedError {
    case couldNotCreateDocument

    var errorDescription: String? {
        "The PDF document could not be created."
    }
}

enum PDFCatalogueExporter {
    private static let pageSize = CGSize(width: 612, height: 792)

    static func export(
        products: [Product],
        sourceName: String,
        settings: CatalogueSettingsSnapshot,
        to url: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        await progress(0.03)
        let imageData: [String: Data]
        if settings.showImage {
            imageData = await fetchImages(for: products) { completed, total in
                let fraction = total == 0 ? 1 : Double(completed) / Double(total)
                Task { @MainActor in progress(0.05 + (fraction * 0.65)) }
            }
        } else {
            imageData = [:]
        }

        await progress(0.72)
        try await MainActor.run {
            try render(
                products: products,
                sourceName: sourceName,
                settings: settings,
                imageData: imageData,
                to: url
            )
        }
        await progress(1)
    }

    static func fetchImages(
        for products: [Product],
        onProgress: @escaping @Sendable (_ completed: Int, _ total: Int) -> Void
    ) async -> [String: Data] {
        let productsWithImages = products.filter { $0.primaryImageURL != nil }
        let total = productsWithImages.count
        var result: [String: Data] = [:]
        var completed = 0
        let chunkSize = 10

        for start in stride(from: 0, to: productsWithImages.count, by: chunkSize) {
            let end = min(start + chunkSize, productsWithImages.count)
            let chunk = Array(productsWithImages[start..<end])

            await withTaskGroup(of: (String, Data?).self) { group in
                for product in chunk {
                    group.addTask {
                        guard let url = product.primaryImageURL else { return (product.id, nil) }
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 18
                        request.cachePolicy = .returnCacheDataElseLoad
                        do {
                            let (data, response) = try await URLSession.shared.data(for: request)
                            guard let http = response as? HTTPURLResponse,
                                  (200..<300).contains(http.statusCode),
                                  data.count < 18_000_000 else {
                                return (product.id, nil)
                            }
                            return (product.id, normalizedImageData(data) ?? data)
                        } catch {
                            return (product.id, nil)
                        }
                    }
                }

                for await (id, data) in group {
                    if let data { result[id] = data }
                    completed += 1
                    onProgress(completed, total)
                }
            }
        }
        return result
    }

    private static func normalizedImageData(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 900
                ] as CFDictionary
              ) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    @MainActor
    static func render(
        products: [Product],
        sourceName: String,
        settings: CatalogueSettingsSnapshot,
        imageData: [String: Data],
        to url: URL
    ) throws {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                [
                    kCGPDFContextTitle as String: settings.catalogueTitle,
                    kCGPDFContextAuthor as String: "WooDisplay",
                    kCGPDFContextSubject as String: "Generated from \(sourceName)",
                    kCGPDFContextCreator as String: "WooDisplay"
                ] as CFDictionary
              ) else {
            throw PDFExportError.couldNotCreateDocument
        }

        let pages = CataloguePaginator.pages(products: products, settings: settings)
        for (pageIndex, page) in pages.enumerated() {
            drawProductPage(
                context: context,
                page: page,
                imageData: imageData,
                pageNumber: pageIndex + 1,
                pageCount: pages.count,
                settings: settings
            )
        }
        context.closePDF()
    }

    @MainActor
    private static func drawProductPage(
        context: CGContext,
        page: CataloguePage,
        imageData: [String: Data],
        pageNumber: Int,
        pageCount: Int,
        settings: CatalogueSettingsSnapshot
    ) {
        let colors = settings.colors(for: page.category)
        beginPage(context, pageColor: colors.page.nsColor)

        let headerHeight: CGFloat = settings.showPageHeader ? 58 : 25
        if settings.showPageHeader {
            drawHeader(settings: settings, page: page, colors: colors)
        }

        let margin: CGFloat = 30
        let footerHeight: CGFloat = 24
        let bottomPadding: CGFloat = 11
        let gap = settings.spacing.gap
        let gridWidth = pageSize.width - margin * 2
        let gridHeight = pageSize.height - headerHeight - footerHeight - bottomPadding
        let cellWidth = (gridWidth - CGFloat(settings.columns - 1) * gap) / CGFloat(settings.columns)
        let cellHeight = (gridHeight - CGFloat(settings.rows - 1) * gap) / CGFloat(settings.rows)

        for (index, product) in page.products.enumerated() {
            let column = index % settings.columns
            let row = index / settings.columns
            let rect = CGRect(
                x: margin + CGFloat(column) * (cellWidth + gap),
                y: headerHeight + CGFloat(row) * (cellHeight + gap),
                width: cellWidth,
                height: cellHeight
            )
            drawProductCell(
                product,
                in: rect,
                imageData: imageData[product.id],
                settings: settings,
                colors: colors
            )
        }

        drawText(
            "\(page.firstProductNumber)-\(page.lastProductNumber)",
            in: CGRect(x: margin, y: pageSize.height - 18, width: 120, height: 11),
            font: settings.font.nsFont(size: 8.5, weight: .medium),
            color: colors.text.nsColor.withAlphaComponent(0.55)
        )
        drawText(
            "\(pageNumber) / \(pageCount)",
            in: CGRect(x: pageSize.width - margin - 120, y: pageSize.height - 18, width: 120, height: 11),
            font: settings.font.nsFont(size: 8.5, weight: .medium),
            color: colors.text.nsColor.withAlphaComponent(0.55),
            alignment: .right
        )
        endPage(context)
    }

    @MainActor
    private static func drawHeader(
        settings: CatalogueSettingsSnapshot,
        page: CataloguePage,
        colors: CatalogueColorTheme
    ) {
        let textColor = colors.text.nsColor
        let accent = colors.accent.nsColor
        let title = page.category.map { "Category: \($0)" } ?? settings.catalogueTitle
        let eyebrow = page.category == nil ? "ALL PRODUCTS" : settings.catalogueTitle.uppercased()
        let pageLabel = page.category == nil
            ? "CATALOGUE"
            : "CATEGORY PAGE \(page.pageInCategory) OF \(page.categoryPageCount)"

        let hasLogo = settings.companyLogoData.flatMap(NSImage.init(data:)) != nil
        if let logoData = settings.companyLogoData {
            drawCompanyLogo(data: logoData, in: CGRect(x: 30, y: 16, width: 30, height: 30))
        }
        let leadingTextX: CGFloat = hasLogo ? 70 : 30

        switch settings.layoutStyle {
        case .studio:
            drawEyebrow(eyebrow, x: leadingTextX, width: 410 - leadingTextX, settings: settings, color: textColor)
            drawText(
                title,
                in: CGRect(x: leadingTextX, y: 26, width: 430 - leadingTextX, height: 22),
                font: settings.font.nsFont(size: 16.5, weight: .semibold),
                color: textColor,
                truncation: .byTruncatingTail
            )
            drawHeaderBadge(pageLabel, rect: CGRect(x: 455, y: 25, width: 127, height: 19), colors: colors)
            textColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(rect: CGRect(x: 30, y: 57, width: 552, height: 0.8)).fill()

        case .editorial:
            drawEyebrow(eyebrow, x: 86, width: 390, settings: settings, color: textColor, alignment: .center)
            drawText(
                title,
                in: CGRect(x: 86, y: 26, width: 390, height: 22),
                font: settings.font.nsFont(size: 17, weight: .semibold),
                color: textColor,
                alignment: .center,
                truncation: .byTruncatingTail
            )
            drawHeaderBadge(pageLabel, rect: CGRect(x: 488, y: 25, width: 94, height: 19), colors: colors)
            accent.setFill()
            NSBezierPath(rect: CGRect(x: 282, y: 54, width: 48, height: 2)).fill()

        case .poster:
            drawEyebrow(eyebrow, x: leadingTextX, width: 430 - leadingTextX, settings: settings, color: textColor)
            drawText(
                title.uppercased(),
                in: CGRect(x: leadingTextX, y: 24, width: 445 - leadingTextX, height: 24),
                font: settings.font.nsFont(size: 19, weight: .bold),
                color: textColor,
                tracking: 0.35,
                truncation: .byTruncatingTail
            )
            drawHeaderBadge(pageLabel, rect: CGRect(x: 455, y: 24, width: 127, height: 21), colors: colors)

        case .gallery:
            accent.setFill()
            let accentX = hasLogo ? 69.0 : 30.0
            NSBezierPath(roundedRect: CGRect(x: accentX, y: 17, width: 8, height: 28), xRadius: 2, yRadius: 2).fill()
            let galleryTextX = accentX + 18
            drawEyebrow(eyebrow, x: galleryTextX, width: 427 - galleryTextX, settings: settings, color: textColor)
            drawText(
                title,
                in: CGRect(x: galleryTextX, y: 26, width: 427 - galleryTextX, height: 21),
                font: settings.font.nsFont(size: 16, weight: .semibold),
                color: textColor,
                truncation: .byTruncatingTail
            )
            drawHeaderBadge(pageLabel, rect: CGRect(x: 455, y: 25, width: 127, height: 19), colors: colors)
        }
    }

    @MainActor
    private static func drawCompanyLogo(data: Data, in rect: CGRect) {
        guard let image = NSImage(data: data) else { return }
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return }
        let scale = min(rect.width / sourceSize.width, rect.height / sourceSize.height)
        let fitted = CGRect(
            x: rect.midX - sourceSize.width * scale / 2,
            y: rect.midY - sourceSize.height * scale / 2,
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        NSGraphicsContext.saveGraphicsState()
        image.draw(
            in: fitted,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    @MainActor
    private static func drawEyebrow(
        _ text: String,
        x: CGFloat,
        width: CGFloat,
        settings: CatalogueSettingsSnapshot,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        drawText(
            text,
            in: CGRect(x: x, y: 17, width: width, height: 9),
            font: NSFont.systemFont(ofSize: 6.5, weight: .bold),
            color: color.withAlphaComponent(0.62),
            alignment: alignment,
            tracking: 0.7,
            truncation: .byTruncatingTail
        )
    }

    @MainActor
    private static func drawHeaderBadge(
        _ text: String,
        rect: CGRect,
        colors: CatalogueColorTheme
    ) {
        colors.accent.nsColor.setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: rect.height / 2,
            yRadius: rect.height / 2
        ).fill()
        drawText(
            text,
            in: CGRect(x: rect.minX + 5, y: rect.minY + 5, width: rect.width - 10, height: 9),
            font: NSFont.systemFont(ofSize: 6.5, weight: .bold),
            color: colors.accent.contrastingText.nsColor,
            alignment: .center,
            tracking: 0.25,
            truncation: .byTruncatingTail
        )
    }

    @MainActor
    private static func drawProductCell(
        _ product: Product,
        in rect: CGRect,
        imageData: Data?,
        settings: CatalogueSettingsSnapshot,
        colors: CatalogueColorTheme
    ) {
        let radius = settings.cornerStyle.radius
        let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let textColor = colors.text.nsColor
        colors.card.nsColor.setFill()
        shape.fill()

        if settings.borderStyle.width > 0 {
            textColor.withAlphaComponent(settings.borderStyle.opacity).setStroke()
            shape.lineWidth = settings.borderStyle.width
            shape.stroke()
        }

        let metadataCount = [
            settings.showSKU && !product.sku.isEmpty,
            settings.showCategory,
            settings.showStock,
            settings.showBrand && !product.brand.isEmpty
        ].filter { $0 }.count
        let nameHeight: CGFloat = settings.showName ? 27 : 0
        let priceHeight: CGFloat = settings.showPrice ? 15 : 0
        let descriptionHeight: CGFloat = settings.showDescription ? 20 : 0
        let metadataHeight = CGFloat(metadataCount) * 10
        let textPadding: CGFloat = 15
        let reservedTextHeight = nameHeight + priceHeight + descriptionHeight + metadataHeight + textPadding

        var textTop = rect.minY + 9
        if settings.showImage {
            let inset: CGFloat = settings.cornerStyle == .rounded ? 8 : 0
            let maximumImageHeight = max(24, rect.height - reservedTextHeight)
            let preferredImageHeight = rect.height * (settings.productsPerPage == 6 ? 0.70 : 0.66)
            let imageHeight = min(preferredImageHeight, maximumImageHeight)
            let imageRect = CGRect(
                x: rect.minX + inset,
                y: rect.minY + inset,
                width: rect.width - inset * 2,
                height: max(20, imageHeight - inset)
            )
            colors.imageBackground.nsColor.setFill()
            NSBezierPath(
                roundedRect: imageRect,
                xRadius: settings.cornerStyle == .rounded ? 5 : 0,
                yRadius: settings.cornerStyle == .rounded ? 5 : 0
            ).fill()

            if let imageData, let image = NSImage(data: imageData) {
                let target = imageRect.insetBy(dx: 4, dy: 4)
                let fitted = settings.imageFit == .fill
                    ? aspectFill(image.size, inside: target)
                    : aspectFit(image.size, inside: target)
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: imageRect).addClip()
                image.draw(
                    in: fitted,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
                NSGraphicsContext.restoreGraphicsState()
            } else {
                drawText(
                    "No image",
                    in: CGRect(x: imageRect.minX, y: imageRect.midY - 5, width: imageRect.width, height: 12),
                    font: NSFont.systemFont(ofSize: 8.5),
                    color: textColor.withAlphaComponent(0.35),
                    alignment: .center
                )
            }
            textTop = imageRect.maxY + 6
        }

        let horizontalInset: CGFloat = settings.layoutStyle == .poster ? 8 : 6
        let textRect = CGRect(
            x: rect.minX + horizontalInset,
            y: textTop,
            width: rect.width - horizontalInset * 2,
            height: rect.maxY - textTop - 7
        )
        let alignment: NSTextAlignment
        switch settings.textAlignment {
        case .leading: alignment = .left
        case .center: alignment = .center
        case .trailing: alignment = .right
        }
        var cursor = textRect.minY
        let nameSize: CGFloat = settings.productsPerPage == 16 ? 8.5 : 10
        let priceSize: CGFloat = settings.productsPerPage == 16 ? 8.5 : 10.5

        if settings.showName {
            drawText(
                product.name,
                in: CGRect(x: textRect.minX, y: cursor, width: textRect.width, height: nameHeight),
                font: settings.font.nsFont(size: nameSize, weight: .semibold),
                color: textColor,
                alignment: alignment,
                lineHeight: nameSize + 2,
                truncation: .byWordWrapping
            )
            cursor += nameHeight
        }

        if settings.showPrice {
            drawText(
                product.priceLabel,
                in: CGRect(x: textRect.minX, y: cursor, width: textRect.width, height: priceHeight),
                font: settings.font.nsFont(size: priceSize, weight: .bold),
                color: colors.price.nsColor,
                alignment: alignment,
                truncation: .byTruncatingTail
            )
            cursor += priceHeight
        }

        let metadataColor = textColor.withAlphaComponent(0.62)
        func drawMetadata(_ value: String) {
            drawText(
                value,
                in: CGRect(x: textRect.minX, y: cursor, width: textRect.width, height: 10),
                font: settings.font.nsFont(size: 7.5),
                color: metadataColor,
                alignment: alignment,
                truncation: .byTruncatingTail
            )
            cursor += 10
        }

        if settings.showSKU && !product.sku.isEmpty { drawMetadata("SKU \(product.sku)") }
        if settings.showCategory { drawMetadata(product.primaryCategory) }
        if settings.showStock { drawMetadata(product.stockLabel) }
        if settings.showBrand && !product.brand.isEmpty { drawMetadata(product.brand) }
        if settings.showDescription {
            drawText(
                product.cleanDescription,
                in: CGRect(x: textRect.minX, y: cursor, width: textRect.width, height: descriptionHeight),
                font: settings.font.nsFont(size: 7.5),
                color: textColor.withAlphaComponent(0.65),
                alignment: alignment,
                lineHeight: 9,
                truncation: .byWordWrapping
            )
        }
    }

    @MainActor
    private static func beginPage(_ context: CGContext, pageColor: NSColor) {
        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: 0, y: pageSize.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        pageColor.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: pageSize)).fill()
    }

    @MainActor
    private static func endPage(_ context: CGContext) {
        NSGraphicsContext.current = nil
        context.restoreGState()
        context.endPDFPage()
    }

    @MainActor
    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left,
        lineHeight: CGFloat? = nil,
        tracking: CGFloat = 0,
        truncation: NSLineBreakMode = .byWordWrapping
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = truncation
        if let lineHeight {
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
        }
        NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
                .kern: tracking
            ]
        ).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    private static func aspectFit(_ source: CGSize, inside rect: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return rect }
        let scale = min(rect.width / source.width, rect.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func aspectFill(_ source: CGSize, inside rect: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return rect }
        let scale = max(rect.width / source.width, rect.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
