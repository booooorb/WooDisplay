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

        let pageCount = max(1, Int(ceil(Double(products.count) / Double(settings.productsPerPage))))
        for pageIndex in 0..<pageCount {
            let start = pageIndex * settings.productsPerPage
            let end = min(start + settings.productsPerPage, products.count)
            let pageProducts = start < products.count ? Array(products[start..<end]) : []
            drawProductPage(
                context: context,
                products: pageProducts,
                imageData: imageData,
                pageNumber: pageIndex + 1,
                pageCount: pageCount,
                totalProducts: products.count,
                settings: settings
            )
        }
        context.closePDF()
    }

    @MainActor
    private static func drawProductPage(
        context: CGContext,
        products: [Product],
        imageData: [String: Data],
        pageNumber: Int,
        pageCount: Int,
        totalProducts: Int,
        settings: CatalogueSettingsSnapshot
    ) {
        beginPage(context, pageColor: settings.pageColor.nsColor)

        let headerHeight: CGFloat = settings.showPageHeader ? 58 : 25
        if settings.showPageHeader {
            drawHeader(settings: settings)
        }

        let margin: CGFloat = 30
        let footerHeight: CGFloat = 24
        let bottomPadding: CGFloat = 11
        let gap: CGFloat = settings.layoutStyle == .poster ? 8 : 10
        let rowGap: CGFloat = settings.layoutStyle == .editorial ? 14 : gap
        let gridWidth = pageSize.width - margin * 2
        let gridHeight = pageSize.height - headerHeight - footerHeight - bottomPadding
        let cellWidth = (gridWidth - CGFloat(settings.columns - 1) * gap) / CGFloat(settings.columns)
        let cellHeight = (gridHeight - CGFloat(settings.rows - 1) * rowGap) / CGFloat(settings.rows)

        for (index, product) in products.enumerated() {
            let column = index % settings.columns
            let row = index / settings.columns
            let rect = CGRect(
                x: margin + CGFloat(column) * (cellWidth + gap),
                y: headerHeight + CGFloat(row) * (cellHeight + rowGap),
                width: cellWidth,
                height: cellHeight
            )
            drawProductCell(
                product,
                in: rect,
                imageData: imageData[product.id],
                settings: settings
            )
        }

        let firstProduct = products.isEmpty ? 0 : ((pageNumber - 1) * settings.productsPerPage) + 1
        let lastProduct = min(pageNumber * settings.productsPerPage, totalProducts)
        drawText(
            "\(firstProduct)–\(lastProduct)",
            in: CGRect(x: margin, y: pageSize.height - 18, width: 120, height: 11),
            font: settings.font.nsFont(size: 8.5, weight: .medium),
            color: settings.textColor.nsColor.withAlphaComponent(0.55)
        )
        drawText(
            "\(pageNumber) / \(pageCount)",
            in: CGRect(x: pageSize.width - margin - 120, y: pageSize.height - 18, width: 120, height: 11),
            font: settings.font.nsFont(size: 8.5, weight: .medium),
            color: settings.textColor.nsColor.withAlphaComponent(0.55),
            alignment: .right
        )
        endPage(context)
    }

    @MainActor
    private static func drawHeader(settings: CatalogueSettingsSnapshot) {
        let textColor = settings.textColor.nsColor
        let accent = settings.accent.nsColor

        switch settings.layoutStyle {
        case .studio:
            drawText(
                settings.catalogueTitle,
                in: CGRect(x: 30, y: 23, width: 400, height: 24),
                font: settings.font.nsFont(size: 17, weight: .bold),
                color: textColor
            )
            accent.setFill()
            NSBezierPath(roundedRect: CGRect(x: 547, y: 31, width: 35, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
            textColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(rect: CGRect(x: 30, y: 57, width: 552, height: 0.8)).fill()

        case .editorial:
            drawText(
                settings.catalogueTitle,
                in: CGRect(x: 106, y: 21, width: 400, height: 25),
                font: settings.font.nsFont(size: 18, weight: .semibold),
                color: textColor,
                alignment: .center
            )
            accent.setFill()
            NSBezierPath(rect: CGRect(x: 282, y: 54, width: 48, height: 2)).fill()

        case .poster:
            drawText(
                settings.catalogueTitle.uppercased(),
                in: CGRect(x: 30, y: 18, width: 425, height: 29),
                font: settings.font.nsFont(size: 21, weight: .bold),
                color: textColor,
                tracking: 0.4
            )
            accent.setFill()
            NSBezierPath(rect: CGRect(x: 500, y: 23, width: 82, height: 22)).fill()
            drawText(
                "CATALOGUE",
                in: CGRect(x: 505, y: 29, width: 72, height: 10),
                font: NSFont.systemFont(ofSize: 8, weight: .black),
                color: settings.accent.contrastingText.nsColor,
                alignment: .center,
                tracking: 0.5
            )

        case .gallery:
            accent.setFill()
            NSBezierPath(roundedRect: CGRect(x: 30, y: 17, width: 10, height: 28), xRadius: 2, yRadius: 2).fill()
            drawText(
                settings.catalogueTitle,
                in: CGRect(x: 50, y: 23, width: 430, height: 22),
                font: settings.font.nsFont(size: 16, weight: .semibold),
                color: textColor
            )
        }
    }

    @MainActor
    private static func drawProductCell(
        _ product: Product,
        in rect: CGRect,
        imageData: Data?,
        settings: CatalogueSettingsSnapshot
    ) {
        let radius: CGFloat = settings.layoutStyle == .gallery ? 8 : 0
        let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let textColor = settings.textColor.nsColor
        let accent = settings.accent.nsColor

        switch settings.layoutStyle {
        case .studio, .editorial:
            NSColor.clear.setFill()
            shape.fill()
        case .poster:
            accent.withAlphaComponent(0.12).setFill()
            shape.fill()
        case .gallery:
            NSColor.white.withAlphaComponent(0.88).setFill()
            shape.fill()
        }

        switch settings.layoutStyle {
        case .studio:
            textColor.withAlphaComponent(0.15).setStroke()
            shape.lineWidth = 0.75
        case .editorial:
            accent.withAlphaComponent(0.28).setStroke()
            shape.lineWidth = 0.7
        case .poster:
            textColor.setStroke()
            shape.lineWidth = 2
        case .gallery:
            accent.withAlphaComponent(0.18).setStroke()
            shape.lineWidth = 0.75
        }
        shape.stroke()

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
            let inset: CGFloat = settings.layoutStyle == .gallery ? 8 : 0
            let maximumImageHeight = max(24, rect.height - reservedTextHeight)
            let preferredImageHeight = rect.height * (settings.productsPerPage == 6 ? 0.70 : 0.66)
            let imageHeight = min(preferredImageHeight, maximumImageHeight)
            let imageRect = CGRect(
                x: rect.minX + inset,
                y: rect.minY + inset,
                width: rect.width - inset * 2,
                height: max(20, imageHeight - inset)
            )
            textColor.withAlphaComponent(0.035).setFill()
            NSBezierPath(roundedRect: imageRect, xRadius: settings.layoutStyle == .gallery ? 5 : 0, yRadius: settings.layoutStyle == .gallery ? 5 : 0).fill()

            if let imageData, let image = NSImage(data: imageData) {
                let fitted = aspectFit(image.size, inside: imageRect.insetBy(dx: 4, dy: 4))
                image.draw(
                    in: fitted,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
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
        let alignment: NSTextAlignment = settings.layoutStyle == .editorial ? .center : .left
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
                color: settings.layoutStyle == .poster ? textColor : accent,
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
}
