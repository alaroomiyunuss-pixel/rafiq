// PATH: ios-app/Rafiq/Design/
// FILENAME: Theme.swift

import SwiftUI

// MARK: - Colors

enum RafiqColors {
    static let primary = Color("Primary", bundle: nil)
    static let primaryDark = Color("PrimaryDark", bundle: nil)
    static let accent = Color("Accent", bundle: nil)
    static let background = Color("Background", bundle: nil)
    static let surface = Color("Surface", bundle: nil)
    static let textPrimary = Color("TextPrimary", bundle: nil)
    static let textSecondary = Color("TextSecondary", bundle: nil)
    static let success = Color("Success", bundle: nil)
    static let warning = Color("Warning", bundle: nil)
    static let error = Color("Error", bundle: nil)

    // Fallback initializers (used until Asset Catalog is configured)
    static let primaryFallback = Color(hex: "#1B6B4A")
    static let primaryDarkFallback = Color(hex: "#0F4030")
    static let accentFallback = Color(hex: "#CD7C5E")
    static let backgroundFallback = Color(hex: "#F5F2ED")
    static let surfaceFallback = Color.white
    static let textPrimaryFallback = Color(hex: "#1A1A1A")
    static let textSecondaryFallback = Color(hex: "#6B7280")
    static let successFallback = Color(hex: "#10B981")
    static let warningFallback = Color(hex: "#F59E0B")
    static let errorFallback = Color(hex: "#EF4444")
}

// MARK: - Typography

enum RafiqFonts {
    static func heading1() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    static func heading2() -> Font {
        .system(size: 22, weight: .bold, design: .rounded)
    }

    static func heading3() -> Font {
        .system(size: 18, weight: .semibold, design: .rounded)
    }

    static func body() -> Font {
        .system(size: 16, weight: .regular)
    }

    static func bodyBold() -> Font {
        .system(size: 16, weight: .semibold)
    }

    static func caption() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func small() -> Font {
        .system(size: 11, weight: .medium)
    }
}

// MARK: - Spacing

enum RafiqSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum RafiqRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

// MARK: - Shadows

struct RafiqShadow: ViewModifier {
    enum Style {
        case light, medium, heavy
    }

    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .light:
            content.shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        case .medium:
            content.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        case .heavy:
            content.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        }
    }
}

extension View {
    func rafiqShadow(_ style: RafiqShadow.Style = .medium) -> some View {
        modifier(RafiqShadow(style: style))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("Theme Colors") {
    ScrollView {
        VStack(spacing: RafiqSpacing.md) {
            Text("ألوان رفيق")
                .font(RafiqFonts.heading1())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                colorSwatch("Primary", RafiqColors.primaryFallback)
                colorSwatch("Primary Dark", RafiqColors.primaryDarkFallback)
                colorSwatch("Accent", RafiqColors.accentFallback)
                colorSwatch("Background", RafiqColors.backgroundFallback)
                colorSwatch("Success", RafiqColors.successFallback)
                colorSwatch("Warning", RafiqColors.warningFallback)
                colorSwatch("Error", RafiqColors.errorFallback)
                colorSwatch("Text Secondary", RafiqColors.textSecondaryFallback)
            }
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}

@ViewBuilder
private func colorSwatch(_ name: String, _ color: Color) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: RafiqRadius.sm)
            .fill(color)
            .frame(height: 60)
        Text(name)
            .font(RafiqFonts.caption())
    }
}
