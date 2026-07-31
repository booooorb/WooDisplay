import AppKit
import SwiftUI

struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let cobalt = RGBAColor(red: 0.10, green: 0.32, blue: 0.86)
    static let aubergine = RGBAColor(red: 0.28, green: 0.12, blue: 0.24)
    static let posterYellow = RGBAColor(red: 0.96, green: 0.78, blue: 0.16)
    static let forest = RGBAColor(red: 0.12, green: 0.34, blue: 0.25)
    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let ivory = RGBAColor(red: 0.98, green: 0.96, blue: 0.91)
    static let cream = RGBAColor(red: 1.00, green: 0.98, blue: 0.87)
    static let sage = RGBAColor(red: 0.91, green: 0.94, blue: 0.89)
    static let ink = RGBAColor(red: 0.08, green: 0.09, blue: 0.11)
    static let softGray = RGBAColor(red: 0.965, green: 0.97, blue: 0.98)

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var contrastingText: RGBAColor {
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58 ? .ink : .white
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        red = Double(converted.redComponent)
        green = Double(converted.greenComponent)
        blue = Double(converted.blueComponent)
        alpha = Double(converted.alphaComponent)
    }
}

enum CatalogueFontFamily: String, CaseIterable, Identifiable, Sendable {
    case systemSans
    case avenirNext
    case helveticaNeue
    case futura
    case gillSans
    case optima
    case georgia
    case baskerville
    case palatino
    case copperplate
    case dinCondensed
    case menlo
    case courier

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemSans: "System Sans"
        case .avenirNext: "Avenir Next"
        case .helveticaNeue: "Helvetica Neue"
        case .futura: "Futura"
        case .gillSans: "Gill Sans"
        case .optima: "Optima"
        case .georgia: "Georgia"
        case .baskerville: "Baskerville"
        case .palatino: "Palatino"
        case .copperplate: "Copperplate"
        case .dinCondensed: "DIN Condensed"
        case .menlo: "Menlo"
        case .courier: "Courier"
        }
    }

    var postScriptName: String? {
        switch self {
        case .systemSans: nil
        case .avenirNext: "AvenirNext-Medium"
        case .helveticaNeue: "HelveticaNeue"
        case .futura: "Futura-Medium"
        case .gillSans: "GillSans"
        case .optima: "Optima-Regular"
        case .georgia: "Georgia"
        case .baskerville: "Baskerville"
        case .palatino: "Palatino-Roman"
        case .copperplate: "Copperplate"
        case .dinCondensed: "DINCondensed-Bold"
        case .menlo: "Menlo-Regular"
        case .courier: "Courier"
        }
    }

    func swiftUIFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let postScriptName {
            return .custom(postScriptName, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if let postScriptName, let font = NSFont(name: postScriptName, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: weight)
    }
}

enum CatalogueLayoutStyle: String, Sendable {
    case studio
    case editorial
    case poster
    case gallery
}

enum CatalogueSortOrder: String, CaseIterable, Identifiable, Sendable {
    case categoryThenName
    case name
    case priceLow
    case priceHigh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categoryThenName: "Category, then name"
        case .name: "Product name"
        case .priceLow: "Price, low to high"
        case .priceHigh: "Price, high to low"
        }
    }
}

enum CatalogueTextAlignment: String, CaseIterable, Identifiable, Sendable {
    case leading
    case center
    case trailing

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CatalogueImageFit: String, CaseIterable, Identifiable, Sendable {
    case contain
    case fill

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CatalogueCornerStyle: String, CaseIterable, Identifiable, Sendable {
    case square
    case subtle
    case rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: "Square"
        case .subtle: "Subtle"
        case .rounded: "Rounded"
        }
    }

    var radius: CGFloat {
        switch self {
        case .square: 0
        case .subtle: 5
        case .rounded: 10
        }
    }
}

enum CatalogueBorderStyle: String, CaseIterable, Identifiable, Sendable {
    case none
    case subtle
    case strong

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var width: CGFloat {
        switch self {
        case .none: 0
        case .subtle: 0.75
        case .strong: 2
        }
    }

    var opacity: Double {
        switch self {
        case .none: 0
        case .subtle: 0.18
        case .strong: 0.85
        }
    }
}

enum CatalogueSpacing: String, CaseIterable, Identifiable, Sendable {
    case compact
    case comfortable
    case airy

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var gap: CGFloat {
        switch self {
        case .compact: 6
        case .comfortable: 10
        case .airy: 16
        }
    }
}

enum CatalogueThemePreset: String, CaseIterable, Identifiable, Sendable {
    case studio
    case editorial
    case poster
    case gallery
    case custom

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var accent: RGBAColor {
        switch self {
        case .studio, .custom: .cobalt
        case .editorial: .aubergine
        case .poster: .posterYellow
        case .gallery: .forest
        }
    }

    var pageColor: RGBAColor {
        switch self {
        case .studio, .custom: .white
        case .editorial: .ivory
        case .poster: .cream
        case .gallery: .sage
        }
    }

    var font: CatalogueFontFamily {
        switch self {
        case .studio, .custom: .systemSans
        case .editorial: .georgia
        case .poster: .dinCondensed
        case .gallery: .avenirNext
        }
    }

    var layoutStyle: CatalogueLayoutStyle {
        switch self {
        case .studio, .custom: .studio
        case .editorial: .editorial
        case .poster: .poster
        case .gallery: .gallery
        }
    }

    var textColor: RGBAColor { pageColor.contrastingText }
    var priceColor: RGBAColor { layoutStyle == .poster ? textColor : accent }

    var cardColor: RGBAColor {
        switch self {
        case .gallery: .white
        case .poster: RGBAColor(red: 1, green: 0.95, blue: 0.68)
        default: pageColor
        }
    }

    var imageBackgroundColor: RGBAColor {
        switch self {
        case .gallery: RGBAColor(red: 0.96, green: 0.97, blue: 0.95)
        case .editorial: RGBAColor(red: 0.95, green: 0.92, blue: 0.87)
        case .poster: RGBAColor(red: 1, green: 0.97, blue: 0.82)
        default: .softGray
        }
    }

    var textAlignment: CatalogueTextAlignment {
        layoutStyle == .editorial ? .center : .leading
    }

    var cornerStyle: CatalogueCornerStyle {
        layoutStyle == .gallery ? .rounded : .square
    }

    var borderStyle: CatalogueBorderStyle {
        layoutStyle == .poster ? .strong : .subtle
    }

    var spacing: CatalogueSpacing {
        layoutStyle == .editorial ? .airy : .comfortable
    }
}

struct CatalogueSettingsSnapshot: Sendable {
    let showImage: Bool
    let showName: Bool
    let showPrice: Bool
    let showSKU: Bool
    let showCategory: Bool
    let showStock: Bool
    let showBrand: Bool
    let showDescription: Bool
    let productsPerPage: Int
    let showPageHeader: Bool
    let catalogueTitle: String

    let groupByCategory: Bool
    let sortOrder: CatalogueSortOrder
    let categoryOrder: [String]

    let theme: CatalogueThemePreset
    let accent: RGBAColor
    let pageColor: RGBAColor
    let textColor: RGBAColor
    let priceColor: RGBAColor
    let cardColor: RGBAColor
    let imageBackgroundColor: RGBAColor
    let font: CatalogueFontFamily
    let layoutStyle: CatalogueLayoutStyle
    let textAlignment: CatalogueTextAlignment
    let imageFit: CatalogueImageFit
    let cornerStyle: CatalogueCornerStyle
    let borderStyle: CatalogueBorderStyle
    let spacing: CatalogueSpacing

    var columns: Int {
        switch productsPerPage {
        case 6: 2
        case 16: 4
        default: 3
        }
    }

    var rows: Int {
        max(1, Int(ceil(Double(productsPerPage) / Double(columns))))
    }
}
