import AppKit
import SwiftUI

struct CatalogueView: View {
    @EnvironmentObject private var store: CatalogueStore

    var body: some View {
        VStack(spacing: 0) {
            CatalogueTopBar()
            Divider()

            HStack(spacing: 0) {
                SettingsInspector()
                    .frame(width: 306)
                Divider()
                PreviewWorkspace()
            }
        }
        .background(Color.white)
        .overlay { exportOverlay }
        .alert(
            "Catalogue could not be loaded",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("Choose CSV") { store.importCSV() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "PDF catalogue exported",
            isPresented: Binding(
                get: { store.completedExportURL != nil },
                set: { if !$0 { store.completedExportURL = nil } }
            )
        ) {
            Button("Show in Finder") { store.revealCompletedExport() }
            Button("Done", role: .cancel) { store.completedExportURL = nil }
        } message: {
            Text(store.completedExportURL?.path ?? "")
        }
    }

    @ViewBuilder
    private var exportOverlay: some View {
        if store.isExporting {
            ZStack {
                Color.black.opacity(0.18).ignoresSafeArea()
                VStack(spacing: 13) {
                    ProgressView(value: store.exportProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 230)
                    Text("Creating your catalogue…")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(Int(store.exportProgress * 100))%")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 23)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 24, y: 8)
            }
        }
    }
}

private struct CatalogueTopBar: View {
    @EnvironmentObject private var store: CatalogueStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(store.settings.accent.swiftUIColor)
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.settings.accent.contrastingText.swiftUIColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("WooDisplay")
                    .font(.system(size: 16, weight: .bold))
                Text(store.sourceName.isEmpty ? "No CSV selected" : "\(store.sourceName)  •  \(store.products.count) products")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: store.importCSV) {
                Label("Import CSV", systemImage: "square.and.arrow.down")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: store.exportPDF) {
                Label("Export PDF", systemImage: "arrow.up.doc.fill")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(PrimaryActionButtonStyle(accent: store.settings.accent.swiftUIColor))
            .disabled(store.products.isEmpty || store.isExporting)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color.white)
    }
}

private struct SettingsInspector: View {
    @EnvironmentObject private var store: CatalogueStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                contentSection
                layoutSection
                themeSection
                customSection
            }
            .padding(18)
        }
        .background(AppPalette.inspector)
    }

    private var contentSection: some View {
        InspectorSection(title: "CONTENT", subtitle: "Choose what appears on each product.") {
            VStack(alignment: .leading, spacing: 8) {
                ContentToggle("Product image", isOn: $store.showImage)
                ContentToggle("Product name", isOn: $store.showName)
                ContentToggle("Price", isOn: $store.showPrice)
                Divider().padding(.vertical, 2)
                ContentToggle("SKU", isOn: $store.showSKU)
                ContentToggle("Category", isOn: $store.showCategory)
                ContentToggle("Stock", isOn: $store.showStock)
                ContentToggle("Brand", isOn: $store.showBrand)
                ContentToggle("Description", isOn: $store.showDescription)
            }
        }
    }

    private var layoutSection: some View {
        InspectorSection(title: "LAYOUT", subtitle: "Keep it airy or fit more products.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Products per page")
                    .font(.system(size: 11.5, weight: .medium))

                HStack(spacing: 5) {
                    ForEach([6, 9, 12, 16], id: \.self) { count in
                        Button {
                            store.setProductsPerPage(count)
                        } label: {
                            Text("\(count)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 27)
                                .foregroundStyle(store.productsPerPage == count ? Color.white : Color.primary)
                                .background(store.productsPerPage == count ? store.settings.accent.swiftUIColor : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(AppPalette.border)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                ContentToggle("Page header", isOn: $store.showPageHeader)
                if store.showPageHeader {
                    TextField("Catalogue title", text: $store.catalogueTitle)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var themeSection: some View {
        InspectorSection(title: "THEME", subtitle: "Four distinct presets, plus your own.") {
            HStack(spacing: 7) {
                ForEach(CatalogueThemePreset.allCases) { theme in
                    ThemeSwatch(theme: theme, isSelected: store.selectedTheme == theme) {
                        store.selectTheme(theme)
                    }
                }
            }
        }
    }

    private var customSection: some View {
        InspectorSection(title: "CUSTOMIZE", subtitle: "Changing a value activates Custom.") {
            VStack(spacing: 9) {
                ColorPicker("Accent color", selection: accentBinding, supportsOpacity: false)
                    .font(.system(size: 11.5))
                ColorPicker("Page color", selection: pageColorBinding, supportsOpacity: false)
                    .font(.system(size: 11.5))
                Picker("Font", selection: fontBinding) {
                    ForEach(CatalogueFontFamily.allCases) { font in
                        Text(font.title).tag(font)
                    }
                }
                .font(.system(size: 11.5))
            }
        }
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { store.settings.accent.swiftUIColor },
            set: { store.customizeAccent(RGBAColor(nsColor: NSColor($0))) }
        )
    }

    private var pageColorBinding: Binding<Color> {
        Binding(
            get: { store.settings.pageColor.swiftUIColor },
            set: { store.customizePageColor(RGBAColor(nsColor: NSColor($0))) }
        )
    }

    private var fontBinding: Binding<CatalogueFontFamily> {
        Binding(
            get: { store.settings.font },
            set: { store.customizeFont($0) }
        )
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            content
        }
    }
}

private struct ContentToggle: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.checkbox)
            .font(.system(size: 11.5))
    }
}

private struct ThemeSwatch: View {
    let theme: CatalogueThemePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(theme.pageColor.swiftUIColor)
                    if theme == .custom {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 3) {
                            Rectangle().fill(theme.accent.swiftUIColor).frame(height: 4)
                            HStack(spacing: 2) {
                                Rectangle().fill(theme.accent.swiftUIColor.opacity(0.2))
                                Rectangle().fill(theme.accent.swiftUIColor.opacity(0.35))
                            }
                        }
                        .padding(5)
                    }
                }
                .frame(height: 38)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isSelected ? theme.accent.swiftUIColor : AppPalette.border, lineWidth: isSelected ? 2 : 1)
                }

                Text(theme.title)
                    .font(.system(size: 8.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewWorkspace: View {
    @EnvironmentObject private var store: CatalogueStore

    var body: some View {
        GeometryReader { geometry in
            let navHeight: CGFloat = 50
            let availableWidth = max(1, geometry.size.width - 80)
            let availableHeight = max(1, geometry.size.height - navHeight - 38)
            let scale = min(availableWidth / 612, availableHeight / 792, 1.05)

            VStack(spacing: 0) {
                Spacer(minLength: 18)
                PDFPagePreview(
                    products: store.pageProducts,
                    pageNumber: store.currentPage + 1,
                    pageCount: store.pageCount,
                    settings: store.settings
                )
                .frame(width: 612, height: 792)
                .scaleEffect(scale)
                .frame(width: 612 * scale, height: 792 * scale)
                .shadow(color: .black.opacity(0.20), radius: 18, y: 8)
                Spacer(minLength: 12)
                PageNavigator()
                    .frame(height: navHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppPalette.canvas)
    }
}

private struct PageNavigator: View {
    @EnvironmentObject private var store: CatalogueStore

    var body: some View {
        HStack(spacing: 13) {
            Button(action: store.previousPage) {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.bordered)
            .disabled(store.currentPage == 0)

            Text("Page \(store.currentPage + 1) of \(store.pageCount)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 96)

            Button(action: store.nextPage) {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.bordered)
            .disabled(store.currentPage >= store.pageCount - 1)
        }
    }
}
