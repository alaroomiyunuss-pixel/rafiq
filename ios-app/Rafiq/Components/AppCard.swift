// PATH: ios-app/Rafiq/Components/
// FILENAME: AppCard.swift

import SwiftUI

struct AppCard<Content: View>: View {
    var padding: CGFloat = RafiqSpacing.md
    var shadow: RafiqShadow.Style = .light
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RafiqColors.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
        .rafiqShadow(shadow)
    }
}

// MARK: - Convenience: Card with Header

struct AppCardWithHeader<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = RafiqColors.primaryFallback
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppCard {
            // Header
            HStack(spacing: RafiqSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 36, height: 36)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    if let subtitle {
                        Text(subtitle)
                            .font(RafiqFonts.caption())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }
                }

                Spacer()
            }

            Divider()
                .padding(.vertical, RafiqSpacing.sm)

            // Content
            content()
        }
    }
}

// MARK: - Preview

#Preview("App Cards") {
    ScrollView {
        VStack(spacing: RafiqSpacing.md) {
            AppCard {
                Text("بطاقة بسيطة")
                    .font(RafiqFonts.body())
                Text("محتوى البطاقة هنا")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }

            AppCardWithHeader(
                title: "تفاصيل الرحلة",
                subtitle: "الرياض → جدة",
                icon: "car.fill"
            ) {
                HStack {
                    Label("3 مقاعد متاحة", systemImage: "person.3.fill")
                        .font(RafiqFonts.caption())
                    Spacer()
                    Text("150 ر.س")
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.primaryFallback)
                }
            }

            AppCard(shadow: .heavy) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("أحمد محمد")
                            .font(RafiqFonts.bodyBold())
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(RafiqColors.warningFallback)
                                .font(.system(size: 12))
                            Text("4.8")
                                .font(RafiqFonts.caption())
                        }
                    }
                    Spacer()
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
        }
        .padding()
    }
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}
