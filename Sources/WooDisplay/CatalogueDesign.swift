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
    case georgia
    case dinCondensed
    case menlo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemSans: "System Sans"
        case .avenirNext: "Avenir Next"
        case .georgia: "Georgia"
        case .dinCondensed: "DIN Condensed"
        case .menlo: "Menlo"
        }
    }

    var postScriptName: String? {
        switch self {
        case .systemSans: nil
        case .avenirNext: "AvenirNext-Medium"
        case .georgia: "Georgia"
        case .dinCondensed: "DINCondensed-Bold"
        case .menlo: "Menlo-Regular"
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
    let theme: CatalogueThemePreset
    let accent: RGBAColor
    let pageColor: RGBAColor
    let font: CatalogueFontFamily
    let layoutStyle: CatalogueLayoutStyle

    var textColor: RGBAColor { pageColor.contrastingText }

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
