import AppKit
import SwiftUI

struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let cobalt = RGBAColor(red: 0.10, green: 0.32, blue: 0.86)
    static let aubergine = RGBAColor(red: 0.28, green: 0.12, blue: 0.24)
    static let posterOrange = RGBAColor(red: 0.74, green: 0.29, blue: 0.10)
    static let forest = RGBAColor(red: 0.12, green: 0.34, blue: 0.25)
    static let nordicBlue = RGBAColor(red: 0.30, green: 0.47, blue: 0.56)
    static let midnightBlue = RGBAColor(red: 0.32, green: 0.72, blue: 0.96)
    static let terracotta = RGBAColor(red: 0.72, green: 0.25, blue: 0.16)
    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let ivory = RGBAColor(red: 0.98, green: 0.96, blue: 0.91)
    static let cream = RGBAColor(red: 1.00, green: 0.98, blue: 0.87)
    static let sage = RGBAColor(red: 0.91, green: 0.94, blue: 0.89)
    static let ink = RGBAColor(red: 0.08, green: 0.09, blue: 0.11)
    static let softGray = RGBAColor(red: 0.965, green: 0.97, blue: 0.98)
    static let midnight = RGBAColor(red: 0.045, green: 0.065, blue: 0.11)

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

enum CatalogueFontFamily: String, CaseIterable, Codable, Identifiable, Sendable {
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

enum CatalogueLayoutStyle: String, Codable, Sendable {
    case studio
    case editorial
    case poster
    case gallery
}

enum SettingsInspectorMode: String, CaseIterable, Identifiable, Sendable {
    case layout
    case theme

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .layout: "rectangle.3.group"
        case .theme: "paintpalette"
        }
    }
}

enum CatalogueSortOrder: String, CaseIterable, Codable, Identifiable, Sendable {
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

enum CatalogueTextAlignment: String, CaseIterable, Codable, Identifiable, Sendable {
    case leading
    case center
    case trailing

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CatalogueImageFit: String, CaseIterable, Codable, Identifiable, Sendable {
    case contain
    case fill

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CatalogueCornerStyle: String, CaseIterable, Codable, Identifiable, Sendable {
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

enum CatalogueBorderStyle: String, CaseIterable, Codable, Identifiable, Sendable {
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

enum CatalogueSpacing: String, CaseIterable, Codable, Identifiable, Sendable {
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

enum CatalogueThemePreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case studio
    case editorial
    case poster
    case gallery
    case nordic
    case midnight
    case terracotta
    case mono
    case custom

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var accent: RGBAColor {
        switch self {
        case .studio, .custom: .cobalt
        case .editorial: .aubergine
        case .poster: .posterOrange
        case .gallery: .forest
        case .nordic: .nordicBlue
        case .midnight: .midnightBlue
        case .terracotta: .terracotta
        case .mono: .ink
        }
    }

    var pageColor: RGBAColor {
        switch self {
        case .studio, .custom: .white
        case .editorial: .ivory
        case .poster: RGBAColor(red: 0.985, green: 0.97, blue: 0.93)
        case .gallery: .sage
        case .nordic: RGBAColor(red: 0.96, green: 0.98, blue: 0.985)
        case .midnight: .midnight
        case .terracotta: RGBAColor(red: 0.97, green: 0.91, blue: 0.83)
        case .mono: .white
        }
    }

    var font: CatalogueFontFamily {
        switch self {
        case .studio, .custom: .systemSans
        case .editorial: .optima
        case .poster: .avenirNext
        case .gallery: .avenirNext
        case .nordic: .optima
        case .midnight: .helveticaNeue
        case .terracotta: .baskerville
        case .mono: .menlo
        }
    }

    var layoutStyle: CatalogueLayoutStyle {
        switch self {
        case .studio, .custom: .studio
        case .editorial: .editorial
        case .poster: .poster
        case .gallery: .gallery
        case .nordic: .studio
        case .midnight: .gallery
        case .terracotta: .editorial
        case .mono: .studio
        }
    }

    var textColor: RGBAColor { pageColor.contrastingText }
    var priceColor: RGBAColor { accent }

    var cardColor: RGBAColor {
        switch self {
        case .gallery: .white
        case .editorial, .poster: .white
        case .nordic: .white
        case .midnight: RGBAColor(red: 0.08, green: 0.11, blue: 0.18)
        case .terracotta: RGBAColor(red: 1.0, green: 0.965, blue: 0.91)
        case .mono: .white
        default: pageColor
        }
    }

    var imageBackgroundColor: RGBAColor {
        switch self {
        case .gallery: RGBAColor(red: 0.96, green: 0.97, blue: 0.95)
        case .editorial: RGBAColor(red: 0.955, green: 0.94, blue: 0.91)
        case .poster: RGBAColor(red: 0.96, green: 0.93, blue: 0.87)
        case .nordic: RGBAColor(red: 0.90, green: 0.95, blue: 0.97)
        case .midnight: RGBAColor(red: 0.11, green: 0.15, blue: 0.22)
        case .terracotta: RGBAColor(red: 0.95, green: 0.82, blue: 0.72)
        case .mono: RGBAColor(red: 0.93, green: 0.93, blue: 0.93)
        default: .softGray
        }
    }

    var textAlignment: CatalogueTextAlignment {
        switch self {
        case .editorial: .leading
        default: .leading
        }
    }

    var cornerStyle: CatalogueCornerStyle {
        switch self {
        case .gallery, .midnight: .rounded
        case .nordic, .terracotta: .subtle
        default: .square
        }
    }

    var borderStyle: CatalogueBorderStyle {
        switch self {
        case .mono: .strong
        case .poster: .subtle
        case .midnight: .none
        default: .subtle
        }
    }

    var spacing: CatalogueSpacing {
        switch self {
        case .nordic: .airy
        case .editorial: .comfortable
        case .mono: .compact
        default: .comfortable
        }
    }

    var colors: CatalogueColorTheme {
        CatalogueColorTheme(
            accent: accent,
            page: pageColor,
            text: textColor,
            price: priceColor,
            card: cardColor,
            imageBackground: imageBackgroundColor
        )
    }
}

struct CatalogueColorTheme: Codable, Hashable, Sendable {
    var accent: RGBAColor
    var page: RGBAColor
    var text: RGBAColor
    var price: RGBAColor
    var card: RGBAColor
    var imageBackground: RGBAColor
}

struct CatalogueThemeDocument: Codable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var selectedTheme: CatalogueThemePreset
    var customColors: CatalogueColorTheme
    var font: CatalogueFontFamily
    var layoutStyle: CatalogueLayoutStyle
    var textAlignment: CatalogueTextAlignment
    var imageFit: CatalogueImageFit
    var cornerStyle: CatalogueCornerStyle
    var borderStyle: CatalogueBorderStyle
    var spacing: CatalogueSpacing
    var categoryColors: [String: CatalogueColorTheme]
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
    let companyLogoData: Data?
    let companyLogoSize: Double

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
    let categoryColors: [String: CatalogueColorTheme]

    var globalColors: CatalogueColorTheme {
        CatalogueColorTheme(
            accent: accent,
            page: pageColor,
            text: textColor,
            price: priceColor,
            card: cardColor,
            imageBackground: imageBackgroundColor
        )
    }

    func colors(for category: String?) -> CatalogueColorTheme {
        guard let category else { return globalColors }
        return categoryColors[category] ?? globalColors
    }

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
