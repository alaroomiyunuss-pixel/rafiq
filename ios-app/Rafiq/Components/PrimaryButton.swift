// PATH: ios-app/Rafiq/Components/
// FILENAME: PrimaryButton.swift

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .filled
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case filled, outline, destructive
    }

    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                action()
            }
        }) {
            HStack(spacing: RafiqSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.85)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(RafiqFonts.bodyBold())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
            .overlay {
                if style == .outline {
                    RoundedRectangle(cornerRadius: RafiqRadius.md)
                        .stroke(borderColor, lineWidth: 1.5)
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }

    private var backgroundColor: Color {
        switch style {
        case .filled:
            return RafiqColors.primaryFallback
        case .outline:
            return .clear
        case .destructive:
            return RafiqColors.errorFallback
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .outline:
            return RafiqColors.primaryFallback
        case .destructive:
            return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline:
            return RafiqColors.primaryFallback
        default:
            return .clear
        }
    }
}

// MARK: - Preview

#Preview("Primary Buttons") {
    VStack(spacing: RafiqSpacing.md) {
        PrimaryButton(title: "تأكيد الحجز", icon: "checkmark.circle.fill") {}

        PrimaryButton(title: "جاري التحميل...", isLoading: true) {}

        PrimaryButton(title: "البحث عن رحلة", style: .outline, icon: "magnifyingglass") {}

        PrimaryButton(title: "إلغاء الحجز", style: .destructive, icon: "xmark.circle.fill") {}

        PrimaryButton(title: "غير متاح", isDisabled: true) {}
    }
    .padding()
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}
